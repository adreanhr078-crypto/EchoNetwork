"""Expand nested DCC packages into working copies, never source directories."""
import hashlib
import io
import json
from pathlib import Path, PurePosixPath
import subprocess
import tarfile
import zipfile

from inventory import file_hash, write_json, ANIMATION_EXTENSIONS

PACKAGED = {".zip", ".rar", ".unitypackage"}
WORK_FORMATS = ANIMATION_EXTENSIONS | PACKAGED | {".txt", ".md", ".bip", ".i_caf", ".rlmotion", ".uasset", ".max", ".ma"}


def main():
    app = Path.cwd().resolve()
    base = app / "art/production/master-animation-library/manifests"
    inventory = json.loads((base / "SourceInventory.json").read_text(encoding="utf-8"))
    working = app / ".tmp/master-animation-library/sources"
    original_files = list(inventory["files"])
    children = []
    archives = {a["path"]: a["working_archive"] for a in inventory["archives"]}

    def cache(data, suffix):
        digest = hashlib.sha256(data).hexdigest()
        target = working / (digest + suffix.lower())
        if target.exists():
            if file_hash(target) != digest:
                raise ValueError("Work cache corruption")
        else:
            target.write_bytes(data)
        return target, digest

    def add(parent, entry, data, depth):
        if depth > 5:
            raise ValueError("Unexpected package nesting depth")
        logical = PurePosixPath(entry.replace("\\", "/"))
        if logical.is_absolute() or ".." in logical.parts or ":" in str(logical):
            raise ValueError(f"Unsafe nested source entry: {entry}")
        suffix = logical.suffix.lower()
        digest = hashlib.sha256(data).hexdigest()
        target = None
        if suffix in WORK_FORMATS:
            target, digest = cache(data, suffix)
        source_id = parent["source_id"] + "!" + entry
        record = {"source_id": source_id, "source_pack": parent["source_pack"],
                  "archive_path": parent["archive_path"] + "!" + parent["source_entry"],
                  "archive_sha256": parent["sha256"], "entry_index": None,
                  "source_entry": entry, "original_filename": logical.name, "bytes": len(data),
                  "sha256": digest, "extension": suffix, "parent_source_id": parent["source_id"],
                  "working_copy": str(target.relative_to(app)).replace("\\", "/") if target else None,
                  "inspection_status": "pending" if suffix in ANIMATION_EXTENSIONS else "format_or_document_review",
                  "license_status": "needs_source_document_review"}
        children.append(record)
        if suffix in PACKAGED and target:
            expand(record, target, depth + 1)

    def expand(parent, path, depth):
        if path.suffix.lower() == ".zip":
            with zipfile.ZipFile(path) as z:
                for info in z.infolist():
                    if not info.is_dir():
                        add(parent, info.filename, z.read(info), depth)
        elif path.suffix.lower() == ".unitypackage":
            with tarfile.open(path, "r:gz") as t:
                names = t.getnames()
                for name in names:
                    if name.endswith("/pathname"):
                        stream = t.extractfile(name)
                        if stream is None:
                            continue
                        logical = stream.read().decode("utf-8-sig").strip()
                        asset_name = name.rsplit("/", 1)[0] + "/asset"
                        if asset_name in names:
                            asset = t.extractfile(asset_name)
                            if asset:
                                add(parent, logical, asset.read(), depth)
        elif path.suffix.lower() == ".rar":
            seven = Path(r"C:\Program Files\7-Zip\7z.exe")
            listing = subprocess.run([str(seven), "l", "-slt", str(path)], capture_output=True, text=True, check=True).stdout
            member_section = listing.split("----------", 1)[-1]
            for line in member_section.splitlines():
                if line.startswith("Path = "):
                    p = PurePosixPath(line[7:].replace("\\", "/"))
                    if p.is_absolute() or ".." in p.parts or ":" in str(p):
                        raise ValueError("Unsafe RAR entry")
            destination = app / ".tmp/master-animation-library/package_extracted" / parent["sha256"]
            destination.mkdir(parents=True, exist_ok=True)
            if not destination.resolve().is_relative_to((app / ".tmp").resolve()):
                raise ValueError("Package destination escaped work directory")
            subprocess.run([str(seven), "x", str(path), "-o" + str(destination), "-aos", "-y"], capture_output=True, check=True)
            for child in destination.rglob("*"):
                if child.is_file():
                    add(parent, child.relative_to(destination).as_posix(), child.read_bytes(), depth)

    for record in original_files:
        extension = record["extension"]
        if extension not in WORK_FORMATS or record.get("parent_source_id"):
            continue
        if record["working_copy"]:
            path = app / record["working_copy"]
        else:
            with zipfile.ZipFile(archives[record["archive_path"]]) as archive:
                info = archive.infolist()[record["entry_index"]]
                path, digest = cache(archive.read(info), extension)
                if digest != record["sha256"]:
                    raise ValueError("Pack entry no longer matches preserved hash")
            record["working_copy"] = str(path.relative_to(app)).replace("\\", "/")
            record["inspection_status"] = "pending" if extension in ANIMATION_EXTENSIONS else "format_or_document_review"
        if extension in PACKAGED:
            expand(record, path, 1)
    known = {r["source_id"] for r in original_files}
    inventory["files"] = original_files + [r for r in children if r["source_id"] not in known]
    inventory["nested_packages_expanded"] = True
    inventory["animation_scene_entries"] = sum(r["extension"] in ANIMATION_EXTENSIONS for r in inventory["files"])
    inventory["unique_animation_scene_files"] = len({r["sha256"] for r in inventory["files"] if r["extension"] in ANIMATION_EXTENSIONS})
    inventory["status"] = "nested_file_inventory_complete_take_inventory_pending"
    write_json(base / "SourceInventory.json", inventory)
    print(json.dumps({"nested_entries": len(children), "animation_scene_entries": inventory["animation_scene_entries"],
                      "unique_animation_scene_files": inventory["unique_animation_scene_files"]}))


if __name__ == "__main__":
    main()

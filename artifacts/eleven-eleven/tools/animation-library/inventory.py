"""Read-only source inventory and content-addressed working copies.

Original archives and files are never changed. Resume uses SHA-256, not filenames.
Run from the active application root; output manifests live outside res://.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import zipfile

PACKS = {
    "Rokoko": "روكوكو انيميشن.zip",
    "Mixamo": "ميكسامو انيميشن.zip",
    "Motus_MCO": "موكاب انيميشن.zip",
    "Motifect": "موتيفيكت انيميشن.zip",
}
ANIMATION_EXTENSIONS = {".fbx", ".bvh", ".glb", ".gltf", ".blend"}


def file_hash(path):
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def write_json(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    temp = path.with_suffix(path.suffix + ".partial")
    temp.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    os.replace(temp, path)


def inventory(app, downloads):
    manifests = app / "art/production/master-animation-library/manifests"
    staging = app / ".tmp/master-animation-library/sources"
    staging.mkdir(parents=True, exist_ok=True)
    outer = downloads / "انيميشن ايكو نيتوورك.zip"
    wrapper = {"path": str(outer), "sha256_before": file_hash(outer), "nested_archives": []}
    archive_cache = app / ".tmp/master-animation-library/archives"
    archive_cache.mkdir(parents=True, exist_ok=True)
    nested = {}
    with zipfile.ZipFile(outer) as container:
        for info in container.infolist():
            if info.is_dir():
                continue
            filename = PurePosixPath(info.filename.replace("\\", "/")).name
            if filename not in PACKS.values():
                raise ValueError(f"Unexpected top-level source entry: {info.filename}")
            temp = archive_cache / (hashlib.sha256(info.filename.encode()).hexdigest() + ".partial")
            h = hashlib.sha256()
            with container.open(info) as stream, temp.open("wb") as output:
                for block in iter(lambda: stream.read(1024 * 1024), b""):
                    h.update(block)
                    output.write(block)
            target = archive_cache / (h.hexdigest() + ".zip")
            if target.exists():
                if file_hash(target) != h.hexdigest():
                    raise ValueError("Cached source archive hash mismatch")
                temp.unlink()  # disposable work file only; never a source
            else:
                temp.rename(target)
            if filename in nested:
                raise ValueError(f"Duplicate top-level archive name: {filename}")
            nested[filename] = (target, info.filename)
            external = downloads / filename
            matches = external.exists() and file_hash(external) == h.hexdigest()
            wrapper["nested_archives"].append({"entry": info.filename, "sha256": h.hexdigest(), "matches_external_copy": matches})
            print(json.dumps({"nested_archive": filename, "cached": True}), flush=True)
    if set(nested) != set(PACKS.values()):
        raise ValueError("Source wrapper is missing an expected pack")
    records, archives = [], []
    for pack, filename in PACKS.items():
        archive, container_entry = nested[filename]
        initial = file_hash(archive)
        source_path = str(outer) + "!" + container_entry
        archives.append({"pack": pack, "path": source_path, "working_archive": str(archive), "bytes": archive.stat().st_size,
                         "sha256_before": initial, "sha256_after": None})
        with zipfile.ZipFile(archive) as source:
            for ordinal, info in enumerate(source.infolist()):
                if info.is_dir():
                    continue
                logical = PurePosixPath(info.filename.replace("\\", "/"))
                if logical.is_absolute() or ".." in logical.parts or ":" in str(logical):
                    raise ValueError(f"Unsafe archive entry in {filename}: {info.filename}")
                extension = logical.suffix.lower()
                h = hashlib.sha256()
                with source.open(info) as stream:
                    for block in iter(lambda: stream.read(1024 * 1024), b""):
                        h.update(block)
                digest = h.hexdigest()
                working = None
                if extension in ANIMATION_EXTENSIONS:
                    target = staging / (digest + extension)
                    if target.exists():
                        if file_hash(target) != digest:
                            raise ValueError(f"Working copy hash mismatch: {target}")
                    else:
                        with source.open(info) as stream, target.open("xb") as output:
                            for block in iter(lambda: stream.read(1024 * 1024), b""):
                                output.write(block)
                        if file_hash(target) != digest:
                            raise ValueError(f"Extraction hash mismatch: {target}")
                    working = str(target.relative_to(app)).replace("\\", "/")
                records.append({"source_id": f"{pack.lower()}:{ordinal}", "source_pack": pack,
                                "archive_path": source_path, "archive_sha256": initial,
                                "entry_index": ordinal, "source_entry": info.filename,
                                "original_filename": logical.name, "bytes": info.file_size,
                                "sha256": digest, "extension": extension,
                                "working_copy": working, "inspection_status": "pending" if working else "non_animation_entry",
                                "license_status": "needs_source_document_review"})
        archives[-1]["sha256_after"] = file_hash(archive)
        if initial != archives[-1]["sha256_after"]:
            raise ValueError(f"Source changed while reading: {archive}")
        write_json(manifests / "SourceInventory.json", {"schema_version": 1, "status": "in_progress",
                   "archives": archives, "files": records})
        print(json.dumps({"pack": pack, "entries": len(records), "status": "source_preserved"}), flush=True)
    wrapper["sha256_after"] = file_hash(outer)
    if wrapper["sha256_before"] != wrapper["sha256_after"]:
        raise ValueError("Outer archive changed")
    by_hash = {}
    for record in records:
        if record["working_copy"]:
            by_hash.setdefault(record["sha256"], []).append(record["source_id"])
    result = {"schema_version": 1, "status": "file_inventory_complete_take_inventory_pending",
              "originals_preserved": True, "archives": archives, "wrapper": wrapper,
              "animation_scene_entries": sum(bool(r["working_copy"]) for r in records),
              "unique_animation_scene_files": len(by_hash), "files": records,
              "byte_identical_groups": [v for v in by_hash.values() if len(v) > 1]}
    write_json(manifests / "SourceInventory.json", result)
    print(json.dumps({k: result[k] for k in ("status", "animation_scene_entries", "unique_animation_scene_files", "originals_preserved")}), flush=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--app", type=Path, default=Path.cwd())
    parser.add_argument("--downloads", type=Path, default=Path.home() / "Downloads")
    args = parser.parse_args()
    inventory(args.app.resolve(), args.downloads.resolve())

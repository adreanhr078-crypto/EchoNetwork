"""Read declared FBX/BVH time bases without changing or importing the source."""
import json
from pathlib import Path
import struct

from inventory import write_json, ANIMATION_EXTENSIONS

TIME_MODES = {1: 120, 2: 100, 3: 60, 4: 50, 5: 48, 6: 30, 7: 30,
              8: 30000 / 1001, 9: 30000 / 1001, 10: 25, 11: 24, 12: 1000,
              13: 24000 / 1001, 15: 96, 16: 72, 17: 60000 / 1001}


def property_value(stream):
    code = stream.read(1)
    scalar = {b"Y": ("h", 2), b"C": ("?", 1), b"I": ("i", 4), b"F": ("f", 4),
              b"D": ("d", 8), b"L": ("q", 8)}
    if code in scalar:
        fmt, size = scalar[code]
        return struct.unpack("<" + fmt, stream.read(size))[0]
    if code in (b"S", b"R"):
        length = struct.unpack("<I", stream.read(4))[0]
        raw = stream.read(length)
        return raw.decode("utf-8", errors="replace") if code == b"S" else None
    if code in (b"f", b"d", b"l", b"i", b"b", b"c"):
        count, encoding, size = struct.unpack("<III", stream.read(12))
        stream.seek(size, 1)
        return None
    raise ValueError(f"Unknown FBX property code {code!r}")


def fbx_metadata(path):
    values = {}
    with path.open("rb") as stream:
        header = stream.read(27)
        if not header.startswith(b"Kaydara FBX Binary"):
            return {"status": "ascii_fbx_metadata_adapter_pending", "source_fps": None}
        version = struct.unpack("<I", header[23:27])[0]
        wide = version >= 7500
        size = 25 if wide else 13

        def node(collect=False):
            raw = stream.read(size)
            if len(raw) != size:
                return False
            end, count, length, name_length = struct.unpack("<QQQB" if wide else "<IIIB", raw)
            if end == 0:
                return False
            name = stream.read(name_length).decode("utf-8", errors="replace")
            if collect or name == "GlobalSettings":
                props = [property_value(stream) for _ in range(count)]
                if name == "P" and props and props[0] in ("TimeMode", "CustomFrameRate", "UnitScaleFactor", "OriginalUnitScaleFactor", "UpAxis", "UpAxisSign", "FrontAxis", "FrontAxisSign", "CoordAxis", "CoordAxisSign"):
                    values[props[0]] = props[-1]
                while stream.tell() < end - size:
                    if not node(True):
                        break
            stream.seek(end)
            return True

        while node():
            if "TimeMode" in values:
                break
    mode = values.get("TimeMode")
    fps = values.get("CustomFrameRate") if mode == 14 else TIME_MODES.get(mode)
    if fps is not None and fps <= 0:
        fps = None
    return {"status": "declared_source_metadata" if fps else "source_fps_unresolved",
            "source_fps": fps, "fbx_version": version, "global_settings": values}


def main():
    app = Path.cwd()
    base = app / "art/production/master-animation-library/manifests"
    inventory = json.loads((base / "SourceInventory.json").read_text(encoding="utf-8"))
    results = {}
    for record in inventory["files"]:
        digest = record["sha256"]
        if digest in results or record["extension"] not in ANIMATION_EXTENSIONS:
            continue
        path = app / record["working_copy"]
        try:
            if path.suffix == ".fbx":
                result = fbx_metadata(path)
            elif path.suffix == ".bvh":
                text = path.read_text(encoding="utf-8-sig", errors="replace")
                line = next(line for line in text.splitlines() if line.strip().startswith("Frame Time:"))
                result = {"status": "declared_source_metadata", "source_fps": 1 / float(line.split(":", 1)[1]), "time_base_line": line.strip()}
            else:
                result = {"status": "metadata_adapter_pending", "source_fps": None}
        except Exception as exc:
            result = {"status": "metadata_read_failed", "source_fps": None, "error": str(exc)}
        results[digest] = result
    write_json(base / "SourceMetadata.json", {"schema_version": 1, "files": results})
    from collections import Counter
    print(json.dumps(dict(Counter(r["status"] for r in results.values()))))


if __name__ == "__main__":
    main()

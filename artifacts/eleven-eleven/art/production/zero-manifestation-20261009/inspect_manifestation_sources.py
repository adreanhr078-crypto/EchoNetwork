"""Read-only glTF provenance and mesh/bone coordinates; no opaque scene claims."""
import hashlib
import json
import math
import struct
from pathlib import Path

APP = Path(__file__).resolve().parents[3]
CASE = Path(__file__).resolve().parent
FILES = {
    "wing_source": APP / "art/production/tripo-20261007/echo-shadow-wing-v1/tripo-out/echo-shadow-wing-v1-20261008-dc3f46f8/model.glb",
    "echo_current": APP / "godot/assets/characters/echo_opening_uniform_v13.glb",
    "echo_prospective": APP / "audits/evidence/quality-execution-20261006/current-target/supplied-v31-20261007/source-reference-v8/echo-v31-measured-reference.glb",
}


def multiply(a, b):
    return [[sum(a[r][k] * b[k][c] for k in range(4)) for c in range(4)] for r in range(4)]


def transform(node):
    if "matrix" in node:
        return [[node["matrix"][r + c * 4] for c in range(4)] for r in range(4)]
    x, y, z, w = node.get("rotation", [0, 0, 0, 1])
    sx, sy, sz = node.get("scale", [1, 1, 1])
    t = node.get("translation", [0, 0, 0])
    return [
        [(1-2*y*y-2*z*z)*sx, (2*x*y-2*z*w)*sy, (2*x*z+2*y*w)*sz, t[0]],
        [(2*x*y+2*z*w)*sx, (1-2*x*x-2*z*z)*sy, (2*y*z-2*x*w)*sz, t[1]],
        [(2*x*z-2*y*w)*sx, (2*y*z+2*x*w)*sy, (1-2*x*x-2*y*y)*sz, t[2]],
        [0, 0, 0, 1],
    ]


def inspect(path):
    raw = path.read_bytes()
    length, kind = struct.unpack_from("<II", raw, 12)
    assert kind == 0x4E4F534A
    data = json.loads(raw[20:20 + length])
    identity = [[1 if r == c else 0 for c in range(4)] for r in range(4)]
    nodes = data.get("nodes", [])
    parents = {child: parent for parent, node in enumerate(nodes) for child in node.get("children", [])}
    cache = {}

    def world(index):
        if index not in cache:
            cache[index] = multiply(world(parents[index]) if index in parents else identity, transform(nodes[index]))
        return cache[index]

    bones = []
    for skin in data.get("skins", []):
        for i in skin["joints"]:
            m = world(i)
            bones.append({"name": nodes[i].get("name"), "position": [m[r][3] for r in range(3)], "basis": [row[:3] for row in m[:3]]})
    meshes = []
    for mesh in data.get("meshes", []):
        for primitive in mesh.get("primitives", []):
            accessor = data["accessors"][primitive["attributes"]["POSITION"]]
            index = data["accessors"][primitive["indices"]] if "indices" in primitive else accessor
            meshes.append({"name": mesh.get("name"), "vertices": accessor["count"], "triangles": index["count"] // 3,
                           "minimum": accessor.get("min"), "maximum": accessor.get("max"), "material": primitive.get("material")})
    return {"path": str(path), "sha256": hashlib.sha256(raw).hexdigest(), "bytes": len(raw), "meshes": meshes,
            "bones": bones, "materials": data.get("materials", []), "animations": [x.get("name") for x in data.get("animations", [])]}


if __name__ == "__main__":
    records = {name: inspect(path) for name, path in FILES.items()}
    destination = CASE / "source-inspection.json"
    destination.write_text(json.dumps(records, indent=2), encoding="utf-8")
    for name, record in records.items():
        print(name, record["sha256"], record["bytes"], record["meshes"])
        print([x for x in record["bones"] if "Head" in x["name"] or "Shoulder" in x["name"] or "Spine" in x["name"] or "Limb_0" in x["name"]])

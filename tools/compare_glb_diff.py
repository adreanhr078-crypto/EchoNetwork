import os
import sys
import json
import struct
import hashlib
from pathlib import Path

REPO_ROOT = Path(r"c:\Users\yasmo\EchoNetwork")

def get_image_dimensions(data, mime_type):
    # Try JPEG
    if data.startswith(b'\xff\xd8'):
        # JPEG
        idx = 2
        while idx < len(data):
            if data[idx] != 0xff:
                break
            marker = data[idx+1]
            idx += 2
            if marker in (0xd8, 0xd9): # SOI, EOI
                continue
            if marker in (0xc0, 0xc1, 0xc2): # SOF0, SOF1, SOF2
                length = struct.unpack('>H', data[idx:idx+2])[0]
                h, w = struct.unpack('>HH', data[idx+3:idx+7])
                return w, h
            else:
                length = struct.unpack('>H', data[idx:idx+2])[0]
                idx += length
    elif data.startswith(b'\x89PNG\r\n\x1a\n'):
        # PNG
        w, h = struct.unpack('>II', data[16:24])
        return w, h
    return None, None

def parse_glb(file_path):
    with open(file_path, "rb") as f:
        data = f.read()

    magic, version, length = struct.unpack("<4sII", data[:12])
    assert magic == b"glTF", f"Not a GLB: {magic}"

    offset = 12
    json_chunk = None
    bin_chunk = None

    while offset < len(data):
        chunk_len, chunk_type = struct.unpack("<II", data[offset:offset+8])
        chunk_data = data[offset+8:offset+8+chunk_len]
        offset += 8 + chunk_len
        if chunk_type == 0x4E4F534A: # JSON
            json_chunk = json.loads(chunk_data.decode("utf-8"))
        elif chunk_type == 0x004E4942: # BIN
            bin_chunk = chunk_data

    return json_chunk, bin_chunk, data

def compare_weapons_and_props():
    for name in ["standard_katana_tripo_20261008.glb", "shadow_katana_tripo_20261008.glb"]:
        p_weap = REPO_ROOT / "artifacts/eleven-eleven/godot/assets/weapons" / name
        p_prop = REPO_ROOT / "artifacts/eleven-eleven/godot/assets/props" / name

        j_w, b_w, d_w = parse_glb(p_weap)
        j_p, b_p, d_p = parse_glb(p_prop)

        print(f"=== {name} ===")
        print(f"Weapons size: {len(d_w)} bytes, BIN size: {len(b_w) if b_w else 0}")
        print(f"Props size:   {len(d_p)} bytes, BIN size: {len(b_p) if b_p else 0}")
        print(f"JSON diff nodes: {j_w.get('nodes')} vs {j_p.get('nodes')}")
        if json.dumps(j_w) != json.dumps(j_p):
            print("JSON chunks differ!")
            # Find what differs in json keys
            for k in set(list(j_w.keys()) + list(j_p.keys())):
                if j_w.get(k) != j_p.get(k):
                    print(f"Difference in key: {k}")
                    print(f"  Weapon: {json.dumps(j_w.get(k))[:200]}")
                    print(f"  Prop:   {json.dumps(j_p.get(k))[:200]}")
        if b_w == b_p:
            print("BIN chunks are IDENTICAL!")
        else:
            print("BIN chunks DIFFER!")

if __name__ == "__main__":
    compare_weapons_and_props()

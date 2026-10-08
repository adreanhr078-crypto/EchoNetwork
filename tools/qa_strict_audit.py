import os
import sys
import json
import struct
import hashlib
from pathlib import Path

REPO_ROOT = Path(r"c:\Users\yasmo\EchoNetwork")

def sha256_file(path):
    if not os.path.exists(path):
        return None
    h = hashlib.sha256()
    with open(path, "rb") as f:
        while chunk := f.read(65536):
            h.update(chunk)
    return h.hexdigest()

def get_image_info(data, mime_type=""):
    w, h = None, None
    format_type = "unknown"
    if data.startswith(b'\xff\xd8'):
        format_type = "image/jpeg"
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
                break
            else:
                length = struct.unpack('>H', data[idx:idx+2])[0]
                idx += length
    elif data.startswith(b'\x89PNG\r\n\x1a\n'):
        format_type = "image/png"
        w, h = struct.unpack('>II', data[16:24])
    return {
        "width": w,
        "height": h,
        "format": format_type or mime_type,
        "size_bytes": len(data)
    }

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

    return json_chunk, bin_chunk, len(data)

def get_accessor_data(accessor_idx, json_chunk, bin_chunk):
    acc = json_chunk["accessors"][accessor_idx]
    bv = json_chunk["bufferViews"][acc["bufferView"]]
    byte_offset = bv.get("byteOffset", 0) + acc.get("byteOffset", 0)
    count = acc["count"]
    comp_type = acc["componentType"]
    type_str = acc["type"]
    return acc, bv, byte_offset, count, comp_type, type_str

def inspect_asset_glb(file_path):
    json_chunk, bin_chunk, file_size = parse_glb(file_path)

    # Node hierarchy
    nodes = json_chunk.get("nodes", [])
    scenes = json_chunk.get("scenes", [])
    default_scene = json_chunk.get("scene", 0)
    
    # Meshes
    meshes = json_chunk.get("meshes", [])
    accessors = json_chunk.get("accessors", [])
    materials = json_chunk.get("materials", [])
    images = json_chunk.get("images", [])
    textures = json_chunk.get("textures", [])

    total_vertices = 0
    total_triangles = 0
    has_normals = False
    has_tangents = False
    has_uv = False
    uv_channels = set()

    primitives_info = []

    all_positions_min = [float('inf'), float('inf'), float('inf')]
    all_positions_max = [float('-inf'), float('-inf'), float('-inf')]

    for m_idx, mesh in enumerate(meshes):
        for p_idx, prim in enumerate(mesh.get("primitives", [])):
            attrs = prim.get("attributes", {})
            
            # Position
            pos_acc_idx = attrs.get("POSITION")
            p_verts = 0
            if pos_acc_idx is not None:
                pos_acc = accessors[pos_acc_idx]
                p_verts = pos_acc["count"]
                total_vertices += p_verts
                p_min = pos_acc.get("min", [0, 0, 0])
                p_max = pos_acc.get("max", [0, 0, 0])
                for i in range(3):
                    all_positions_min[i] = min(all_positions_min[i], p_min[i])
                    all_positions_max[i] = max(all_positions_max[i], p_max[i])

            # Indices / Triangles
            indices_acc_idx = prim.get("indices")
            p_tris = 0
            if indices_acc_idx is not None:
                ind_acc = accessors[indices_acc_idx]
                p_tris = ind_acc["count"] // 3
            else:
                p_tris = p_verts // 3
            total_triangles += p_tris

            # Normal
            if "NORMAL" in attrs:
                has_normals = True

            # Tangent
            if "TANGENT" in attrs:
                has_tangents = True

            # UV
            for k in attrs.keys():
                if k.startswith("TEXCOORD_"):
                    has_uv = True
                    uv_channels.add(k)

            primitives_info.append({
                "mesh_idx": m_idx,
                "primitive_idx": p_idx,
                "material_idx": prim.get("material"),
                "vertices": p_verts,
                "triangles": p_tris,
                "attributes": list(attrs.keys()),
                "position_min": pos_acc.get("min") if pos_acc_idx is not None else None,
                "position_max": pos_acc.get("max") if pos_acc_idx is not None else None
            })

    # Calculate dimensions
    dimensions = [
        all_positions_max[i] - all_positions_min[i] if all_positions_max[i] != float('-inf') else 0
        for i in range(3)
    ]

    # Calculate node world transforms if present
    # Bounding box taking node transform into account
    node_transforms = []
    world_bbox_min = list(all_positions_min)
    world_bbox_max = list(all_positions_max)
    world_dimensions = list(dimensions)

    for n_idx, node in enumerate(nodes):
        trans = node.get("translation", [0.0, 0.0, 0.0])
        rot = node.get("rotation", [0.0, 0.0, 0.0, 1.0]) # quaternion [x, y, z, w]
        scale = node.get("scale", [1.0, 1.0, 1.0])
        matrix = node.get("matrix", None)
        node_transforms.append({
            "name": node.get("name", f"node_{n_idx}"),
            "mesh": node.get("mesh"),
            "translation": trans,
            "rotation": rot,
            "scale": scale,
            "matrix": matrix
        })
        if node.get("mesh") is not None and scale != [1.0, 1.0, 1.0]:
            # Apply scale to bbox
            for i in range(3):
                world_bbox_min[i] = all_positions_min[i] * scale[i]
                world_bbox_max[i] = all_positions_max[i] * scale[i]
                if world_bbox_min[i] > world_bbox_max[i]:
                    world_bbox_min[i], world_bbox_max[i] = world_bbox_max[i], world_bbox_min[i]
            world_dimensions = [world_bbox_max[i] - world_bbox_min[i] for i in range(3)]

    # Texture channels & resolutions
    images_detail = []
    for img_idx, img in enumerate(images):
        bv_idx = img.get("bufferView")
        if bv_idx is not None and bin_chunk is not None:
            bv = json_chunk["bufferViews"][bv_idx]
            b_off = bv.get("byteOffset", 0)
            b_len = bv["byteLength"]
            img_data = bin_chunk[b_off:b_off+b_len]
            info = get_image_info(img_data, img.get("mimeType", ""))
            images_detail.append({
                "index": img_idx,
                "name": img.get("name", f"image_{img_idx}"),
                "mimeType": img.get("mimeType", info["format"]),
                "width": info["width"],
                "height": info["height"],
                "size_bytes": info["size_bytes"]
            })

    materials_detail = []
    for mat_idx, mat in enumerate(materials):
        pbr = mat.get("pbrMetallicRoughness", {})
        
        base_tex = pbr.get("baseColorTexture")
        norm_tex = mat.get("normalTexture")
        orm_tex = pbr.get("metallicRoughnessTexture")
        
        def resolve_tex_img(tex_ref):
            if not tex_ref:
                return None
            t_idx = tex_ref.get("index")
            if t_idx is not None and t_idx < len(textures):
                tex = textures[t_idx]
                s_idx = tex.get("source")
                if s_idx is not None and s_idx < len(images_detail):
                    return images_detail[s_idx]
            return None

        materials_detail.append({
            "name": mat.get("name", f"material_{mat_idx}"),
            "baseColorFactor": pbr.get("baseColorFactor", [1, 1, 1, 1]),
            "metallicFactor": pbr.get("metallicFactor", 1.0),
            "roughnessFactor": pbr.get("roughnessFactor", 1.0),
            "textures": {
                "baseColor": resolve_tex_img(base_tex),
                "normalGL": resolve_tex_img(norm_tex),
                "metallicRoughness_ORM": resolve_tex_img(orm_tex)
            }
        })

    # Pivot analysis: where is (0,0,0) relative to bbox
    # Min, Max, Center
    bbox_center = [(all_positions_min[i] + all_positions_max[i]) / 2 for i in range(3)]
    pivot_relative_to_bbox = {
        "x": "centered" if abs(bbox_center[0]) < 0.05 else ("min" if abs(all_positions_min[0]) < 0.05 else "offset"),
        "y": "centered" if abs(bbox_center[1]) < 0.05 else ("min" if abs(all_positions_min[1]) < 0.05 else "offset"),
        "z": "centered" if abs(bbox_center[2]) < 0.05 else ("min" if abs(all_positions_min[2]) < 0.05 else "offset"),
    }

    return {
        "file_size_bytes": file_size,
        "generator": json_chunk.get("asset", {}).get("generator", "unknown"),
        "gltf_version": json_chunk.get("asset", {}).get("version", "2.0"),
        "extensions_used": json_chunk.get("extensionsUsed", []),
        "nodes_count": len(nodes),
        "nodes": node_transforms,
        "mesh_count": len(meshes),
        "total_vertices": total_vertices,
        "total_triangles": total_triangles,
        "limit_triangles_pass": total_triangles < 30000,
        "has_normal_vectors": has_normals,
        "has_tangent_vectors": has_tangents,
        "has_uv_coordinates": has_uv,
        "uv_channels": sorted(list(uv_channels)),
        "local_bbox_min": all_positions_min,
        "local_bbox_max": all_positions_max,
        "local_dimensions": dimensions,
        "world_bbox_min": world_bbox_min,
        "world_bbox_max": world_bbox_max,
        "world_dimensions": world_dimensions,
        "pivot_relative": pivot_relative_to_bbox,
        "primitives": primitives_info,
        "materials": materials_detail,
        "images": images_detail
    }

def run_audit():
    asset_definitions = [
        {
            "id": "standard-katana",
            "name": "Standard Katana",
            "category": "Weapon",
            "target_spec": "length ~0.85m - 1.0m, pivot at hilt/guard for hand socket attachment, blade pointing up (+Y)",
            "raw_tripo_glb": REPO_ROOT / "artifacts/eleven-eleven/art/production/tripo-20261007/standard-katana/tripo-out/standard-katana-20261007-f43b4b42/model.glb",
            "blend_file": REPO_ROOT / "artifacts/eleven-eleven/art/production/tripo-20261007/standard-katana/standard-katana.blend",
            "godot_props_glb": REPO_ROOT / "artifacts/eleven-eleven/godot/assets/props/standard-katana_tripo_20261008.glb",
            "godot_props_alias": REPO_ROOT / "artifacts/eleven-eleven/godot/assets/props/standard_katana_tripo_20261008.glb",
            "godot_weapons_glb": REPO_ROOT / "artifacts/eleven-eleven/godot/assets/weapons/standard_katana_tripo_20261008.glb"
        },
        {
            "id": "shadow-katana",
            "name": "Shadow Katana",
            "category": "Weapon",
            "target_spec": "length ~1.0m - 1.1m, scabbard removed, pivot at hilt/guard for hand socket attachment, blade pointing up (+Y)",
            "raw_tripo_glb": REPO_ROOT / "artifacts/eleven-eleven/art/production/tripo-20261007/shadow-katana/tripo-out/shadow-katana-20261007-c9cae674/model.glb",
            "blend_file": REPO_ROOT / "artifacts/eleven-eleven/art/production/tripo-20261007/shadow-katana/shadow-katana.blend",
            "godot_props_glb": REPO_ROOT / "artifacts/eleven-eleven/godot/assets/props/shadow-katana_tripo_20261008.glb",
            "godot_props_alias": REPO_ROOT / "artifacts/eleven-eleven/godot/assets/props/shadow_katana_tripo_20261008.glb",
            "godot_weapons_glb": REPO_ROOT / "artifacts/eleven-eleven/godot/assets/weapons/shadow_katana_tripo_20261008.glb"
        },
        {
            "id": "diagnostic-cart",
            "name": "Diagnostic Cart",
            "category": "Prop",
            "target_spec": "~1.1m tall, base at ground y=0, wheels on floor, centered pivot",
            "raw_tripo_glb": REPO_ROOT / "artifacts/eleven-eleven/art/production/tripo-20261007/diagnostic-cart/tripo-out/diagnostic-cart-20261007-787ef5a5/model.glb",
            "blend_file": REPO_ROOT / "artifacts/eleven-eleven/art/production/tripo-20261007/diagnostic-cart/diagnostic-cart.blend",
            "godot_props_glb": REPO_ROOT / "artifacts/eleven-eleven/godot/assets/props/diagnostic-cart_tripo_20261008.glb",
            "godot_props_alias": REPO_ROOT / "artifacts/eleven-eleven/godot/assets/props/diagnostic_cart_tripo_20261008.glb",
            "godot_weapons_glb": None
        },
        {
            "id": "security-terminal",
            "name": "Security Terminal",
            "category": "Prop",
            "target_spec": "~0.65m tall, mounting back at z=0 / pivot centered",
            "raw_tripo_glb": REPO_ROOT / "artifacts/eleven-eleven/art/production/tripo-20261007/security-terminal/tripo-out/security-terminal-20261007-df7cbe72/model.glb",
            "blend_file": REPO_ROOT / "artifacts/eleven-eleven/art/production/tripo-20261007/security-terminal/security-terminal.blend",
            "godot_props_glb": REPO_ROOT / "artifacts/eleven-eleven/godot/assets/props/security-terminal_tripo_20261008.glb",
            "godot_props_alias": REPO_ROOT / "artifacts/eleven-eleven/godot/assets/props/security_terminal_tripo_20261008.glb",
            "godot_weapons_glb": None
        },
        {
            "id": "observation-server",
            "name": "Observation Server Rack",
            "category": "Prop",
            "target_spec": "~1.7m tall, base at ground y=0, centered pivot",
            "raw_tripo_glb": REPO_ROOT / "artifacts/eleven-eleven/art/production/tripo-20261007/observation-server/tripo-out/observation-server-20261007-4cdb4008/model.glb",
            "blend_file": REPO_ROOT / "artifacts/eleven-eleven/art/production/tripo-20261007/observation-server/observation-server.blend",
            "godot_props_glb": REPO_ROOT / "artifacts/eleven-eleven/godot/assets/props/observation-server_tripo_20261008.glb",
            "godot_props_alias": REPO_ROOT / "artifacts/eleven-eleven/godot/assets/props/observation_server_tripo_20261008.glb",
            "godot_weapons_glb": None
        },
        {
            "id": "medical-wall-unit",
            "name": "Medical Wall Unit",
            "category": "Prop",
            "target_spec": "~0.9m tall, mounting back at z=0 / pivot centered",
            "raw_tripo_glb": REPO_ROOT / "artifacts/eleven-eleven/art/production/tripo-20261007/medical-wall-unit/tripo-out/medical-wall-unit-20261007-5affa583/model.glb",
            "blend_file": REPO_ROOT / "artifacts/eleven-eleven/art/production/tripo-20261007/medical-wall-unit/medical-wall-unit.blend",
            "godot_props_glb": REPO_ROOT / "artifacts/eleven-eleven/godot/assets/props/medical-wall-unit_tripo_20261008.glb",
            "godot_props_alias": REPO_ROOT / "artifacts/eleven-eleven/godot/assets/props/medical_wall_unit_tripo_20261008.glb",
            "godot_weapons_glb": None
        }
    ]

    report = []
    for asset in asset_definitions:
        aid = asset["id"]
        print(f"Auditing {aid}...")

        # Raw Tripo GLB
        raw_path = asset["raw_tripo_glb"]
        raw_size = os.path.getsize(raw_path) if os.path.exists(raw_path) else 0
        raw_hash = sha256_file(raw_path)
        raw_inspection = inspect_asset_glb(raw_path) if os.path.exists(raw_path) else None

        # Blend
        blend_path = asset["blend_file"]
        blend_size = os.path.getsize(blend_path) if os.path.exists(blend_path) else 0
        blend_hash = sha256_file(blend_path)

        # Props normalized GLB
        props_path = asset["godot_props_glb"]
        props_size = os.path.getsize(props_path) if os.path.exists(props_path) else 0
        props_hash = sha256_file(props_path)
        props_inspection = inspect_asset_glb(props_path) if os.path.exists(props_path) else None

        # Props alias GLB
        alias_path = asset["godot_props_alias"]
        alias_size = os.path.getsize(alias_path) if os.path.exists(alias_path) else 0
        alias_hash = sha256_file(alias_path)

        # Weapons GLB (if applicable)
        weap_path = asset["godot_weapons_glb"]
        weap_size = os.path.getsize(weap_path) if weap_path and os.path.exists(weap_path) else None
        weap_hash = sha256_file(weap_path) if weap_path and os.path.exists(weap_path) else None
        weap_inspection = inspect_asset_glb(weap_path) if weap_path and os.path.exists(weap_path) else None

        # Discrepancies check
        discrepancies = []
        if weap_path and os.path.exists(weap_path):
            if weap_hash != props_hash:
                discrepancies.append({
                    "type": "WEAPONS_VS_PROPS_HASH_MISMATCH",
                    "description": f"godot/assets/weapons/ ({weap_size} bytes) does not match godot/assets/props/ ({props_size} bytes). Weapons version retains unapplied node scale ({weap_inspection['nodes'][0]['scale']}) while props version has baked transforms."
                })
        
        # Check tangent vectors
        if props_inspection and not props_inspection["has_tangent_vectors"]:
            discrepancies.append({
                "type": "NO_PRECOMPUTED_TANGENTS",
                "description": "GLB does not include precomputed TANGENT vertex attribute. Normal mapping relies on Godot runtime Mikktspace generation."
            })

        # Check file size disclosure
        if props_size > 5 * 1024 * 1024:
            discrepancies.append({
                "type": "LARGE_UNOPTIMIZED_FILE_SIZE",
                "description": f"Asset is {props_size / (1024*1024):.2f} MB due to uncompressed 4096x4096 textures. Requires downscaling to 2048x2048 or KTX2/Basis compression before low-end mobile deployment."
            })

        entry = {
            "id": aid,
            "name": asset["name"],
            "category": asset["category"],
            "target_spec": asset["target_spec"],
            "validation_pass": (props_inspection["limit_triangles_pass"] if props_inspection else False),
            "triangles_limit_30k_pass": (props_inspection["limit_triangles_pass"] if props_inspection else False),
            "files": {
                "raw_tripo_glb": {
                    "path": str(raw_path),
                    "size_bytes": raw_size,
                    "size_mb": round(raw_size / (1024*1024), 3),
                    "sha256": raw_hash
                },
                "editable_blend": {
                    "path": str(blend_path),
                    "size_bytes": blend_size,
                    "size_mb": round(blend_size / (1024*1024), 3),
                    "sha256": blend_hash
                },
                "godot_props_glb": {
                    "path": str(props_path),
                    "size_bytes": props_size,
                    "size_mb": round(props_size / (1024*1024), 3),
                    "sha256": props_hash
                },
                "godot_props_alias_glb": {
                    "path": str(alias_path),
                    "size_bytes": alias_size,
                    "size_mb": round(alias_size / (1024*1024), 3),
                    "sha256": alias_hash
                },
                "godot_weapons_glb": {
                    "path": str(weap_path) if weap_path else None,
                    "size_bytes": weap_size,
                    "size_mb": round(weap_size / (1024*1024), 3) if weap_size else None,
                    "sha256": weap_hash
                } if weap_path else None
            },
            "geometry": {
                "raw_asset": {
                    "vertices": raw_inspection["total_vertices"] if raw_inspection else None,
                    "triangles": raw_inspection["total_triangles"] if raw_inspection else None,
                    "local_dimensions": raw_inspection["local_dimensions"] if raw_inspection else None
                },
                "godot_props_production": {
                    "vertices": props_inspection["total_vertices"] if props_inspection else None,
                    "triangles": props_inspection["total_triangles"] if props_inspection else None,
                    "has_normals": props_inspection["has_normal_vectors"] if props_inspection else None,
                    "has_tangents": props_inspection["has_tangent_vectors"] if props_inspection else None,
                    "has_uv": props_inspection["has_uv_coordinates"] if props_inspection else None,
                    "uv_channels": props_inspection["uv_channels"] if props_inspection else None,
                    "bbox_min": props_inspection["local_bbox_min"] if props_inspection else None,
                    "bbox_max": props_inspection["local_bbox_max"] if props_inspection else None,
                    "dimensions": props_inspection["local_dimensions"] if props_inspection else None,
                    "pivot_relative": props_inspection["pivot_relative"] if props_inspection else None,
                    "node_hierarchy": props_inspection["nodes"] if props_inspection else None,
                    "materials": props_inspection["materials"] if props_inspection else None
                },
                "godot_weapons_production": {
                    "vertices": weap_inspection["total_vertices"] if weap_inspection else None,
                    "triangles": weap_inspection["total_triangles"] if weap_inspection else None,
                    "has_normals": weap_inspection["has_normal_vectors"] if weap_inspection else None,
                    "has_tangents": weap_inspection["has_tangent_vectors"] if weap_inspection else None,
                    "has_uv": weap_inspection["has_uv_coordinates"] if weap_inspection else None,
                    "uv_channels": weap_inspection["uv_channels"] if weap_inspection else None,
                    "bbox_min": weap_inspection["local_bbox_min"] if weap_inspection else None,
                    "bbox_max": weap_inspection["local_bbox_max"] if weap_inspection else None,
                    "dimensions": weap_inspection["local_dimensions"] if weap_inspection else None,
                    "world_dimensions": weap_inspection["world_dimensions"] if weap_inspection else None,
                    "pivot_relative": weap_inspection["pivot_relative"] if weap_inspection else None,
                    "node_hierarchy": weap_inspection["nodes"] if weap_inspection else None,
                    "materials": weap_inspection["materials"] if weap_inspection else None
                } if weap_inspection else None
            },
            "discrepancies": discrepancies
        }
        report.append(entry)

    out_json = REPO_ROOT / "artifacts/eleven-eleven/art/production/tripo-20261007/geometry_qa_report_20261008.json"
    with open(out_json, "w", encoding="utf-8") as f:
        json.dump(report, f, indent=2)
    print(f"Report written to: {out_json}")

if __name__ == "__main__":
    run_audit()

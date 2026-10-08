import os
import sys
import json
import hashlib
import numpy as np
import bpy

BASE_DIR = r"C:\Users\yasmo\EchoNetwork"
TRIPO_DIR = os.path.join(BASE_DIR, r"artifacts\eleven-eleven\art\production\tripo-20261007")
GODOT_PROPS_DIR = os.path.join(BASE_DIR, r"artifacts\eleven-eleven\godot\assets\props")

ASSETS = [
    {
        "id": "standard-katana",
        "category": "Weapon",
        "target_spec": "length ~0.85m - 1.0m, pivot at hilt/guard for hand socket attachment, blade pointing up (+Y)",
        "raw_glb": os.path.join(TRIPO_DIR, r"standard-katana\tripo-out\standard-katana-20261007-f43b4b42\model.glb"),
        "blend": os.path.join(TRIPO_DIR, r"standard-katana\standard-katana.blend"),
        "normalized_glb": os.path.join(GODOT_PROPS_DIR, "standard-katana_tripo_20261008.glb")
    },
    {
        "id": "shadow-katana",
        "category": "Weapon",
        "target_spec": "length ~1.0m - 1.1m, scabbard removed, pivot at hilt/guard for hand socket attachment, blade pointing up (+Y)",
        "raw_glb": os.path.join(TRIPO_DIR, r"shadow-katana\tripo-out\shadow-katana-20261007-c9cae674\model.glb"),
        "blend": os.path.join(TRIPO_DIR, r"shadow-katana\shadow-katana.blend"),
        "normalized_glb": os.path.join(GODOT_PROPS_DIR, "shadow-katana_tripo_20261008.glb")
    },
    {
        "id": "diagnostic-cart",
        "category": "Prop",
        "target_spec": "~1.1m tall, base at ground y=0, wheels on floor, centered pivot",
        "raw_glb": os.path.join(TRIPO_DIR, r"diagnostic-cart\tripo-out\diagnostic-cart-20261007-787ef5a5\model.glb"),
        "blend": os.path.join(TRIPO_DIR, r"diagnostic-cart\diagnostic-cart.blend"),
        "normalized_glb": os.path.join(GODOT_PROPS_DIR, "diagnostic-cart_tripo_20261008.glb")
    },
    {
        "id": "security-terminal",
        "category": "Prop",
        "target_spec": "~0.65m tall, mounting back at z=0 / pivot centered",
        "raw_glb": os.path.join(TRIPO_DIR, r"security-terminal\tripo-out\security-terminal-20261007-df7cbe72\model.glb"),
        "blend": os.path.join(TRIPO_DIR, r"security-terminal\security-terminal.blend"),
        "normalized_glb": os.path.join(GODOT_PROPS_DIR, "security-terminal_tripo_20261008.glb")
    },
    {
        "id": "observation-server",
        "category": "Prop",
        "target_spec": "~1.7m tall, base at ground y=0, centered pivot",
        "raw_glb": os.path.join(TRIPO_DIR, r"observation-server\tripo-out\observation-server-20261007-4cdb4008\model.glb"),
        "blend": os.path.join(TRIPO_DIR, r"observation-server\observation-server.blend"),
        "normalized_glb": os.path.join(GODOT_PROPS_DIR, "observation-server_tripo_20261008.glb")
    },
    {
        "id": "medical-wall-unit",
        "category": "Prop",
        "target_spec": "~0.9m tall, mounting back at z=0 / pivot centered",
        "raw_glb": os.path.join(TRIPO_DIR, r"medical-wall-unit\tripo-out\medical-wall-unit-20261007-5affa583\model.glb"),
        "blend": os.path.join(TRIPO_DIR, r"medical-wall-unit\medical-wall-unit.blend"),
        "normalized_glb": os.path.join(GODOT_PROPS_DIR, "medical-wall-unit_tripo_20261008.glb")
    }
]

def sha256_file(p):
    if not os.path.exists(p):
        return None
    h = hashlib.sha256()
    with open(p, "rb") as f:
        while chunk := f.read(65536):
            h.update(chunk)
    return h.hexdigest()

def inspect_glb_file(glb_path):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=glb_path)
    objs = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    
    total_verts = sum(len(o.data.vertices) for o in objs)
    total_faces = sum(len(o.data.polygons) for o in objs)
    
    # Calculate triangles
    total_tris = 0
    for o in objs:
        o.data.calc_loop_triangles()
        total_tris += len(o.data.loop_triangles)

    all_coords = []
    for o in objs:
        for v in o.data.vertices:
            world_co = o.matrix_world @ v.co
            all_coords.append(world_co)
    all_coords = np.array(all_coords)

    min_c = all_coords.min(axis=0)
    max_c = all_coords.max(axis=0)
    dims = max_c - min_c

    # Check materials & textures
    materials = []
    for mat in bpy.data.materials:
        textures = []
        if mat.use_nodes and mat.node_tree:
            for node in mat.node_tree.nodes:
                if node.type == 'TEX_IMAGE' and node.image:
                    textures.append({
                        "name": node.image.name,
                        "size": list(node.image.size)
                    })
        materials.append({
            "name": mat.name,
            "textures": textures
        })

    return {
        "vertices": int(total_verts),
        "faces": int(total_faces),
        "triangles": int(total_tris),
        "bbox_min": [float(x) for x in min_c],
        "bbox_max": [float(x) for x in max_c],
        "dimensions": [float(x) for x in dims],
        "materials": materials
    }

def main():
    report = []
    for asset in ASSETS:
        print(f"Validating {asset['id']}...")
        norm_info = inspect_glb_file(asset["normalized_glb"])
        
        # Raw inspection
        raw_info = inspect_glb_file(asset["raw_glb"])

        raw_size = os.path.getsize(asset["raw_glb"])
        raw_hash = sha256_file(asset["raw_glb"])
        
        blend_size = os.path.getsize(asset["blend"])
        blend_hash = sha256_file(asset["blend"])

        norm_size = os.path.getsize(asset["normalized_glb"])
        norm_hash = sha256_file(asset["normalized_glb"])

        face_limit_pass = norm_info["faces"] <= 30000

        entry = {
            "id": asset["id"],
            "category": asset["category"],
            "target_spec": asset["target_spec"],
            "validation_pass": face_limit_pass,
            "raw_asset": {
                "path": asset["raw_glb"],
                "size_bytes": raw_size,
                "sha256": raw_hash,
                "vertices": raw_info["vertices"],
                "faces": raw_info["faces"],
                "triangles": raw_info["triangles"],
                "dimensions": raw_info["dimensions"]
            },
            "editable_blend": {
                "path": asset["blend"],
                "size_bytes": blend_size,
                "sha256": blend_hash
            },
            "normalized_godot_glb": {
                "path": asset["normalized_glb"],
                "size_bytes": norm_size,
                "sha256": norm_hash,
                "vertices": norm_info["vertices"],
                "faces": norm_info["faces"],
                "triangles": norm_info["triangles"],
                "bbox_min": norm_info["bbox_min"],
                "bbox_max": norm_info["bbox_max"],
                "dimensions": norm_info["dimensions"],
                "materials": norm_info["materials"]
            }
        }
        report.append(entry)

    out_report_path = os.path.join(BASE_DIR, r"artifacts\eleven-eleven\art\production\tripo-20261007\geometry_qa_report_20261008.json")
    with open(out_report_path, "w") as f:
        json.dump(report, f, indent=2)

    print("\n=== VALIDATION COMPLETE ===")
    print(f"Report written to: {out_report_path}")
    print(json.dumps(report, indent=2))

if __name__ == "__main__":
    main()

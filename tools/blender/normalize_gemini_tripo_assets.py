"""tools/blender/normalize_gemini_tripo_assets.py

Headless Blender script to inspect, normalize, save .blend sources,
and export Godot-ready GLBs for the 6 Tripo assets generated on 2026-10-08.
"""

import sys
import json
import hashlib
from pathlib import Path
import bpy
import mathutils

REPO_ROOT = Path(__file__).resolve().parent.parent.parent

ASSETS_SPEC = [
    {
        "id": "diagnostic-cart",
        "name": "diagnostic_cart_tripo_20261008",
        "task_id": "787ef5a5-0e0e-4131-a060-7711b10541e3",
        "raw_dir": REPO_ROOT / "artifacts/eleven-eleven/art/production/tripo-20261007/diagnostic-cart/tripo-out/diagnostic-cart-20261007-787ef5a5",
        "target_height": 1.10,
        "type": "ground_prop",
        "description": "Futuristic mobile medical diagnostic trolley with caster wheels and monitoring screen"
    },
    {
        "id": "security-terminal",
        "name": "security_terminal_tripo_20261008",
        "task_id": "df7cbe72-3f48-4f1c-b085-db87e2e7bcb9",
        "raw_dir": REPO_ROOT / "artifacts/eleven-eleven/art/production/tripo-20261007/security-terminal/tripo-out/security-terminal-20261007-df7cbe72",
        "target_height": 0.65,
        "type": "wall_prop",
        "description": "Wall-mounted security console terminal with cyan scanner lens and touch interface"
    },
    {
        "id": "observation-server",
        "name": "observation_server_tripo_20261008",
        "task_id": "4cdb4008-91a9-46be-af7b-27846de0f7e0",
        "raw_dir": REPO_ROOT / "artifacts/eleven-eleven/art/production/tripo-20261007/observation-server/tripo-out/observation-server-20261007-4cdb4008",
        "target_height": 1.70,
        "type": "ground_prop",
        "description": "Tall cryogenic laboratory observation server rack cabinet with telemetry indicators"
    },
    {
        "id": "medical-wall-unit",
        "name": "medical_wall_unit_tripo_20261008",
        "task_id": "5affa583-0772-4141-8287-cb4ff9efa62b",
        "raw_dir": REPO_ROOT / "artifacts/eleven-eleven/art/production/tripo-20261007/medical-wall-unit/tripo-out/medical-wall-unit-20261007-5affa583",
        "target_height": 0.90,
        "type": "wall_prop",
        "description": "Medical diagnostic wall module with ceramic housing, screen and probe cable mounts"
    },
    {
        "id": "standard-katana",
        "name": "standard_katana_tripo_20261008",
        "task_id": "f43b4b42-6c2b-4c3d-8ac3-d42a4daa062a",
        "raw_dir": REPO_ROOT / "artifacts/eleven-eleven/art/production/tripo-20261007/standard-katana/tripo-out/standard-katana-20261007-f43b4b42",
        "target_length": 1.05,
        "type": "weapon",
        "description": "Single-edged high-carbon steel katana with brushed silver edge and cyan power channel"
    },
    {
        "id": "shadow-katana",
        "name": "shadow_katana_tripo_20261008",
        "task_id": "c9cae674-2f4d-49b5-8632-59f2a5caa740",
        "raw_dir": REPO_ROOT / "artifacts/eleven-eleven/art/production/tripo-20261007/shadow-katana/tripo-out/shadow-katana-20261007-c9cae674",
        "target_length": 1.10,
        "type": "weapon",
        "description": "Long obsidian katana blade with violet fracture inlays and dark wrapped grip"
    }
]

def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        while chunk := f.read(65536):
            h.update(chunk)
    return h.hexdigest()

def clear_scene():
    bpy.ops.wm.read_homefile(use_empty=True)

def process_asset(spec: dict) -> dict:
    raw_glb = spec["raw_dir"] / "model.glb"
    if not raw_glb.exists():
        raise FileNotFoundError(f"Raw GLB missing: {raw_glb}")
    
    raw_sha = sha256_file(raw_glb)
    raw_bytes = raw_glb.stat().st_size

    clear_scene()

    # Import raw GLB
    bpy.ops.import_scene.gltf(filepath=str(raw_glb))
    
    # Collect meshes
    mesh_objs = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    if not mesh_objs:
        raise ValueError(f"No mesh objects found in {raw_glb}")
    
    # Calculate initial bounds
    total_verts = sum(len(o.data.vertices) for o in mesh_objs)
    total_triangles = sum(len(o.data.polygons) for o in mesh_objs)
    
    # Calculate global bounding box
    bbox_corners = []
    for o in mesh_objs:
        for corner in o.bound_box:
            bbox_corners.append(o.matrix_world @ mathutils.Vector(corner))
    
    min_x = min(v.x for v in bbox_corners)
    max_x = max(v.x for v in bbox_corners)
    min_y = min(v.y for v in bbox_corners)
    max_y = max(v.y for v in bbox_corners)
    min_z = min(v.z for v in bbox_corners)
    max_z = max(v.z for v in bbox_corners)

    raw_dim_x = max_x - min_x
    raw_dim_y = max_y - min_y
    raw_dim_z = max_z - min_z

    print(f"[{spec['id']}] Raw dimensions: X={raw_dim_x:.3f}, Y={raw_dim_y:.3f}, Z={raw_dim_z:.3f} (Z-up Blender)")

    # Blender coordinate system is Z-up. Godot GLTF importer translates Z-up to Y-up automatically.
    # Height in Blender is Z extent.
    # Determine uniform scale factor
    scale_factor = 1.0
    if "target_height" in spec:
        current_h = raw_dim_z
        target_h = spec["target_height"]
        if current_h > 0.001:
            scale_factor = target_h / current_h
    elif "target_length" in spec:
        max_extent = max(raw_dim_x, raw_dim_y, raw_dim_z)
        target_len = spec["target_length"]
        if max_extent > 0.001:
            scale_factor = target_len / max_extent

    print(f"[{spec['id']}] Scale factor: {scale_factor:.4f}")

    # Scale root / objects
    for o in mesh_objs:
        o.scale *= scale_factor
    bpy.context.view_layer.update()

    # Re-apply transform
    for o in mesh_objs:
        bpy.context.view_layer.objects.active = o
        o.select_set(True)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        o.select_set(False)

    # Recalculate corners after scale
    bbox_corners = []
    for o in mesh_objs:
        for corner in o.bound_box:
            bbox_corners.append(o.matrix_world @ mathutils.Vector(corner))

    min_x = min(v.x for v in bbox_corners)
    max_x = max(v.x for v in bbox_corners)
    min_y = min(v.y for v in bbox_corners)
    max_y = max(v.y for v in bbox_corners)
    min_z = min(v.z for v in bbox_corners)
    max_z = max(v.z for v in bbox_corners)

    norm_dim_x = max_x - min_x
    norm_dim_y = max_y - min_y
    norm_dim_z = max_z - min_z

    # Pivot adjustment:
    # Ground prop: Center X, Center Y, Min Z at 0.0
    # Wall prop: Center X, Back Y at 0.0, Center Z
    # Weapon: align along Z with origin at hilt guard (e.g. 20% from bottom of blade extent)
    offset = mathutils.Vector((0, 0, 0))
    if spec["type"] == "ground_prop":
        offset = mathutils.Vector((-(min_x + max_x) * 0.5, -(min_y + max_y) * 0.5, -min_z))
    elif spec["type"] == "wall_prop":
        offset = mathutils.Vector((-(min_x + max_x) * 0.5, -min_y, -(min_z + max_z) * 0.5))
    elif spec["type"] == "weapon":
        # For weapon in Blender: if longest axis is Z or Y
        offset = mathutils.Vector((-(min_x + max_x) * 0.5, -(min_y + max_y) * 0.5, -(min_z + (max_z - min_z) * 0.20)))

    for o in mesh_objs:
        o.location += offset

    bpy.context.view_layer.update()
    for o in mesh_objs:
        bpy.context.view_layer.objects.active = o
        o.select_set(True)
        bpy.ops.object.transform_apply(location=True, rotation=False, scale=False)
        o.select_set(False)

    # Save .blend source
    blend_out_dir = REPO_ROOT / f"artifacts/eleven-eleven/art/production/tripo-20261007/{spec['id']}"
    blend_out_dir.mkdir(parents=True, exist_ok=True)
    blend_file = blend_out_dir / f"{spec['name']}_source.blend"
    bpy.ops.wm.save_as_mainfile(filepath=str(blend_file))
    print(f"[{spec['id']}] Saved .blend source to {blend_file}")

    # Export normalized GLB
    norm_glb = blend_out_dir / f"{spec['name']}_normalized.glb"
    bpy.ops.export_scene.gltf(
        filepath=str(norm_glb),
        export_format='GLB',
        use_selection=False,
        export_apply=True,
        export_yup=True, # Standard glTF Y-up
        export_tangents=True,
        export_materials='EXPORT',
        export_image_format='AUTO'
    )
    print(f"[{spec['id']}] Exported normalized GLB to {norm_glb}")

    norm_sha = sha256_file(norm_glb)
    norm_bytes = norm_glb.stat().st_size

    # Texture maps list
    textures = []
    for img in bpy.data.images:
        if img.name not in ["Render Result", "Viewer Node"]:
            textures.append({
                "name": img.name,
                "size": list(img.size),
                "filepath": img.filepath
            })

    return {
        "id": spec["id"],
        "name": spec["name"],
        "task_id": spec["task_id"],
        "description": spec["description"],
        "raw_file": str(raw_glb),
        "raw_sha256": raw_sha,
        "raw_bytes": raw_bytes,
        "blend_source": str(blend_file),
        "normalized_file": str(norm_glb),
        "normalized_sha256": norm_sha,
        "normalized_bytes": norm_bytes,
        "triangles": total_triangles,
        "vertices": total_verts,
        "scale_applied": scale_factor,
        "dimensions_meters": {
            "x": round(norm_dim_x, 4),
            "y": round(norm_dim_y, 4),
            "z": round(norm_dim_z, 4)
        },
        "textures": textures
    }

def main():
    results = []
    for spec in ASSETS_SPEC:
        res = process_asset(spec)
        results.append(res)
    
    out_json = REPO_ROOT / "artifacts/eleven-eleven/audits/evidence/tripo-normalization-results-20261008.json"
    out_json.parent.mkdir(parents=True, exist_ok=True)
    with open(out_json, "w", encoding="utf-8") as f:
        json.dump(results, f, indent=2)
    
    print(f"NORMALIZATION_COMPLETE results_saved={out_json}")

if __name__ == "__main__":
    main()

"""Production cleanup and normalization of Standard Katana and Shadow Katana.
Applies honest proportions:
- overall length: ~0.95m - 1.05m
- blade width: ~0.03m - 0.04m (0.035m)
- blade spine: ~0.008m (8mm)
- guard diameter: ~0.08m (80mm)
- grip length: ~0.25m - 0.28m
- grip cross-section: ~0.026m x ~0.020m
- measured guard/grip pivot: (0, 0, 0) precisely at the center of the guard/tsuba
- single intended blade (removes loose degenerate vertices/islands)
- preserves all original materials, textures, UV maps
- updates Blender .blend sources and exports normalized GLBs
- copies to Godot assets/weapons directory
"""
import sys
import json
import shutil
import hashlib
from pathlib import Path
import bpy
import bmesh
import mathutils

REPO_ROOT = Path("c:/Users/yasmo/EchoNetwork")

def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        while chunk := f.read(65536):
            h.update(chunk)
    return h.hexdigest()

def smoothstep(edge0, edge1, x):
    t = max(0.0, min(1.0, (x - edge0) / (edge1 - edge0)))
    return t * t * (3.0 - 2.0 * t)

def lerp(a, b, t):
    return a + (b - a) * t

def process_weapon(blend_path, config):
    print(f"\n==================================================")
    print(f"Processing {config['name']} from {blend_path.name}")
    print(f"==================================================")
    
    bpy.ops.wm.read_homefile(use_empty=True)
    bpy.ops.wm.open_mainfile(filepath=str(blend_path))
    
    mesh_objs = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    if not mesh_objs:
        raise ValueError(f"No mesh objects found in {blend_path}")
    obj = mesh_objs[0]
    me = obj.data
    
    # 1. Apply any existing object transform so mesh coordinates are true world coordinates
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    
    # 2. Optional Z shift (for shadow katana to align guard plate at Z=0)
    z_shift = config.get("z_shift", 0.0)
    if abs(z_shift) > 1e-6:
        print(f"Applying Z-shift: {z_shift:+.4f}m")
        for v in me.vertices:
            v.co.z += z_shift
            
    # 3. Clean up loose/degenerate tiny noise islands (< 10 vertices)
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.verts.ensure_lookup_table()
    
    visited = set()
    islands_to_delete = []
    for v in bm.verts:
        if v in visited:
            continue
        island = []
        q = [v]
        visited.add(v)
        while q:
            curr = q.pop()
            island.append(curr)
            for e in curr.link_edges:
                ov = e.other_vert(curr)
                if ov not in visited:
                    visited.add(ov)
                    q.append(ov)
        if len(island) < 10:
            islands_to_delete.append(island)
            
    del_count = 0
    for island in islands_to_delete:
        for v in island:
            bm.verts.remove(v)
            del_count += 1
            
    bm.to_mesh(me)
    bm.free()
    print(f"Removed {len(islands_to_delete)} degenerate noise islands ({del_count} vertices).")
    
    # 4. Measure exact guard center in XY near Z=0 (-0.01 to +0.01)
    guard_verts = [v.co for v in me.vertices if -0.01 <= v.co.z <= 0.01]
    if not guard_verts:
        guard_verts = [v.co for v in me.vertices if -0.02 <= v.co.z <= 0.02]
    guard_cx = (min(v.x for v in guard_verts) + max(v.x for v in guard_verts)) / 2.0
    guard_cy = (min(v.y for v in guard_verts) + max(v.y for v in guard_verts)) / 2.0
    print(f"Guard center XY offset measured: X={guard_cx:+.4f}m, Y={guard_cy:+.4f}m")
    
    # Shift vertices so guard center is precisely at (0, 0)
    for v in me.vertices:
        v.co.x -= guard_cx
        v.co.y -= guard_cy
        
    # 5. Apply smooth proportional normalization along Z
    z_guard_min = config["z_guard_min"]
    z_guard_max = config["z_guard_max"]
    z_trans_grip = config["z_trans_grip"]
    z_trans_blade = config["z_trans_blade"]
    
    scale_grip_x = config["scale_grip_x"]
    scale_grip_y = config["scale_grip_y"]
    scale_guard_x = config["scale_guard_x"]
    scale_guard_y = config["scale_guard_y"]
    scale_blade_x = config["scale_blade_x"]
    scale_blade_y = config["scale_blade_y"]
    
    for v in me.vertices:
        z = v.co.z
        if z < z_guard_min:
            t = smoothstep(z_trans_grip, z_guard_min, z)
            sx = lerp(scale_grip_x, scale_guard_x, t)
            sy = lerp(scale_grip_y, scale_guard_y, t)
        elif z > z_guard_max:
            t = smoothstep(z_guard_max, z_trans_blade, z)
            sx = lerp(scale_guard_x, scale_blade_x, t)
            sy = lerp(scale_guard_y, scale_blade_y, t)
        else:
            sx = scale_guard_x
            sy = scale_guard_y
            
        v.co.x *= sx
        v.co.y *= sy
        
    me.update()
    
    # 6. Recalculate smooth normals
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.shade_smooth()
    
    # Also recalculate normals in bmesh
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    me.update()
    
    # 7. Final measurements and verification
    xs = [v.co.x for v in me.vertices]
    ys = [v.co.y for v in me.vertices]
    zs = [v.co.z for v in me.vertices]
    
    g_verts = [v.co for v in me.vertices if -0.01 <= v.co.z <= 0.01]
    g_diam_x = max(v.x for v in g_verts) - min(v.x for v in g_verts)
    g_diam_y = max(v.y for v in g_verts) - min(v.y for v in g_verts)
    
    b_verts = [v.co for v in me.vertices if 0.35 <= v.co.z <= 0.40]
    b_width = max(v.x for v in b_verts) - min(v.x for v in b_verts)
    b_spine = max(v.y for v in b_verts) - min(v.y for v in b_verts)
    
    grip_verts = [v.co for v in me.vertices if -0.15 <= v.co.z <= -0.10]
    gr_width = max(v.x for v in grip_verts) - min(v.x for v in grip_verts)
    gr_thick = max(v.y for v in grip_verts) - min(v.y for v in grip_verts)
    
    grip_len = abs(min(zs))
    total_len = max(zs) - min(zs)
    
    # 8. Save updated .blend files
    # Save main .blend
    bpy.ops.wm.save_as_mainfile(filepath=str(blend_path))
    print(f"Saved normalized source: {blend_path}")
    
    # Also save to _source.blend
    source_blend = blend_path.parent / f"{config['output_base']}_source.blend"
    bpy.ops.wm.save_as_mainfile(filepath=str(source_blend))
    print(f"Saved secondary source: {source_blend}")
    
    # 9. Export normalized GLB
    normalized_glb = blend_path.parent / f"{config['output_base']}_normalized.glb"
    bpy.ops.export_scene.gltf(
        filepath=str(normalized_glb),
        export_format='GLB',
        use_selection=False,
        export_apply=True,
        export_yup=True,
        export_tangents=True,
        export_materials='EXPORT',
        export_image_format='AUTO'
    )
    print(f"Exported normalized GLB: {normalized_glb} ({normalized_glb.stat().st_size} bytes)")
    
    # 10. Copy to Godot weapons folder
    godot_dest = REPO_ROOT / f"artifacts/eleven-eleven/godot/assets/weapons/{config['output_base']}.glb"
    shutil.copy2(normalized_glb, godot_dest)
    print(f"Copied to Godot weapons folder: {godot_dest}")
    
    glb_sha = sha256_file(normalized_glb)
    godot_sha = sha256_file(godot_dest)
    assert glb_sha == godot_sha, "Export and Godot copy SHA mismatch!"
    
    summary = {
        "weapon_id": config["name"],
        "output_base": config["output_base"],
        "blend_file": str(blend_path),
        "source_blend_file": str(source_blend),
        "normalized_glb": str(normalized_glb),
        "godot_glb": str(godot_dest),
        "sha256": glb_sha,
        "file_size_bytes": normalized_glb.stat().st_size,
        "vertices": len(me.vertices),
        "triangles": len(me.polygons),
        "overall_length_m": round(total_len, 4),
        "grip_length_m": round(grip_len, 4),
        "guard_diameter_x_m": round(g_diam_x, 4),
        "guard_diameter_y_m": round(g_diam_y, 4),
        "blade_width_m": round(b_width, 4),
        "blade_spine_m": round(b_spine, 4),
        "grip_width_m": round(gr_width, 4),
        "grip_thickness_m": round(gr_thick, 4),
        "pivot_point": [0.0, 0.0, 0.0],
        "bbox_min": [round(min(xs), 4), round(min(ys), 4), round(min(zs), 4)],
        "bbox_max": [round(max(xs), 4), round(max(ys), 4), round(max(zs), 4)],
        "bbox_size": [round(max(xs)-min(xs), 4), round(max(ys)-min(ys), 4), round(max(zs)-min(zs), 4)]
    }
    
    print("\n--- Summary ---")
    for k, v in summary.items():
        print(f"  {k}: {v}")
        
    return summary

def main():
    std_config = {
        "name": "Standard Katana",
        "output_base": "standard_katana_tripo_20261008",
        "z_shift": 0.0,
        "z_guard_min": -0.010,
        "z_guard_max": 0.008,
        "z_trans_grip": -0.025,
        "z_trans_blade": 0.025,
        "scale_guard_x": 0.080 / 0.163, # ~0.4908
        "scale_guard_y": 0.080 / 0.145, # ~0.5517
        "scale_grip_x": 0.470,          # ergonomic grip width ~0.027m
        "scale_grip_y": 0.400,          # ergonomic grip thickness ~0.020m
        "scale_blade_x": 0.035 / 0.065, # ~0.538 (blade width 0.035m)
        "scale_blade_y": 0.008 / 0.032, # ~0.250 (blade spine 0.008m)
    }

    shd_config = {
        "name": "Shadow Katana",
        "output_base": "shadow_katana_tripo_20261008",
        "z_shift": 0.043,               # shifts guard plate from -0.043 to 0.0
        "z_guard_min": -0.010,
        "z_guard_max": 0.008,
        "z_trans_grip": -0.025,
        "z_trans_blade": 0.025,
        "scale_guard_x": 0.080 / 0.162, # ~0.4938
        "scale_guard_y": 0.080 / 0.160, # ~0.5000
        "scale_grip_x": 0.600,          # ergonomic grip width ~0.027m
        "scale_grip_y": 0.460,          # ergonomic grip thickness ~0.020m
        "scale_blade_x": 0.035 / 0.038, # ~0.921 (blade width 0.035m)
        "scale_blade_y": 0.008 / 0.043, # ~0.186 (blade spine 0.008m)
    }
    
    std_summary = process_weapon(
        REPO_ROOT / "artifacts/eleven-eleven/art/production/tripo-20261007/standard-katana/standard-katana.blend",
        std_config
    )
    
    shd_summary = process_weapon(
        REPO_ROOT / "artifacts/eleven-eleven/art/production/tripo-20261007/shadow-katana/shadow-katana.blend",
        shd_config
    )
    
    out_evidence = REPO_ROOT / "artifacts/eleven-eleven/audits/evidence/tripo_weapons_cleanup_evidence_20261008.json"
    out_evidence.parent.mkdir(parents=True, exist_ok=True)
    with open(out_evidence, "w", encoding="utf-8") as f:
        json.dump({
            "standard_katana": std_summary,
            "shadow_katana": shd_summary
        }, f, indent=2)
        
    print(f"\nSaved complete cleanup evidence to: {out_evidence}")

if __name__ == "__main__":
    main()

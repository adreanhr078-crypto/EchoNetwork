import os
import sys
import json
import hashlib
import numpy as np
import bpy
import bmesh
from mathutils import Vector, Matrix

BASE_DIR = r"C:\Users\yasmo\EchoNetwork"
TRIPO_DIR = os.path.join(BASE_DIR, r"artifacts\eleven-eleven\art\production\tripo-20261007")
GODOT_PROPS_DIR = os.path.join(BASE_DIR, r"artifacts\eleven-eleven\godot\assets\props")

os.makedirs(GODOT_PROPS_DIR, exist_ok=True)

def setup_scene(in_glb):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=in_glb)
    obj = bpy.context.scene.objects[0]
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    # Bake node scale, rotation, translation into mesh data
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return obj

def normalize_standard_katana():
    asset_id = "standard-katana"
    in_glb = os.path.join(TRIPO_DIR, r"standard-katana\tripo-out\standard-katana-20261007-f43b4b42\model.glb")
    out_blend = os.path.join(TRIPO_DIR, r"standard-katana\standard-katana.blend")
    out_glb = os.path.join(GODOT_PROPS_DIR, f"{asset_id}_tripo_20261008.glb")

    obj = setup_scene(in_glb)
    mesh = obj.data

    coords = np.array([v.co for v in mesh.vertices])
    centroid = coords.mean(axis=0)
    centered = coords - centroid
    cov = np.cov(centered, rowvar=False)
    eig_vals, eig_vecs = np.linalg.eigh(cov)
    axis_long = eig_vecs[:, 2] # major axis
    vec_tip = -axis_long
    vec_tip /= np.linalg.norm(vec_tip)

    p_tip = centered @ vec_tip
    # Guard / tsuba center
    mask_guard = (p_tip >= -0.20 * 0.65) & (p_tip <= 0.0)
    guard_center = coords[mask_guard].mean(axis=0)
    mask_tip = p_tip >= (p_tip.max() - 0.05 * 0.65)
    tip_center = coords[mask_tip].mean(axis=0)
    mask_pommel = p_tip <= (p_tip.min() + 0.05 * 0.65)
    pommel_center = coords[mask_pommel].mean(axis=0)

    # Longitudinal vector from guard to tip
    v_long = (tip_center - guard_center)
    v_long /= np.linalg.norm(v_long)

    # In Blender: +Z is UP (becomes +Y UP in Godot)
    target_z = Vector((0.0, 0.0, 1.0))
    rot_q = Vector(v_long).rotation_difference(target_z)
    rot_mat = rot_q.to_matrix().to_4x4()
    trans_mat = Matrix.Translation(-Vector(guard_center))
    transform1 = rot_mat @ trans_mat

    for v in mesh.vertices:
        v.co = transform1 @ v.co

    coords_rot = np.array([v.co for v in mesh.vertices])
    z_min = coords_rot[:, 2].min()
    z_max = coords_rot[:, 2].max()
    curr_len = z_max - z_min
    target_len = 0.95 # Target length: 0.95m total (~0.85m - 1.0m)
    scale_fac = target_len / curr_len

    # Align blade flat to X and cutting edge to -Y (forward in Blender)
    blade_verts = coords_rot[(coords_rot[:, 2] >= 0.1 * curr_len) & (coords_rot[:, 2] <= 0.4 * curr_len)]
    cov_xy = np.cov(blade_verts[:, :2], rowvar=False)
    _, e_vecs_xy = np.linalg.eigh(cov_xy)
    edge_axis = e_vecs_xy[:, 1]
    angle = np.arctan2(edge_axis[0], -edge_axis[1])
    rot_z = Matrix.Rotation(angle, 4, 'Z')

    scale_mat = Matrix.Diagonal((scale_fac, scale_fac, scale_fac, 1.0))
    final_transform = rot_z @ scale_mat

    for v in mesh.vertices:
        v.co = final_transform @ v.co

    # Ensure Guard is exactly at Z = 0
    guard_z = np.mean([v.co.z for v in mesh.vertices if abs(v.co.z) < 0.02 * target_len])
    for v in mesh.vertices:
        v.co.z -= guard_z

    mesh.update()
    bpy.ops.file.pack_all()
    bpy.ops.wm.save_as_mainfile(filepath=out_blend)
    bpy.ops.export_scene.gltf(filepath=out_glb, export_format='GLB')
    return {"id": asset_id, "out_blend": out_blend, "out_glb": out_glb}

def normalize_shadow_katana():
    asset_id = "shadow-katana"
    in_glb = os.path.join(TRIPO_DIR, r"shadow-katana\tripo-out\shadow-katana-20261007-c9cae674\model.glb")
    out_blend = os.path.join(TRIPO_DIR, r"shadow-katana\shadow-katana.blend")
    out_glb = os.path.join(GODOT_PROPS_DIR, f"{asset_id}_tripo_20261008.glb")

    obj = setup_scene(in_glb)
    
    # Isolate blade mesh (Z > 0) and discard scabbard (Z < 0)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    verts_to_delete = [v for v in bm.verts if v.co.z < 0]
    bmesh.ops.delete(bm, geom=verts_to_delete, context='VERTS')
    bm.to_mesh(obj.data)
    bm.free()

    mesh = obj.data
    coords = np.array([v.co for v in mesh.vertices])

    # Currently for Part Pos (Z > 0):
    # Length is along Y (from min Y to max Y)
    # Tsuba is around Y = -0.22
    guard_mask = (coords[:, 1] >= -0.25) & (coords[:, 1] <= -0.18)
    guard_center = coords[guard_mask].mean(axis=0)

    # Move guard to (0, 0, 0) and rotate +Y to +Z
    rot_x = Matrix.Rotation(np.pi / 2, 4, 'X')
    for v in mesh.vertices:
        v.co = rot_x @ Vector(v.co - Vector(guard_center))

    coords_rot = np.array([v.co for v in mesh.vertices])
    z_min = coords_rot[:, 2].min()
    z_max = coords_rot[:, 2].max()
    curr_len = z_max - z_min
    target_len = 1.05 # Spec ~1.0m - 1.1m
    scale_fac = target_len / curr_len

    scale_mat = Matrix.Diagonal((scale_fac, scale_fac, scale_fac, 1.0))
    for v in mesh.vertices:
        v.co = scale_mat @ v.co

    guard_z = np.mean([v.co.z for v in mesh.vertices if abs(v.co.z) < 0.02 * target_len])
    for v in mesh.vertices:
        v.co.z -= guard_z

    mesh.update()
    bpy.ops.file.pack_all()
    bpy.ops.wm.save_as_mainfile(filepath=out_blend)
    bpy.ops.export_scene.gltf(filepath=out_glb, export_format='GLB')
    return {"id": asset_id, "out_blend": out_blend, "out_glb": out_glb}

def normalize_diagnostic_cart():
    asset_id = "diagnostic-cart"
    in_glb = os.path.join(TRIPO_DIR, r"diagnostic-cart\tripo-out\diagnostic-cart-20261007-787ef5a5\model.glb")
    out_blend = os.path.join(TRIPO_DIR, r"diagnostic-cart\diagnostic-cart.blend")
    out_glb = os.path.join(GODOT_PROPS_DIR, f"{asset_id}_tripo_20261008.glb")

    obj = setup_scene(in_glb)
    mesh = obj.data

    coords = np.array([v.co for v in mesh.vertices])
    z_min = coords[:, 2].min()
    z_max = coords[:, 2].max()
    curr_height = z_max - z_min
    target_height = 1.10 # Target: 1.1m tall
    scale_fac = target_height / curr_height

    x_center = (coords[:, 0].min() + coords[:, 0].max()) / 2.0
    y_center = (coords[:, 1].min() + coords[:, 1].max()) / 2.0

    for v in mesh.vertices:
        x = (v.co.x - x_center) * scale_fac
        y = (v.co.y - y_center) * scale_fac
        z = (v.co.z - z_min) * scale_fac # wheels on floor at Z=0
        v.co = Vector((x, y, z))

    mesh.update()
    bpy.ops.file.pack_all()
    bpy.ops.wm.save_as_mainfile(filepath=out_blend)
    bpy.ops.export_scene.gltf(filepath=out_glb, export_format='GLB')
    return {"id": asset_id, "out_blend": out_blend, "out_glb": out_glb}

def normalize_security_terminal():
    asset_id = "security-terminal"
    in_glb = os.path.join(TRIPO_DIR, r"security-terminal\tripo-out\security-terminal-20261007-df7cbe72\model.glb")
    out_blend = os.path.join(TRIPO_DIR, r"security-terminal\security-terminal.blend")
    out_glb = os.path.join(GODOT_PROPS_DIR, f"{asset_id}_tripo_20261008.glb")

    obj = setup_scene(in_glb)
    mesh = obj.data

    # Rotate -90 deg around Z: Pos X (screen) -> -Y (forward), Neg X (back) -> +Y (mounting back)
    rot_z = Matrix.Rotation(-np.pi / 2, 4, 'Z')
    for v in mesh.vertices:
        v.co = rot_z @ v.co

    coords = np.array([v.co for v in mesh.vertices])
    z_min = coords[:, 2].min()
    z_max = coords[:, 2].max()
    curr_height = z_max - z_min
    target_height = 0.65 # Target: 0.65m tall
    scale_fac = target_height / curr_height

    y_back = coords[:, 1].max() # mounting back plane
    x_center = (coords[:, 0].min() + coords[:, 0].max()) / 2.0
    z_center = (coords[:, 2].min() + coords[:, 2].max()) / 2.0

    for v in mesh.vertices:
        x = (v.co.x - x_center) * scale_fac
        y = (v.co.y - y_back) * scale_fac # mounting back at Y=0
        z = (v.co.z - z_center) * scale_fac # centered vertically
        v.co = Vector((x, y, z))

    mesh.update()
    bpy.ops.file.pack_all()
    bpy.ops.wm.save_as_mainfile(filepath=out_blend)
    bpy.ops.export_scene.gltf(filepath=out_glb, export_format='GLB')
    return {"id": asset_id, "out_blend": out_blend, "out_glb": out_glb}

def normalize_observation_server():
    asset_id = "observation-server"
    in_glb = os.path.join(TRIPO_DIR, r"observation-server\tripo-out\observation-server-20261007-4cdb4008\model.glb")
    out_blend = os.path.join(TRIPO_DIR, r"observation-server\observation-server.blend")
    out_glb = os.path.join(GODOT_PROPS_DIR, f"{asset_id}_tripo_20261008.glb")

    obj = setup_scene(in_glb)
    mesh = obj.data

    coords = np.array([v.co for v in mesh.vertices])
    z_min = coords[:, 2].min()
    z_max = coords[:, 2].max()
    curr_height = z_max - z_min
    target_height = 1.70 # Target: 1.7m tall
    scale_fac = target_height / curr_height

    x_center = (coords[:, 0].min() + coords[:, 0].max()) / 2.0
    y_center = (coords[:, 1].min() + coords[:, 1].max()) / 2.0

    for v in mesh.vertices:
        x = (v.co.x - x_center) * scale_fac
        y = (v.co.y - y_center) * scale_fac
        z = (v.co.z - z_min) * scale_fac # base on floor at Z=0
        v.co = Vector((x, y, z))

    mesh.update()
    bpy.ops.file.pack_all()
    bpy.ops.wm.save_as_mainfile(filepath=out_blend)
    bpy.ops.export_scene.gltf(filepath=out_glb, export_format='GLB')
    return {"id": asset_id, "out_blend": out_blend, "out_glb": out_glb}

def normalize_medical_wall_unit():
    asset_id = "medical-wall-unit"
    in_glb = os.path.join(TRIPO_DIR, r"medical-wall-unit\tripo-out\medical-wall-unit-20261007-5affa583\model.glb")
    out_blend = os.path.join(TRIPO_DIR, r"medical-wall-unit\medical-wall-unit.blend")
    out_glb = os.path.join(GODOT_PROPS_DIR, f"{asset_id}_tripo_20261008.glb")

    obj = setup_scene(in_glb)
    mesh = obj.data

    coords = np.array([v.co for v in mesh.vertices])
    z_min = coords[:, 2].min()
    z_max = coords[:, 2].max()
    curr_height = z_max - z_min
    target_height = 0.90 # Target: 0.9m tall
    scale_fac = target_height / curr_height

    y_back = coords[:, 1].max() # mounting back plane
    x_center = (coords[:, 0].min() + coords[:, 0].max()) / 2.0
    z_center = (coords[:, 2].min() + coords[:, 2].max()) / 2.0

    for v in mesh.vertices:
        x = (v.co.x - x_center) * scale_fac
        y = (v.co.y - y_back) * scale_fac # mounting back at Y=0
        z = (v.co.z - z_center) * scale_fac # centered vertically
        v.co = Vector((x, y, z))

    mesh.update()
    bpy.ops.file.pack_all()
    bpy.ops.wm.save_as_mainfile(filepath=out_blend)
    bpy.ops.export_scene.gltf(filepath=out_glb, export_format='GLB')
    return {"id": asset_id, "out_blend": out_blend, "out_glb": out_glb}

def main():
    runners = [
        normalize_standard_katana,
        normalize_shadow_katana,
        normalize_diagnostic_cart,
        normalize_security_terminal,
        normalize_observation_server,
        normalize_medical_wall_unit
    ]
    for r in runners:
        print(f"Running {r.__name__}...")
        res = r()
        print(f"Done: {res}")

if __name__ == "__main__":
    main()

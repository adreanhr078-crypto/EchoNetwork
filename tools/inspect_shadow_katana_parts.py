import bpy
import numpy as np

bpy.ops.wm.read_factory_settings(use_empty=True)
glb_path = r"C:\Users\yasmo\EchoNetwork\artifacts\eleven-eleven\art\production\tripo-20261007\shadow-katana\tripo-out\shadow-katana-20261007-c9cae674\model.glb"
bpy.ops.import_scene.gltf(filepath=glb_path)
obj = bpy.context.scene.objects[0]
mesh = obj.data

coords = np.array([v.co for v in mesh.vertices])
obj_neg = coords[coords[:, 2] < 0]
obj_pos = coords[coords[:, 2] > 0]
obj_mid = coords[(coords[:, 2] >= -0.2) & (coords[:, 2] <= 0.2)]

print(f"Total vertices: {len(coords)}")
print(f"Vertices with Z < 0: {len(obj_neg)}")
print(f"Vertices with Z > 0: {len(obj_pos)}")
print(f"Vertices with -0.2 <= Z <= 0.2: {len(obj_mid)}")

print("\n--- Object Neg (Z < 0) ---")
print(f"BBox min: {obj_neg.min(axis=0)}")
print(f"BBox max: {obj_neg.max(axis=0)}")
dims_neg = obj_neg.max(axis=0) - obj_neg.min(axis=0)
print(f"Dims: {dims_neg}")

print("\n--- Object Pos (Z > 0) ---")
print(f"BBox min: {obj_pos.min(axis=0)}")
print(f"BBox max: {obj_pos.max(axis=0)}")
dims_pos = obj_pos.max(axis=0) - obj_pos.min(axis=0)
print(f"Dims: {dims_pos}")

# Analyze shape of both along Y (length)
# In katana, blade has a sharp cutting edge (narrow cross-section, thickness < 1-2cm)
# While scabbard is thicker throughout (hollow sheath)
for name, pts in [("Neg (Z < 0)", obj_neg), ("Pos (Z > 0)", obj_pos)]:
    print(f"\nProfile of {name} along Y (from min Y to max Y):")
    y_min, y_max = pts[:, 1].min(), pts[:, 1].max()
    y_steps = np.linspace(y_min, y_max, 6)
    for i in range(5):
        m = (pts[:, 1] >= y_steps[i]) & (pts[:, 1] < y_steps[i+1])
        s_pts = pts[m]
        if len(s_pts) > 0:
            x_w = s_pts[:, 0].max() - s_pts[:, 0].min()
            z_w = s_pts[:, 2].max() - s_pts[:, 2].min()
            print(f"  Y [{y_steps[i]:.2f}, {y_steps[i+1]:.2f}]: count={len(s_pts)}, x_width={x_w:.4f}, z_width={z_w:.4f}")

bpy.ops.wm.quit_blender()

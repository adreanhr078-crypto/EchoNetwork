import bpy
import numpy as np

bpy.ops.wm.read_factory_settings(use_empty=True)
glb_path = r"C:\Users\yasmo\EchoNetwork\artifacts\eleven-eleven\art\production\tripo-20261007\shadow-katana\tripo-out\shadow-katana-20261007-c9cae674\model.glb"
bpy.ops.import_scene.gltf(filepath=glb_path)
obj = bpy.context.scene.objects[0]
coords = np.array([v.co for v in obj.data.vertices])

# Let's inspect Part Neg (Z < 0) vs Part Pos (Z > 0)
neg_mask = coords[:, 2] < 0
pos_mask = coords[:, 2] > 0

coords_neg = coords[neg_mask]
coords_pos = coords[pos_mask]

# For both parts, find pommel (min Y) and tip (max Y)
print(f"Neg: Y range [{coords_neg[:, 1].min():.4f}, {coords_neg[:, 1].max():.4f}], Z mean={coords_neg[:, 2].mean():.4f}")
print(f"Pos: Y range [{coords_pos[:, 1].min():.4f}, {coords_pos[:, 1].max():.4f}], Z mean={coords_pos[:, 2].mean():.4f}")

# Look at the cross-section of the 'blade' region (Y from 0.1 to 0.4)
# In a blade, thickness is narrow.
# Let's see thickness (range in X or Z) in that region:
neg_blade = coords_neg[(coords_neg[:, 1] >= 0.1) & (coords_neg[:, 1] <= 0.4)]
pos_blade = coords_pos[(coords_pos[:, 1] >= 0.1) & (coords_pos[:, 1] <= 0.4)]

print("Neg blade section:")
print(f"  X span: {neg_blade[:, 0].max() - neg_blade[:, 0].min():.4f}")
print(f"  Z span: {neg_blade[:, 2].max() - neg_blade[:, 2].min():.4f}")

print("Pos blade section:")
print(f"  X span: {pos_blade[:, 0].max() - pos_blade[:, 0].min():.4f}")
print(f"  Z span: {pos_blade[:, 2].max() - pos_blade[:, 2].min():.4f}")

# Look at the tsuba/guard region (Y around -0.2)
neg_guard = coords_neg[(coords_neg[:, 1] >= -0.25) & (coords_neg[:, 1] <= -0.15)]
pos_guard = coords_pos[(coords_pos[:, 1] >= -0.25) & (coords_pos[:, 1] <= -0.15)]
print(f"Neg guard X span: {neg_guard[:, 0].max() - neg_guard[:, 0].min():.4f}")
print(f"Pos guard X span: {pos_guard[:, 0].max() - pos_guard[:, 0].min():.4f}")

# Look at the grip region (Y around -0.4)
neg_grip = coords_neg[(coords_neg[:, 1] >= -0.45) & (coords_neg[:, 1] <= -0.35)]
pos_grip = coords_pos[(coords_pos[:, 1] >= -0.45) & (coords_pos[:, 1] <= -0.35)]
print(f"Neg grip X span: {neg_grip[:, 0].max() - neg_grip[:, 0].min():.4f}")
print(f"Pos grip X span: {pos_grip[:, 0].max() - pos_grip[:, 0].min():.4f}")

bpy.ops.wm.quit_blender()

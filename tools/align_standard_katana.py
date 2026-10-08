import bpy
import numpy as np
from mathutils import Vector, Matrix

bpy.ops.wm.read_factory_settings(use_empty=True)
glb_path = r"C:\Users\yasmo\EchoNetwork\artifacts\eleven-eleven\art\production\tripo-20261007\standard-katana\tripo-out\standard-katana-20261007-f43b4b42\model.glb"
bpy.ops.import_scene.gltf(filepath=glb_path)
obj = bpy.context.scene.objects[0]
mesh = obj.data

coords = np.array([v.co for v in mesh.vertices])

# In our earlier analysis:
# Major axis = [-0.33296659, 0.65091443, 0.68223432]
# Negative projection = Tip of blade
# Positive projection = Pommel
# Guard (tsuba) is at projection ~ 0.11
# Let's verify by finding the tsuba vertices:
# The tsuba has maximum radius perpendicular to the major axis!
centroid = coords.mean(axis=0)
centered = coords - centroid
cov = np.cov(centered, rowvar=False)
eig_vals, eig_vecs = np.linalg.eigh(cov)
# Primary axis is eig_vecs[:, 2]
axis_long = eig_vecs[:, 2]
# Ensure axis_long points from pommel to tip (towards blade tip)
# If negative projection is tip, let's make axis_long point towards tip:
proj = centered @ axis_long
if (coords[proj < proj.mean(), 1].mean() < coords[proj > proj.mean(), 1].mean()):
    pass # Let's check which end is tip:
# We know slice 0 (min proj ~ -0.9) is tip, slice 9 (max proj ~ +0.5) is pommel.
# So to point from pommel to tip, vector should be -axis_long:
vec_tip = -axis_long
vec_tip /= np.linalg.norm(vec_tip)

# Let's find the guard (tsuba) center:
# In projection along -axis_long, pommel is at min, tip is at max
p_tip = centered @ vec_tip
# Guard was at around centered @ axis_long = 0.11 -> p_tip = -0.11
# In that slice, max distance from axis was highest (tsuba has guard wings)
mask_guard = (p_tip >= -0.20) & (p_tip <= 0.0)
guard_coords = coords[mask_guard]
guard_center = guard_coords.mean(axis=0)

# Pommel center
mask_pommel = p_tip <= (p_tip.min() + 0.05)
pommel_center = coords[mask_pommel].mean(axis=0)

# Tip center
mask_tip = p_tip >= (p_tip.max() - 0.05)
tip_center = coords[mask_tip].mean(axis=0)

print(f"Pommel center: {pommel_center}")
print(f"Guard center: {guard_center}")
print(f"Tip center: {tip_center}")

# Handle vector: guard_center - pommel_center
# Blade vector: tip_center - guard_center
handle_len = np.linalg.norm(guard_center - pommel_center)
blade_len = np.linalg.norm(tip_center - guard_center)
total_len = np.linalg.norm(tip_center - pommel_center)

print(f"Handle length: {handle_len:.4f} m")
print(f"Blade length: {blade_len:.4f} m")
print(f"Total tip-to-pommel length: {total_len:.4f} m")

bpy.ops.wm.quit_blender()

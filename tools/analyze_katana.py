import bpy
import numpy as np
from mathutils import Vector

bpy.ops.wm.read_factory_settings(use_empty=True)
glb_path = r"C:\Users\yasmo\EchoNetwork\artifacts\eleven-eleven\art\production\tripo-20261007\standard-katana\tripo-out\standard-katana-20261007-f43b4b42\model.glb"
bpy.ops.import_scene.gltf(filepath=glb_path)

mesh_objs = [obj for obj in bpy.context.scene.objects if obj.type == 'MESH']
assert len(mesh_objs) == 1
obj = mesh_objs[0]
mesh = obj.data

# Get vertex coordinates
coords = np.array([v.co for v in mesh.vertices])
print(f"Vertex count: {len(coords)}")
print(f"Min coords: {coords.min(axis=0)}")
print(f"Max coords: {coords.max(axis=0)}")
print(f"Dimensions: {coords.max(axis=0) - coords.min(axis=0)}")

# PCA to find the principal length axis
centroid = coords.mean(axis=0)
centered = coords - centroid
cov = np.cov(centered, rowvar=False)
eigenvalues, eigenvectors = np.linalg.eigh(cov)
# Major axis is the last eigenvector
major_axis = eigenvectors[:, 2]
print(f"Centroid: {centroid}")
print(f"Major axis: {major_axis}")

# Project vertices onto major axis
projections = centered @ major_axis
min_proj = projections.min()
max_proj = projections.max()
length_along_major = max_proj - min_proj
print(f"Total length along major axis: {length_along_major:.4f} m")

# Look at slices along the major axis to identify which end is hilt vs tip
# For example, 10 slices
slice_steps = np.linspace(min_proj, max_proj, 11)
print("Slices along major axis (min to max):")
for i in range(10):
    mask = (projections >= slice_steps[i]) & (projections < slice_steps[i+1])
    slice_coords = centered[mask]
    if len(slice_coords) > 0:
        # Distance from major axis
        proj_pts = np.outer(projections[mask], major_axis)
        perp_dists = np.linalg.norm(slice_coords - proj_pts, axis=1)
        print(f"Slice {i} ({slice_steps[i]:.2f} to {slice_steps[i+1]:.2f}): count={len(slice_coords)}, max_radius={perp_dists.max():.4f}, mean_radius={perp_dists.mean():.4f}")

bpy.ops.wm.quit_blender()

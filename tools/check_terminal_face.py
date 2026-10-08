import bpy
import numpy as np

bpy.ops.wm.read_factory_settings(use_empty=True)
glb_path = r"C:\Users\yasmo\EchoNetwork\artifacts\eleven-eleven\art\production\tripo-20261007\security-terminal\tripo-out\security-terminal-20261007-df7cbe72\model.glb"
bpy.ops.import_scene.gltf(filepath=glb_path)
obj = bpy.context.scene.objects[0]
coords = np.array([v.co for v in obj.data.vertices])

# Check vertices near max X vs min X
pos_x = coords[coords[:, 0] > 0.08]
neg_x = coords[coords[:, 0] < -0.08]

print(f"Pos X count: {len(pos_x)}, mean X = {pos_x[:, 0].mean():.4f}")
print(f"Neg X count: {len(neg_x)}, mean X = {neg_x[:, 0].mean():.4f}")

# Check UVs or polygon normals
# Flat back will have normal pointing almost entirely in +X or -X
mesh = obj.data
pos_x_normals = [p.normal for p in mesh.polygons if p.center.x > 0.08]
neg_x_normals = [p.normal for p in mesh.polygons if p.center.x < -0.08]

print("Pos X face normals X-component mean:", np.mean([n.x for n in pos_x_normals]))
print("Neg X face normals X-component mean:", np.mean([n.x for n in neg_x_normals]))

# Which side has buttons and screen?
# Buttons and screen have high curvature and varying normals.
print("Pos X face normals std dev:", np.std([n for n in pos_x_normals], axis=0))
print("Neg X face normals std dev:", np.std([n for n in neg_x_normals], axis=0))

bpy.ops.wm.quit_blender()

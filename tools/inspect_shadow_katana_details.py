import bpy
import numpy as np

bpy.ops.wm.read_factory_settings(use_empty=True)
glb_path = r"C:\Users\yasmo\EchoNetwork\artifacts\eleven-eleven\art\production\tripo-20261007\shadow-katana\tripo-out\shadow-katana-20261007-c9cae674\model.glb"
bpy.ops.import_scene.gltf(filepath=glb_path)
obj = bpy.context.scene.objects[0]
mesh = obj.data

# Find image
img = bpy.data.images.get("Color_c9cae674-2f4d-49b5-8632-59f2a5caa740")
if not img:
    img = bpy.data.images[0]

# Check UV layer
uv_layer = mesh.uv_layers.active.data

# For Neg (Z < 0) and Pos (Z > 0)
# Look at the tips (Y > 0.45)
# In katana, the blade tip (kissaki) has geometry and sharp edge
tips_neg = [v for v in mesh.vertices if v.co.z < 0 and v.co.y > 0.45]
tips_pos = [v for v in mesh.vertices if v.co.z > 0 and v.co.y > 0.45]

print(f"Tips Neg count (Y > 0.45): {len(tips_neg)}, max Y = {max([v.co.y for v in tips_neg])}")
print(f"Tips Pos count (Y > 0.45): {len(tips_pos)}, max Y = {max([v.co.y for v in tips_pos])}")

# Let's inspect faces at Y in [0.2, 0.4] for both
# Check normals and curvature/sharpness
for name, z_sign in [("Neg (Z < 0)", -1), ("Pos (Z > 0)", 1)]:
    v_indices = set([v.index for v in mesh.vertices if (v.co.z * z_sign > 0)])
    part_polys = [p for p in mesh.polygons if p.vertices[0] in v_indices]
    print(f"\nPart {name}: {len(part_polys)} polygons")
    # Check polygon areas
    areas = [p.area for p in part_polys]
    print(f"  Total surface area: {sum(areas):.4f} m^2")

bpy.ops.wm.quit_blender()

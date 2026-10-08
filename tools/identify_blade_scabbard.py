import bpy
import numpy as np

bpy.ops.wm.read_factory_settings(use_empty=True)
glb_path = r"C:\Users\yasmo\EchoNetwork\artifacts\eleven-eleven\art\production\tripo-20261007\shadow-katana\tripo-out\shadow-katana-20261007-c9cae674\model.glb"
bpy.ops.import_scene.gltf(filepath=glb_path)
obj = bpy.context.scene.objects[0]
mesh = obj.data

# Let's inspect the pommel at the min Y end (around Y = -0.48 to -0.50)
pommel_neg = [v for v in mesh.vertices if v.co.z < 0 and v.co.y < -0.46]
pommel_pos = [v for v in mesh.vertices if v.co.z > 0 and v.co.y < -0.46]

print(f"Neg (Z < 0) pommel vertices count: {len(pommel_neg)}")
print(f"Pos (Z > 0) pommel vertices count: {len(pommel_pos)}")

# Check camera in preview image:
# Usually Tripo renders preview with Camera looking from +Z or -Z or angled.
# In Tripo preview:
# The image shows Top object and Bottom object.
# Let's check which one is which by looking at basecolor UV samples on the pommel or blade!
img = bpy.data.images[0]
# Sample color of pommel for Neg vs Pos
uv_data = mesh.uv_layers.active.data
polys = mesh.polygons

def get_mean_color(vert_filter):
    selected_poly_indices = []
    for poly in polys:
        if all(vert_filter(mesh.vertices[v_idx]) for v_idx in poly.vertices):
            selected_poly_indices.append(poly.index)
    
    print(f"Selected polygons: {len(selected_poly_indices)}")
    # Sample UVs
    u_list = []
    v_list = []
    for p_idx in selected_poly_indices:
        poly = polys[p_idx]
        for loop_idx in poly.loop_indices:
            uv = uv_data[loop_idx].uv
            u_list.append(uv.x)
            v_list.append(uv.y)
    if u_list:
        print(f"  UV bounds: U=[{min(u_list):.3f}, {max(u_list):.3f}], V=[{min(v_list):.3f}, {max(v_list):.3f}]")

print("Neg pommel UVs:")
get_mean_color(lambda v: v.co.z < 0 and v.co.y < -0.46)

print("Pos pommel UVs:")
get_mean_color(lambda v: v.co.z > 0 and v.co.y < -0.46)

bpy.ops.wm.quit_blender()

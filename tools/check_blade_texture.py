import bpy
import numpy as np

glb = r'artifacts/eleven-eleven/art/production/tripo-20261007/shadow-katana/tripo-out/shadow-katana-20261007-c9cae674/model.glb'
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=glb)
obj = bpy.context.scene.objects[0]
mesh = obj.data

# Let's inspect the two parts:
# In the blade portion (e.g. Y from 0.0 to 0.4):
# Sample the base color image for Z < 0 vs Z > 0
img = None
for image in bpy.data.images:
    if "Color" in image.name:
        img = image
        break

print("Color image:", img.name if img else "None", "size:", img.size if img else "")

# Get UVs and sample colors
uv_layer = mesh.uv_layers.active.data

def sample_colors(z_condition, name):
    samples = []
    # Find polygons where vertices satisfy z_condition and Y is in [0.0, 0.3] (blade / sheath body)
    for poly in mesh.polygons:
        if all(z_condition(mesh.vertices[v_idx]) and (0.0 < mesh.vertices[v_idx].co.y < 0.3) for v_idx in poly.vertices):
            # Sample UV center
            u = sum(uv_layer[l_idx].uv.x for l_idx in poly.loop_indices) / len(poly.loop_indices)
            v = sum(uv_layer[l_idx].uv.y for l_idx in poly.loop_indices) / len(poly.loop_indices)
            samples.append((u, v))
    print(f"{name}: found {len(samples)} blade-body polygons")
    if img and samples:
        # Sample pixels from image
        w, h = img.size
        pixels = np.array(img.pixels[:]).reshape((h, w, 4))
        rgb_vals = []
        for u, v in samples[:100]:
            px = int(np.clip(u * w, 0, w - 1))
            py = int(np.clip(v * h, 0, h - 1))
            rgb_vals.append(pixels[py, px, :3])
        mean_rgb = np.mean(rgb_vals, axis=0)
        print(f"  {name} mean RGB: {mean_rgb} (R={mean_rgb[0]:.3f}, G={mean_rgb[1]:.3f}, B={mean_rgb[2]:.3f})")

sample_colors(lambda v: v.co.z < 0, "neg_Z (Z < 0)")
sample_colors(lambda v: v.co.z > 0, "pos_Z (Z > 0)")

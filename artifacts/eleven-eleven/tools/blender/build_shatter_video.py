import bpy
import os
import math
import random
import sys

def script_args():
    return sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []

# Basic setup
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.render.engine = 'BLENDER_EEVEE'
try:
    bpy.context.scene.eevee.taa_render_samples = 16
except:
    pass
scene.render.resolution_x = 1280
scene.render.resolution_y = 720
scene.render.fps = 24
scene.frame_start = 1
scene.frame_end = 120 # 5 seconds is enough for a transition

args = script_args()
img_path = args[0] if len(args) > 0 else "public/assets/cinematics/echo_shatter.jpg"
img_path = os.path.abspath(img_path)

# 1. Background image (Echo)
bpy.ops.mesh.primitive_plane_add(size=10, location=(0, 0, -5))
bg_plane = bpy.context.active_object
bg_mat = bpy.data.materials.new(name="BG_Mat")
bg_mat.use_nodes = True
bsdf = bg_mat.node_tree.nodes["Principled BSDF"]
tex_image = bg_mat.node_tree.nodes.new('ShaderNodeTexImage')
try:
    tex_image.image = bpy.data.images.load(img_path)
except:
    pass
bg_mat.node_tree.links.new(bsdf.inputs['Base Color'], tex_image.outputs['Color'])
bg_mat.node_tree.links.new(bsdf.inputs['Emission Color'], tex_image.outputs['Color'])
bsdf.inputs['Emission Strength'].default_value = 1.0
bg_plane.data.materials.append(bg_mat)
bg_plane.rotation_euler = (0, 0, 0) # facing +Z
bg_plane.scale = (1.6, 0.9, 1.0) # 16:9 approx

# 2. Glass screen to shatter
bpy.ops.mesh.primitive_plane_add(size=10, location=(0, 0, -2))
glass_plane = bpy.context.active_object
glass_plane.scale = (1.6, 0.9, 1.0)

# Apply a material to the glass
glass_mat = bpy.data.materials.new(name="Glass_Mat")
glass_mat.use_nodes = True
glass_bsdf = glass_mat.node_tree.nodes["Principled BSDF"]
glass_bsdf.inputs['Base Color'].default_value = (0.01, 0.02, 0.05, 1)
glass_bsdf.inputs['Roughness'].default_value = 0.1
glass_bsdf.inputs['Metallic'].default_value = 0.8
glass_bsdf.inputs['Alpha'].default_value = 0.8
glass_mat.blend_method = 'BLEND'
glass_plane.data.materials.append(glass_mat)

# Subdivide glass for shattering
bpy.ops.object.mode_set(mode='EDIT')
bpy.ops.mesh.subdivide(number_cuts=20)
bpy.ops.mesh.subdivide(number_cuts=2)
bpy.ops.object.mode_set(mode='OBJECT')

# Add Explode modifier to glass
mod_build = glass_plane.modifiers.new("Explode", 'EXPLODE')
mod_build.use_edge_cut = True

# Add Particle System to drive the explode
bpy.ops.object.particle_system_add()
psrc = glass_plane.particle_systems[0].settings
psrc.count = 2000
psrc.frame_start = 24
psrc.frame_end = 30
psrc.lifetime = 100
psrc.emit_from = 'FACE'
psrc.use_modifier_stack = True
psrc.normal_factor = 10.0 # blast towards +Z
psrc.factor_random = 5.0
psrc.effector_weights.gravity = 0.0

# Add a force field
bpy.ops.object.effector_add(type='TURBULENCE', radius=2, location=(0,0,-2))
turb = bpy.context.active_object
turb.field.strength = 15.0
turb.field.noise = 5.0

# 3. Camera
bpy.ops.object.camera_add(location=(0, 0, 5), rotation=(0, 0, 0))
cam = bpy.context.active_object
bpy.context.scene.camera = cam

# Animate Camera
cam.keyframe_insert(data_path="location", frame=1)
cam.location[2] = 1.5
cam.keyframe_insert(data_path="location", frame=120)

# 4. Lighting
bpy.ops.object.light_add(type='POINT', radius=1, location=(0, 0, -1))
light = bpy.context.active_object
light.data.energy = 5000
light.data.color = (1.0, 0.2, 0.3)

bpy.ops.object.light_add(type='POINT', radius=1, location=(2, 2, 2))
light2 = bpy.context.active_object
light2.data.energy = 2000
light2.data.color = (0.3, 0.8, 1.0)

output_dir = os.path.abspath("public/assets/cinematics/frames/")
os.makedirs(output_dir, exist_ok=True)
scene.render.filepath = os.path.join(output_dir, "frame_")
print(f"Starting render to {output_dir}")
bpy.ops.render.render(animation=True)
print("CINEMATIC_RENDER_OK")

"""Editable, isolated Sector 11 conduit presentation candidate for 3D Jutsu.
No gameplay, collision, rig, player, or animation data. Blender metre units.
"""
import bpy
import math
from mathutils import Vector

scene = bpy.context.scene
scene.unit_settings.system = 'METRIC'
scene.unit_settings.scale_length = 1.0
scene.render.engine = 'BLENDER_EEVEE'
scene.render.resolution_x = 768
scene.render.resolution_y = 1024
scene.render.resolution_percentage = 100
scene.render.image_settings.media_type = 'IMAGE'
scene.render.image_settings.file_format = 'PNG'
scene.render.image_settings.color_mode = 'RGB'
scene.render.film_transparent = False
scene.world = bpy.data.worlds.new('Sector11_NeutralStudio')
scene.world.use_nodes = True
scene.world.node_tree.nodes['Background'].inputs['Color'].default_value = (0.07, 0.09, 0.13, 1)
scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value = 0.35
prop = bpy.data.collections.new('Conduit_Presentation')
studio = bpy.data.collections.new('Review_Studio_ExcludeFromRuntime')
scene.collection.children.link(prop)
scene.collection.children.link(studio)

def move_collection(obj, collection):
    for c in list(obj.users_collection):
        c.objects.unlink(obj)
    collection.objects.link(obj)

def material(name, color, metal=0.0, rough=0.4, emission=0.0):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    mat.use_nodes = True
    p = mat.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value = (*color, 1)
    p.inputs['Metallic'].default_value = metal
    p.inputs['Roughness'].default_value = rough
    p.inputs['Emission Color'].default_value = (*color, 1)
    p.inputs['Emission Strength'].default_value = emission
    return mat

shell = material('Shell_DeepBlueSteel', (0.026, 0.042, 0.075), 0.78, 0.33)
edge = material('Edge_BlueGraphite', (0.062, 0.085, 0.115), 0.72, 0.29)
dark = material('Recess_Obsidian', (0.009, 0.014, 0.022), 0.3, 0.56)
ivory = material('Service_CeramicIvory', (0.48, 0.51, 0.50), 0.15, 0.47)
signal = material('Signal_DormantAmber', (0.52, 0.16, 0.018), 0.22, 0.26, 0.65)
fastener = material('Fastener_BrushedSteel', (0.17, 0.22, 0.27), 0.82, 0.4)

def finish(obj, name, mat, bevel=0.0):
    obj.name = name
    move_collection(obj, prop)
    obj.data.materials.append(mat)
    if bevel:
        mod = obj.modifiers.new('Editable edge bevel', 'BEVEL')
        mod.width = bevel
        mod.segments = 2
    for poly in obj.data.polygons:
        poly.use_smooth = len(poly.vertices) <= 4
    return obj

def cylinder(name, radius, depth, loc, mat, bevel=0.008, front=False, vertices=32):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=loc)
    obj = finish(bpy.context.object, name, mat, bevel)
    if front:
        obj.rotation_euler.x = math.pi / 2
    return obj

def box(name, dims, loc, mat, bevel=0.008):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    obj = bpy.context.object
    obj.dimensions = dims
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish(obj, name, mat, bevel)

def torus(name, radius, tube, loc, mat, front=False):
    bpy.ops.mesh.primitive_torus_add(major_segments=32, minor_segments=8, major_radius=radius, minor_radius=tube, location=loc)
    obj = finish(bpy.context.object, name, mat)
    if front:
        obj.rotation_euler.x = math.pi / 2
    return obj

# The .45m footprint and 1.8m height preserve the existing Godot prop contract.
cylinder('Foundation_Rim', 0.45, 0.10, (0, 0, 0.05), edge)
cylinder('Foundation_Gasket', 0.408, 0.032, (0, 0, 0.116), dark, 0.004)
cylinder('Lower_Housing', 0.395, 0.27, (0, 0, 0.255), shell)
bpy.ops.mesh.primitive_cone_add(vertices=32, radius1=0.385, radius2=0.321, depth=1.31, location=(0, 0, 1.035))
finish(bpy.context.object, 'Tapered_Shell', shell, 0.01)
cylinder('Top_Recess', 0.329, 0.03, (0, 0, 1.69), dark, 0.004)
cylinder('Top_Beveled_Cap', 0.35, 0.095, (0, 0, 1.7475), edge, 0.01)
cylinder('Top_Service_Cover', 0.283, 0.005, (0, 0, 1.7975), shell, 0.002)
torus('Lower_Service_Collar', 0.382, 0.016, (0, 0, 0.385), edge)

# Lens sits beyond the housing front; its emission stays readable without bloom.
cylinder('Lens_Recess_Backplate', 0.238, 0.050, (0, -0.331, 1.30), dark, 0.006, True)
torus('Lens_Beveled_Retainer', 0.211, 0.022, (0, -0.358, 1.30), fastener, True)
cylinder('Core_Lens', 0.188, 0.020, (0, -0.386, 1.30), signal, 0.004, True)
torus('Core_Lens_Inner_Rim', 0.166, 0.008, (0, -0.400, 1.30), edge, True)
box('Lens_Signal_Divider', (0.012, 0.008, 0.30), (0, -0.407, 1.30), edge, 0.002)
box('Lens_Ivory_Witness', (0.061, 0.009, 0.012), (-0.067, -0.407, 1.372), ivory, 0.002)

# Functional service detail, quiet rhythm and no fabricated readable label.
box('Service_Panel_Recess', (0.262, 0.04, 0.50), (0, -0.344, 0.743), dark, 0.014)
box('Service_Panel', (0.224, 0.014, 0.452), (0, -0.371, 0.743), edge, 0.010)
box('Status_Window', (0.148, 0.012, 0.027), (0, -0.389, 0.953), signal, 0.005)
for index, z in enumerate([0.855, 0.805, 0.755]):
    box('Vent_Recess_%02d' % index, (0.138, 0.009, 0.018), (0, -0.384, z), dark, 0.002)
box('Service_Handle', (0.089, 0.018, 0.035), (0, -0.395, 0.58), fastener, 0.007)
for index, (x, z) in enumerate([(-0.089, 0.925), (0.089, 0.925), (-0.089, 0.556), (0.089, 0.556)]):
    cylinder('Service_Fastener_%02d' % index, 0.011, 0.009, (x, -0.384, z), fastener, 0.001, True, 12)
for index, angle in enumerate([math.pi * 0.20, math.pi * 0.8, math.pi * 1.15, math.pi * 1.85]):
    x, y = 0.365 * math.cos(angle), 0.365 * math.sin(angle)
    rib = box('Shell_Service_Rib_%02d' % index, (0.034, 0.028, 0.63), (x, y, 0.73), edge, 0.006)
    rib.rotation_euler.z = angle - math.pi / 2

# Presentation-only studio. Runtime GLB must export Conduit_Presentation only.
bpy.ops.mesh.primitive_plane_add(size=200)
ground = bpy.context.object
ground.name = 'ReviewGround_EXCLUDE'
ground.data.materials.append(material('ReviewGround', (0.08, 0.10, 0.14), 0, 0.78))
move_collection(ground, studio)
bpy.ops.object.camera_add(location=(2.55, -4.4, 2.85))
camera = bpy.context.object
camera.name = 'Review_Delivery_Camera'
camera.rotation_euler = (Vector((0, 0, 0.90)) - camera.location).to_track_quat('-Z', 'Y').to_euler()
camera.data.type = 'ORTHO'
camera.data.ortho_scale = 2.55
scene.camera = camera
move_collection(camera, studio)
def light(name, loc, energy, color, size):
    data = bpy.data.lights.new(name, 'AREA')
    data.energy = energy
    data.color = color
    data.shape = 'DISK'
    data.size = size
    obj = bpy.data.objects.new(name, data)
    studio.objects.link(obj)
    obj.location = loc
    obj.rotation_euler = (Vector((0, 0, 1)) - obj.location).to_track_quat('-Z', 'Y').to_euler()
light('Review_Key', (2, -3, 4.0), 500, (0.83, 0.90, 1.0), 3)
light('Review_Fill', (-2, -1, 2.0), 180, (0.60, 0.72, 1.0), 2.5)
light('Review_Rim', (0, 2, 3.5), 500, (0.75, 0.85, 1.0), 2)
bpy.context.view_layer.update()
points = [o.matrix_world @ Vector(v) for o in prop.objects for v in o.bound_box]
result = {'units':'metres','candidate_status':'REVIEW_PENDING','collection':'Conduit_Presentation','object_count':len(prop.objects),'height':max(v.z for v in points)-min(v.z for v in points),'footprint_radius_limit':0.45,'state':'dormant','signal_material':'Signal_DormantAmber','runtime_integration':False}
target = artifacts.file(name='conduit-dormant-review.png', media_type='image/png')
scene.render.filepath = target.path
bpy.ops.render.render(write_still=True)
target.publish()

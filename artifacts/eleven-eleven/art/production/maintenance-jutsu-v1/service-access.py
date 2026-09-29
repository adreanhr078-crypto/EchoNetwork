"""Scoped Jutsu edit: physical service override, portable surface detail and exit.
Preserves the measured climbs. No character, dialogue or reward authority.
"""
import bpy, math, random
from mathutils import Vector
scene = bpy.context.scene
steel = bpy.data.materials['Graphite structural steel']
ivory = bpy.data.materials['Ivory grip ceramic']
dark = bpy.data.materials['Deep service void']
signal = bpy.data.materials['Route cyan']
amber = bpy.data.materials['Warning amber']

def box(name, location, size, material, bevel=.025):
    bpy.ops.mesh.primitive_cube_add(size=1, location=location)
    obj = bpy.context.object
    obj.name, obj.dimensions = name, size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(material)
    if bevel:
        modifier = obj.modifiers.new('Machined edge', 'BEVEL')
        modifier.width, modifier.segments = bevel, 2
    return obj

def packed_surface(material, name, color, ceramic=False):
    # Original authored pixels: no provider download or external image dependency.
    image = bpy.data.images.new(name, width=512, height=512)
    rng = random.Random(1111 if ceramic else 110)
    pixels = []
    for y in range(512):
        brush = rng.uniform(-.018, .018)
        for x in range(512):
            grain = rng.uniform(-.009, .009)
            variation = grain if ceramic else brush + grain
            seam = .93 if ceramic and (x < 3 or y < 3) else 1
            pixels.extend([max(.01, min(1, (c + variation) * seam)) for c in color] + [1])
    image.pixels.foreach_set(pixels)
    image.pack()
    tree = material.node_tree
    texture = tree.nodes.new('ShaderNodeTexImage')
    texture.name, texture.image = name, image
    tree.links.new(texture.outputs['Color'], tree.nodes['Principled BSDF'].inputs['Base Color'])

packed_surface(steel, 'Maintenance brushed graphite 512', (.16,.20,.24))
packed_surface(ivory, 'Maintenance ceramic grain 512', (.38,.41,.42), True)
steel.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value = .62
ivory.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value = .78

# Keep dynamic hierarchies intact in the compact derivative.
gate = bpy.data.objects.new('ServiceGateRoot', None)
scene.collection.objects.link(gate)
gate.location = (0,12.94,5.4)
gate['runtime_dynamic'] = True
bpy.context.view_layer.update()
for obj in list(scene.objects):
    if obj.name.startswith(('ServiceAccess_InnerPanel','ServiceAccess_PanelSeam','ServiceAccess_CenterSeam')):
        world = obj.matrix_world.copy()
        obj.parent = gate
        obj.matrix_world = world
gate['slide_metres'] = 2.1
gate['duration_seconds'] = 1.6

box('COLL_ServiceVestibule', (0,13.55,5.2), (3,1.5,.4), steel)
for x in [-2,2]:
    box('COLL_ServiceSideReturn', (x,13.45,6.4), (1,1.6,2), dark)
    box('ServiceAccess_RecessStrip', (x*.73,13.25,6.5), (.05,1.1,1.6), steel)
box('ServiceAccess_HeaderCover', (0,13,8), (2.7,.5,.8), dark)

valve = bpy.data.objects.new('ServiceValveRoot', None)
scene.collection.objects.link(valve)
valve.location = (1.25,12.48,6.35)
valve['runtime_dynamic'] = True
bpy.context.view_layer.update()
bpy.ops.mesh.primitive_torus_add(major_radius=.205, minor_radius=.026,
    major_segments=24, minor_segments=8, location=valve.location,
    rotation=(math.pi/2,0,0))
ring = bpy.context.object
ring.name = 'ServiceValve_Handwheel'
ring.data.materials.append(amber)
parts = [ring]
for angle in [0, math.pi/3, math.pi*2/3]:
    spoke = box('ServiceValve_Spoke', valve.location, (.36,.035,.035), steel, .009)
    spoke.rotation_euler.y = angle
    parts.append(spoke)
for obj in parts:
    world = obj.matrix_world.copy()
    obj.parent = valve
    obj.matrix_world = world
box('ServiceValve_Mount', (1.25,12.61,6.35), (.18,.2,.18), steel)
box('ServiceValve_Readout', (1.25,12.52,6.75), (.22,.04,.13), signal, .01)
for z in [5.85,6.1,6.6,6.85]:
    box('ServiceAccess_PressureGaugeTick', (1.25,12.52,z), (.1,.025,.02), ivory, 0)

# Vertical destination landmark and motivated illumination, not extra route clutter.
for x in [-.91,.91]:
    box('ServiceAccess_DoorGuideLight', (x,12.58,6.45), (.035,.04,1.5), signal, .005)
data = bpy.data.lights.new('ServiceAccess_Key', 'POINT')
data.energy, data.color, data.shadow_soft_size = 95, (.8,.9,1), .65
light = bpy.data.objects.new(data.name, data)
scene.collection.objects.link(light)
light.location = (0,11.9,7.25)
scene.world.node_tree.nodes['Background'].inputs[1].default_value = .2
scene.camera.location = (3.1,9.4,7.1)
scene.camera.rotation_euler = (Vector((.2,12.6,6.35))-scene.camera.location).to_track_quat('-Z','Y').to_euler()
scene.camera.data.lens = 28
scene.render.engine = 'BLENDER_EEVEE'
scene.view_settings.view_transform = 'Khronos PBR Neutral'
scene.frame_set(1)
result = {'objects':len(scene.objects), 'packedTextures':2,
    'dynamicRoots':['ServiceGateRoot','ServiceValveRoot'], 'doorLift':2.1,
    'route':'climbs preserved; upper manual pressure override -> physical vestibule',
    'colliders':[o.name for o in scene.objects if o.name.startswith('COLL_')]}

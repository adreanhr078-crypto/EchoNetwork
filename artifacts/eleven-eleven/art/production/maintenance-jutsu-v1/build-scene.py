"""Editable metre-scale maintenance traversal study. Blender 5.2 / 3D Jutsu.
Godot conversion: Blender (x,y,z) -> Godot (x,z,-y). No baked UI text.
"""
import bpy, math
from mathutils import Vector

scene = bpy.context.scene
scene.render.fps = 24
scene.frame_start, scene.frame_end = 1, 145
def material(name, color, metallic=0, roughness=.5, emission=0):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1)
    m.use_nodes = True
    p = m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value = (*color,1)
    p.inputs['Metallic'].default_value = metallic
    p.inputs['Roughness'].default_value = roughness
    p.inputs['Emission Color'].default_value = (*color,1)
    p.inputs['Emission Strength'].default_value = emission
    return m
steel = material('Graphite structural steel', (.12,.16,.20), .55, .52)
grip = material('Ivory grip ceramic', (.43,.46,.44), .1, .72)
dark = material('Deep service void', (.028,.04,.054), .25, .7)
signal = material('Route cyan', (.08,.48,.52), .2, .38, 1.2)
warning = material('Warning amber', (.55,.31,.1), .25, .5)
def box(name, pos, size, mat, bevel=.035):
    bpy.ops.mesh.primitive_cube_add(size=1, location=pos)
    o = bpy.context.object
    o.name = name
    o.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    o.data.materials.append(mat)
    if bevel:
        mod = o.modifiers.new('Editable edge radius', 'BEVEL')
        mod.width, mod.segments = bevel, 2
    return o

# Semantic COLL_* names are the collision contract used by the Godot adapter.
box('COLL_EntryFloor', (0,2,-.15), (8,8,.3), steel)
box('COLL_CLIMB_FirstWall', (0,6,1.7), (5,.5,3.4), grip)
box('COLL_UpperRest', (0,7,3.2), (5,2.4,.4), steel)
box('COLL_GapLanding', (4,7,3.2), (2,2.4,.4), steel)
box('COLL_CLIMB_SecondWall', (4,9.4,4.4), (2,.5,2), grip)
box('COLL_FinalRest', (4,10.7,5.2), (2,2.2,.4), steel)
box('COLL_ExitDeck', (0,12.3,5.2), (6,1.2,.4), steel)
box('COLL_LeftBoundary', (-4.4,7,4), (.4,15,8), dark)
box('COLL_RightBoundary', (5.4,7,4), (.4,15,8), dark)
box('COLL_FarBoundary', (.5,14.5,4), (10,.4,8), dark)
for x in [-4.12,5.12]:
    for y in [0,3,6,9,12]:
        box('ServiceRib_%s_%s' % (x,y), (x,y,4), (.2,.2,8), steel)
for x in [-1.9,-.65,.65,1.9]:
    for z in [.45,1.05,1.65,2.25,2.85]:
        box('ClimbGrip', (x,5.72,z), (.48,.13,.12), steel, .02)
for x in [3.45,4.55]:
    for z in [3.8,4.4,5.0]:
        box('UpperGrip', (x,9.12,z), (.42,.12,.12), steel, .02)
for y in [0,1.8,3.6]:
    box('EntryRouteStripe', (0,y,.025), (.08,.65,.015), signal, 0)
for x in [1.8,2.3,3.35,3.85]:
    box('GapEdgeWarning', (x,6.0,3.43), (.25,.08,.025), warning, 0)
for x,y,z in [(-3,2,5),(1,6,6.5),(4,10,7)]:
    box('ServiceLightHousing', (x,y,z), (1.2,.4,.15), steel)
    box('ServiceLightDiffuser', (x,y,z-.1), (1.05,.3,.035), grip)
    data = bpy.data.lights.new('MotivatedServiceLight', 'POINT')
    data.energy, data.color, data.shadow_soft_size = 170, (.72,.83,1), 1.2
    o = bpy.data.objects.new(data.name,data)
    scene.collection.objects.link(o)
    o.location = (x,y,z-.2)
# Authored mechanical signal cycle; it is a prop animation, not character motion.
rotor = box('ServiceSignalRotor', (-3,6,3.9), (.5,.12,.14), signal)
for frame, angle in [(1,0),(49,math.pi/2),(97,math.pi),(145,math.pi*2)]:
    rotor.rotation_euler.y = angle
    rotor.keyframe_insert(data_path='rotation_euler',frame=frame)
rotor.animation_data.action.name = 'Maintenance_Signal_Cycle'
world = scene.world or bpy.data.worlds.new('Maintenance ambient')
scene.world = world
world.use_nodes = True
world.node_tree.nodes['Background'].inputs[0].default_value = (.1,.13,.19,1)
world.node_tree.nodes['Background'].inputs[1].default_value = .3
camera_data = bpy.data.cameras.new('DeliveryCamera')
camera = bpy.data.objects.new('DeliveryCamera', camera_data)
scene.collection.objects.link(camera)
camera.location = (10,-5,8)
camera.rotation_euler = (Vector((0,7,2.5)) - camera.location).to_track_quat('-Z','Y').to_euler()
camera_data.lens = 29
scene.camera = camera
scene.frame_set(1)
scene.render.resolution_x, scene.render.resolution_y = 480,270
scene.render.resolution_percentage = 100
scene.view_settings.view_transform = 'Khronos PBR Neutral'
result = {'objects':len(scene.objects), 'route':'entry -> first climb -> gap -> second climb -> exit deck', 'collisionObjects':[o.name for o in scene.objects if o.name.startswith('COLL_')], 'animation':'Maintenance_Signal_Cycle', 'fps':24, 'frameRange':[1,145]}

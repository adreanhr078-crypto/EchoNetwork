# Editable console study for the opening. bpy coordinates: metres, Z up.
# Preserve the existing G0 room and camera. No gameplay text or authority.
import bpy
from mathutils import Vector
from math import radians

prefix = 'EchoSignalConsole_'
if any(o.name.startswith(prefix) for o in bpy.data.objects):
    raise RuntimeError('Console already exists: inspect before repeating mutation')
collection = bpy.data.collections.new('EchoSignalConsole_Study')
bpy.context.scene.collection.children.link(collection)
root = bpy.data.objects.new(prefix+'Root', None)
collection.objects.link(root)
root.location = (-2.8, -7.1, 0.14)

def material(name, rgb, metal, rough, emission=0.0):
    mat=bpy.data.materials.new(prefix+name)
    mat.use_nodes=True
    node=mat.node_tree.nodes.get('Principled BSDF')
    node.inputs['Base Color'].default_value=(*rgb,1)
    node.inputs['Metallic'].default_value=metal
    node.inputs['Roughness'].default_value=rough
    if emission:
        node.inputs['Emission Color'].default_value=(*rgb,1)
        node.inputs['Emission Strength'].default_value=emission
    return mat
steel=material('Graphite',(.085,.10,.13),.62,.48)
trim=material('Titanium',(.28,.32,.36),.75,.38)
rubber=material('Rubber',(.014,.020,.026),0,.88)
cyan=material('Signal',(.035,.33,.43),.15,.46,.45)
amber=material('Attention',(.42,.17,.03),.2,.6,.3)

def box(name, size, position, mat, parent=root, bevel=.012):
    bpy.ops.mesh.primitive_cube_add(size=1)
    obj=bpy.context.object
    obj.name=prefix+name
    for old in list(obj.users_collection): old.objects.unlink(obj)
    collection.objects.link(obj)
    # Apply dimensions in mesh space so bevel width remains in metres.
    for vertex in obj.data.vertices:
        vertex.co.x*=size[0]; vertex.co.y*=size[1]; vertex.co.z*=size[2]
    obj.parent=parent
    obj.location=position
    obj.data.materials.append(mat)
    if bevel:
        modifier=obj.modifiers.new('Manufactured chamfer','BEVEL')
        modifier.width=bevel; modifier.segments=2
    return obj

box('Foot',(.95,.65,.09),(0,0,.045),rubber,bevel=.026)
box('FootPlate',(.87,.59,.035),(0,0,.105),trim)
box('Pedestal',(.57,.42,.99),(0,0,.615),steel,bevel=.035)
box('ServicePanel',(.41,.018,.55),(0,-.22,.60),trim)
box('ServiceInset',(.36,.015,.48),(0,-.236,.60),steel)
for i in range(5):
    box('Vent%02d'%i,(.24,.015,.016),(0,-.249,.44+i*.047),rubber,bevel=.003)
for x in [-.21,.21]:
    box('FootRail'+str(x),(.038,.5,.014),(x,-.008,.13),steel,bevel=.005)

mount=bpy.data.objects.new(prefix+'ScreenMount',None)
collection.objects.link(mount); mount.parent=root
mount.location=(0,-.23,1.35); mount.rotation_euler.x=radians(-25)
box('BackCover',(1.30,.12,.80),(0,0,0),steel,mount,.04)
# A recessed black face awaits live Godot UI; four separate bezel rails.
box('Face',(1.17,.018,.66),(0,-.07,0),rubber,mount,.012)
for x in [-.618,.618]:
    box('BezelSide'+str(x),(.056,.048,.74),(x,-.067,0),trim,mount,.014)
for z in [-.367,.367]:
    box('BezelRail'+str(z),(1.18,.048,.056),(0,-.067,z),trim,mount,.014)
box('StatusStrip',(.21,.024,.020),(.405,-.087,-.306),cyan,mount,.006)
box('CautionTab',(.055,.024,.020),(-.525,-.087,-.306),amber,mount,.006)
for x in [-.57,.57]:
    for z in [-.323,.323]:
        box('Recess_%s_%s'%(x,z),(.027,.01,.027),(x,-.095,z),rubber,mount,.004)
# Purposeful physical acknowledgment, played on interaction only.
button=box('AcknowledgmentKey',(.07,.025,.025),(.245,-.096,-.306),trim,mount,.005)
fps = bpy.context.scene.render.fps / bpy.context.scene.render.fps_base
for seconds, y in [(0,-.096),(.17,-.086),(.46,-.086),(.79,-.096),(.96,-.096)]:
    frame = 1 + round(seconds * fps)
    button.location.y=y
    button.keyframe_insert(data_path='location',index=1,frame=frame)
button.animation_data.action.name='Console_Acknowledge'
for layer in button.animation_data.action.layers:
    for strip in layer.strips:
        for bag in strip.channelbags:
            for curve in bag.fcurves:
                for key in curve.keyframe_points: key.interpolation='BEZIER'
# Dedicated preview setup; the G0 delivery camera is preserved.
cam_data=bpy.data.cameras.new(prefix+'PreviewCamera')
cam=bpy.data.objects.new(prefix+'PreviewCamera',cam_data)
collection.objects.link(cam)
cam.location=root.location+Vector((2.05,-3.25,2.10))
target=root.location+Vector((0,-.12,.91))
cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler()
cam_data.lens=52
bpy.context.scene.frame_set(1)
result={'created_objects':len(collection.objects),'root':root.name,'height_m':1.35+.4,'width_m':1.30,'animation':'Console_Acknowledge','animation_frames':[1,1+round(.96*fps)],'fps':fps,'preview_camera':cam.name,'existing_delivery_camera':bpy.context.scene.camera.name}

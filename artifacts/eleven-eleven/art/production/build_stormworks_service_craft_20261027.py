"""Rigid, metre-authored service dressing; gameplay roots retain all authority."""
import bpy, math, pathlib, json, hashlib
from mathutils import Vector
OUT=pathlib.Path(r'C:/Users/yasmo/EchoNetwork/artifacts/eleven-eleven/godot/assets/environments/maintenance_stormworks')
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
def material(name,color,metal=.65,rough=.42,emission=0):
 m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True
 p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1)
 p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=rough
 if emission:p.inputs['Emission Color'].default_value=(*color,1);p.inputs['Emission Strength'].default_value=emission
 return m
steel=material('Satin blue grey pressure steel',(.18,.24,.27))
rim=material('Brushed titanium machined edge',(.42,.49,.5),.8,.34)
dark=material('Graphite rubber gasket',(.025,.035,.038),.08,.75)
amber=material('Safety ochre enamel',(.56,.29,.055),.3,.48)
light=material('Warm white status lens',(.7,.88,.9),.1,.35,2.0)
def xyz(v):return (v[0],-v[2],v[1])
def box(name,pos,size,mat,bevel=.012):
 bpy.ops.mesh.primitive_cube_add(size=1,location=xyz(pos));o=bpy.context.object;o.name=name
 o.dimensions=(size[0],size[2],size[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 o.data.materials.append(mat)
 if bevel:
  m=o.modifiers.new('Manufactured edge radius','BEVEL');m.width=bevel;m.segments=3
  bpy.ops.object.modifier_apply(modifier=m.name)
  m=o.modifiers.new('Weighted corner normals','WEIGHTED_NORMAL');bpy.ops.object.modifier_apply(modifier=m.name)
 return o
def cylinder(name,pos,radius,depth,mat):
 bpy.ops.mesh.primitive_cylinder_add(vertices=48,radius=radius,depth=depth,location=xyz(pos),rotation=(math.pi/2,0,0))
 o=bpy.context.object;o.name=name;o.data.materials.append(mat)
 m=o.modifiers.new('Turned edge radius','BEVEL');m.width=.005;m.segments=3;bpy.ops.object.modifier_apply(modifier=m.name)
 for p in o.data.polygons:p.use_smooth=True
 return o
def export(name):
 bpy.ops.object.select_all(action='SELECT')
 path=OUT/name;bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,export_animations=False)
 blob=path.read_bytes();print('CRAFT_ASSET '+json.dumps({'path':str(path),'bytes':len(blob),'sha256':hashlib.sha256(blob).hexdigest()}),flush=True)
 bpy.ops.object.delete(use_global=False)
# Leaf origin is its geometric centre; native gate root supplies closed/open motion.
box('PressureLeaf', (0,0,0),(1.72,2.18,.14),steel,.035)
box('InsetSeal',(0,0,.081),(1.56,2.02,.025),dark,.022)
box('RaisedPressurePanel',(0,.04,.105),(1.42,1.83,.035),rim,.028)
box('RecessedBluePanel',(0,.04,.13),(1.3,1.7,.024),steel,.018)
for x in [-.67,.67]:
 box('EdgeWearStrip',(x,0,.15),(.045,1.93,.026),rim,.008)
 for y in [-.69,-.37,.37,.69]:cylinder('CaptiveHexBolt',(x,y,.175),.021,.018,rim)
for y in [-.65,-.46,-.27,.27,.46,.65]:
 box('HorizontalStampedRib',(0,y,.16),(1.16,.032,.035),rim,.009)
box('ServiceWarningEnamel',(0,-.96,.16),(1.34,.09,.02),amber,.008)
box('DoorStatusLens',(0,.96,.16),(.34,.035,.025),light,.008)
export('stormworks_precision_gate_v1.glb')
# The actual hand-contact radius remains 0.21m. The six-spoke wheel turns as one rigid assembly.
bpy.ops.mesh.primitive_torus_add(major_radius=.205,minor_radius=.018,major_segments=96,minor_segments=16,location=(0,0,0),rotation=(math.pi/2,0,0))
o=bpy.context.object;o.name='CastSixSpokeHandwheel';o.data.materials.append(amber)
for p in o.data.polygons:p.use_smooth=True
for i in range(6):
 theta=i*math.tau/6
 o=box('MachinedWheelSpoke',(.113*math.cos(theta),.113*math.sin(theta),-.002),(.168,.022,.024),rim,.008)
 o.rotation_euler.y=-theta
cylinder('KeyedWheelHub',(0,0,0),.045,.082,rim)
cylinder('HubFastener',(0,0,.049),.019,.018,dark)
export('stormworks_precision_wheel_v1.glb')
# Fixed frame, open central aperture. No collision is added by this visual asset.
for x in [-1.04,1.04]:
 box('MachinedPortalUpright',(x,0,0),(.2,2.44,.3),steel,.025)
 box('PortalInboardTrim',(x,0,.18),(.075,2.3,.055),rim,.012)
 for y in [-1,-.65,0,.65,1]:cylinder('FrameAnchor',(x,y,.223),.024,.025,rim)
for y in [-1.19,1.19]:box('PortalCrossmember',(0,y,0),(2.28,.17,.3),steel,.025)
for x in [-1.55,1.55]:
 box('ValveSideConsole',(x,0,-.02),(.83,2.28,.17),steel,.025)
 box('ConsoleInset',(x,.1,.08),(.67,1.83,.035),rim,.014)
 for y in [-.65,-.45,.45,.65]:box('ConsolePressedRib',(x,y,.11),(.58,.035,.02),steel,.006)
box('ValveInstrumentMount',(1.25,-.01,.18),(.4,.48,.13),dark,.025)
export('stormworks_precision_bulkhead_v1.glb')

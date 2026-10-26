"""Original editable laboratory modules; metres, Blender Z-up -> glTF Y-up.
No characters, animation, collision, progress or imported source assets.
"""
import bpy, math, json, hashlib
from pathlib import Path
from mathutils import Vector

OUT=Path(__file__).resolve().parent/'lab-clinical-kit-20261023'
OUT.mkdir(exist_ok=True)
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
def mat(name,col,metal,rough,emit=0):
    m=bpy.data.materials.new(name);m.use_nodes=True
    bs=m.node_tree.nodes.get('Principled BSDF')
    bs.inputs['Base Color'].default_value=(*col,1)
    bs.inputs['Metallic'].default_value=metal;bs.inputs['Roughness'].default_value=rough
    bs.inputs['Emission Color'].default_value=(*col,1);bs.inputs['Emission Strength'].default_value=emit
    return m
ceramic=mat('ClinicalPearlCeramic',(.58,.65,.70),.12,.43)
graphite=mat('GraphiteGaskets',(.025,.039,.055),.38,.58)
alloy=mat('BrushedSurgicalAlloy',(.35,.43,.49),.72,.30)
pad=mat('ReplaceableChairCushion',(.12,.20,.26),0,.72)
ice=mat('SurgicalTaskLight',(.58,.85,.95),.1,.3,2)
amber=mat('ServiceAmber',(.95,.43,.09),.1,.4,1.5)
parts=[]
def finish(obj,name,material,bevel=0):
    obj.name=name;obj.data.materials.append(material)
    if bevel:
        b=obj.modifiers.new('Machined edge radii','BEVEL');b.width=bevel;b.segments=3
        bpy.context.view_layer.objects.active=obj
        bpy.ops.object.modifier_apply(modifier=b.name)
        n=obj.modifiers.new('Weighted corner normals','WEIGHTED_NORMAL');n.keep_sharp=True
        bpy.ops.object.modifier_apply(modifier=n.name)
    parts.append(obj);return obj
def box(name,loc,size,material,bevel=.02):
    bpy.ops.mesh.primitive_cube_add(size=1,location=loc)
    o=bpy.context.object;o.scale=size;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    return finish(o,name,material,min(bevel,min(size)*.25))
def cyl(name,loc,r,depth,material):
    bpy.ops.mesh.primitive_cylinder_add(vertices=32,radius=r,depth=depth,location=loc)
    return finish(bpy.context.object,name,material,.008)
def rod(name,a,b,r,material):
    a,b=Vector(a),Vector(b);o=cyl(name,(a+b)*.5,r,(b-a).length,material)
    o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler();return o
def ring(name,loc,r,section,material):
    bpy.ops.mesh.primitive_torus_add(major_segments=64,minor_segments=8,location=loc,major_radius=r,minor_radius=section)
    return finish(bpy.context.object,name,material)
def module(name,build):
    parts.clear();build()
    bpy.ops.object.select_all(action='DESELECT')
    for p in parts:p.select_set(True)
    bpy.context.view_layer.objects.active=parts[0]
    bpy.ops.object.join();obj=bpy.context.object;obj.name=name
    bpy.context.scene.cursor.location=(0,0,0);bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',use_selection=True,export_yup=True,export_animations=False)
    return {'name':name,'vertices':len(obj.data.vertices),'triangles':sum(len(p.vertices)-2 for p in obj.data.polygons),'sha256':hashlib.sha256((OUT/(name+'.glb')).read_bytes()).hexdigest()}
def chair():
    box('ServiceBase',(0,0,.20),(.95,1.8,.38),graphite,.08)
    box('HydraulicPedestal',(0,.08,.53),(.54,.68,.40),alloy,.05)
    box('SeatShell',(0,0,.83),(1.10,.88,.20),ceramic,.07)
    box('SeatCushion',(0,0,.97),(.88,.75,.12),pad,.05)
    shell=box('BackShell',(0,.62,1.28),(1.08,1.10,.18),ceramic,.06);shell.rotation_euler.x=math.radians(32)
    cushion=box('BackCushion',(0,.58,1.39),(.87,.93,.12),pad,.05);cushion.rotation_euler.x=math.radians(32)
    head=box('HeadCradle',(0,1.14,1.69),(.64,.42,.16),pad,.06);head.rotation_euler.x=math.radians(32)
    box('LegShell',(0,-.77,.67),(.94,.85,.18),ceramic,.05)
    box('LegCushion',(0,-.76,.79),(.76,.75,.09),pad,.03)
    box('HeelSupport',(0,-1.26,.53),(.86,.25,.20),alloy,.03)
    for side in [-1,1]:
        rod('ArmSupport',(side*.48,-.1,.75),(side*.63,-.1,1.08),.04,alloy)
        box('ArmPad',(side*.63,-.12,1.12),(.20,.77,.13),pad,.04)
        box('HandSensor',(side*.63,-.48,1.14),(.22,.14,.06),ceramic)
        for y in [-.65,-.35,0,.35,.65]:box('ServiceVent',(side*.481,y,.26),(.016,.15,.035),alloy,.002)
        for y in [-.5,.4]:cyl('GroundMount',(side*.39,y,.055),.07,.10,alloy)
        rod('CableConduit',(side*.28,.65,.24),(side*.28,1.1,1.05),.028,graphite)
    box('StatusBar',(0,-.91,.24),(.48,.025,.05),amber,.006)
def scanner():
    for z,r,s,m in [(0,2.65,.16,graphite),(.12,2.68,.11,ceramic),(-.13,2.43,.055,ice),(.22,2.48,.07,alloy)]:ring('SegmentedScanGantry',(0,0,z),r,s,m)
    for i in range(12):
        a=math.tau*i/12;x,y=2.65*math.cos(a),2.65*math.sin(a)
        o=box('GantryModule',(x,y,.08),(.38,.60,.38),ceramic,.04);o.rotation_euler.z=a
        cyl('ScannerLens',(x*.90,y*.90,-.15),.065,.12,ice)
    for side in [-1,1]:
        a=(side*2.3,0,-.1);b=(side*2.0,.1,-1.2);c=(side*1.0,.5,-1.6)
        rod('SuspendedBoom',a,b,.12,ceramic);rod('InstrumentArm',b,c,.09,ceramic)
        for p in [a,b,c]:cyl('PrecisionHinge',p,.17,.19,alloy)
        rod('InstrumentTool',c,(c[0],c[1],c[2]-.40),.035,alloy)
        rod('CeilingSuspension',(side*1.8,0,.2),(side*1.8,0,2.4),.065,alloy)
def wall():
    # A single3m-wide,3m-high layer, only0.18m deep. Local front is-Y.
    box('ServiceBackplane',(0,0,1.5),(3,.16,3),graphite,.025)
    for x in [-.73,.73]:
        box('BeveledCeramicPanel',(x,-.11,1.5),(1.42,.10,2.90),ceramic,.04)
        for z in [.15,2.85]:
            for bx in [x-.55,x+.55]:cyl('RecessedFastener',(bx,-.17,z),.025,.025,alloy)
    box('ServiceSeam',(0,-.18,1.5),(.055,.045,2.78),alloy,.008)
    box('TaskStrip',(.02,-.21,2.72),(1.8,.025,.05),ice,.005)
    box('AmberSafetyTag',(-1.20,-.19,.60),(.045,.025,.30),amber,.005)
def cart():
    box('EquipmentCabinet',(0,0,.66),(.70,.57,1.0),ceramic,.045)
    box('Chassis',(0,0,.13),(.76,.64,.10),alloy)
    for x in [-.28,.28]:
        for y in [-.22,.22]:cyl('Caster',(x,y,.065),.065,.10,graphite)
    for z in [.36,.57,.78]:
        box('DrawerFace',(0,-.30,z),(.59,.03,.18),ceramic,.01)
        box('RecessedPull',(0,-.33,z+.03),(.23,.025,.025),graphite,.004)
    rod('MonitorArm',(0,.10,1.14),(0,.1,1.65),.035,alloy)
    box('MonitorHousing',(0,.08,1.68),(.72,.12,.48),graphite,.035)
    box('DiagnosticDisplay',(0,.008,1.68),(.64,.015,.39),ice,.012)
    for i in range(7):box('DiagnosticTrace',(-.24+i*.08,-.005,1.65+.06*math.sin(i*2)),(.048,.008,.012),alloy,.002)
    box('EquipmentStatus',(0,-.322,1.03),(.33,.018,.035),amber,.005)
records=[module(n,f) for n,f in [('neural_chair',chair),('surgical_scan_gantry',scanner),('clinical_wall_module',wall),('diagnostic_cart',cart)]]
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'lab-clinical-kit.blend'))
(OUT/'source-manifest.json').write_text(json.dumps({'units':'metres','source':'Original procedural hard-surface construction; no external mesh or character source','modules':records,'native_review':'OPEN'},indent=2)+'\n')
print('LAB_KIT_BUILT',json.dumps(records))

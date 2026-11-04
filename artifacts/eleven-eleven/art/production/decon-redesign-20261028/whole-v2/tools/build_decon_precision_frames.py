import bpy, pathlib, math, json, hashlib
from mathutils import Vector
P=pathlib.Path(r'C:\Users\yasmo\EchoNetwork\artifacts\eleven-eleven\art\production\decon-redesign-20261028\whole-v2')
O=pathlib.Path(r'C:\Users\yasmo\EchoNetwork\artifacts\eleven-eleven\godot\assets\environments\decon_clinical')
bpy.ops.wm.read_factory_settings(use_empty=True)
materials={}
for name,color,metal,rough in [('Graphite',(0.075,.095,.12,1),.35,.56),('Ceramic',(.65,.67,.66,1),.08,.58),('Steel',(.28,.32,.36,1),.65,.4),('UVEmitter',(.28,.08,.65,1),.05,.38),('ServiceLamp',(.85,.7,.4,1),.05,.5),('Signal',(.5,.025,.035,1),.1,.5)]:
 m=bpy.data.materials.new(name);m.diffuse_color=color;m.use_nodes=True
 shader=m.node_tree.nodes.get('Principled BSDF');shader.inputs['Base Color'].default_value=color;shader.inputs['Metallic'].default_value=metal;shader.inputs['Roughness'].default_value=rough;materials[name]=m

def box(name,point,size,material,bevel=.018):
 bpy.ops.mesh.primitive_cube_add(size=1,location=(point[0],point[2],point[1]));obj=bpy.context.object;obj.name=name;obj.dimensions=(size[0],size[2],size[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 if bevel:
  modifier=obj.modifiers.new('Manufactured edge radii','BEVEL');modifier.width=bevel;modifier.segments=3;bpy.ops.object.modifier_apply(modifier=modifier.name)
 for poly in obj.data.polygons:poly.use_smooth=True
 modifier=obj.modifiers.new('Planar weighted normals','WEIGHTED_NORMAL');modifier.keep_sharp=True;bpy.ops.object.modifier_apply(modifier=modifier.name)
 obj.data.materials.append(materials[material]);return obj

def bolt(name,x,y,z,radius=.028,depth=.024):
 bpy.ops.mesh.primitive_cylinder_add(vertices=12,radius=radius,depth=depth,location=(x,z,y),rotation=(math.pi/2,0,0));obj=bpy.context.object;obj.name=name
 modifier=obj.modifiers.new('Machined bolt edge','BEVEL');modifier.width=.004;modifier.segments=2;bpy.ops.object.modifier_apply(modifier=modifier.name);obj.data.materials.append(materials['Steel'])
 return obj

def export(label,objects):
 bpy.ops.object.select_all(action='DESELECT')
 for obj in objects:obj.select_set(True)
 bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.join();obj=bpy.context.object;obj.name=label
 bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
 # The geometry is in metres with its ground datum at zero; material slots
 # name the manufactured finish. Godot assigns shared authored shaders.
 target=O/(label+'.glb');bpy.ops.export_scene.gltf(filepath=str(target),export_format='GLB',use_selection=True,export_apply=True)
 return {'asset':str(target),'triangles':sum(len(p.vertices)-2 for p in obj.data.polygons),'sha256':hashlib.sha256(target.read_bytes()).hexdigest()}

start=set(bpy.data.objects)
for side in [-1,1]:
 x=side*1.8
 for y,h,w,d in [(.12,.24,.4,.45),(.45,.38,.36,.38),(2.0,2.9,.27,.30),(3.65,.42,.36,.40),(3.96,.28,.4,.45)]:box('Cast structural column',(x,y,0),(w,h,d),'Graphite')
 box('Ivory protective column inset',(x-side*.015,2.02,-.17),(.19,2.74,.04),'Ceramic',.009)
 box('Recessed sterilizer channel',(x-side*.19,2.02,0),(.065,2.9,.15),'Steel',.008)
 box('Vertical physical UV tube',(x-side*.19,2.02,-.075),(.025,2.63,.025),'UVEmitter',.006)
 for y in [.23,.63,3.43,3.88]:
  for offset in [-.115,.115]:bolt('Recessed service fastener',x+offset,y,-.232)
 box('Column inspection cover',(x,.46,-.213),(.23,.20,.035),'Steel',.01)
box('Rigid upper sterilizer beam',(0,3.99,0),(3.6,.30,.38),'Graphite',.03)
box('Upper ceramic service inset',(0,4.02,-.205),(2.97,.16,.035),'Ceramic',.012)
box('Upper sterilizer recess',(0,3.81,0),(3.2,.09,.18),'Steel',.01)
box('Upper sterilizer tube',(0,3.77,-.035),(3.12,.032,.055),'UVEmitter',.008)
for x in [-1.32,-.8,0,.8,1.32]:bolt('Beam service fastener',x,4.03,-.238)
box('Device state bezel',(0,4.16,-.05),(.43,.16,.27),'Graphite',.018)
box('Device state lamp',(0,4.16,-.195),(.27,.045,.025),'Signal',.008)
arch=export('decon_sterilizer_precision',[o for o in bpy.data.objects if o not in start])

start=set(bpy.data.objects)
box('Continuous vertical service spine',(0,3.6,0),(.34,7.16,.30),'Graphite',.025)
box('Inset service conduit',(0,3.6,-.17),(.14,6.60,.05),'Steel',.009)
for y in [.2,2.8,5.15,6.98]:
 box('Structural connection collar',(0,y,0),(.46,.23,.38),'Graphite',.025)
 for x in [-.135,.135]:bolt('Collar fastener',x,y,-.205,.024,.02)
box('Spine safety status bezel',(0,2.16,-.18),(.19,.68,.075),'Graphite',.01)
box('Spine crimson status bar',(0,2.16,-.224),(.052,.45,.02),'Signal',.006)
spine=export('decon_service_spine_precision',[o for o in bpy.data.objects if o not in start])

start=set(bpy.data.objects)
box('Recessed horizontal fixture',(0,0,0),(2.85,.14,.14),'Graphite',.016)
box('Brushed fixture edge',(0,0,-.076),(2.70,.09,.028),'Steel',.008)
box('Warm clinical diffuser',(0,0,-.096),(2.58,.055,.018),'ServiceLamp',.006)
lamp=export('decon_service_light_precision',[o for o in bpy.data.objects if o not in start])

start=set(bpy.data.objects)
box('Sealed instrument body',(0,0,0),(.58,.39,.12),'Graphite',.025)
for x in [-.273,.273]:box('Instrument side bezel',(x,0,-.072),(.035,.34,.035),'Steel',.008)
for y in [-.17,.17]:box('Instrument top bottom bezel',(0,y,-.072),(.53,.035,.035),'Steel',.008)
for x in [-.245,.245]:
 for y in [-.142,.142]:bolt('Instrument recessed fastener',x,y,-.094,.015,.012)
gauge=export('decon_pressure_gauge_precision',[o for o in bpy.data.objects if o not in start])
bpy.ops.wm.save_as_mainfile(filepath=str(P/'precision-service-frames.blend'))
report={'scope':'Selective precise frames for existing room;no regenerated room,route or collision ownership','arch':arch,'service_spine':spine,'service_light':lamp,'pressure_gauge':gauge,'native_clear_width_m':3.2,'native_clear_height_m':3.75,'original_tripo_sources_preserved':True}
(P/'optimized/precision-frames-report.json').write_text(json.dumps(report,indent=2));print('PRECISION_FRAMES_EXPORTED',report,flush=True)

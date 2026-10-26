"""Local mechanical/readability repairs from actual native four-view critique."""
import bpy,math,json,hashlib
from pathlib import Path
APP=Path(__file__).resolve().parents[2];P=APP/'art/production/specimen-refinement-20261025';OUT=APP/'godot/assets/environments/specimen_cp45'
bpy.ops.wm.read_factory_settings(use_empty=True)
def material(name,col,metal,rough):
 m=bpy.data.materials.new(name);m.use_nodes=True;m.diffuse_color=(*col,1);b=m.node_tree.nodes.get('Principled BSDF');b.inputs['Base Color'].default_value=(*col,1);b.inputs['Metallic'].default_value=metal;b.inputs['Roughness'].default_value=rough;return m
ceramic=material('SensorMutedPearl',(.36,.41,.46),.22,.45)
alloy=material('SensorMachinedAlloy',(.22,.28,.33),.72,.34)
dark=material('SensorGasket',(.035,.045,.06),.12,.6)
def box(name,p,size,mat,bevel=.012):
 bpy.ops.mesh.primitive_cube_add(size=1,location=p);o=bpy.context.object;o.name=name;o.dimensions=size;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(mat)
 if bevel:
  m=o.modifiers.new('FunctionalBevel','BEVEL');m.width=bevel;m.segments=3;bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=m.name)
 return o
def bolt(name,p,r,h,mat,axis='Z'):
 bpy.ops.mesh.primitive_cylinder_add(vertices=6,radius=r,depth=h,location=p);o=bpy.context.object;o.name=name;o.data.materials.append(mat)
 if axis=='Y':o.rotation_euler[0]=math.pi*.5
 return o
rows=[]
def export(name,objects):
 bpy.ops.object.select_all(action='DESELECT')
 for o in objects:o.select_set(True)
 bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.join();o=bpy.context.object;o.name=name;bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
 o.data.calc_loop_triangles();path=OUT/(name+'.glb')
 bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,export_animations=False)
 rows.append({'file':path.name,'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'triangles':len(o.data.loop_triangles),'surfaces':len(o.data.materials)})
 o.hide_set(True);return o
# Native x/y/z=.48/.38/.78. Blender y carries native depth.
sensor=[box('SealedSensorHousing',(0,0,0),(.48,.72,.38),ceramic,.025),box('RecessedOpticalNose',(0,.36,0),(.39,.06,.29),alloy,.016)]
for x in [-.165,.165]:
 for z in [-.105,.105]:sensor.append(bolt('SensorNoseFastener',(x,.393,z),.012,.008,dark,'Y'))
for y in [-.20,-.10,0,.10,.20]:sensor.append(box('VentFin',(.238,y,0),(.004,.035,.16),dark,.001))
export('specimen_sensor_housing',sensor)
# Terminal visual fits the original1.2x1.2x.8m solid exactly.
terminal=[box('TerminalFoot',(0,0,.08),(1.19,.79,.16),alloy,.018),box('CeramicConsoleCore',(0,0,.665),(1.17,.77,1.07),ceramic,.025)]
for x in [-.30,.30]:
 terminal.append(box('RecessedAccessPanel',(x,-.386,.65),(.53,.012,.85),alloy,.009))
 for xx in [-.23,.23]:
  for zz in [-.35,.35]:terminal.append(bolt('ConsolePanelFastener',(x+xx,-.396,.65+zz),.013,.006,dark,'Y'))
for i in range(7):terminal.append(box('ConsoleServiceVent',(.586,0,.38+i*.05),(.006,.42,.018),dark,.002))
export('specimen_terminal_case',terminal)
trim=[box('MachinedTrimUnit',(0,0,0),(1,1,1),alloy,.07)]
export('specimen_trim_unit',trim)
for o in bpy.context.scene.objects:o.hide_set(False)
bpy.ops.wm.save_as_mainfile(filepath=str(P/'specimen-readability-editable.blend'))
(P/'readability-build.json').write_text(json.dumps({'assets':rows,'scope':'Visuals only. Sensor native rotation/light/detector,terminal native Area/collider/authority remain unchanged.'},indent=2),encoding='utf-8')
print('SPECIMEN_READABILITY_BUILT',json.dumps(rows))

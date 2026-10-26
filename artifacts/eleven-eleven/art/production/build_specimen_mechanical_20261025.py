"""Measured editable dressing. Native solids and gameplay remain in Godot."""
import bpy, math, json, hashlib
from pathlib import Path
APP=Path(__file__).resolve().parents[2]
P=APP/'art/production/specimen-refinement-20261025'
OUT=APP/'godot/assets/environments/specimen_cp45'
OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.scene.unit_settings.system='METRIC'
def mat(name,color,metal,rough):
 m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True
 bs=m.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(*color,1);bs.inputs['Metallic'].default_value=metal;bs.inputs['Roughness'].default_value=rough
 return m
ceramic=mat('SpecimenPearlCeramic',(.57,.63,.68),.12,.48)
alloy=mat('SpecimenBrushedTitanium',(.22,.29,.34),.72,.38)
graphite=mat('SpecimenGraphiteSeals',(.032,.047,.059),.15,.69)
def finish(o,name,m,bevel=0):
 o.name=name;o.data.materials.clear();o.data.materials.append(m)
 if bevel:
  b=o.modifiers.new('MeasuredMachinedBevel','BEVEL');b.width=bevel;b.segments=3
  bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=b.name)
 for face in o.data.polygons:face.use_smooth=False
 return o
def box(name,pos,size,m,bevel=.015):
 bpy.ops.mesh.primitive_cube_add(size=1,location=pos);o=bpy.context.object;o.dimensions=size
 bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 return finish(o,name,m,bevel)
def cylinder(name,pos,r,h,m,vertices=48):
 bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=r,depth=h,location=pos)
 return finish(bpy.context.object,name,m,min(.006,h*.1))
def annulus(name,z,ri,ro,h,m,segments=96):
 verts=[];faces=[]
 for level in [z-h*.5,z+h*.5]:
  for radius in [ri,ro]:
   for i in range(segments):
    t=i*math.tau/segments;verts.append((math.cos(t)*radius,math.sin(t)*radius,level))
 for i in range(segments):
  j=(i+1)%segments
  faces.extend([(i,j,segments+j,segments+i),(2*segments+i,3*segments+i,3*segments+j,2*segments+j),(i,2*segments+i,2*segments+j,j),(segments+i,segments+j,3*segments+j,3*segments+i)])
 mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update()
 o=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(o);return finish(o,name,m,.004)
exports=[]
def export(name,objects,bounds):
 bpy.ops.object.select_all(action='DESELECT')
 for o in objects:o.select_set(True)
 bpy.context.view_layer.objects.active=objects[0]
 bpy.ops.object.join();o=bpy.context.object;o.name=name
 bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
 o.data.calc_loop_triangles();tri=len(o.data.loop_triangles)
 path=OUT/(name+'.glb')
 bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,export_animations=False,export_yup=True)
 exports.append({'file':str(path.relative_to(APP)).replace('\\','/'),'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'triangles':tri,'surfaces':len(o.data.materials),'native_bounds_m':bounds})
 o.hide_set(True);o.hide_render=True
 return o
# Blender Z maps to native Y. Cap occupies precisely y0..0.30,
# x/z +/-1.25. Circular seals are mechanical dressing, never glass/fluid.
cap=[]
cap.append(box('FlangedCeramicFoundation',(0,0,.095),(2.5,2.5,.19),ceramic,.035))
cap.append(annulus('PerimeterSeal',.202,1.075,1.19,.024,graphite))
cap.append(annulus('MachinedClampRing',.251,1.079,1.165,.098,alloy))
for i in range(12):
 t=i*math.tau/12;r=1.195
 cap.append(cylinder('FlushSealFastener%02d'%i,(math.cos(t)*r,math.sin(t)*r,.204),.022,.028,alloy,6))
for x in [-1,1]:
 for y in [-1,1]:
  cap.append(cylinder('StaySocket',(x*.82,y*.82,.242),.073,.116,alloy,24))
  seal=annulus('StaySocketSeal',.294,.032,.058,.012,graphite,24)
  seal.location.x=x*.82;seal.location.y=y*.82;cap.append(seal)
export('specimen_seal_cap',cap,{'min':[-1.25,0,-1.25],'max':[1.25,.3,1.25]})
# Wall module width2.96m,height3.46m,depth.08m; front in native+Z.
# In Blender native Y is Z and native+Z is -Y.
panel=[]
panel.append(box('RecessedGraphiteChassis',(0,0,1.73),(2.96,.055,3.46),graphite,.008))
panel.append(box('PlanarCeramicPanel',(0,-.0325,1.73),(2.86,.03,3.36),ceramic,.018))
for x in [-1.37,1.37]:
 for z in [.14,3.32]:
  screw=cylinder('PanelFlushFastener',(x,-.051,z),.017,.008,alloy,6);screw.rotation_euler[0]=math.pi/2;panel.append(screw)
export('specimen_wall_service_panel',panel,{'width':2.96,'height':3.46,'depth':.08})
tray=[]
tray.append(box('ClosedCableBacking',(0,0,.11),(.34,2.98,.025),graphite,.004))
for x in [-.15,.15]:tray.append(box('RaisedCableChannel',(x,0,.07),(.035,2.98,.14),alloy,.006))
for i in range(15):tray.append(box('CableTrayCrossmember',(0,-1.4+i*.2,.025),(.3,.025,.045),alloy,.004))
for y in [-1.2,0,1.2]:
 tray.append(box('CeilingMountTie',(0,y,.14),(.42,.06,.025),alloy,.004))
export('specimen_ceiling_tray',tray,{'width':.42,'length':2.98,'height':.1525})
for o in bpy.context.scene.objects:o.hide_set(False);o.hide_render=False
bpy.ops.wm.save_as_mainfile(filepath=str(P/'specimen-mechanical-editable.blend'))
(P/'mechanical-build.json').write_text(json.dumps({'exports':exports,'protected':'No physics, labels, fluids, scanner, signals or state in GLBs. Source and native solids preserved.','status':'built; native review pending'},indent=2),encoding='utf-8')
print('SPECIMEN_MECHANICAL_BUILT',json.dumps(exports))

import bpy,json,pathlib,math,hashlib
from mathutils import Vector,Matrix
P=pathlib.Path(r'C:\Users\yasmo\EchoNetwork\artifacts\eleven-eleven\art\production\surveillance-20261029')
OUT=pathlib.Path(r'C:\Users\yasmo\EchoNetwork\artifacts\eleven-eleven\godot\assets\environments\surveillance_cp45');OUT.mkdir(parents=True,exist_ok=True)
report={}
def reset():
 bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
def export(label,filename):
 meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
 bpy.ops.object.select_all(action='DESELECT')
 for o in meshes:o.select_set(True)
 bpy.context.view_layer.objects.active=meshes[0];bpy.ops.object.transform_apply(location=True,rotation=True,scale=True);bpy.ops.object.join();obj=bpy.context.object;obj.name=label
 obj.data.calc_loop_triangles();triangles=len(obj.data.loop_triangles)
 file=OUT/filename
 if file.exists():
  backup=P/'source'/(filename+'.before-build');backup.write_bytes(file.read_bytes()) if not backup.exists() else None
 bpy.ops.export_scene.gltf(filepath=str(file),export_format='GLB',use_selection=True,export_apply=True,export_animations=False)
 report[label]={'asset':filename,'triangles':triangles,'vertices':len(obj.data.vertices),'sha256':hashlib.sha256(file.read_bytes()).hexdigest()}
 return obj
reset();bpy.ops.import_scene.gltf(filepath=str(P/'source/server-bay-p2-pbr4k.glb'))
meshes=[o for o in bpy.context.scene.objects if o.type=='MESH'];points=[o.matrix_world@Vector(c) for o in meshes for c in o.bound_box]
low=Vector(tuple(min(p[i] for p in points) for i in range(3)));high=Vector(tuple(max(p[i] for p in points) for i in range(3)));dims=high-low
anchor=Vector(((low.x+high.x)*.5,(low.y+high.y)*.5,low.z))
transform=Matrix.Diagonal((3.2/dims.x,.32/dims.y,3.4/dims.z,1))@Matrix.Translation(-anchor)
for o in meshes:o.matrix_world=transform@o.matrix_world
bpy.context.view_layer.update();export('SurveillanceBayP2','surveillance_server_bay_p2.glb')
report['calibration']={'original_blender_xyz':list(dims),'target_native_width_height_depth':[3.2,3.4,.32],'front':'native+Z;Blender-Y','original_uv_materials_preserved':True}
for image in bpy.data.images:
 if image.source=='FILE' and not image.packed_file:
  try:image.pack()
  except RuntimeError:pass
bpy.ops.wm.save_as_mainfile(filepath=str(P/'source/server-bay-metric.blend'))
reset()
def material(name,color,metal,rough):
 m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True;n=m.node_tree.nodes.get('Principled BSDF');n.inputs['Base Color'].default_value=(*color,1);n.inputs['Metallic'].default_value=metal;n.inputs['Roughness'].default_value=rough;return m
graphite=material('Graphite',(.075,.09,.115),.5,.5);steel=material('Steel',(.20,.24,.28),.65,.42);warm=material('ServiceLamp',(.9,.76,.54),.05,.4)
def box(name,point,size,mat,bevel=.012):
 bpy.ops.mesh.primitive_cube_add(size=1,location=(point[0],-point[2],point[1]));o=bpy.context.object;o.name=name;o.dimensions=(size[0],size[2],size[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(mat)
 if bevel:
  mod=o.modifiers.new('ManufacturedEdge','BEVEL');mod.width=bevel;mod.segments=2;bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=mod.name)
 return o
def beam(name,start,end,width,depth,mat):
 a=Vector((start[0],-start[2],start[1]));b=Vector((end[0],-end[2],end[1]));o=box(name,(0,0,0),(width,(b-a).length,depth),mat,.007);o.location=(a+b)*.5;o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler();return o
for y in [.05,.63]:box('TrussChord',(0,y,0),(27.6,.12,.22),graphite,.025)
for i in range(23):
 x=-13.2+i*1.2;beam('DiagonalWeb',(x-.6,.11,0),(x+.6,.57,0),.055,.075,steel)
for x in [-13.5,-6.8,0,6.8,13.5]:
 box('BoltedSaddle',(x,.33,0),(.23,.74,.28),steel,.028)
 for y in [.09,.58]:box('SaddleFastener',(x,y,.15),(.065,.065,.025),graphite,.009)
for x in [-10,-5,5,10]:box('TrussTaskLight',(x,.025,.14),(1.8,.035,.045),warm,.009)
export('SurveillanceCeilingTruss','surveillance_ceiling_truss.glb');bpy.ops.wm.save_as_mainfile(filepath=str(P/'source/ceiling-truss.blend'))
reset()
for y in [.20,.98]:box('ContinuousHandrail',(0,y,0),(8.0,.055,.075),steel,.018)
for x in [-3.97,-2.67,-1.34,0,1.34,2.67,3.97]:
 box('RailUpright',(x,.50,0),(.055,1,.075),graphite,.012);box('RailFoot',(x,.025,0),(.16,.05,.14),steel,.008)
export('SurveillanceOpenRail','surveillance_open_rail.glb');bpy.ops.wm.save_as_mainfile(filepath=str(P/'source/open-railing.blend'))
(P/'runtime-kit-report.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8');print('RUNTIME_KIT',json.dumps(report))

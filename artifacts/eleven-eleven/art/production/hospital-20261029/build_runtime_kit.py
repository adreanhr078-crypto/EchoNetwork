import bpy,math,json,pathlib,sys,hashlib
from mathutils import Vector
P=pathlib.Path(r'C:\Users\yasmo\EchoNetwork\artifacts\eleven-eleven\art\production\hospital-20261029')
OUT=P.parents[2]/'godot/assets/environments/hospital_cp45';OUT.mkdir(parents=True,exist_ok=True)
kind=sys.argv[sys.argv.index('--')+1] if '--' in sys.argv else 'headwall'
def reset():
 bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
def export(name,path):
 meshes=[o for o in bpy.context.scene.objects if o.type=='MESH'];bpy.ops.object.select_all(action='DESELECT')
 for o in meshes:o.select_set(True)
 bpy.context.view_layer.objects.active=meshes[0];bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
 bpy.ops.export_scene.gltf(filepath=str(OUT/path),export_format='GLB',use_selection=True,export_yup=True,export_texcoords=True,export_normals=True,export_materials='EXPORT')
 return {'file':str(OUT/path),'sha256':hashlib.sha256((OUT/path).read_bytes()).hexdigest(),'triangles':sum(len(o.data.loop_triangles) for o in meshes)}
reset();bpy.ops.import_scene.gltf(filepath=str(P/'source'/f'{kind}-p2-pbr.glb'))
meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
for o in meshes:
 o.data.transform(o.matrix_world);o.matrix_world.identity();o.parent=None
points=[Vector(v) for o in meshes for v in o.bound_box];lo=Vector([min(p[i] for p in points) for i in range(3)]);hi=Vector([max(p[i] for p in points) for i in range(3)]);dims=hi-lo
if kind=='headwall':
 for o in meshes:
  for v in o.data.vertices:v.co=Vector((v.co.x/dims.x*2.15,(v.co.y-hi.y)/dims.y*.32,(v.co.z-lo.z)/dims.z*1.8))
else:
 # Mattress contact is measured from central top-facing samples,not overall
 # headboard height. Retain the factory's .72m support surface for recovery.
 for o in meshes:
  for v in o.data.vertices:v.co=Vector(((v.co.x-(hi.x+lo.x)*.5)/dims.x*2.24,(v.co.y-(hi.y+lo.y)*.5)/dims.y*1.04,(v.co.z-lo.z)/dims.z))
 bpy.context.view_layer.update()
 from mathutils.bvhtree import BVHTree
 import bmesh
 tops=[]
 for o in meshes:
  bm=bmesh.new();bm.from_mesh(o.data);tree=BVHTree.FromBMesh(bm)
  for x in [-.15,.15,.42]:
   for y in [-.10,0,.10]:
    hit,normal,_,_=tree.ray_cast(Vector((x,y,3)),Vector((0,0,-1)))
    if hit is not None and normal.z>.45:tops.append(hit.z)
  bm.free()
 assert len(tops)>=5,'Cannot qualify mattress contact'
 top=sorted(tops)[len(tops)//2];factor=.72/top
 for o in meshes:
  for v in o.data.vertices:v.co.z*=factor
for o in meshes:o.data.update();o.data.calc_loop_triangles()
report=export(kind,f'hospital_{kind}_p2.glb');report.update(original_blender_xyz=list(dims),calibration='Width2.15m,height1.8m,front+Z,backZ0' if kind=='headwall' else 'LengthX2.24m,widthZ1.04m,median central contactY.72m',uv_materials_preserved=True)
for image in bpy.data.images:
 if image.source=='FILE' and not image.packed_file:
  try:image.pack()
  except RuntimeError:pass
bpy.ops.wm.save_as_mainfile(filepath=str(P/'source'/f'{kind}-metric.blend'))
(P/f'{kind}-runtime-report.json').write_text(json.dumps(report,indent=2))
if kind=='headwall':
 reset();nx=24;ny=32;verts=[];faces=[]
 for j in range(ny+1):
  for i in range(nx+1):verts.append(((i/nx-.5)*.36,-math.sin(i/nx*math.tau*4)*.035,j/ny*1.75))
 for j in range(ny):
  for i in range(nx):a=j*(nx+1)+i;faces.append((a,a+1,a+nx+2,a+nx+1))
 mesh=bpy.data.meshes.new('PleatedSageCurtain');mesh.from_pydata(verts,[],faces);mesh.update();uv=mesh.uv_layers.new(name='UVMap')
 for poly in mesh.polygons:
  poly.use_smooth=True
  for li in poly.loop_indices:
   vi=mesh.loops[li].vertex_index;uv.data[li].uv=(vi%(nx+1)/nx,vi//(nx+1)/ny)
 o=bpy.data.objects.new('CurtainTopAnchored',mesh);bpy.context.collection.objects.link(o);mesh.calc_loop_triangles()
 export('curtain','hospital_pleated_curtain.glb');bpy.ops.wm.save_as_mainfile(filepath=str(P/'source/pleated-curtain.blend'))
print('WARD_RUNTIME_KIT',json.dumps(report))

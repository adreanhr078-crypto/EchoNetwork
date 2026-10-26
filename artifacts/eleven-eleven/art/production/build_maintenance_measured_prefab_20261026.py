"""Derive measured visual modules from the preserved full-room Tripo source.
No physics,rig,animation,gameplay authority or source-file modifications.
"""
import bpy,json,hashlib
from pathlib import Path
import numpy as np
from mathutils import Vector
A=Path(__file__).resolve().parents[2];P=A/'art/production/maintenance-refinement-20261025'
source=P/'full-room-h31-pbr4k.glb';assert source.exists()
dest=A/'godot/assets/environments/maintenance_cp45/maintenance_measured_fullroom_pbr4k.glb';dest.parent.mkdir(parents=True,exist_ok=True)
assert not dest.exists(),'Preserve earlier derivatives;use a new version for a repair'
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(source))
original=[o for o in bpy.context.scene.objects if o.type=='MESH'];assert len(original)==1
obj=original[0];mesh=obj.data;mesh.calc_loop_triangles()
positions=np.empty(len(mesh.vertices)*3,np.float32);mesh.vertices.foreach_get('co',positions);positions=positions.reshape(-1,3)
matrix=np.asarray(obj.matrix_world,dtype=np.float64);positions=positions@matrix[:3,:3].T+matrix[:3,3]
tri=np.empty(len(mesh.loop_triangles)*3,np.int32);mesh.loop_triangles.foreach_get('vertices',tri);tri=tri.reshape(-1,3)
loop_ids=np.empty(len(mesh.loop_triangles)*3,np.int32);mesh.loop_triangles.foreach_get('loops',loop_ids);loop_ids=loop_ids.reshape(-1,3)
centres=positions[tri].mean(axis=1)
uv=np.empty(len(mesh.loops)*2,np.float32);mesh.uv_layers.active.data.foreach_get('uv',uv);uv=uv.reshape(-1,2)
normals=np.empty(len(mesh.corner_normals)*3,np.float32);mesh.corner_normals.foreach_get('vector',normals);normals=normals.reshape(-1,3)@np.linalg.inv(matrix[:3,:3])
materials=list(mesh.materials);report=[];objects=[]

def inside(points,lo,hi):return np.all((points>=np.asarray(lo))&(points<=np.asarray(hi)),axis=1)
def native_box(name):
 spec=json.loads((A/'godot/assets/environments/maintenance_collision_v1.json').read_text())
 row=next(r for r in spec['bodies'] if r['name']==name);centre=np.asarray(row['position']);size=np.asarray(row['size']);return centre-size*.5,centre+size*.5
def blender_box(glo,ghi):return np.array([glo[0],-ghi[2],glo[1]]),np.array([ghi[0],-glo[2],ghi[1]])
def create(label,src_lo,src_hi,glo,ghi,exclude=None,portal=False):
 lo=np.asarray(src_lo);hi=np.asarray(src_hi);target_lo,target_hi=blender_box(glo,ghi)
 selected=inside(centres,lo,hi)
 if exclude is not None:selected&=~inside(centres,*exclude)
 ids=np.nonzero(selected)[0];assert len(ids)>50,(label,'Empty source region')
 vertices,indices=np.unique(tri[ids].ravel(),return_inverse=True)
 scale=(target_hi-target_lo)/(hi-lo)
 unclamped=positions[vertices];clipped=np.clip(unclamped,lo,hi);mapped=(clipped-lo)*scale+target_lo
 if portal:
  # Widen only the optical aperture by2cm;the old adapter owns its solids.
  cut_lo=np.array([-.92,14.15,5.15]);cut_hi=np.array([.92,14.85,8.65])
  coords=mapped[indices.reshape(-1,3)];overlap=np.all(coords.max(axis=1)>=cut_lo,axis=1)&np.all(coords.min(axis=1)<=cut_hi,axis=1)
  ids=ids[~overlap];vertices,indices=np.unique(tri[ids].ravel(),return_inverse=True)
  unclamped=positions[vertices];clipped=np.clip(unclamped,lo,hi);mapped=(clipped-lo)*scale+target_lo
 out=bpy.data.meshes.new(label);out.vertices.add(len(vertices));out.vertices.foreach_set('co',mapped.astype(np.float32).ravel())
 out.loops.add(len(indices));out.loops.foreach_set('vertex_index',indices.astype(np.int32))
 out.polygons.add(len(ids));out.polygons.foreach_set('loop_start',np.arange(len(ids),dtype=np.int32)*3);out.polygons.foreach_set('loop_total',np.full(len(ids),3,dtype=np.int32));out.polygons.foreach_set('use_smooth',np.ones(len(ids),dtype=np.bool_))
 out.update();layer=out.uv_layers.new(name='UVMap');selected_loops=loop_ids[ids].ravel();layer.data.foreach_set('uv',uv[selected_loops].astype(np.float32).ravel())
 transformed=normals[selected_loops]/scale;transformed/=np.maximum(np.linalg.norm(transformed,axis=1,keepdims=True),1e-12)
 out.normals_split_custom_set(transformed.tolist())
 for material in materials:out.materials.append(material)
 part=bpy.data.objects.new(label,out);bpy.context.collection.objects.link(part);objects.append(part)
 actual_lo=mapped.min(axis=0);actual_hi=mapped.max(axis=0)
 assert np.all(actual_lo>=target_lo-1e-5) and np.all(actual_hi<=target_hi+1e-5)
 part['visual_only']=True;part['native_min']=list(map(float,glo));part['native_max']=list(map(float,ghi))
 report.append({'part':label,'source_region_blender':[list(src_lo),list(src_hi)],'triangles':len(ids),'vertices':len(vertices),'clipped_boundary_vertices':int(np.count_nonzero(np.any(abs(unclamped-clipped)>1e-7,axis=1))),'native_target_box':[list(map(float,glo)),list(map(float,ghi))],'actual_blender_box':[actual_lo.tolist(),actual_hi.tolist()],'normal_transform':'inverse-transpose of source world basis and measured affine scale','source_uv_retained':True})

# Side/back skins occupy the old solid wall volumes. Source relief is fitted
# deliberately;the original unmodified1.913M model remains the master source.
create('MeasuredLeftPressureBulkhead',[-.491,-.299,.045],[-.34,.298,.49],*native_box('COLL_LeftBoundary'))
create('MeasuredRightPressureBulkhead',[.33,-.299,.045],[.491,.298,.49],*native_box('COLL_RightBoundary'))
create('MeasuredRearServiceBulkhead',[-.34,.244,.045],[.33,.299,.49],*native_box('COLL_FarBoundary'),exclude=([-.27,.215,.15],[.24,.31,.405]),portal=True)
# Native hand/foot planes and the original grip rows will be drawn in front
# of these manufactured surrounds by the runtime kit;no source grip is a
# new interaction. Bounds remain exactly within the original climb solids.
create('MeasuredFirstClimbMachinery',[-.286,-.211,.038],[.104,-.039,.314],*native_box('COLL_CLIMB_FirstWall'))
create('MeasuredSecondClimbMachinery',[.09,.125,.287],[.31,.235,.351],*native_box('COLL_CLIMB_SecondWall'))
# Reuse one real manufactured grating patch at each old platform. Continuous
# original physics support remains unchanged,including the jump gap.
for name in ['COLL_UpperRest','COLL_GapLanding','COLL_FinalRest','COLL_ExitDeck','COLL_ServiceVestibule']:
 create('MeasuredGrating_'+name,[-.265,-.18,.284],[.115,-.047,.309],*native_box(name))
create('MeasuredEntryServiceFloor',[-.49,-.297,0],[.49,.297,.047],*native_box('COLL_EntryFloor'))
# This ceiling trim is above any reachable motion;the original roof collider
# remains at10.6m. It adds no apparent floor or obstacle on the player route.
create('UpperPressureBayBeamCrown',[-.491,-.299,.49],[.491,.299,.543],[-4.58,10.18,-14.68],[5.58,10.59,.48])

bpy.data.objects.remove(obj,do_unlink=True)
bpy.ops.object.select_all(action='DESELECT')
for part in objects:part.select_set(True)
bpy.context.view_layer.objects.active=objects[0]
bpy.ops.export_scene.gltf(filepath=str(dest),export_format='GLB',use_selection=True,export_apply=True,export_texcoords=True,export_normals=True,export_tangents=True,export_animations=False)
bpy.ops.wm.save_as_mainfile(filepath=str(P/'maintenance-measured-fullroom-editable.blend'))
receipt={'source':source.name,'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'source_triangles':len(tri),'derivative':str(dest.relative_to(A)).replace('\\','/'),'derivative_sha256':hashlib.sha256(dest.read_bytes()).hexdigest(),'derivative_bytes':dest.stat().st_size,'triangles':sum(p['triangles'] for p in report),'parts':report,'physics_objects_added':0,'scope':'Measured modular derivative of whole-room Tripo source. Source proportion remapping/clipped cut-boundaries explicit;not exact image geometry,not art/player acceptance. Original grip/contact/gate/wheel/camera/save owners remain native.'}
(P/'measured-prefab-build.json').write_text(json.dumps(receipt,indent=2),encoding='utf-8')
print('MAINTENANCE_MEASURED_PREFAB',json.dumps({k:v for k,v in receipt.items() if k!='parts'}))

"""Explicit mount versus distal contact,using triangle intersection endpoints.

The source wing intentionally emerges through the shoulder/clothing junction.
Its reviewed 12.5cm mount is reported separately,never claimed collision-free.
All distal intersection endpoints remain disallowed. Body vertices stay exact.
"""
from pathlib import Path
import sys,json,math,hashlib
import bpy
from mathutils import Vector,Quaternion,geometry
from mathutils.bvhtree import BVHTree
case=Path(sys.argv[sys.argv.index('--')+1]).resolve();ref=json.loads((case/'blender-reference.json').read_text());bpy.ops.wm.open_mainfile(filepath=str(case/'single-motion.blend'))
rig=bpy.data.objects[ref['target_rig']];bone=rig.pose.bones['WingRootLeft'];bone.rotation_mode='QUATERNION'
mesh=next(o for o in bpy.context.scene.objects if o.type=='MESH' and any(m.type=='ARMATURE' and m.object==rig for m in o.modifiers));groups={g.index for g in mesh.vertex_groups if g.name.startswith('Wing')};wing={v.index for v in mesh.data.vertices if sum(g.weight for g in v.groups if g.group in groups)>1e-8};assert len(wing)==32860
body=[i for i in range(len(mesh.data.vertices)) if i not in wing];basis=(rig.matrix_world@bone.bone.matrix_local).to_quaternion().inverted();rows=[];body_error=0.0
def skin(frame,q):
 bpy.context.scene.frame_set(int(frame),subframe=frame-int(frame));bone.rotation_quaternion=q;bpy.context.view_layer.update();e=mesh.evaluated_get(bpy.context.evaluated_depsgraph_get());d=e.to_mesh();d.calc_loop_triangles();v=[e.matrix_world@x.co for x in d.vertices];tri=[tuple(t.vertices) for t in d.loop_triangles];e.to_mesh_clear();return v,tri
def smooth(t):t=max(0,min(1,t));return t*t*(3-2*t)
def endpoints(a,b):
 points=[]
 for edge,face in [(a,b),(b,a)]:
  for i in range(3):
   origin=edge[i];delta=edge[(i+1)%3]-origin
   if delta.length<1e-10:continue
   hit=geometry.intersect_ray_tri(*face,delta.normalized(),origin,True)
   if hit is not None and (hit-origin).dot(delta)>=-1e-9 and (hit-origin).length<=delta.length+1e-7:points.append(hit)
 return points
def measure(index,dx=0,dz=0):
 global body_error
 f=index/4;pulse=smooth((f-30)/3)*(1-smooth((f-34)/3));weight=smooth((f-8)/10)*(1-smooth((f-44)/12));q=Quaternion(basis@Vector((0,0,1)),math.radians(45+dz*pulse)*weight)@Quaternion(basis@Vector((1,0,0)),math.radians(45+dx*pulse)*weight)
 original,_=skin(f,Quaternion());vertices,tri=skin(f,q);body_error=max(body_error,max((vertices[i]-original[i]).length for i in body))
 wt=[t for t in tri if all(i in wing for i in t)];bt=[t for t in tri if not any(i in wing for i in t)];raw=BVHTree.FromPolygons(vertices,wt,all_triangles=True).overlap(BVHTree.FromPolygons(vertices,bt,all_triangles=True));mount=rig.matrix_world@bone.matrix.translation;distal=0;max_radius=0.0;unresolved=0
 for wi,bi in raw:
  a=[vertices[i] for i in wt[wi]];b=[vertices[i] for i in bt[bi]];points=endpoints(a,b)
  if not points:
   unresolved+=1;points=a+b # Conservative unresolved/coplanar fallback.
  radius=max((p-mount).length for p in points);max_radius=max(max_radius,radius)
  if radius>.125:distal+=1
 return {'time':f/30,'frame':f,'raw_pairs':len(raw),'mount_pairs':len(raw)-distal,'distal_pairs':distal,'unresolved_pairs':unresolved,'maximum_intersection_radius_m':max_radius,'rotation_xyzw':[q.x,q.y,q.z,q.w],'body_floor_z':min(vertices[i].z for i in body),'wing_floor_z':min(vertices[i].z for i in wing)}

fine='--fine-search' in sys.argv
trials=[];dx=dz=0
if fine:
 for x,z in [(0,0),(-2.5,0),(2.5,0),(0,-2.5),(0,2.5),(-5,0),(5,0),(0,-5),(0,5)]:
  values=[measure(round(f*4),x,z)['distal_pairs'] for f in [32.5,33,33.25,33.5,34]]
  trial={'dx':x,'dz':z,'worst':max(values),'sum':sum(values)};trials.append(trial);print('WING_FINE',trial,flush=True)
 best=min(trials,key=lambda t:(t['worst'],t['sum'],abs(t['dx'])+abs(t['dz'])));dx=best['dx'];dz=best['dz']
for index in range((len(ref['samples'])-1)*4+1):
 row=measure(index,dx,dz);rows.append(row)
 if index%48==0:print('WING_ENDPOINT_REVIEW',index,row['distal_pairs'],flush=True)
report={'status':'PASS_SCOPED_DISTAL_CONTACT' if body_error<1e-5 and all(r['distal_pairs']==0 for r in rows) else 'FAIL','samples':rows,'fps':120,'body_skin_max_change_m':body_error,'source_blend_sha256':hashlib.sha256((case/'single-motion.blend').read_bytes()).hexdigest(),'tool_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'mount_radius_m':.125,'mount_review':'Four phases xthree actual shoulder views plus two whole-body views inspected;feathers emerge at the anatomical shoulder/clothing junction. Mount contacts are reported and allowed,not declared collision-free.','source_keys_modified':False,'limits':'Animated distal wing/body geometry only. Fresh Godot equality,visual/camera/floor and gameplay gates remain separate.'}
report['fine_trials']=trials;report['fine_offsets_degrees']=[dx,dz]
(case/('wing-reviewed-clearance-fine.json' if fine else 'wing-reviewed-clearance.json')).write_text(json.dumps(report,indent=2)+'\n');print('WING_ENDPOINT_RESULT',report['status'],len(rows),body_error,max(r['distal_pairs'] for r in rows))

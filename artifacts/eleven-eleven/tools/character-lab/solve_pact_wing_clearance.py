"""Bounded WingRoot-only clearance experiment; never edits body/source keys."""
from pathlib import Path
import sys,json,hashlib,math
import bpy
from collections import Counter
from mathutils import Quaternion,Vector
from mathutils.bvhtree import BVHTree
case=Path(sys.argv[sys.argv.index('--')+1]).resolve();ref=json.loads((case/'blender-reference.json').read_text())
joint='WingInnerLeft' if '--inner-pivot' in sys.argv else 'WingRootLeft'
lift_axis='--lift-axis' in sys.argv
lateral_axis='--lateral-axis' in sys.argv
combined='--combined' in sys.argv
retract_root='--retract-root' in sys.argv
bpy.ops.wm.open_mainfile(filepath=str(case/'single-motion.blend'))
rig=bpy.data.objects[ref['target_rig']];root=rig.pose.bones[joint];root.rotation_mode='QUATERNION'
mesh=next(o for o in bpy.context.scene.objects if o.type=='MESH' and any(m.type=='ARMATURE' and m.object==rig for m in o.modifiers))
groups={g.index for g in mesh.vertex_groups if g.name.startswith('Wing')};wing={v.index for v in mesh.data.vertices if sum(g.weight for g in v.groups if g.group in groups)>1e-8};assert len(wing)==32860
body=[i for i in range(len(mesh.data.vertices)) if i not in wing]
axis=((rig.matrix_world@root.bone.matrix_local).to_quaternion().inverted()@Vector((1,0,0) if lateral_axis else (0,1,0) if lift_axis else (0,0,1))).normalized()
scene=bpy.context.scene
detail={}
def evaluate(frame,angle):
 global detail
 scene.frame_set(frame)
 if isinstance(angle,tuple):
  basis=(rig.matrix_world@root.bone.matrix_local).to_quaternion().inverted()
  root.rotation_quaternion=Quaternion(basis@Vector((0,0,1)),math.radians(angle[1]))@Quaternion(basis@Vector((1,0,0)),math.radians(angle[0]))
 else:root.rotation_quaternion=Quaternion(axis,math.radians(angle))
 root.scale=Vector((1,1,1))*(1-angle[2] if isinstance(angle,tuple) and len(angle)==3 else 1)
 bpy.context.view_layer.update()
 e=mesh.evaluated_get(bpy.context.evaluated_depsgraph_get());d=e.to_mesh();d.calc_loop_triangles();v=[e.matrix_world@x.co for x in d.vertices];mount=rig.matrix_world@rig.pose.bones['WingRootLeft'].matrix.translation
 wt=[];bt=[]
 for t in d.loop_triangles:
  ids=tuple(t.vertices)
  if all(i in wing for i in ids):
   if min((v[i]-mount).length for i in ids)>.10:wt.append(ids)
  elif not any(i in wing for i in ids):bt.append(ids)
 overlaps=BVHTree.FromPolygons(v,wt,all_triangles=True).overlap(BVHTree.FromPolygons(v,bt,all_triangles=True))
 parts=Counter();radii=[];points=[]
 for wi,bi in overlaps:
  weights=Counter()
  for vi in bt[bi]:
   for g in mesh.data.vertices[vi].groups:weights[mesh.vertex_groups[g.group].name]+=g.weight
  if weights:parts[weights.most_common(1)[0][0]]+=1
  center=sum((v[i] for i in wt[wi]),Vector())/3;radii.append((center-mount).length);points.append(list(center))
 detail={'body_roles':dict(parts),'root_radius_min_m':min(radii) if radii else None,'root_radius_max_m':max(radii) if radii else None,'centers':points[:12]}
 e.to_mesh_clear()
 return len(overlaps),v
if '--detail-only' in sys.argv:
 rows=[]
 for f in [24,28,31,34,36,37,40,44]:
  pairs,_=evaluate(f,(45,45));rows.append({'frame':f,'pairs':pairs,**detail})
 (case/'wing-contact-detail.json').write_text(json.dumps(rows,indent=2)+'\n');print(json.dumps(rows));raise SystemExit(0)
# The measured failure occupies28..44. Move the wing before that interval and
# recover smoothly afterward; no fitted body motion or source timing changes.
def envelope(frame):
 def smooth(t):t=max(0,min(1,t));return t*t*(3-2*t)
 return smooth((frame-(8 if retract_root else 18))/10)*(1-smooth((frame-44)/12))
candidates=[]
for angle in ([(x,45,s) for s in [.1,.2] for x in [30,45]] if retract_root else [(x,z) for x in [15,30,45] for z in [30,45,60]] if combined else [-15,15,-30,30,-45,45,-60,60]):
 counts=[evaluate(f,angle)[0] for f in [28,31,34,37,40,44]]
 row={'angle_degrees':angle,'pairs':counts,'worst':max(counts),'sum':sum(counts)};candidates.append(row);print('WING_CANDIDATE',row,flush=True)
best=min(candidates,key=lambda x:(x['worst'],x['sum'],sum(abs(v) for v in x['angle_degrees']) if combined else abs(x['angle_degrees'])))
rows=[];body_error=0.0
for f,s in enumerate(ref['samples']):
 angles=tuple(v*envelope(f) for v in best['angle_degrees']) if combined else best['angle_degrees']*envelope(f)
 _,original=evaluate(f,0);pairs,changed=evaluate(f,angles);body_error=max(body_error,max((changed[i]-original[i]).length for i in body));rows.append({'frame':f,'time':s['time'],'angle_degrees':angles,'distal_pairs':pairs,'body_floor_z':min(changed[i].z for i in body),'wing_floor_z':min(changed[i].z for i in wing)})
 if f%12==0:print('WING_VERIFY',f,pairs,flush=True)
report={'status':'PASS_SCOPED_WING_CLEARANCE' if all(r['distal_pairs']==0 for r in rows) and body_error<1e-5 else 'FAIL','joint':joint,'source_blend_sha256':hashlib.sha256((case/'single-motion.blend').read_bytes()).hexdigest(),'tool_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'axis_local':list(axis),'candidates':candidates,'selected':best,'samples':rows,'body_skin_max_change_m':body_error,'source_keys_modified':False,'limits':'Eligible wing joint only presentation candidate. Requires fresh Blender and Godot actual render review,interpolated skin contacts and runtime body/camera/floor gates. No body keys or source export changed.'}
report['combined_axes_xz']=combined
(case/('wing-retract-clearance-candidate.json' if retract_root else 'wing-combined-clearance-candidate.json' if combined else 'wing-lateral-clearance-candidate.json' if lateral_axis else 'wing-lift-clearance-candidate.json' if lift_axis else 'wing-inner-clearance-candidate.json' if joint=='WingInnerLeft' else 'wing-clearance-candidate.json')).write_text(json.dumps(report,indent=2)+'\n');print('WING_CLEARANCE',report['status'],best['angle_degrees'],body_error)

"""Read-only evaluated Pact72 wing/body contacts at every native source sample.

The seven explicitly authored Wing weights define the semantic wing. Only the
10cm anatomical mounting region is excluded from distal feather/body overlap.
This records evidence; it neither repairs skin nor accepts gameplay.
"""
from pathlib import Path
import sys,json,hashlib
import bpy
from mathutils.bvhtree import BVHTree

case=Path(sys.argv[sys.argv.index('--')+1]).resolve()
floor_only='--floor-only' in sys.argv
blend=case/'single-motion.blend';reference=json.loads((case/'blender-reference.json').read_text())
bpy.ops.wm.open_mainfile(filepath=str(blend))
rig=bpy.data.objects[reference['target_rig']]
mesh=next(o for o in bpy.context.scene.objects if o.type=='MESH' and any(m.type=='ARMATURE' and m.object==rig for m in o.modifiers))
wing_groups={g.index for g in mesh.vertex_groups if g.name.startswith('Wing')}
wing={v.index for v in mesh.data.vertices if sum(g.weight for g in v.groups if g.group in wing_groups)>1e-8}
assert len(wing)==32860 or (floor_only and '--school-body' in sys.argv and len(wing)==0 and len(rig.data.bones)==65),(len(wing),'Semantic avatar identity differs')
scene=bpy.context.scene;rows=[]
subdivisions=4 if '--hz120' in sys.argv else 1
for index in range((len(reference['samples'])-1)*subdivisions+1):
 frame=index/subdivisions;sample={'time':frame/reference['fps']}
 scene.frame_set(int(frame),subframe=frame-int(frame));bpy.context.view_layer.update()
 evaluated=mesh.evaluated_get(bpy.context.evaluated_depsgraph_get());data=evaluated.to_mesh();data.calc_loop_triangles()
 vertices=[evaluated.matrix_world@v.co for v in data.vertices]
 root=rig.matrix_world@rig.pose.bones['WingRootLeft'].matrix.translation if wing else None
 wing_tri=[];body_tri=[]
 for t in ([] if floor_only else data.loop_triangles):
  ids=tuple(t.vertices)
  if all(i in wing for i in ids):
   if min((vertices[i]-root).length for i in ids)>.10:wing_tri.append(ids)
  elif not any(i in wing for i in ids):body_tri.append(ids)
 overlap=[] if floor_only else BVHTree.FromPolygons(vertices,wing_tri,all_triangles=True,epsilon=0).overlap(BVHTree.FromPolygons(vertices,body_tri,all_triangles=True,epsilon=0))
 rows.append({'frame':frame,'time':sample['time'],'distal_wing_body_triangle_pairs':len(overlap),'body_min_z':min(v.z for i,v in enumerate(vertices) if i not in wing),'wing_min_z':min(vertices[i].z for i in wing) if wing else None})
 evaluated.to_mesh_clear()
 if index%48==0:print('PACT_SKIN_SAMPLE',frame,len(overlap),flush=True)
report={'status':'MEASURED_NOT_RUNTIME_ACCEPTANCE','blend_sha256':hashlib.sha256(blend.read_bytes()).hexdigest(),'tool_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'native_fps':reference['fps'],'samples':rows,'wing_vertices':len(wing),'mount_exclusion_radius_m':.10,'source_keys_modified':False,'worst_distal_triangle_pairs':max(x['distal_wing_body_triangle_pairs'] for x in rows),'limits':'No simulation or skin correction. Triangle surface intersections do not establish art/floor/capsule/camera acceptance;mount region intentionally excluded.'}
report['distal_contacts_measured']=not floor_only
report['measurement_fps']=reference['fps']*subdivisions
(case/('skin-floor-measurement-120hz.json' if floor_only and subdivisions==4 else 'skin-floor-measurement.json' if floor_only else 'skin-contact-measurement.json')).write_text(json.dumps(report,indent=2)+'\n')
print('PACT_SKIN_MEASURED',len(rows),report['worst_distal_triangle_pairs'])

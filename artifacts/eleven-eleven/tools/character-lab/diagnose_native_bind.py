"""Read-only native bind/rest compatibility diagnosis for the rejected Wake take."""
import bpy, json, math, sys
from pathlib import Path
from mathutils import Vector

app=Path(__file__).resolve().parents[2]
case=app/'art/production/echo-school-rebuild-20261029/motions/wake'
bpy.ops.wm.open_mainfile(filepath=str(case/'source-inspection.blend'))
record=json.loads((case/'source-record.json').read_text())
diagnosis=json.loads((case/'diagnosis.json').read_text())
source=bpy.data.objects[record['candidate']['rig']]
target=next(o for o in bpy.data.objects if o.type=='ARMATURE' and o!=source)
yaw=math.radians(diagnosis['alignment_yaw_degrees'])
from mathutils import Quaternion
align=Quaternion((0,0,1),yaw)
rows={}
for side in ['left','right']:
    for limb in ['arm','forearm','upleg','leg']:
        role=side+limb
        mapping=diagnosis['mapping_and_local_axes'][role]
        sb=source.data.bones[mapping['source']]
        tb=target.data.bones[mapping['target']]
        sv=align @ (source.matrix_world.to_3x3() @ (sb.tail_local-sb.head_local))
        tv=target.matrix_world.to_3x3() @ (tb.tail_local-tb.head_local)
        rows[role]={'aligned_source_rest_direction':list(sv.normalized()),'target_rest_direction':list(tv.normalized()),'angle_degrees':math.degrees(sv.angle(tv))}
# Native joint motion is independently verified already; measure whether the
# source's head/hips actually turn from horizontal to vertical during the take.
frames=[]
for frame in [1,25,49,73]:
    bpy.context.scene.frame_set(frame)
    bpy.context.view_layer.update()
    points={role:(source.matrix_world @ source.pose.bones[name].matrix).translation for role,name in record['source_roles'].items()}
    torso=(points['head']-points['hips']).normalized()
    frames.append({'source_frame':frame,'head_minus_hips_direction':list(torso),'hips':list(points['hips'])})
result={'status':'MEASURED_REFERENCE_POSE_INCOMPATIBILITY','alignment_yaw_degrees':diagnosis['alignment_yaw_degrees'],'rest_limb_directions':rows,'native_torso_directions':frames,'source_unchanged':True,'decision':'Keep native source and failed bake isolated. Rest-delta numeric fidelity alone is insufficient for this legacy22 source; no runtime export.'}
(case/'reference-pose-diagnosis.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result))

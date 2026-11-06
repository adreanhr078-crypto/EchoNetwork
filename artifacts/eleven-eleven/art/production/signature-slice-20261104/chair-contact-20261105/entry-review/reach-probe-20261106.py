import bpy, json
from mathutils import Vector

rig = next(o for o in bpy.context.scene.objects if o.type == 'ARMATURE')
bones = {b.name.rsplit(':', 1)[-1]: b for b in rig.pose.bones}
target = Vector((.70, -.68, .085))
rows = []
for frame in [27, 32, 35, 38, 41, 44]:
    bpy.context.scene.frame_set(frame)
    bpy.context.view_layer.update()
    joint = lambda n: rig.matrix_world @ bones[n].head
    hip, knee, ankle = (joint(n) for n in ('RightUpLeg', 'RightLeg', 'RightFoot'))
    length = (knee - hip).length + (ankle - knee).length
    distance = (target - hip).length
    rows.append({'frame': frame, 'target_distance_m': distance, 'leg_length_m': length,
                 'geometric_excess_m': max(0, distance - length),
                 'actual_target_error_m': (target - ankle).length})
print('CHAIR_REACH_PROBE ' + json.dumps(rows))

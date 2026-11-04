"""Read-only bind compatibility and source record for a native Tripo take."""
import argparse
import hashlib
import json
import math
from pathlib import Path
import sys

import bpy
from mathutils import Quaternion, Vector

APP = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(APP/'tools/animation-library'))
from golden_reference import verify, guard_output
from retarget_contract import joint_map, planar_yaw

parser = argparse.ArgumentParser()
parser.add_argument('--case', type=Path, required=True)
parser.add_argument('--original-name', default='echo-school-wake-studio-20261102.glb')
parser.add_argument('--take-label', default='studio-wake-20261102')
args = parser.parse_args(sys.argv[sys.argv.index('--')+1:])
case = args.case.resolve(strict=True)
guard_output(case)
verify()
raw_path = case/'native-source/exact-native-source.json'
raw = json.loads(raw_path.read_text(encoding='utf-8'))
source_path = case/'source.glb'
sha = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()
assert sha(source_path) == raw['source_sha256']
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.scene.render.fps = raw['fps']
bpy.ops.import_scene.gltf(filepath=str(source_path))
source = next(obj for obj in bpy.context.scene.objects if obj.type == 'ARMATURE')
action = next(item for item in bpy.data.actions if item.name == raw['action'])
source.animation_data_create()
for track in source.animation_data.nla_tracks:
    track.mute = True
source.animation_data.action = action
if action.is_action_layered:
    assert len(action.slots) == 1
    source.animation_data.action_slot = action.slots[0]
source_name = source.name
before = set(bpy.context.scene.objects)
profile = json.loads((APP/'art/production/echo-school-rebuild-20261029/target-profile.json').read_text())
target_path = Path(profile['target_file'])
assert sha(target_path) == profile['target_sha256']
bpy.ops.import_scene.gltf(filepath=str(target_path))
target = next(obj for obj in bpy.context.scene.objects if obj not in before and obj.type == 'ARMATURE')
sm, tm = joint_map(source.data.bones.keys()), joint_map(target.data.bones.keys())
common = sorted(set(sm) & set(tm))
rest = lambda obj, mapping: {key: obj.matrix_world @ obj.data.bones[mapping[key]].matrix_local for key in common}
sr, tr = rest(source, sm), rest(target, tm)
forward = lambda rows: sum((rows[s+'toebase'].translation-rows[s+'foot'].translation for s in ['left', 'right']), Vector())
yaw = planar_yaw(forward(sr), forward(tr))
align = Quaternion((0, 0, 1), yaw)
limbs = {}
# Joint-to-child vectors describe anatomy; Blender's inferred leaf tails do not.
for side in ['left', 'right']:
    for first, last in [('arm', 'forearm'), ('forearm', 'hand'), ('upleg', 'leg'), ('leg', 'foot')]:
        role, child = side+first, side+last
        sv = align @ (sr[child].translation-sr[role].translation)
        tv = tr[child].translation-tr[role].translation
        limbs[role] = math.degrees(sv.angle(tv))
samples = []
for index in sorted({round((len(raw['frames'])-1)*i/8) for i in range(9)}):
    clock = raw['frames'][index]['time']*raw['fps']
    whole = int(clock+1e-5)
    bpy.context.scene.frame_set(whole, subframe=max(0, clock-whole))
    bpy.context.view_layer.update()
    points = {role: (source.matrix_world @ source.pose.bones[sm[role]].matrix).translation for role in ['hips', 'head', 'leftfoot', 'rightfoot', 'lefthand', 'righthand']}
    samples.append({'index': index, 'time': raw['frames'][index]['time'],
                    'torso_direction': list((points['head']-points['hips']).normalized()),
                    'points': {key: list(point) for key, point in points.items()}})
identity = sha(source_path)
record = {'candidate': {'take_id': identity[:24]+':'+args.take_label,
           'file_sha256': identity, 'source_take': action.name, 'rig': source_name,
           'original_filename': args.original_name, 'fps': raw['fps'],
           'source_frame_range': list(action.frame_range)},
          'entry': {'sha256': identity, 'working_copy': source_path.relative_to(APP).as_posix()},
          'raw_reference': str(raw_path), 'source_roles': sm,
          'scope': 'Original native clock and keys; source66 and target65 compared before frozen transfer'}
# Serialize actual rest matrices in a stable name order for rig identity.
matrices = {bone.name: [list(row) for row in bone.matrix_local] for bone in source.data.bones}
record['candidate']['rig_hash'] = hashlib.sha256(json.dumps(matrices, sort_keys=True).encode()).hexdigest()
(case/'source-record.json').write_text(json.dumps(record, indent=2)+'\n')
report = {'status': 'MEASURED_BIND_COMPATIBILITY', 'source_sha256': identity,
          'target_sha256': profile['target_sha256'], 'source_bones': len(source.data.bones),
          'target_bones': len(target.data.bones), 'common_roles': len(common),
          'aligned_rest_limb_angles_degrees': limbs, 'samples': samples,
          'source_keys_changed': False, 'visual_and_contact_acceptance': 'OPEN'}
(case/'bind-compatibility.json').write_text(json.dumps(report, indent=2)+'\n')
print(json.dumps({key: report[key] for key in ['source_bones', 'target_bones', 'common_roles', 'aligned_rest_limb_angles_degrees']}))
assert sha(source_path) == identity
verify()

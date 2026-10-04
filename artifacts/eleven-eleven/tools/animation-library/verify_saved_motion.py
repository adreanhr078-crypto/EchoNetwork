"""Read-only replay of an existing saved bake; never inserts keys or saves scenes."""
import argparse
import hashlib
import json
import math
from pathlib import Path
import sys

import bpy
from mathutils import Quaternion, Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
from golden_reference import APP, ROOT, guard_output, sha, verify
from native_timing import read_native_fps, validate_timing


def rotation_error(actual, expected):
    relative = actual.rotation_difference(expected).normalized()
    return math.degrees(2*math.atan2(math.sqrt(relative.x**2+relative.y**2+relative.z**2), abs(relative.w)))


def action_fingerprint(action):
    """Hash source and target keys before/after evaluation, including handles."""
    curves = []
    if action.is_action_layered:
        for layer in action.layers:
            for strip in layer.strips:
                for bag in strip.channelbags:
                    curves.extend((bag.slot_handle, curve) for curve in bag.fcurves)
    else:
        curves.extend((0, curve) for curve in action.fcurves)
    records = [{'slot': slot, 'path': curve.data_path, 'index': curve.array_index,
                'keys': [{'co': list(point.co), 'left': list(point.handle_left),
                          'right': list(point.handle_right), 'interpolation': point.interpolation}
                         for point in curve.keyframe_points]} for slot, curve in curves]
    records.sort(key=lambda record: (record['slot'], record['path'], record['index']))
    return {'sha256': hashlib.sha256(json.dumps(records, sort_keys=True).encode()).hexdigest(),
            'curves': len(records), 'key_count': sum(len(record['keys']) for record in records)}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--case', type=Path, required=True)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args(sys.argv[sys.argv.index('--')+1:])
    case = args.case.resolve()
    output = (args.output or case/'saved-replay.json').resolve()
    guard_output(case)
    if output.parent != case or output.name != 'saved-replay.json':
        raise ValueError('Replay writes only saved-replay.json in this isolated case')
    golden = verify()
    blend = case/'single-motion.blend'
    reference_path = case/'blender-reference.json'
    diagnosis_path = case/'diagnosis.json'
    visual_path = case/'blender-visual-review.json'
    reference = json.loads(reference_path.read_text(encoding='utf-8'))
    diagnosis = json.loads(diagnosis_path.read_text(encoding='utf-8'))
    visual = json.loads(visual_path.read_text(encoding='utf-8'))
    if reference['status'] != 'PASS' or visual['status'] != 'PASS':
        raise ValueError('Existing Blender acceptance gate failed')
    if reference['take_id'] == golden['take_id']:
        raise ValueError('This helper does not reopen the frozen Golden Walk')
    if reference['take_id'] != diagnosis['take_id'] or sha(blend) != visual['blend_sha256']:
        raise ValueError('Saved bake identity or visual gate is stale')
    candidates = json.loads((APP/'art/production/master-animation-library/manifests/CandidateReviews.json').read_text(encoding='utf-8'))['candidates']
    candidate = next(item for item in candidates if item['take_id'] == reference['take_id'])
    protected = {path: sha(Path(path)) for path in reference['hashes']}
    if protected != reference['hashes']:
        raise ValueError('Original source/target changed')
    protected.update({str(path): sha(path) for path in [blend, reference_path, diagnosis_path, visual_path]})
    source_paths = [Path(path) for path in reference['hashes'] if Path(path).suffix.lower() == '.fbx']
    if len(source_paths) != 1:
        raise ValueError('Expected exactly one original FBX')
    native = read_native_fps(source_paths[0])
    validate_timing(reference['fps'], candidate, *candidate['source_frame_range'], native)
    bpy.ops.wm.open_mainfile(filepath=str(blend))
    targets = [obj for obj in bpy.context.scene.objects if obj.type == 'ARMATURE' and obj.name != diagnosis['source_rig']
               and set(reference['target_bones'].values()).issubset(obj.data.bones.keys())]
    if len(targets) != 1:
        raise ValueError('Saved target rig is ambiguous')
    target = targets[0]
    source = bpy.data.objects.get(diagnosis['source_rig'])
    if source is None or source == target or source.type != 'ARMATURE':
        raise ValueError('Saved original source armature is missing')
    if not source.animation_data or not source.animation_data.action or source.animation_data.action.name != candidate['source_take']:
        raise ValueError('Saved original source action changed')
    if not target.animation_data or not target.animation_data.action or target.animation_data.action.name != reference['action']:
        raise ValueError('Saved target does not already use the expected baked action')
    scene_fps = bpy.context.scene.render.fps/bpy.context.scene.render.fps_base
    if scene_fps != reference['fps'] or len(reference['samples']) != int(candidate['source_frame_range'][1]):
        raise ValueError('Saved frame timing changed')
    if any(sample['time'] != index/reference['fps'] for index, sample in enumerate(reference['samples'])):
        raise ValueError('Stored sample timing differs from original bake')
    before = {name: action_fingerprint(obj.animation_data.action) for name, obj in [('source', source), ('target', target)]}
    max_position = 0.0
    max_rotation = 0.0
    per_bone = {role: {'position_m': 0.0, 'rotation_degrees': 0.0} for role in reference['target_bones']}
    for frame, sample in enumerate(reference['samples']):
        if set(sample['bones']) != set(reference['target_bones']):
            raise ValueError('Saved reference does not cover every mapped joint')
        bpy.context.scene.frame_set(frame)
        bpy.context.view_layer.update()
        for role, expected in sample['bones'].items():
            matrix = target.matrix_world @ target.pose.bones[reference['target_bones'][role]].matrix
            if not all(math.isfinite(value) for row in matrix for value in row):
                raise ValueError('Nonfinite saved pose')
            position = (matrix.translation-Vector(expected['position'])).length
            rotation = rotation_error(matrix.to_quaternion(), Quaternion(expected['quaternion_wxyz']))
            max_position = max(max_position, position)
            max_rotation = max(max_rotation, rotation)
            per_bone[role]['position_m'] = max(per_bone[role]['position_m'], position)
            per_bone[role]['rotation_degrees'] = max(per_bone[role]['rotation_degrees'], rotation)
    after = {name: action_fingerprint(obj.animation_data.action) for name, obj in [('source', source), ('target', target)]}
    if before != after:
        raise ValueError('Animation keys changed during read-only replay')
    if any(sha(Path(path)) != digest for path, digest in protected.items()):
        raise ValueError('Saved fixture or original asset bytes changed')
    verify()
    report = {'status': 'PASS' if max_position < .00001 and max_rotation < .05 else 'FAIL',
              'take_id': reference['take_id'], 'action': reference['action'], 'samples': len(reference['samples']),
              'joints': len(per_bone), 'max_position_error_m': max_position, 'max_rotation_error_degrees': max_rotation,
              'per_bone': per_bone, 'native_timing': native, 'action_keys_before': before, 'action_keys_after': after,
              'fixture_hashes_unchanged': protected, 'golden_protected_files': len(golden['protected_files']),
              'golden_manifest_sha256': sha(ROOT/'GoldenReference.json'), 'verifier_sha256': sha(Path(__file__)),
              'read_only': True, 'rebaked': False, 'source_key_edits': False, 'scene_saved': False,
              'scope': 'Existing saved target evaluated against original Blender reference; no animation import, key edits, bake, or scene save.'}
    output.write_text(json.dumps(report, indent=2)+'\n', encoding='utf-8')
    print('SAVED_MOTION_REPLAY '+json.dumps({key: report[key] for key in ['status', 'samples', 'joints', 'max_position_error_m', 'max_rotation_error_degrees', 'rebaked']}))
    if report['status'] != 'PASS':
        raise ValueError('Existing saved bake does not reproduce its accepted reference')


if __name__ == '__main__':
    main()

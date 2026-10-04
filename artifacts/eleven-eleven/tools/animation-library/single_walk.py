"""One existing take, one Echo: diagnose first, bake rest-space transforms only.

No IK, contact correction, transport fitting, smoothing, or authored keys.
"""
import argparse
import hashlib
import json
import math
import struct
from pathlib import Path
import sys

import bpy
from mathutils import Matrix, Quaternion, Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
from retarget_contract import joint_map, planar_yaw


def write(path, value):
    path.write_text(json.dumps(value, indent=2) + '\n', encoding='utf-8')


def angle(a, b):
    return math.degrees(a.rotation_difference(b).angle) % 360 if a.dot(b) >= 0 else math.degrees(a.rotation_difference(-b).angle)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--mode', choices=['inspect', 'bake', 'export'], required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:])
    if args.mode == 'export':
        report = json.loads((args.output/'blender-reference.json').read_text())
        visual = json.loads((args.output/'blender-visual-review.json').read_text())
        if report['status'] != 'PASS' or visual['status'] != 'PASS':
            raise ValueError('Numerical and visual Blender gates must precede export')
        if hashlib.sha256((args.output/'single-walk.blend').read_bytes()).hexdigest() != visual['blend_sha256']:
            raise ValueError('Visual gate is stale for this Blender bake')
        for path,digest in report['hashes'].items():
            if hashlib.sha256(Path(path).read_bytes()).hexdigest() != digest:
                raise ValueError('Input changed since diagnosis')
        bpy.ops.wm.open_mainfile(filepath=str(args.output/'single-walk.blend'))
        targets = [o for o in bpy.context.scene.objects if o.type == 'ARMATURE'
                   and set(report['target_bones'].values()).issubset(o.data.bones.keys())]
        if len(targets) != 1:
            raise ValueError('Baked target rig is ambiguous')
        target = targets[0]
        bpy.ops.object.select_all(action='DESELECT')
        target.select_set(True)
        for obj in bpy.context.scene.objects:
            if obj.type == 'MESH' and any(m.type == 'ARMATURE' and m.object == target for m in obj.modifiers):
                obj.select_set(True)
        bpy.context.view_layer.objects.active = target
        bpy.ops.export_scene.gltf(filepath=str(args.output/'single-walk.glb'),export_format='GLB',use_selection=True,
                                  export_animations=True,export_skins=True,export_yup=True,export_force_sampling=True,
                                  export_frame_range=True,export_frame_step=1,export_animation_mode='ACTIVE_ACTIONS',
                                  export_nla_strips_merged_animation_name=report['action'])
        payload = (args.output/'single-walk.glb').read_bytes()
        length = struct.unpack_from('<I',payload,12)[0]
        document = json.loads(payload[20:20+length])
        animations = document.get('animations',[])
        if len(animations) != 1 or animations[0].get('name') != report['action']:
            raise ValueError('Export must contain exactly the selected baked Walk')
        write(args.output/'export-check.json',{'status':'PASS','animation_names':[a['name'] for a in animations],
                                              'glb_sha256':hashlib.sha256(payload).hexdigest()})
        return
    app = Path(__file__).resolve().parents[2]
    manifests = app/'art/production/master-animation-library/manifests'
    candidates = json.loads((manifests/'CandidateReviews.json').read_text(encoding='utf-8'))['candidates']
    candidate = next(c for c in candidates if c['file_sha256'].startswith('d72ede82bef3'))
    inventory = json.loads((manifests/'SourceInventory.json').read_text(encoding='utf-8'))['files']
    entry = next(f for f in inventory if f['sha256'] == candidate['file_sha256'])
    source_path = app/entry['working_copy']
    target_path = app/'art/production/echo-master-character/prepared-v1/echo-master-review-lod.glb'
    hashes = {str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in [source_path,target_path]}
    if hashes[str(source_path)] != candidate['file_sha256']:
        raise ValueError('Source hash differs from inventory')
    args.output.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=str(source_path), use_anim=True)
    source = bpy.data.objects[candidate['rig']]
    action = bpy.data.actions[candidate['source_take']]
    source.animation_data.action = action
    fps = bpy.context.scene.render.fps/bpy.context.scene.render.fps_base
    before = set(bpy.context.scene.objects)
    bpy.ops.import_scene.gltf(filepath=str(target_path))
    target = next(o for o in bpy.context.scene.objects if o not in before and o.type == 'ARMATURE')
    sm, tm = joint_map(source.data.bones.keys()), joint_map(target.data.bones.keys())
    common = set(sm) & set(tm)
    required = {'hips','leftupleg','rightupleg','leftleg','rightleg','leftfoot','rightfoot','head'}
    if required-common:
        raise ValueError('Missing primary mapping')
    sw, tw = source.matrix_world.copy(), target.matrix_world.copy()
    for matrix in [sw,tw]:
        scale = matrix.to_scale()
        if min(scale) <= 0 or max(scale)-min(scale) > .000001 or matrix.to_3x3().determinant() <= 0:
            raise ValueError('Nonuniform/negative armature transform needs diagnosis first')
    sr = {k: sw @ source.data.bones[sm[k]].matrix_local for k in common}
    tr = {k: tw @ target.data.bones[tm[k]].matrix_local for k in common}
    forward = lambda rest: sum((rest[s+'toebase'].translation-rest[s+'foot'].translation for s in ['left','right']),Vector())
    yaw = planar_yaw(forward(sr), forward(tr))
    align = Quaternion((0,0,1), yaw)
    leg_length = lambda rest: sum((rest[s+'leg'].translation-rest[s+'upleg'].translation).length+(rest[s+'foot'].translation-rest[s+'leg'].translation).length for s in ['left','right'])/2
    ratio = leg_length(tr)/leg_length(sr)
    first,last = action.frame_range
    if fps != 30 or first != 1 or last != 37:
        raise ValueError('This bounded fixture expects the verified original 37 samples at 30 fps')
    poses = []
    for frame in range(1,38):
        bpy.context.scene.frame_set(frame)
        bpy.context.view_layer.update()
        poses.append({k:source.matrix_world @ source.pose.bones[sm[k]].matrix for k in common})
    # Read-only measurements precede any new bake.
    axes = {}
    raw_errors = {k:0.0 for k in required}
    for k in sorted(common):
        sb, tb = source.data.bones[sm[k]], target.data.bones[tm[k]]
        sl = sb.parent.matrix_local.inverted() @ sb.matrix_local if sb.parent else sb.matrix_local
        tl = tb.parent.matrix_local.inverted() @ tb.matrix_local if tb.parent else tb.matrix_local
        axes[k] = {'source':sm[k], 'target':tm[k], 'source_parent':sb.parent.name if sb.parent else None,
                   'target_parent':tb.parent.name if tb.parent else None,
                   'source_rest_local':[list(row) for row in sl], 'target_rest_local':[list(row) for row in tl],
                   'local_rest_rotation_difference_degrees':angle(sl.to_quaternion(),tl.to_quaternion())}
    for frame,pose in enumerate(poses,1):
        bpy.context.scene.frame_set(frame)
        for bone in target.data.bones:
            pb = target.pose.bones[bone.name]
            key = next((k for k in common if tm[k] == bone.name), None)
            pb.matrix_basis = source.pose.bones[sm[key]].matrix_basis.copy() if key else Matrix.Identity(4)
        bpy.context.view_layer.update()
        for k in required:
            expected = align @ (pose[k].to_quaternion() @ sr[k].to_quaternion().inverted()) @ align.inverted() @ tr[k].to_quaternion()
            raw_errors[k] = max(raw_errors[k],angle(expected,(tw @ target.pose.bones[tm[k]].matrix).to_quaternion()))
    for pb in target.pose.bones:
        pb.matrix_basis = Matrix.Identity(4)
    bpy.context.view_layer.update()
    transforms = {name:{'matrix_world':[list(row) for row in obj.matrix_world], 'scale':list(obj.matrix_world.to_scale()),
                        'determinant':obj.matrix_world.to_3x3().determinant()} for name,obj in [('source',source),('target',target)]}
    source_metrics = {'samples':37, 'fps':fps, 'duration_seconds':1.2,
                      'finite':all(math.isfinite(v) for p in poses for m in p.values() for row in m for v in row),
                      'hips_displacement_m':list(poses[-1]['hips'].translation-poses[0]['hips'].translation),
                      'upper_leg_rotation_excursion_degrees':{s: max(angle(poses[0][s+'upleg'].to_quaternion(),p[s+'upleg'].to_quaternion()) for p in poses) for s in ['left','right']}}
    diagnosis = {'fixture':'MOB1_Walk_F + Echo review LOD', 'hashes':hashes,'source_metrics':source_metrics,
                 'armature_transforms':transforms,'mapping_and_local_axes':axes,'alignment_yaw_degrees':math.degrees(yaw),
                 'leg_length_ratio':ratio,'raw_basis_copy_max_global_rotation_error_degrees':raw_errors,
                 'root_cause':'Changing track names or copying local bone rotations between different rest bases is not retargeting. The runtime bridge copies key values unchanged. The earlier review solver additionally replaces full limb rotation with direction-only aiming/IK and adds sole corrections, so it cannot prove faithful source transfer.',
                 'repair_contract':'Transfer the full source world-space rotation delta relative to source rest, conjugate by yaw, apply to target rest. Resolve parent-first target local basis; keep target rest limb offsets. Scale original Hips translation once. No IK, sole edits, fitted root, blending or manual keys.',
                 'godot_cause':'Not presumed. Compare every baked joint transform at all 37 times before editing Godot.'}
    if args.mode == 'inspect':
        write(args.output/'diagnosis.json',diagnosis)
        bpy.ops.wm.save_as_mainfile(filepath=str(args.output/'source-inspection.blend'))
        print('SINGLE_WALK_DIAGNOSED '+json.dumps(source_metrics))
        return
    prior = json.loads((args.output/'diagnosis.json').read_text())
    if prior['hashes'] != hashes or prior['repair_contract'] != diagnosis['repair_contract']:
        raise ValueError('Diagnosis must precede bake for these exact inputs')
    target.animation_data_create()
    baked = bpy.data.actions.new('Walk_Source_Retarget')
    target.animation_data.action = baked
    if baked.is_action_layered:
        target.animation_data.action_slot = baked.slots.new('OBJECT',target.name)
    measurements = []
    max_rotation_error = 0.0
    max_length_error = 0.0
    for i,pose in enumerate(poses):
        bpy.context.scene.frame_set(i+1)
        # Reset each frame; no dependency on prior pose or evaluation order.
        for pb in target.pose.bones:
            pb.matrix_basis = Matrix.Identity(4)
        bpy.context.view_layer.update()
        for bone in target.data.bones:
            k = next((k for k in common if tm[k] == bone.name),None)
            if not k:
                continue
            pb = target.pose.bones[bone.name]
            rotation = align @ (pose[k].to_quaternion() @ sr[k].to_quaternion().inverted()) @ align.inverted() @ tr[k].to_quaternion()
            if k == 'hips':
                position = tr[k].translation + (align @ (pose[k].translation-sr[k].translation))*ratio
            elif bone.parent:
                position = (tw @ target.pose.bones[bone.parent.name].matrix @ bone.parent.matrix_local.inverted() @ bone.matrix_local).translation
            else:
                position = tr[k].translation
            desired = Matrix.Translation(position) @ rotation.to_matrix().to_4x4() @ Matrix.Diagonal((*tw.to_scale(),1))
            pb.matrix = tw.inverted() @ desired
            bpy.context.view_layer.update()
            max_rotation_error = max(max_rotation_error,angle(rotation,(tw @ pb.matrix).to_quaternion()))
            if bone.parent and k != 'hips':
                actual_length = (pb.matrix.translation-target.pose.bones[bone.parent.name].matrix.translation).length
                rest_length = (bone.matrix_local.translation-bone.parent.matrix_local.translation).length
                max_length_error = max(max_length_error,abs(actual_length-rest_length))
            pb.rotation_mode = 'QUATERNION'
            pb.keyframe_insert(data_path='rotation_quaternion',frame=i,group=bone.name)
            if k == 'hips':
                pb.keyframe_insert(data_path='location',frame=i,group=bone.name)
        measurements.append({'time':i/30,'bones':{k:{'position':list((tw @ target.pose.bones[tm[k]].matrix).translation),
                                                      'quaternion_wxyz':list((tw @ target.pose.bones[tm[k]].matrix).to_quaternion())} for k in common}})
    # Evaluate the completed action afresh, not just assigned matrices.
    replay_error = 0.0
    replay_rotation_error = 0.0
    for i,sample in enumerate(measurements):
        bpy.context.scene.frame_set(i)
        bpy.context.view_layer.update()
        for k,expected in sample['bones'].items():
            actual = tw @ target.pose.bones[tm[k]].matrix
            replay_error = max(replay_error,(actual.translation-Vector(expected['position'])).length)
            replay_rotation_error = max(replay_rotation_error,angle(actual.to_quaternion(),Quaternion(expected['quaternion_wxyz'])))
    bpy.context.scene.render.fps = 30
    bpy.context.scene.frame_start = 0
    bpy.context.scene.frame_end = 36
    report = {'action':baked.name,'duration':1.2,'fps':30,'samples':measurements,'target_bones':tm,
              'max_blender_rotation_error_degrees':max_rotation_error,'max_blender_length_error_m':max_length_error,
              'max_blender_baked_replay_position_error_m':replay_error,'hashes':hashes,
              'max_blender_baked_replay_rotation_error_degrees':replay_rotation_error,
              'status':'PASS' if max_rotation_error < .05 and max_length_error < .00001 and replay_error < .00001 and replay_rotation_error < .05 else 'FAIL',
              'limits':'Numerical fidelity; visual/source skin review required. No artistic perfection or contact compensation claimed.'}
    write(args.output/'blender-reference.json',report)
    if report['status'] != 'PASS':
        raise ValueError('Blender gate failed; do not export')
    bpy.ops.wm.save_as_mainfile(filepath=str(args.output/'single-walk.blend'))
    for path,digest in hashes.items():
        if hashlib.sha256(Path(path).read_bytes()).hexdigest() != digest:
            raise ValueError('Input changed')
    print('SINGLE_WALK_BLENDER '+json.dumps({k:v for k,v in report.items() if k not in ['samples','target_bones','hashes']}))


if __name__ == '__main__':
    main()

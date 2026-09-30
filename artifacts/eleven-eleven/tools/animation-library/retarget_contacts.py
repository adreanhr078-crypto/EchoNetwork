"""Bake existing mocap to Echo, with fixed limb lengths and source foot targets.

Review derivatives only. This does not generate motion or grant approval. The
source's whole take is sampled; its translation curve stays in the sidecar.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import sys

import bpy
import numpy as np
from mathutils import Matrix, Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
from bone_roles import normalize

CHILD = {"spine": "spine1", "spine1": "spine2", "spine2": "neck", "neck": "head"}
for side in ("left", "right"):
    CHILD.update({side+"shoulder": side+"arm", side+"arm": side+"forearm",
                  side+"forearm": side+"hand", side+"foot": side+"toebase"})


def two_bone(hip, ankle, pole, upper, lower):
    line = ankle - hip
    distance = line.length
    if distance < 1e-6:
        raise ValueError("Degenerate hip/ankle target")
    axis = line.normalized()
    bend = pole - hip
    bend -= axis * bend.dot(axis)
    if bend.length < 1e-5:
        bend = Vector((0, 1, 0)) - axis * axis.y
    if bend.length < 1e-5:
        bend = Vector((1, 0, 0)) - axis * axis.x
    bend.normalize()
    safe = min(max(distance, abs(upper-lower) + 1e-5), upper+lower - 1e-5)
    along = (upper*upper - lower*lower + safe*safe) / (2*safe)
    knee = hip + axis*along + bend*math.sqrt(max(0, upper*upper-along*along))
    endpoint = hip + axis*safe
    return knee, endpoint, abs(safe-distance)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--target", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--action", required=True)
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:])
    preserved = {str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in (args.source, args.target)}
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=str(args.source.resolve()), use_anim=True)
    source = next(o for o in bpy.context.scene.objects if o.type == "ARMATURE")
    action = source.animation_data.action
    if action is None:
        raise ValueError("Missing source take")
    source_fps = bpy.context.scene.render.fps / bpy.context.scene.render.fps_base
    before = set(bpy.context.scene.objects)
    bpy.ops.import_scene.gltf(filepath=str(args.target.resolve()))
    target = next(o for o in bpy.context.scene.objects if o.type == "ARMATURE" and o not in before)
    src_names = {normalize(b.name): b.name for b in source.data.bones}
    dst_names = {normalize(b.name): b.name for b in target.data.bones}
    common = set(src_names) & set(dst_names)
    needed = {"hips", "head"} | {s+j for s in ("left", "right") for j in ("upleg", "leg", "foot", "toebase")}
    if needed - common:
        raise ValueError(f"Missing mapped primary joints: {needed-common}")
    sw, tw = source.matrix_world.copy(), target.matrix_world.copy()
    sr = {k: sw @ source.data.bones[v].matrix_local for k, v in src_names.items()}
    tr = {k: tw @ target.data.bones[v].matrix_local for k, v in dst_names.items()}
    src_forward = sum((sr[s+"toebase"].translation-sr[s+"foot"].translation for s in ("left", "right")), Vector())
    dst_forward = sum((tr[s+"toebase"].translation-tr[s+"foot"].translation for s in ("left", "right")), Vector())
    src_forward.z = dst_forward.z = 0
    alignment = src_forward.rotation_difference(dst_forward)
    src_length = sum((sr[s+"upleg"].translation-sr[s+"leg"].translation).length +
                     (sr[s+"leg"].translation-sr[s+"foot"].translation).length for s in ("left", "right"))/2
    dst_length = sum((tr[s+"upleg"].translation-tr[s+"leg"].translation).length +
                     (tr[s+"leg"].translation-tr[s+"foot"].translation).length for s in ("left", "right"))/2
    ratio = dst_length/src_length
    first, last = map(float, action.frame_range)
    duration = (last-first)/source_fps
    count = max(2, round(duration*30)+1)
    times = np.linspace(0, duration, count)
    sampled = []
    for t in times:
        frame = first+t*source_fps
        bpy.context.scene.frame_set(math.floor(frame), subframe=frame % 1)
        bpy.context.view_layer.update()
        sampled.append({k: sw @ source.pose.bones[v].matrix for k, v in src_names.items() if k in common})
    source_ground = float(np.quantile([p[s+"toebase"].translation.z for p in sampled for s in ("left", "right")], .02))
    translation = [alignment @ (p["hips"].translation-sampled[0]["hips"].translation)*ratio for p in sampled]
    displacement = translation[-1].copy(); displacement.z = 0
    # In-place mocap has no translating root. Fit transport only to near-ground
    # stance samples and retain the source residual for review, never as approval.
    velocity = displacement/max(duration, .001)
    root_mode = "source_translation"
    if displacement.length < .03:
        stance_velocities = []
        for side in ("left", "right"):
            for i in range(count-1):
                a, b = sampled[i][side+"toebase"].translation, sampled[i+1][side+"toebase"].translation
                if max(a.z, b.z) < source_ground+.045:
                    v = alignment @ (b-a)*ratio/float(times[i+1]-times[i]); v.z = 0
                    stance_velocities.append(tuple(-v))
        if not stance_velocities:
            raise ValueError("In-place clip has no transport/contact evidence")
        velocity = Vector(np.median(stance_velocities, axis=0))
        root_mode = "fitted_in_place_transport_needs_review"
    if target.animation_data:
        target.animation_data_clear()
    contact_flags = []
    for i, pose in enumerate(sampled):
        flags = {}
        a, b = max(0, i-1), min(count-1, i+1)
        for side in ("left", "right"):
            motion = alignment @ (sampled[b][side+"toebase"].translation-sampled[a][side+"toebase"].translation)*ratio/float(times[b]-times[a])
            if root_mode.startswith("fitted"):
                motion += velocity
            # Height alone mistakes low, fast swing toes for planted feet.
            flags[side] = pose[side+"toebase"].translation.z < source_ground+.025 and Vector((motion.x,motion.y,0)).length < .25
        contact_flags.append(flags)
    target.animation_data_create()
    baked = bpy.data.actions.new(args.action)
    target.animation_data.action = baked
    if baked.is_action_layered and not target.animation_data.action_slot:
        target.animation_data.action_slot = baked.slots.new('OBJECT', target.name)
    errors, target_positions, source_contacts, root_curve = [], [], [], []
    def set_pose(key, position, rotation):
        pb = target.pose.bones[dst_names[key]]
        pb.matrix = tw.inverted() @ (Matrix.Translation(position) @ rotation.to_matrix().to_4x4() @
                                    Matrix.Diagonal((*tw.to_scale(), 1)))
        bpy.context.view_layer.update()
    def aim(key, direction):
        bone = target.data.bones[dst_names[key]]
        parent = target.pose.bones[bone.parent.name] if bone.parent else None
        rest = tr[key]
        position = (tw @ parent.matrix @ bone.parent.matrix_local.inverted() @ bone.matrix_local).translation if parent else rest.translation
        # glTF has joint pivots, not Blender bone tails. Imported display tails
        # can point elsewhere; only the next semantic joint defines the limb.
        child_key = key.removesuffix("upleg")+"leg" if key.endswith("upleg") else key.removesuffix("leg")+"foot"
        rest_direction = tr[child_key].translation-rest.translation
        rotation = rest_direction.rotation_difference(direction) @ rest.to_quaternion()
        set_pose(key, position, rotation)
    for i, (t, pose) in enumerate(zip(times, sampled)):
        transport = velocity*float(t)
        hips = tr["hips"].translation + alignment @ (pose["hips"].translation-sr["hips"].translation)*ratio
        hips.x -= transport.x; hips.y -= transport.y
        ankle_targets = {}
        foot_rotations = {}
        for side in ("left", "right"):
            foot, toe = side+"foot", side+"toebase"
            toe_goal = tr["hips"].translation + alignment @ (pose[toe].translation-sr["hips"].translation)*ratio - transport
            toe_goal.z = tr[toe].translation.z + (pose[toe].translation.z-source_ground)*ratio
            rest_vector = tr[toe].translation-tr[foot].translation
            # Different rigs have different ankle-to-toe slopes in rest. Copy
            # the source's *change* of foot orientation, not its absolute slope;
            # the latter tilts Echo's neutral shoe into a permanent tiptoe pose.
            foot_delta = alignment @ (pose[foot].to_quaternion() @ sr[foot].to_quaternion().inverted()) @ alignment.inverted()
            rotation = foot_delta @ tr[foot].to_quaternion()
            ankle_targets[side] = toe_goal - (foot_delta @ rest_vector)
            foot_rotations[side] = rotation
        # One pelvis correction for both legs; unreachable targets remain measured.
        for _ in range(3):
            correction = 0.0
            for side in ("left", "right"):
                offset = tr[side+"upleg"].translation-tr["hips"].translation
                a = (tr[side+"leg"].translation-tr[side+"upleg"].translation).length
                b = (tr[side+"foot"].translation-tr[side+"leg"].translation).length
                delta = hips+offset-ankle_targets[side]
                horizontal = delta.x*delta.x+delta.y*delta.y
                reachable_height = math.sqrt(max(0, (a+b-.002)**2-horizontal))
                correction = max(correction, delta.z-reachable_height)
            hips.z -= max(0, correction)
        for bone in target.data.bones:
            key = normalize(bone.name)
            if key not in common or any(key == side+j for side in ("left", "right") for j in ("upleg", "leg", "foot", "toebase")):
                continue
            delta = alignment @ (pose[key].to_quaternion() @ sr[key].to_quaternion().inverted()) @ alignment.inverted()
            rotation = delta @ tr[key].to_quaternion()
            if key == "hips":
                position = hips
            elif bone.parent:
                position = (tw @ target.pose.bones[bone.parent.name].matrix @ bone.parent.matrix_local.inverted() @ bone.matrix_local).translation
            else:
                position = tr[key].translation
            if key in CHILD and CHILD[key] in common:
                rest_dir = tr[CHILD[key]].translation-tr[key].translation
                direction = alignment @ (pose[CHILD[key]].translation-pose[key].translation)
                rotation = rest_dir.rotation_difference(direction) @ tr[key].to_quaternion()
            set_pose(key, position, rotation)
        contacts, coordinates = {}, {}
        for side in ("left", "right"):
            upper, lower, foot, toe = (side+j for j in ("upleg", "leg", "foot", "toebase"))
            bone = target.data.bones[dst_names[upper]]
            hip = (tw @ target.pose.bones[bone.parent.name].matrix @ bone.parent.matrix_local.inverted() @ bone.matrix_local).translation
            a = (tr[lower].translation-tr[upper].translation).length
            b = (tr[foot].translation-tr[lower].translation).length
            pole = hip + alignment @ (pose[lower].translation-pose[upper].translation)*ratio
            knee, ankle, error = two_bone(hip, ankle_targets[side], pole, a, b)
            aim(upper, knee-hip); aim(lower, ankle-knee)
            current_ankle = (tw @ target.pose.bones[dst_names[foot]].matrix).translation
            set_pose(foot, current_ankle, foot_rotations[side])
            # Neutral toe local rotation follows the foot; source toe twist is not
            # invented for a rig without an independently mapped toe tip.
            target.pose.bones[dst_names[toe]].matrix_basis = Matrix.Identity(4)
            bpy.context.view_layer.update()
            contacts[side] = contact_flags[i][side]
            coordinates[side] = list((tw @ target.pose.bones[dst_names[toe]].matrix).translation + transport)
            errors.append(error)
        for key in common:
            pb = target.pose.bones[dst_names[key]]
            pb.rotation_mode = "QUATERNION"
            pb.keyframe_insert(data_path="rotation_quaternion", frame=i, group=pb.name)
            if key == "hips":
                pb.keyframe_insert(data_path="location", frame=i, group=pb.name)
        target_positions.append({"time":float(t), **coordinates})
        source_contacts.append(contacts)
        root_curve.append([float(t), *list(transport)])
    bpy.context.scene.render.fps = 30
    bpy.context.scene.frame_start = 0; bpy.context.scene.frame_end = count-1
    for obj in list(bpy.context.scene.objects):
        if obj == source or (obj.type == "MESH" and any(m.type == "ARMATURE" and m.object == source for m in obj.modifiers)):
            bpy.data.objects.remove(obj, do_unlink=True)
    bpy.data.actions.remove(action, do_unlink=True)
    bpy.ops.object.select_all(action="DESELECT"); target.select_set(True)
    for obj in bpy.context.scene.objects:
        if obj.type == "MESH" and any(m.type == "ARMATURE" and m.object == target for m in obj.modifiers): obj.select_set(True)
    bpy.context.view_layer.objects.active = target
    args.output.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(args.output.resolve()), export_format="GLB", use_selection=True,
                               export_animations=True, export_skins=True, export_yup=True)
    intervals = {}
    for side in ("left", "right"):
        intervals[side] = []
        engaged = []
        for i, contact in enumerate(source_contacts):
            if contact[side]: engaged.append(i)
            if engaged and (not contact[side] or i == count-1):
                xyz = np.array([target_positions[j][side] for j in engaged])
                drift = float(np.max(np.linalg.norm(xyz[:,:2]-xyz[0,:2],axis=1)))
                intervals[side].append({"start":float(times[engaged[0]]),"end":float(times[engaged[-1]]),"world_drift_m":drift})
                engaged = []
    summary = {"profile":"echo_source_contacts_v1_review","action":args.action,"status":"requires_visual_comparison",
               "source_file":args.source.name,"source_sha256":preserved[str(args.source)],"target_sha256":preserved[str(args.target)],
               "source_fps":source_fps,"baked_fps":30,"duration_seconds":duration,"baked_duration_seconds":(count-1)/30,"samples":count,"scale_ratio":ratio,
               "root_mode":root_mode,"transport_speed_mps":velocity.length,"root_curve_blender_z_up":root_curve,
               "max_unreachable_error_m":max(errors),"contact_intervals":intervals,"positions":target_positions}
    args.output.with_suffix('.json').write_text(json.dumps(summary,indent=2)+'\n',encoding='utf-8')
    for p, digest in preserved.items():
        if hashlib.sha256(Path(p).read_bytes()).hexdigest() != digest: raise ValueError("Source changed")
    print("CONTACT_RETARGET " + json.dumps({k:v for k,v in summary.items() if k not in ('root_curve_blender_z_up','positions')}), flush=True)


if __name__ == "__main__":
    main()

"""Rest-aware humanoid retarget pilot. Derived review output only; originals stay untouched."""
import argparse
import json
import math
from pathlib import Path
import sys

import bpy
from mathutils import Matrix, Vector

CHAIN_CHILD = {
    "Spine":"Spine1", "Spine1":"Spine2", "Spine2":"Neck", "Neck":"Head",
    "LeftShoulder":"LeftArm", "LeftArm":"LeftForeArm", "LeftForeArm":"LeftHand",
    "RightShoulder":"RightArm", "RightArm":"RightForeArm", "RightForeArm":"RightHand",
    "LeftUpLeg":"LeftLeg", "LeftLeg":"LeftFoot", "LeftFoot":"LeftToeBase",
    "RightUpLeg":"RightLeg", "RightLeg":"RightFoot", "RightFoot":"RightToeBase",
}


def parsed():
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--target", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--action", required=True)
    parser.add_argument("--max-seconds", type=float, default=3)
    return parser.parse_args(sys.argv[sys.argv.index("--") + 1:])


def armature_from_new_objects(before):
    rigs = [obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE" and obj.name not in before]
    if len(rigs) != 1:
        raise ValueError(f"Expected one armature, got {[obj.name for obj in rigs]}")
    return rigs[0]


def main():
    args = parsed()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    before = set()
    bpy.ops.import_scene.fbx(filepath=str(args.source.resolve()), use_anim=True)
    source = armature_from_new_objects(before)
    source_action = source.animation_data.action if source.animation_data else None
    if source_action is None:
        raise ValueError("FBX has no active animation")
    source.name = "SourceReviewOnly"
    bpy.context.view_layer.update()
    before = {obj.name for obj in bpy.context.scene.objects}
    bpy.ops.import_scene.gltf(filepath=str(args.target.resolve()))
    target = armature_from_new_objects(before)
    # GLB import may contain importer idle action. Replace it, never transfer raw local quaternions.
    if target.animation_data:
        target.animation_data_clear()
    target.rotation_mode = "QUATERNION"
    source_names = {bone.name.split(":")[-1]: bone.name for bone in source.data.bones}
    target_names = {bone.name.split(":")[-1]: bone.name for bone in target.data.bones}
    common = [short for short in target_names if short in source_names]
    for role in ("Hips", "Head", "LeftUpLeg", "LeftLeg", "LeftFoot", "RightUpLeg", "RightLeg", "RightFoot"):
        if role not in common:
            raise ValueError(f"Missing critical retarget role: {role}")
    scene = bpy.context.scene
    source_fps = scene.render.fps / scene.render.fps_base
    scene.render.fps = 30
    first, last = source_action.frame_range
    duration = min(args.max_seconds, (last-first)/source_fps)
    samples = max(2, round(duration * 30) + 1)
    target.animation_data_create()
    action = bpy.data.actions.new(args.action)
    target.animation_data.action = action
    if action.is_action_layered and not target.animation_data.action_slot:
        slot = action.slots.new('OBJECT', target.name)
        target.animation_data.action_slot = slot
    source_hip = source_names["Hips"]
    target_hip = target_names["Hips"]
    src_rest_hip = (source.matrix_world @ source.data.bones[source_hip].matrix_local).translation
    tgt_rest_hip = (target.matrix_world @ target.data.bones[target_hip].matrix_local).translation
    unit_ratio = tgt_rest_hip.z / max(0.01, src_rest_hip.z)
    target_root_world = target.matrix_world.copy()
    source_root_world = source.matrix_world.copy()
    # Match the two rigs' horizontal forward axes before comparing world-space limb directions.
    source_forward = sum(((source_root_world @ source.data.bones[source_names[s+"ToeBase"]].head_local) -
                          (source_root_world @ source.data.bones[source_names[s+"Foot"]].head_local)
                          for s in ("Left", "Right")), Vector())
    target_forward = sum(((target_root_world @ target.data.bones[target_names[s+"ToeBase"]].head_local) -
                          (target_root_world @ target.data.bones[target_names[s+"Foot"]].head_local)
                          for s in ("Left", "Right")), Vector())
    source_forward.z = target_forward.z = 0
    yaw_alignment = source_forward.rotation_difference(target_forward)
    for j in range(samples):
        src_frame = first + j * source_fps / 30
        scene.frame_set(int(src_frame), subframe=src_frame % 1)
        bpy.context.view_layer.update()
        out_frame = j + 1
        # Parent-first, because pose.matrix assignment resolves against parent pose.
        for bone in target.data.bones:
            short = bone.name.split(":")[-1]
            if short not in common:
                continue
            src_bone = source.data.bones[source_names[short]]
            src_pose = source.pose.bones[src_bone.name]
            dst_pose = target.pose.bones[bone.name]
            src_rest_world = source_root_world @ src_bone.matrix_local
            src_pose_world = source_root_world @ src_pose.matrix
            dst_rest_world = target_root_world @ bone.matrix_local
            delta = src_pose_world.to_quaternion() @ src_rest_world.to_quaternion().inverted()
            dst_rotation_world = delta @ dst_rest_world.to_quaternion()
            chain_child = CHAIN_CHILD.get(short)
            if chain_child in common:
                src_child_pose = source_root_world @ source.pose.bones[source_names[chain_child]].matrix
                src_direction = yaw_alignment @ (src_child_pose.translation - src_pose_world.translation)
                dst_rest_child = target_root_world @ target.data.bones[target_names[chain_child]].matrix_local
                dst_rest_direction = dst_rest_child.translation - dst_rest_world.translation
                if src_direction.length > 0.001 and dst_rest_direction.length > 0.001:
                    dst_rotation_world = (dst_rest_direction.rotation_difference(src_direction) @
                                          dst_rest_world.to_quaternion())
            elif short in ("LeftHand", "RightHand"):
                # This Tripo rig has no finger chain. Preserve its neutral palm and
                # follow the solved forearm to avoid FBX wrist-axis flips.
                parent = target.pose.bones[bone.parent.name]
                parent_rest = target_root_world @ bone.parent.matrix_local
                parent_world = target_root_world @ parent.matrix
                dst_rotation_world = (parent_world.to_quaternion() @
                                      parent_rest.to_quaternion().inverted() @
                                      dst_rest_world.to_quaternion())
            if bone.name == target_hip:
                movement = src_pose_world.translation - src_rest_world.translation
                # For gameplay capsules, horizontal movement is tracked separately.
                movement.x = movement.y = 0
                position_world = dst_rest_world.translation + movement * unit_ratio
            elif bone.parent:
                parent_pose = target.pose.bones[bone.parent.name]
                position_local = (parent_pose.matrix @ bone.parent.matrix_local.inverted() @ bone.matrix_local).translation
                position_world = target_root_world @ position_local
            else:
                position_world = dst_rest_world.translation
            local_position = target_root_world.inverted() @ position_world
            local_rotation = target_root_world.to_quaternion().inverted() @ dst_rotation_world
            dst_pose.matrix = Matrix.Translation(local_position) @ local_rotation.to_matrix().to_4x4()
            dst_pose.rotation_mode = "QUATERNION"
            dst_pose.keyframe_insert(data_path="rotation_quaternion", frame=out_frame, group=bone.name)
            if bone.name == target_hip:
                dst_pose.keyframe_insert(data_path="location", frame=out_frame, group=bone.name)
            bpy.context.view_layer.update()
    # Export only the target armature and its skinned mesh.
    bpy.ops.object.select_all(action="DESELECT")
    source.animation_data_clear()
    bpy.data.objects.remove(source, do_unlink=True)
    bpy.data.actions.remove(source_action, do_unlink=True)
    target.select_set(True)
    for obj in bpy.context.scene.objects:
        if obj.type == "MESH" and any(mod.type == "ARMATURE" and mod.object == target for mod in obj.modifiers):
            obj.select_set(True)
    bpy.context.view_layer.objects.active = target
    args.output.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(args.output.resolve()), export_format="GLB", use_selection=True,
                               export_animations=True, export_skins=True, export_yup=True)
    print("RETARGET_PILOT " + json.dumps({"source":args.source.name,"action":args.action,"frames":samples,
                                       "mapped_bones":len(common),"source_fps":source_fps,
                                       "output":str(args.output.resolve())}), flush=True)


if __name__ == "__main__":
    main()

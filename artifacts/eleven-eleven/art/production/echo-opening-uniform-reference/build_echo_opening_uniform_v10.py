import bpy
import math
from pathlib import Path
from mathutils import Matrix


ROOT = Path(r"C:\Users\yasmo\EchoNetwork\artifacts\eleven-eleven")
SOURCE = ROOT / "art/production/echo-opening-uniform-reference/echo-opening-uniform-v9.blend"
BLEND = ROOT / "art/production/echo-opening-uniform-reference/echo-opening-uniform-v10.blend"
GLB = ROOT / "godot/assets/characters/echo_opening_uniform_v10.glb"
HOLD_FRAMES = 7
RISE_END_FRAME = 55
END_FRAME = 73


bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
scene = bpy.context.scene
scene.render.fps = 24
rig = bpy.data.objects["EchoOpeningUniformRig"]
armature = rig.data
animation_data = rig.animation_data
bones = [bone.name for bone in armature.bones]

for track in animation_data.nla_tracks:
    track.mute = True


def set_action(action):
    animation_data.action = action
    animation_data.action_slot = action.slots[0] if action and action.slots else None


def pose_matrix_in_local_space(pose_bone):
    kwargs = {}
    if pose_bone.parent:
        kwargs["parent_matrix"] = pose_bone.parent.matrix.copy()
        kwargs["parent_matrix_local"] = pose_bone.parent.bone.matrix_local.copy()
    return pose_bone.bone.convert_local_to_pose(
        pose_bone.matrix.copy(),
        pose_bone.bone.matrix_local.copy(),
        invert=True,
        **kwargs,
    )


def sample_pose(action, frame):
    set_action(action)
    whole_frame = math.floor(frame)
    scene.frame_set(whole_frame, subframe=frame - whole_frame)
    bpy.context.view_layer.update()
    return {name: pose_matrix_in_local_space(rig.pose.bones[name]).copy() for name in bones}


def decompose_pose(matrices):
    return {name: matrix.decompose() for name, matrix in matrices.items()}


fall = bpy.data.actions["preset:fall"]
idle = bpy.data.actions["preset:idle"]
fall_range = fall.frame_range
if int(fall_range[1] - fall_range[0]) != 72:
    raise RuntimeError(f"Unexpected fall clip range: {fall_range}")

prone_pose = decompose_pose(sample_pose(fall, fall_range[1]))
standing_pose = decompose_pose(sample_pose(fall, fall_range[0]))
idle_pose = decompose_pose(sample_pose(idle, idle.frame_range[0]))

poses = []
for frame in range(1, END_FRAME + 1):
    if frame <= HOLD_FRAMES:
        pose = prone_pose
    elif frame <= RISE_END_FRAME:
        phase = (frame - HOLD_FRAMES) / float(RISE_END_FRAME - HOLD_FRAMES)
        eased = phase * phase * (3.0 - 2.0 * phase)
        fall_frame = fall_range[1] - eased * (fall_range[1] - fall_range[0])
        pose = decompose_pose(sample_pose(fall, fall_frame))
    else:
        phase = (frame - RISE_END_FRAME) / float(END_FRAME - RISE_END_FRAME)
        pose = {}
        for name in bones:
            start_location, start_rotation, start_scale = standing_pose[name]
            end_location, end_rotation, end_scale = idle_pose[name]
            if start_rotation.dot(end_rotation) < 0.0:
                end_rotation = -end_rotation
            pose[name] = (
                start_location.lerp(end_location, phase),
                start_rotation.slerp(end_rotation, phase),
                start_scale.lerp(end_scale, phase),
            )
    poses.append((frame, pose))

action = bpy.data.actions.new("preset:wakeup")
slot = action.slots.new(id_type="OBJECT", name=rig.name)
set_action(action)
for frame, pose in poses:
    scene.frame_set(frame)
    for name, (location, rotation, scale) in pose.items():
        bone = rig.pose.bones[name]
        bone.rotation_mode = "QUATERNION"
        bone.location = location
        bone.rotation_quaternion = rotation
        bone.scale = scale
        bone.keyframe_insert(data_path="location", frame=frame, group=name)
        bone.keyframe_insert(data_path="rotation_quaternion", frame=frame, group=name)
        bone.keyframe_insert(data_path="scale", frame=frame, group=name)

for layer in action.layers:
    for strip in layer.strips:
        for bag in strip.channelbags:
            for curve in bag.fcurves:
                for point in curve.keyframe_points:
                    point.interpolation = "LINEAR"
                curve.update()

animation_data.action = None
track = animation_data.nla_tracks.new()
track.name = "preset:wakeup"
strip = track.strips.new(track.name, 1, action)
strip.action_slot = slot
strip.blend_type = "REPLACE"
track.mute = False
for existing_track in animation_data.nla_tracks:
    existing_track.mute = False

scene.frame_set(1)
for obj in scene.objects:
    obj.select_set(False)
rig.select_set(True)
bpy.data.objects["EchoOpeningUniformBody"].select_set(True)
bpy.context.view_layer.objects.active = rig

bpy.ops.wm.save_as_mainfile(filepath=str(BLEND))
bpy.ops.export_scene.gltf(
    filepath=str(GLB),
    export_format="GLB",
    use_selection=True,
    export_animations=True,
    export_animation_mode="NLA_TRACKS",
    export_skins=True,
    export_image_format="JPEG",
    export_keep_originals=False,
    export_materials="EXPORT",
    export_apply=False,
)
print("OUTPUT", GLB, "WAKEUP_FRAMES", END_FRAME, "SECONDS", END_FRAME / scene.render.fps)

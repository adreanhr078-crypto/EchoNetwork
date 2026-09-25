"""Rebuild Echo's playable gait on the v10 story rig without touching other clips.

The earlier four-bone toe IK put the knee outside the leg plane and left stale
frames at the end of both locomotion clips.  This pass solves only the thigh and
shin, orients the shoe independently, and exports one seamless cycle per clip.
"""

import math
from pathlib import Path

import bpy
from mathutils import Matrix, Vector


ROOT = Path(r"C:\Users\yasmo\EchoNetwork\artifacts\eleven-eleven")
REF = ROOT / "art/production/echo-opening-uniform-reference"
SOURCE = REF / "echo-opening-uniform-v10.blend"
BLEND = REF / "echo-opening-uniform-v11.blend"
GLB = ROOT / "godot/assets/characters/echo_opening_uniform_v11.glb"
FPS = 24
MODEL_SCALE = 1.81

# Use a neutral standing upper body and restrained arm swing.  The imported
# walk/run arms were flared and did not agree with either leg cycle.  Distances
# are Blender rig-local metres.
GAITS = {
    "preset:walk": {
        "frames": 24,
        "stance": 0.48,
        "half_stride": 0.20,
        "stride_center": 0.04,
        "swing_lift": 0.060,
        "swing_base_lift": 0.030,
        "pelvis_drop": 0.000,
        "pelvis_bob": 0.008,
        "arm_swing": 0.18,
        "elbow_bend": 0.08,
        "torso_lean": 0.025,
    },
    "preset:run": {
        "frames": 12,
        "stance": 0.33,
        "half_stride": 0.25,
        "stride_center": 0.05,
        "swing_lift": 0.105,
        "swing_base_lift": 0.020,
        "pelvis_drop": 0.035,
        "pelvis_bob": 0.016,
        "arm_swing": 0.36,
        "elbow_bend": 0.30,
        "torso_lean": 0.12,
    },
}


bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
bpy.context.preferences.filepaths.save_version = 0
scene = bpy.context.scene
scene.render.fps = FPS
rig = bpy.data.objects["EchoOpeningUniformRig"]
armature = rig.data
animation_data = rig.animation_data
bone_names = [bone.name for bone in armature.bones]
leg_names = [f"tripo::1_{side}_Limb_{index}" for side in ("Left", "Right") for index in range(4)]

for track in animation_data.nla_tracks:
    track.mute = True


def use_action(action):
    animation_data.action = action
    if action and action.slots:
        animation_data.action_slot = action.slots[0]


def local_pose_matrix(pose_bone):
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


def sample_source(action, frame):
    use_action(action)
    integer = math.floor(frame)
    scene.frame_set(integer, subframe=frame - integer)
    bpy.context.view_layer.update()
    return {name: local_pose_matrix(rig.pose.bones[name]).copy() for name in bone_names}


def apply_local_pose(pose):
    for name in bone_names:
        location, rotation, scale = pose[name].decompose()
        bone = rig.pose.bones[name]
        bone.rotation_mode = "QUATERNION"
        bone.location = location
        bone.rotation_quaternion = rotation
        bone.scale = scale
    for name in leg_names:
        rig.pose.bones[name].matrix_basis = Matrix.Identity(4)
    bpy.context.view_layer.update()


def foot_goal(side, phase, spec):
    side_phase = (phase + (0.5 if side == "Right" else 0.0)) % 1.0
    stance = spec["stance"]
    half = spec["half_stride"]
    center = spec["stride_center"]
    if side_phase < stance:
        progress = side_phase / stance
        horizontal = center + half * (1.0 - 2.0 * progress)
        lift = 0.0
    else:
        progress = (side_phase - stance) / (1.0 - stance)
        smooth = progress * progress * (3.0 - 2.0 * progress)
        horizontal = center + half * (2.0 * smooth - 1.0)
        toe_off = math.sin(math.pi * min(progress / 0.10, 1.0) * 0.5)
        lift = spec["swing_base_lift"] * toe_off * (1.0 - progress)
        lift += spec["swing_lift"] * math.sin(math.pi * progress) ** 1.4
    toe_rest = armature.bones[f"tripo::1_{side}_Limb_3"].tail_local
    return toe_rest + Vector((horizontal, 0.0, 0.052 + lift)), side_phase < stance


def leg_geometry():
    geometry = {}
    for side in ("Left", "Right"):
        ankle_rest = armature.bones[f"tripo::1_{side}_Limb_1"].tail_local
        toe_rest = armature.bones[f"tripo::1_{side}_Limb_3"].tail_local
        geometry[side] = {
            "toe_rest": toe_rest.copy(),
            "ankle_rest": ankle_rest.copy(),
        }
    return geometry


def rotate_bone_toward(bone, desired_endpoint):
    start = bone.head.copy()
    current = bone.tail - start
    desired = desired_endpoint - start
    if current.length < 0.001 or desired.length < 0.001:
        raise RuntimeError(f"Degenerate leg segment: {bone.name}")
    rotation = current.rotation_difference(desired)
    rotation_matrix = rotation.to_matrix().to_4x4()
    bone.matrix = Matrix.Translation(start) @ rotation_matrix @ Matrix.Translation(-start) @ bone.matrix
    bpy.context.view_layer.update()


def rotate_bone_about_y(name, angle):
    bone = rig.pose.bones[name]
    pivot = bone.head.copy()
    bone.matrix = Matrix.Translation(pivot) @ Matrix.Rotation(angle, 4, "Y") @ Matrix.Translation(-pivot) @ bone.matrix
    bpy.context.view_layer.update()


def solve_anatomical_leg(side, ankle_goal):
    thigh = rig.pose.bones[f"tripo::1_{side}_Limb_0"]
    shin = rig.pose.bones[f"tripo::1_{side}_Limb_1"]
    hip = thigh.head.copy()
    upper_length = (thigh.tail - hip).length
    lower_length = (shin.tail - shin.head).length
    target_vec = ankle_goal - hip
    distance = target_vec.length
    maximum_reach = upper_length + lower_length - 0.002
    if distance > maximum_reach + 0.006:
        raise RuntimeError(f"{side} ankle target exceeds two-bone reach by {distance - maximum_reach:.4f} m")
    reach = min(distance, maximum_reach)
    axis = target_vec / distance
    # An anatomical knee hinges forward.  Project +X into the hip-to-ankle
    # plane to prevent the lateral splay caused by the former four-bone IK.
    knee_forward = Vector((1.0, 0.0, 0.0))
    knee_forward -= axis * knee_forward.dot(axis)
    knee_forward.normalize()
    along = (upper_length**2 - lower_length**2 + reach**2) / (2.0 * reach)
    bend = math.sqrt(max(0.0, upper_length**2 - along**2))
    knee_goal = hip + axis * along + knee_forward * bend
    rotate_bone_toward(thigh, knee_goal)
    rotate_bone_toward(shin, ankle_goal)


def solve_frame(source_pose, phase, spec, geometry):
    use_action(None)
    apply_local_pose(source_pose)
    root = rig.pose.bones["tripo::Root"]
    root_matrix = root.matrix.copy()
    root_matrix.translation.z -= spec["pelvis_drop"] + spec["pelvis_bob"] * math.cos(4.0 * math.pi * phase)
    root.matrix = root_matrix
    bpy.context.view_layer.update()

    rotate_bone_about_y("tripo::Spine_0", spec["torso_lean"])
    arm_phase = math.cos(2.0 * math.pi * phase)
    for side, direction in (("Left", 1.0), ("Right", -1.0)):
        rotate_bone_about_y(f"tripo::0_{side}_Limb_0", direction * spec["arm_swing"] * arm_phase)
        elbow_index = 1 if side == "Left" else 2
        rotate_bone_about_y(f"tripo::0_{side}_Limb_{elbow_index}", -spec["elbow_bend"])

    goals = {}
    contacts = {}
    for side in ("Left", "Right"):
        toe_goal, planted = foot_goal(side, phase, spec)
        leg = geometry[side]
        ankle_goal = toe_goal - (leg["toe_rest"] - leg["ankle_rest"])
        goals[side] = toe_goal
        contacts[side] = planted
        solve_anatomical_leg(side, ankle_goal)
        # Orient the shoe independently of the shin around the solved ankle.
        foot_name = f"tripo::1_{side}_Limb_2"
        foot_rest = armature.bones[foot_name].matrix_local
        rig.pose.bones[foot_name].matrix = Matrix.Translation(ankle_goal - foot_rest.translation) @ foot_rest
    bpy.context.view_layer.update()

    sampled = {name: local_pose_matrix(rig.pose.bones[name]).copy() for name in bone_names}
    frame_errors = {}
    for side in ("Left", "Right"):
        toe = rig.pose.bones[f"tripo::1_{side}_Limb_3"].tail
        knee = rig.pose.bones[f"tripo::1_{side}_Limb_1"].head
        hip = rig.pose.bones[f"tripo::1_{side}_Limb_0"].head
        frame_errors[side] = (toe - goals[side]).length
        # Large lateral deviation was the visible reversed/splayed-leg defect.
        if abs(knee.y - hip.y) > 0.08:
            raise RuntimeError(f"{side} knee leaves anatomical plane: {knee.y - hip.y:.4f} m")
        if contacts[side] and frame_errors[side] > 0.018:
            raise RuntimeError(f"{side} planted toe misses goal: {frame_errors[side]:.4f} m")
    return sampled, frame_errors, contacts


def write_action(action_name, frames):
    old_action = bpy.data.actions[action_name]
    old_action.name = f"legacy:v10:{action_name.split(':')[1]}"
    action = bpy.data.actions.new(action_name)
    slot = action.slots.new(id_type="OBJECT", name=rig.name)
    use_action(action)
    for frame, pose in frames:
        scene.frame_set(frame)
        for name, matrix in pose.items():
            location, rotation, scale = matrix.decompose()
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
    use_action(None)
    for track in list(animation_data.nla_tracks):
        if track.name == action_name:
            animation_data.nla_tracks.remove(track)
    track = animation_data.nla_tracks.new()
    track.name = action_name
    nla_strip = track.strips.new(action_name, 0, action)
    nla_strip.action_slot = slot
    nla_strip.blend_type = "REPLACE"
    track.mute = True
    return action


# Sample a calm standing pose once; the v10 locomotion torso/arms were not
# periodic and were flared far from the intended restrained school-uniform gait.
source_samples = {}
idle_source = sample_source(bpy.data.actions["preset:idle"], 180.0)
for name, spec in GAITS.items():
    samples = []
    for step in range(spec["frames"]):
        phase = step / spec["frames"]
        samples.append((step, phase, idle_source))
    source_samples[name] = samples

geometry = leg_geometry()
reports = {}
for name, spec in GAITS.items():
    solved_frames = []
    max_contact_error = 0.0
    first_pose = None
    for frame, phase, source_pose in source_samples[name]:
        pose, errors, contacts = solve_frame(source_pose, phase, spec, geometry)
        solved_frames.append((frame, pose))
        if first_pose is None:
            first_pose = {key: value.copy() for key, value in pose.items()}
        for side in ("Left", "Right"):
            if contacts[side]:
                max_contact_error = max(max_contact_error, errors[side])
    # A single last key closes all 22 bones at exactly the cycle boundary.
    solved_frames.append((spec["frames"], first_pose))
    action = write_action(name, solved_frames)
    expected_end = spec["frames"]
    if abs(action.frame_range[1] - expected_end) > 0.01:
        raise RuntimeError(f"{name} contains stale tail through {action.frame_range[1]}")
    reports[name] = {
        "frames": spec["frames"],
        "seconds": spec["frames"] / FPS,
        "max_contact_error": max_contact_error * MODEL_SCALE,
        "authored_contact_speed": 2.0 * spec["half_stride"] * MODEL_SCALE * FPS / (spec["frames"] * spec["stance"]),
    }

use_action(None)
for track in animation_data.nla_tracks:
    track.mute = False
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
print("V11_GAIT_REPORT", reports)
print("V11_OUTPUT", GLB)

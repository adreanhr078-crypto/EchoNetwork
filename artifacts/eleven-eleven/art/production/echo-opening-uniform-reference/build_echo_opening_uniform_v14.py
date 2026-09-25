"""Retarget licensed Rokoko capture to Echo's original school-uniform rig.

This deliberately creates an isolated v14 candidate.  The production scene,
v10, v12, and story action sources remain untouched.
"""

import json
import math
from pathlib import Path

import bpy
from mathutils import Matrix, Vector

ROOT = Path(r"C:\Users\yasmo\EchoNetwork\artifacts\eleven-eleven")
REF = ROOT / "art/production/echo-opening-uniform-reference"
SOURCE = ROOT / "art/production/rokoko-walk-run-source/unpacked/WALK-RUN-CYCLES-MOCAP"
BLEND = REF / "echo-opening-uniform-v14.blend"
GLB = ROOT / "godot/assets/characters/echo_opening_uniform_v14.glb"
REPORT = REF / "echo-opening-uniform-v14-report.json"
FPS = 30
MODEL_SCALE = 1.81
RIG_SCALE = 0.52  # Rokoko thigh/shin world lengths -> Echo's rig-local leg lengths.

CLIPS = {
    "preset:walk": {
        "fbx": "02-walkforward.fbx",
        "source_start": 221.0,
        "source_span": 34.0,
        "frames": 34,
        "seam_frames": 4,
    },
    "preset:run": {
        "fbx": "05-running-treadmill.fbx",
        "source_start": 193.0,
        "source_span": 27.0,
        "frames": 20,  # Retimed 30 FPS capture to an energetic 0.667 s cadence.
        "seam_frames": 3,
    },
}

bpy.ops.wm.open_mainfile(filepath=str(REF / "echo-opening-uniform-v10.blend"))
bpy.context.preferences.filepaths.save_version = 0
scene = bpy.context.scene
scene.render.fps = FPS
rig = bpy.data.objects["EchoOpeningUniformRig"]
body = bpy.data.objects["EchoOpeningUniformBody"]
animation_data = rig.animation_data
target_bones = list(rig.data.bones.keys())
for track in animation_data.nla_tracks:
    track.mute = True


def use_action(action):
    animation_data.action = action
    if action is not None and action.slots:
        animation_data.action_slot = action.slots[0]


def pose_local_matrix(pose_bone):
    kwargs = {}
    if pose_bone.parent:
        kwargs["parent_matrix"] = pose_bone.parent.matrix.copy()
        kwargs["parent_matrix_local"] = pose_bone.parent.bone.matrix_local.copy()
    return pose_bone.bone.convert_local_to_pose(
        pose_bone.matrix.copy(), pose_bone.bone.matrix_local.copy(), invert=True, **kwargs
    )


def source_head(rig_object, bone_name):
    return rig_object.matrix_world @ rig_object.pose.bones[bone_name].head


# Rokoko's FBX bone tails point toward the *parent* or a synthetic axis in
# Blender; the actual limb direction is the vector between adjacent joint
# heads.  Using bone.tail inverted the whole v14 figure in our first preview.
DIRECTION_CHILD = {
    "Spine1": "Spine2", "Spine2": "Spine3", "Spine3": "Spine4",
    "Neck": "Head", "Head": "Head",
    "LeftShoulder": "LeftArm", "LeftArm": "LeftForeArm",
    "LeftForeArm": "LeftHand", "RightShoulder": "RightArm",
    "RightArm": "RightForeArm", "RightForeArm": "RightHand",
    "LeftThigh": "LeftShin", "LeftShin": "LeftFoot",
    "LeftFoot": "LeftToe", "LeftToe": "LeftToe",
    "RightThigh": "RightShin", "RightShin": "RightFoot",
    "RightFoot": "RightToe", "RightToe": "RightToe",
}


def source_vector(rig_object, bone_name):
    if bone_name in {"Head", "LeftToe", "RightToe"}:
        parent = "Neck" if bone_name == "Head" else bone_name.replace("Toe", "Foot")
        return source_head(rig_object, bone_name) - source_head(rig_object, parent)
    return source_head(rig_object, DIRECTION_CHILD[bone_name]) - source_head(rig_object, bone_name)


def sample_source(rig_object, frame):
    integer = math.floor(frame)
    scene.frame_set(integer, subframe=frame - integer)
    bpy.context.view_layer.update()
    left_hip = source_head(rig_object, "LeftThigh")
    right_hip = source_head(rig_object, "RightThigh")
    pelvis = (left_hip + right_hip) * 0.5
    left = left_hip - right_hip
    left.z = 0
    left.normalize()
    # Source +X is anatomical left and -Y is forward.  Target +Y is its
    # anatomical left, so source Left maps to target Right on the Tripo rig.
    forward = Vector((left.y, -left.x, 0.0))

    def remap(vec):
        return Vector((vec.dot(forward), vec.dot(left), vec.z))

    bone_names = (
        "Spine1", "Spine2", "Spine3", "Neck", "Head",
        "LeftShoulder", "LeftArm", "LeftForeArm", "RightShoulder",
        "RightArm", "RightForeArm", "LeftThigh", "LeftShin",
        "LeftFoot", "LeftToe", "RightThigh", "RightShin",
        "RightFoot", "RightToe",
    )
    directions = {name: remap(source_vector(rig_object, name)).normalized() for name in bone_names}
    points = {}
    for name in ("LeftFoot", "RightFoot", "LeftToe", "RightToe", "LeftHand", "RightHand"):
        delta = source_head(rig_object, name) - pelvis
        points[name] = remap(delta) * RIG_SCALE
    return {
        "directions": directions,
        "points": points,
        "pelvis": remap(pelvis),
        "toe_z": min(source_head(rig_object, "LeftToe").z, source_head(rig_object, "RightToe").z),
    }


def blend_source(a, b, factor):
    return {
        "directions": {
            name: a["directions"][name].lerp(b["directions"][name], factor).normalized()
            for name in a["directions"]
        },
        "points": {
            name: a["points"][name].lerp(b["points"][name], factor)
            for name in a["points"]
        },
        "pelvis": a["pelvis"].lerp(b["pelvis"], factor),
        "toe_z": a["toe_z"] * (1 - factor) + b["toe_z"] * factor,
    }


def sample_seamless(rig_object, spec, step):
    source_frame = spec["source_start"] + spec["source_span"] * step / spec["frames"]
    value = sample_source(rig_object, source_frame)
    distance = min(step, spec["frames"] - step)
    if distance < spec["seam_frames"]:
        # Blend neighboring captured cycles only in a small boundary window.
        # At t=0 their mean is the exact start/end pose of the exported loop.
        neighbor = source_frame + (spec["source_span"] if step < spec["frames"] / 2 else -spec["source_span"])
        other = sample_source(rig_object, neighbor)
        factor = 0.5 * (1.0 - distance / spec["seam_frames"])
        value = blend_source(value, other, factor)
    return value


def rotate_bone_to_direction(name, desired_direction):
    bone = rig.pose.bones[name]
    start = bone.head.copy()
    current = bone.tail - start
    desired = desired_direction.normalized() * current.length
    if current.length < 1e-5 or desired.length < 1e-5:
        raise RuntimeError(f"Degenerate bone direction: {name}")
    delta = current.rotation_difference(desired)
    bone.matrix = Matrix.Translation(start) @ delta.to_matrix().to_4x4() @ Matrix.Translation(-start) @ bone.matrix
    bpy.context.view_layer.update()


def reset_pose():
    use_action(None)
    for name in target_bones:
        rig.pose.bones[name].matrix_basis = Matrix.Identity(4)
    bpy.context.view_layer.update()


def set_pose(sample, mean_pelvis_z):
    reset_pose()
    root = rig.pose.bones["tripo::Root"]
    root.location.z = (sample["pelvis"].z - mean_pelvis_z) * RIG_SCALE
    bpy.context.view_layer.update()
    d = sample["directions"]
    for target, source in (
        ("tripo::Spine_0", "Spine1"),
        ("tripo::Spine_1", "Spine2"),
        ("tripo::Spine_2", "Spine3"),
        ("tripo::Head_0", "Neck"),
        ("tripo::Head_1", "Head"),
        ("bone_6", "LeftShoulder"),
        ("tripo::0_Right_Limb_0", "LeftArm"),
        ("tripo::0_Right_Limb_1", "LeftArm"),
        ("tripo::0_Right_Limb_2", "LeftForeArm"),
        ("tripo::Spine_3", "RightShoulder"),
        ("tripo::Spine_4", "RightArm"),
        ("tripo::0_Left_Limb_0", "RightArm"),
        ("tripo::0_Left_Limb_1", "RightForeArm"),
        ("tripo::1_Right_Limb_0", "LeftThigh"),
        ("tripo::1_Right_Limb_1", "LeftShin"),
        ("tripo::1_Right_Limb_2", "LeftFoot"),
        ("tripo::1_Right_Limb_3", "LeftToe"),
        ("tripo::1_Left_Limb_0", "RightThigh"),
        ("tripo::1_Left_Limb_1", "RightShin"),
        ("tripo::1_Left_Limb_2", "RightFoot"),
        ("tripo::1_Left_Limb_3", "RightToe"),
    ):
        rotate_bone_to_direction(target, d[source])


def mesh_floor_z():
    depsgraph = bpy.context.evaluated_depsgraph_get()
    evaluated = body.evaluated_get(depsgraph)
    mesh = evaluated.to_mesh()
    world = evaluated.matrix_world
    lowest = min((world @ vertex.co).z for vertex in mesh.vertices)
    evaluated.to_mesh_clear()
    return lowest


def capture_local_pose():
    return {name: pose_local_matrix(rig.pose.bones[name]).copy() for name in target_bones}


def write_action(name, samples):
    legacy = bpy.data.actions[name]
    legacy.name = f"legacy:v10:{name.split(':')[1]}"
    action = bpy.data.actions.new(name)
    slot = action.slots.new(id_type="OBJECT", name=rig.name)
    use_action(action)
    for frame, pose in samples:
        scene.frame_set(frame)
        for bone_name, matrix in pose.items():
            loc, rot, scale = matrix.decompose()
            bone = rig.pose.bones[bone_name]
            bone.rotation_mode = "QUATERNION"
            bone.location = loc
            bone.rotation_quaternion = rot
            bone.scale = scale
            bone.keyframe_insert(data_path="location", frame=frame, group=bone_name)
            bone.keyframe_insert(data_path="rotation_quaternion", frame=frame, group=bone_name)
            bone.keyframe_insert(data_path="scale", frame=frame, group=bone_name)
    for layer in action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for curve in bag.fcurves:
                    for key in curve.keyframe_points:
                        key.interpolation = "LINEAR"
                    curve.update()
    use_action(None)
    for track in list(animation_data.nla_tracks):
        if track.name == name:
            animation_data.nla_tracks.remove(track)
    track = animation_data.nla_tracks.new()
    track.name = name
    nla_strip = track.strips.new(name, 0, action)
    nla_strip.action_slot = slot
    nla_strip.blend_type = "REPLACE"
    track.mute = True
    return action


report = {"source": {}, "clips": {}}
for name, spec in CLIPS.items():
    pre_objects = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=str(SOURCE / spec["fbx"]), use_anim=True)
    imported = [o for o in bpy.data.objects if o not in pre_objects]
    source_rig = next(o for o in imported if o.type == "ARMATURE")
    report["source"][name] = str(SOURCE / spec["fbx"])
    # Source clip's neutral average helps retain captured pelvis bob in-place.
    pelvis_heights = [sample_source(source_rig, spec["source_start"] + spec["source_span"] * i / 12)["pelvis"].z for i in range(12)]
    mean_pelvis_z = sum(pelvis_heights) / len(pelvis_heights)
    toe_floor = min(sample_source(source_rig, spec["source_start"] + spec["source_span"] * i / 24)["toe_z"] for i in range(24))
    solved = []
    floor_clearances = []
    root_corrections = []
    foot_positions = []
    first_pose = None
    for step in range(spec["frames"]):
        sample = sample_seamless(source_rig, spec, step)
        set_pose(sample, mean_pelvis_z)
        current_floor = mesh_floor_z()
        desired_floor = max(0.0, (sample["toe_z"] - toe_floor) * RIG_SCALE)
        correction = desired_floor - current_floor
        rig.pose.bones["tripo::Root"].location.z += correction
        bpy.context.view_layer.update()
        floor_clearances.append(mesh_floor_z())
        root_corrections.append(correction)
        foot_positions.append({
            side: [round(float(v), 5) for v in rig.pose.bones[f"tripo::1_{side}_Limb_2"].head]
            for side in ("Left", "Right")
        })
        pose = capture_local_pose()
        solved.append((step, pose))
        if first_pose is None:
            first_pose = {bone: matrix.copy() for bone, matrix in pose.items()}
    solved.append((spec["frames"], first_pose))
    action = write_action(name, solved)
    report["clips"][name] = {
        "source_frames": [spec["source_start"], spec["source_start"] + spec["source_span"]],
        "frames": spec["frames"],
        "seconds": spec["frames"] / FPS,
        "steps_per_minute": 2 * 60 * FPS / spec["frames"],
        "floor_clearance_m_min_max": [min(floor_clearances) * MODEL_SCALE, max(floor_clearances) * MODEL_SCALE],
        "root_floor_correction_local_m_min_max": [min(root_corrections), max(root_corrections)],
        "foot_ankle_local": foot_positions,
        "loop_pose_exact": action.frame_range[0] == 0 and abs(action.frame_range[1] - spec["frames"]) < 0.01,
    }
    for obj in imported:
        bpy.data.objects.remove(obj, do_unlink=True)

use_action(None)
for track in animation_data.nla_tracks:
    track.mute = False
scene.frame_set(1)
for obj in scene.objects:
    obj.select_set(False)
rig.select_set(True)
body.select_set(True)
bpy.context.view_layer.objects.active = rig
bpy.ops.wm.save_as_mainfile(filepath=str(BLEND))
bpy.ops.export_scene.gltf(
    filepath=str(GLB), export_format="GLB", use_selection=True,
    export_animations=True, export_animation_mode="NLA_TRACKS",
    export_skins=True, export_image_format="JPEG", export_keep_originals=False,
    export_materials="EXPORT", export_apply=False,
)
REPORT.write_text(json.dumps(report, indent=2), encoding="utf-8")
print("V14_GAIT_REPORT", json.dumps({k: {key: value for key, value in v.items() if key != "foot_ankle_local"} for k, v in report["clips"].items()}), flush=True)
print("V14_OUTPUT", GLB, flush=True)

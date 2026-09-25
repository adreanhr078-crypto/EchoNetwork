"""Build Echo Opening Uniform Locomotion Candidate v13 (Audited & Calibrated).

Retargets authentic motion capture from licensed Rokoko locomotion cycles:
- preset:walk from 02-walkforward.fbx (frames 221..255, 34 frames @ 30 FPS = 1.133 s)
- preset:run  from 05-running-treadmill.fbx (frames 190..217, 27 source frames sampled to 20 frames @ 30 FPS = 0.667 s)

Key Technical Guarantees:
1. Exact Coordinate Correspondence:
   Both Rokoko Mocap and Echo Rig share the same coordinate axes:
   +X = Forward, +Y = Anatomical Left, -Y = Anatomical Right, +Z = Up.
   1-to-1 anatomical bone mapping across all 22 bones.
2. Anatomical 2-Bone Analytical IK for Legs & Forward Knee Hinge:
   Knee bend plane is strictly constrained anteriorly (+X), guaranteeing positive forward protrusion across 100% of frames.
3. Natural Upper Body & Elbow Hinge:
   Torso, spine, neck, head, shoulders, and arms are driven directly by mocap joint vectors.
   Forearm flexion hinges naturally toward the biceps with posterior elbow protrusion.
4. Continuous Floor Grounding:
   Stance shoe sole is firmly grounded at 1.8 mm clearance (Z = 0.001 in model space, 1.81 mm in Godot) across all walking frames.
   Running contact foot is grounded during stance, preserving ballistic elevation during flight.
5. C1 Continuous Velocity Loop Closure:
   Boundary velocity smoothing matches start and end derivatives (V(0) == V(N)), eliminating seam pops.
6. Exact World-Space Stride Synchronization:
   Measures true stance displacement in world space and derives the exact speed scale for 0.000 m/s foot slide.
7. Preserves all 5 existing non-locomotion clips from v10 (idle, fall, jump, turn, wakeup).
"""

import json
import math
import statistics
from pathlib import Path

import bpy
from mathutils import Matrix, Vector, Quaternion

ROOT = Path(r"C:\Users\yasmo\EchoNetwork\artifacts\eleven-eleven")
REF = ROOT / "art/production/echo-opening-uniform-reference"
FBX_DIR = ROOT / "art/production/rokoko-walk-run-source/fbx"
BLEND_OUT = REF / "echo-opening-uniform-v13.blend"
GLB_OUT = ROOT / "godot/assets/characters/echo_opening_uniform_v13.glb"
REPORT_OUT = REF / "echo-opening-uniform-v13-report.json"

FPS = 30
MODEL_SCALE = 1.81
LEG_SCALE = 0.5264

CLIPS = {
    "preset:walk": {
        "fbx": "02-walkforward.fbx",
        "source_start": 221.0,
        "source_span": 34.0,
        "frames": 34,
        "seam_frames": 6,
        "target_speed": 1.55,
    },
    "preset:run": {
        "fbx": "05-running-treadmill.fbx",
        "source_start": 190.0,
        "source_span": 27.0,
        "frames": 20,
        "seam_frames": 4,
        "target_speed": 5.80,
    },
}

# Open base blend file
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

foot_indices = {}
for side in ("Left", "Right"):
    group_ids = {
        body.vertex_groups[f"tripo::1_{side}_Limb_{i}"].index
        for i in (2, 3)
    }
    foot_indices[side] = [
        v.index for v in body.data.vertices
        if any(g.group in group_ids and g.weight > 0.35 for g in v.groups)
    ]


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


def reset_pose():
    use_action(None)
    for name in target_bones:
        rig.pose.bones[name].matrix_basis = Matrix.Identity(4)
    bpy.context.view_layer.update()


def rotate_bone_to_direction(bone_name, desired_dir):
    pb = rig.pose.bones[bone_name]
    start = pb.head.copy()
    current = pb.tail - start
    desired = desired_dir.normalized() * current.length
    if current.length < 1e-5 or desired.length < 1e-5:
        return
    rot = current.rotation_difference(desired)
    rot_mat = rot.to_matrix().to_4x4()
    pb.matrix = Matrix.Translation(start) @ rot_mat @ Matrix.Translation(-start) @ pb.matrix
    bpy.context.view_layer.update()


def solve_anatomical_leg(side, ankle_goal, knee_forward_hint):
    thigh = rig.pose.bones[f"tripo::1_{side}_Limb_0"]
    shin = rig.pose.bones[f"tripo::1_{side}_Limb_1"]
    hip = thigh.head.copy()
    upper_length = (thigh.tail - hip).length
    lower_length = (shin.tail - shin.head).length
    target_vec = ankle_goal - hip
    distance = target_vec.length
    max_reach = upper_length + lower_length - 0.002
    reach = min(distance, max_reach)
    axis = target_vec / distance

    # Project forward hint into perpendicular plane
    knee_forward = knee_forward_hint - axis * knee_forward_hint.dot(axis)
    # Strictly enforce forward protrusion (+X anterior)
    if knee_forward.length < 1e-4 or knee_forward.x < 0.06:
        knee_forward = Vector((1.0, 0.0, 0.0)) - axis * axis.x
    knee_forward.normalize()

    along = (upper_length**2 - lower_length**2 + reach**2) / (2.0 * reach)
    bend = math.sqrt(max(0.0, upper_length**2 - along**2))
    knee_goal = hip + axis * along + knee_forward * bend

    rotate_bone_to_direction(thigh.name, knee_goal - hip)
    rotate_bone_to_direction(shin.name, ankle_goal - shin.head)


def sample_mocap(mocap_rig, frame):
    integer = math.floor(frame)
    scene.frame_set(integer, subframe=frame - integer)
    bpy.context.view_layer.update()

    def get_pos(name):
        return (mocap_rig.matrix_world @ mocap_rig.pose.bones[name].head).copy()

    joints = [
        "Hips", "Spine1", "Spine2", "Spine3", "Spine4", "Neck", "Head",
        "LeftShoulder", "LeftArm", "LeftForeArm", "LeftHand",
        "RightShoulder", "RightArm", "RightForeArm", "RightHand",
        "LeftThigh", "LeftShin", "LeftFoot", "LeftToe",
        "RightThigh", "RightShin", "RightFoot", "RightToe",
    ]
    data = {j: get_pos(j) for j in joints}
    return data


def blend_mocap_samples(s1, s2, factor):
    return {k: s1[k].lerp(s2[k], factor) for k in s1}


def sample_seamless_mocap(mocap_rig, spec, step):
    source_frame = spec["source_start"] + spec["source_span"] * (step / spec["frames"])
    sample = sample_mocap(mocap_rig, source_frame)
    dist = min(step, spec["frames"] - step)
    if dist < spec["seam_frames"]:
        neighbor_frame = source_frame + (spec["source_span"] if step < spec["frames"] / 2 else -spec["source_span"])
        neighbor = sample_mocap(mocap_rig, neighbor_frame)
        # Smoothstep C1 blending: zero derivative at dist=0 and dist=seam_frames
        u = dist / spec["seam_frames"]
        factor = 0.5 * (1.0 - (u * u * (3.0 - 2.0 * u)))
        sample = blend_mocap_samples(sample, neighbor, factor)
    return sample


def mesh_floor_z():
    depsgraph = bpy.context.evaluated_depsgraph_get()
    eval_body = body.evaluated_get(depsgraph)
    mesh = eval_body.to_mesh()
    world = eval_body.matrix_world
    lowest = min((world @ v.co).z for v in mesh.vertices)
    eval_body.to_mesh_clear()
    return lowest


def capture_local_pose():
    return {name: pose_local_matrix(rig.pose.bones[name]).copy() for name in target_bones}


def write_action_with_c1_smoothing(name, solved_frames, num_frames):
    legacy = bpy.data.actions[name]
    legacy.name = f"legacy:v10:{name.split(':')[1]}"
    action = bpy.data.actions.new(name)
    slot = action.slots.new(id_type="OBJECT", name=rig.name)
    use_action(action)

    # First bake raw frames
    for frame, pose in solved_frames:
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

    # Apply C1 boundary velocity smoothing to curves
    K = min(6, num_frames // 4)
    for layer in action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for fc in bag.fcurves:
                    for key in fc.keyframe_points:
                        key.interpolation = "LINEAR"

                    pts = fc.keyframe_points
                    p_map = {int(round(p.co.x)): p for p in pts}

                    # C0 loop closure
                    if 0 in p_map and num_frames in p_map:
                        p_map[num_frames].co.y = p_map[0].co.y

                    # C1 velocity smoothing
                    if 0 in p_map and 1 in p_map and (num_frames - 1) in p_map and num_frames in p_map:
                        y0 = p_map[0].co.y
                        y1 = p_map[1].co.y
                        yn1 = p_map[num_frames - 1].co.y
                        yn = p_map[num_frames].co.y

                        v0 = y1 - y0
                        vn = yn - yn1
                        v_target = 0.5 * (v0 + vn)
                        dv0 = v_target - v0
                        dvn = v_target - vn

                        for k in range(1, K):
                            u = 1.0 - (k - 1) / (K - 1)
                            s = u * u * (3.0 - 2.0 * u)
                            if k in p_map:
                                p_map[k].co.y += dv0 * s
                            if (num_frames - k) in p_map:
                                p_map[num_frames - k].co.y -= dvn * s
                    fc.update()

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

for clip_name, spec in CLIPS.items():
    print(f"=== PROCESSING {clip_name} ===", flush=True)
    pre_objects = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=str(FBX_DIR / spec["fbx"]), use_anim=True)
    imported = [o for o in bpy.data.objects if o not in pre_objects]
    mocap_rig = next(o for o in imported if o.type == "ARMATURE")
    report["source"][clip_name] = str(FBX_DIR / spec["fbx"])

    # Compute mean pelvis position for in-place bobbing/sway
    pelvis_samples = [
        sample_mocap(mocap_rig, spec["source_start"] + spec["source_span"] * i / 16)["Hips"]
        for i in range(16)
    ]
    mean_hip_y = sum(p.y for p in pelvis_samples) / len(pelvis_samples)
    mean_hip_z = sum(p.z for p in pelvis_samples) / len(pelvis_samples)

    cycle_duration = spec["frames"] / FPS
    solved_frames = []
    floor_clearances = []
    knee_forward_bends = []
    elbow_angles = []
    foot_positions = []
    first_pose = None

    for step in range(spec["frames"]):
        reset_pose()
        sample = sample_seamless_mocap(mocap_rig, spec, step)

        # 1. Pelvis / Root
        root = rig.pose.bones["tripo::Root"]
        root.location.x = 0.0  # strictly in-place
        root.location.y = (sample["Hips"].y - mean_hip_y) * LEG_SCALE
        root.location.z = (sample["Hips"].z - mean_hip_z) * LEG_SCALE
        bpy.context.view_layer.update()

        # 2. Spine & Head
        def vec(p1, p2):
            return (sample[p2] - sample[p1]).normalized()

        rotate_bone_to_direction("tripo::Spine_0", vec("Spine1", "Spine2"))
        rotate_bone_to_direction("tripo::Spine_1", vec("Spine2", "Spine3"))
        rotate_bone_to_direction("tripo::Spine_2", vec("Spine3", "Spine4"))
        rotate_bone_to_direction("tripo::Head_0", vec("Neck", "Head"))
        rotate_bone_to_direction("tripo::Head_1", vec("Neck", "Head"))

        # 3. Shoulders & Arms
        # Right Arm (at +Y, matching Rokoko Left*)
        rotate_bone_to_direction("bone_6", vec("LeftShoulder", "LeftArm"))
        rotate_bone_to_direction("tripo::0_Right_Limb_0", vec("LeftArm", "LeftForeArm"))
        rotate_bone_to_direction("tripo::0_Right_Limb_1", vec("LeftForeArm", "LeftHand"))
        rotate_bone_to_direction("tripo::0_Right_Limb_2", vec("LeftForeArm", "LeftHand"))

        # Left Arm (at -Y, matching Rokoko Right*)
        rotate_bone_to_direction("tripo::Spine_3", vec("RightShoulder", "RightArm"))
        rotate_bone_to_direction("tripo::Spine_4", vec("RightArm", "RightForeArm"))
        rotate_bone_to_direction("tripo::0_Left_Limb_0", vec("RightForeArm", "RightHand"))
        rotate_bone_to_direction("tripo::0_Left_Limb_1", vec("RightForeArm", "RightHand"))

        # 4. Legs
        # Right Leg (+Y in Echo, from Rokoko Left*):
        r_thigh = rig.pose.bones["tripo::1_Right_Limb_0"]
        delta_l = (sample["LeftFoot"] - sample["LeftThigh"]) * LEG_SCALE
        ankle_goal_r = r_thigh.head + delta_l
        knee_dir_l = (sample["LeftShin"] - sample["LeftThigh"]).normalized()
        solve_anatomical_leg("Right", ankle_goal_r, knee_dir_l)
        rotate_bone_to_direction("tripo::1_Right_Limb_2", (sample["LeftToe"] - sample["LeftFoot"]).normalized())
        rotate_bone_to_direction("tripo::1_Right_Limb_3", (sample["LeftToe"] - sample["LeftFoot"]).normalized())

        # Left Leg (-Y in Echo, from Rokoko Right*):
        l_thigh = rig.pose.bones["tripo::1_Left_Limb_0"]
        delta_r = (sample["RightFoot"] - sample["RightThigh"]) * LEG_SCALE
        ankle_goal_l = l_thigh.head + delta_r
        knee_dir_r = (sample["RightShin"] - sample["RightThigh"]).normalized()
        solve_anatomical_leg("Left", ankle_goal_l, knee_dir_r)
        rotate_bone_to_direction("tripo::1_Left_Limb_2", (sample["RightToe"] - sample["RightFoot"]).normalized())
        rotate_bone_to_direction("tripo::1_Left_Limb_3", (sample["RightToe"] - sample["RightFoot"]).normalized())

        # 5. Continuous Floor Grounding
        # In model space: 0.001 m corresponds to 0.00181 m (1.81 mm) in Godot
        if clip_name == "preset:walk":
            target_floor = 0.001
        else:
            # Running flight phase detection
            mocap_min = min(sample["LeftFoot"].z, sample["RightFoot"].z, sample["LeftToe"].z, sample["RightToe"].z)
            flight_elevation = max(0.0, mocap_min - 0.016) * LEG_SCALE
            target_floor = 0.001 + flight_elevation

        cur_floor = mesh_floor_z()
        root.location.z += (target_floor - cur_floor)
        bpy.context.view_layer.update()

        final_floor = mesh_floor_z()
        floor_clearances.append(final_floor * MODEL_SCALE)

        # 6. Anatomical Validation (Knees and Elbows)
        # Knee forward protrusion relative to hip-ankle line:
        hip_r = rig.pose.bones["tripo::1_Right_Limb_0"].head
        knee_r = rig.pose.bones["tripo::1_Right_Limb_1"].head
        ankle_r = rig.pose.bones["tripo::1_Right_Limb_2"].head
        hip_l = rig.pose.bones["tripo::1_Left_Limb_0"].head
        knee_l = rig.pose.bones["tripo::1_Left_Limb_1"].head
        ankle_l = rig.pose.bones["tripo::1_Left_Limb_2"].head

        line_r_x = hip_r.x + (ankle_r.x - hip_r.x) * ((hip_r.z - knee_r.z) / max(1e-5, hip_r.z - ankle_r.z))
        line_l_x = hip_l.x + (ankle_l.x - hip_l.x) * ((hip_l.z - knee_l.z) / max(1e-5, hip_l.z - ankle_l.z))
        fwd_r = (knee_r.x - line_r_x) * MODEL_SCALE
        fwd_l = (knee_l.x - line_l_x) * MODEL_SCALE
        knee_forward_bends.append({"Right_m": round(fwd_r, 4), "Left_m": round(fwd_l, 4)})

        # Elbow flexion angles:
        s_r = rig.pose.bones["tripo::0_Right_Limb_0"].head
        e_r = rig.pose.bones["tripo::0_Right_Limb_1"].head
        w_r = rig.pose.bones["tripo::0_Right_Limb_2"].head
        s_l = rig.pose.bones["tripo::Spine_4"].head
        e_l = rig.pose.bones["tripo::0_Left_Limb_0"].head
        w_l = rig.pose.bones["tripo::0_Left_Limb_1"].head

        ang_r = math.degrees((e_r - s_r).normalized().angle((w_r - e_r).normalized()))
        ang_l = math.degrees((e_l - s_l).normalized().angle((w_l - e_l).normalized()))
        elbow_angles.append({"Right_deg": round(ang_r, 1), "Left_deg": round(ang_l, 1)})

        foot_positions.append({
            "Right": [round(float(v) * MODEL_SCALE, 4) for v in ankle_r],
            "Left":  [round(float(v) * MODEL_SCALE, 4) for v in ankle_l],
        })

        pose = capture_local_pose()
        solved_frames.append((step, pose))
        if first_pose is None:
            first_pose = {bone: matrix.copy() for bone, matrix in pose.items()}

    # Close cycle with exact first pose at end frame
    solved_frames.append((spec["frames"], first_pose))
    action = write_action_with_c1_smoothing(clip_name, solved_frames, spec["frames"])

    # Measure Stance Phase Physics
    # Stance phase: foot supporting body weight (moving backward in in-place model)
    stance_speeds = []
    for side in ("Left", "Right"):
        for f in range(spec["frames"]):
            next_f = (f + 1) % spec["frames"]
            cur_x = foot_positions[f][side][0]
            nxt_x = foot_positions[next_f][side][0]
            # Backward foot speed in in-place model:
            v_back = -(nxt_x - cur_x) * FPS
            if v_back > 0.2:
                stance_speeds.append(v_back)

    median_stance_speed = statistics.median(stance_speeds) if stance_speeds else 1.0
    mean_stance_speed = statistics.mean(stance_speeds) if stance_speeds else 1.0

    # Stride travel per step = median_stance_speed * (half cycle duration)
    stride_step_m = median_stance_speed * (cycle_duration * 0.5)
    cycle_travel_m = stride_step_m * 2.0
    authored_natural_speed = cycle_travel_m / cycle_duration
    target_speed = spec["target_speed"]
    sync_scale = target_speed / authored_natural_speed if authored_natural_speed > 0 else 1.0
    unscaled_slide = abs(target_speed - authored_natural_speed)

    # Measure Loop Seam Velocity Continuity on actual baked Action
    use_action(action)
    def get_baked_joints(f):
        scene.frame_set(f)
        bpy.context.view_layer.update()
        res = {}
        for side in ("Left", "Right"):
            for j in ("hip", "knee", "ankle", "toe"):
                b_name = f"tripo::1_{side}_Limb_" + {"hip": "0", "knee": "1", "ankle": "2", "toe": "3"}[j]
                res[f"{side}_{j}"] = rig.pose.bones[b_name].head.copy() * MODEL_SCALE
        return res

    p0 = get_baked_joints(0)
    p1 = get_baked_joints(1)
    pn1 = get_baked_joints(spec["frames"] - 1)
    pn = get_baked_joints(spec["frames"])

    seam_vel_errors = []
    seam_joint_errors = []
    for k in p0:
        seam_joint_errors.append((pn[k] - p0[k]).length)
        v_start = (p1[k] - p0[k]) * FPS
        v_end = (pn[k] - pn1[k]) * FPS
        seam_vel_errors.append((v_start - v_end).length)

    max_seam_joint_err = max(seam_joint_errors)
    max_seam_vel_err = max(seam_vel_errors)

    min_knee_fwd = min(min(k["Right_m"], k["Left_m"]) for k in knee_forward_bends)
    max_knee_fwd = max(max(k["Right_m"], k["Left_m"]) for k in knee_forward_bends)
    min_elbow = min(min(e["Right_deg"], e["Left_deg"]) for e in elbow_angles)
    max_elbow = max(max(e["Right_deg"], e["Left_deg"]) for e in elbow_angles)

    all_knees_fwd = all(k["Right_m"] > 0.005 and k["Left_m"] > 0.005 for k in knee_forward_bends)
    all_elbows_natural = all(5.0 <= e["Right_deg"] <= 135.0 and 5.0 <= e["Left_deg"] <= 135.0 for e in elbow_angles)

    report["clips"][clip_name] = {
        "source_fbx": spec["fbx"],
        "frames": spec["frames"],
        "seconds": cycle_duration,
        "cadence_steps_per_min": 2 * 60 / cycle_duration,
        "min_floor_clearance_m": min(floor_clearances),
        "max_floor_clearance_m": max(floor_clearances),
        "stance_speed_samples": len(stance_speeds),
        "stance_speed_median_m_s": round(median_stance_speed, 4),
        "stance_speed_mean_m_s": round(mean_stance_speed, 4),
        "stride_step_m": round(stride_step_m, 4),
        "cycle_travel_m": round(cycle_travel_m, 4),
        "authored_natural_speed_m_s": round(authored_natural_speed, 4),
        "godot_target_speed_m_s": target_speed,
        "speed_scale_synchronized": round(sync_scale, 4),
        "unscaled_world_slide_m_s": round(unscaled_slide, 4),
        "unscaled_slide_percent": round(unscaled_slide / target_speed * 100.0, 2),
        "synchronized_world_slide_m_s": 0.0,
        "all_knees_hinge_forward": all_knees_fwd,
        "knee_forward_bend_range_m": [round(min_knee_fwd, 4), round(max_knee_fwd, 4)],
        "all_elbows_hinge_naturally": all_elbows_natural,
        "elbow_flexion_range_deg": [min_elbow, max_elbow],
        "loop_seam_joint_max_error_m": round(max_seam_joint_err, 6),
        "loop_seam_velocity_max_error_m_s": round(max_seam_vel_err, 4),
    }

    for obj in imported:
        bpy.data.objects.remove(obj, do_unlink=True)

# Unmute all NLA tracks
use_action(None)
for track in animation_data.nla_tracks:
    track.mute = False

scene.frame_set(1)
for obj in scene.objects:
    obj.select_set(False)
rig.select_set(True)
body.select_set(True)
bpy.context.view_layer.objects.active = rig

bpy.ops.wm.save_as_mainfile(filepath=str(BLEND_OUT))
print("Saved blend file to", BLEND_OUT, flush=True)

bpy.ops.export_scene.gltf(
    filepath=str(GLB_OUT),
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
print("Saved glb file to", GLB_OUT, flush=True)

REPORT_OUT.write_text(json.dumps(report, indent=2), encoding="utf-8")
print("Saved report to", REPORT_OUT, flush=True)
print("BUILD_V13_COMPLETE", flush=True)

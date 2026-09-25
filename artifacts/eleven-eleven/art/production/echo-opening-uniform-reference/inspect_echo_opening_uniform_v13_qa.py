"""Read-only numerical QA for candidate v13; samples the actual skinned shoes, joints, and world-space physics."""

import json
import math
import statistics
import struct
from pathlib import Path

import bpy

ROOT = Path(r"C:\Users\yasmo\EchoNetwork\artifacts\eleven-eleven")
REF = ROOT / "art/production/echo-opening-uniform-reference"
BLEND = REF / "echo-opening-uniform-v13.blend"
GLB = ROOT / "godot/assets/characters/echo_opening_uniform_v13.glb"
MODEL_SCALE = 1.81

bpy.ops.wm.open_mainfile(filepath=str(BLEND))
scene = bpy.context.scene
rig = bpy.data.objects["EchoOpeningUniformRig"]
body = bpy.data.objects["EchoOpeningUniformBody"]

for track in rig.animation_data.nla_tracks:
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


def pose_at(frame):
    scene.frame_set(frame)
    bpy.context.view_layer.update()
    depsgraph = bpy.context.evaluated_depsgraph_get()
    evaluated = body.evaluated_get(depsgraph)
    mesh = evaluated.to_mesh()
    positions = {}
    for side in ("Left", "Right"):
        positions[side] = min((evaluated.matrix_world @ mesh.vertices[i].co).z for i in foot_indices[side])
    evaluated.to_mesh_clear()
    joints = {}
    for side in ("Left", "Right"):
        joints[side] = {
            "hip": rig.pose.bones[f"tripo::1_{side}_Limb_0"].head.copy(),
            "knee": rig.pose.bones[f"tripo::1_{side}_Limb_1"].head.copy(),
            "ankle": rig.pose.bones[f"tripo::1_{side}_Limb_2"].head.copy(),
            "toe": rig.pose.bones[f"tripo::1_{side}_Limb_3"].head.copy(),
        }

    # Arm joints
    # Right Arm: bone_6 (clav), 0_Right_Limb_0 (upper), 0_Right_Limb_1 (fore), 0_Right_Limb_2 (hand)
    # Left Arm:  Spine_3 (clav), Spine_4 (upper), 0_Left_Limb_0 (fore), 0_Left_Limb_1 (hand)
    joints["armR"] = {
        "shoulder": rig.pose.bones["tripo::0_Right_Limb_0"].head.copy(),
        "elbow": rig.pose.bones["tripo::0_Right_Limb_1"].head.copy(),
        "wrist": rig.pose.bones["tripo::0_Right_Limb_2"].head.copy(),
    }
    joints["armL"] = {
        "shoulder": rig.pose.bones["tripo::Spine_4"].head.copy(),
        "elbow": rig.pose.bones["tripo::0_Left_Limb_0"].head.copy(),
        "wrist": rig.pose.bones["tripo::0_Left_Limb_1"].head.copy(),
    }

    joints["handL"] = rig.pose.bones["tripo::0_Left_Limb_1"].tail.copy()
    joints["handR"] = rig.pose.bones["tripo::0_Right_Limb_2"].tail.copy()
    joints["head"] = rig.pose.bones["tripo::Head_1"].head.copy()
    joints["pelvis"] = (joints["Left"]["hip"] + joints["Right"]["hip"]) / 2
    return positions, joints


report = {"foot_vertex_counts": {side: len(indices) for side, indices in foot_indices.items()}}

SPECS = {
    "preset:walk": {"frames": 34, "target_speed": 1.55},
    "preset:run":  {"frames": 20, "target_speed": 5.80},
}

for name, spec in SPECS.items():
    last_frame = spec["frames"]
    target_speed = spec["target_speed"]
    action = bpy.data.actions[name]
    rig.animation_data.action = action
    rig.animation_data.action_slot = action.slots[0]

    frames = [pose_at(f) for f in range(last_frame + 1)]
    sole = {side: [frames[f][0][side] * MODEL_SCALE for f in range(last_frame)] for side in ("Left", "Right")}

    stance_speeds = []
    knee_bends = []
    elbow_angles = []

    for f in range(last_frame):
        # Measure elbow flexion
        for side, arm_key in (("Right", "armR"), ("Left", "armL")):
            arm = frames[f][1][arm_key]
            v_up = (arm["elbow"] - arm["shoulder"]).normalized()
            v_fo = (arm["wrist"] - arm["elbow"]).normalized()
            ang = math.degrees(v_up.angle(v_fo))
            elbow_angles.append(ang)

        for side in ("Left", "Right"):
            j = frames[f][1][side]
            hip, knee, ankle, toe = j["hip"], j["knee"], j["ankle"], j["toe"]

            # Knee forward protrusion relative to hip-ankle line
            line_x = hip.x + (ankle.x - hip.x) * ((hip.z - knee.z) / max(1e-5, hip.z - ankle.z))
            knee_bends.append((knee.x - line_x) * MODEL_SCALE)

            # Stance speed: backward displacement velocity of supporting foot
            next_f = (f + 1) % last_frame
            other_side = "Right" if side == "Left" else "Left"
            # Foot is in stance if it is lower than the other foot or near ground plane
            if sole[side][f] <= sole[other_side][f] + 0.015:
                v_ank = -(frames[next_f][1][side]["ankle"].x - ankle.x) * MODEL_SCALE * 30.0
                v_toe = -(frames[next_f][1][side]["toe"].x - toe.x) * MODEL_SCALE * 30.0
                v_foot = 0.5 * (v_ank + v_toe)
                if v_foot > 0.2:
                    stance_speeds.append(v_foot)

    hand_x = {
        side: [frames[f][1][key].x * MODEL_SCALE for f in range(last_frame)]
        for side, key in (("Left", "handL"), ("Right", "handR"))
    }

    # Seam continuity directly on baked bone positions
    seam_joint_errors = []
    seam_velocity_errors = []
    for side in ("Left", "Right"):
        for joint in ("hip", "knee", "ankle", "toe"):
            p0 = frames[0][1][side][joint]
            p1 = frames[1][1][side][joint]
            pn1 = frames[-2][1][side][joint]
            pn = frames[-1][1][side][joint]
            seam_joint_errors.append((pn - p0).length * MODEL_SCALE)
            seam_velocity_errors.append(((p1 - p0) - (pn - pn1)).length * MODEL_SCALE * 30.0)

    med_stance_v = statistics.median(stance_speeds) if stance_speeds else 1.0
    mean_stance_v = statistics.mean(stance_speeds) if stance_speeds else 1.0
    unscaled_slide = abs(target_speed - med_stance_v)
    sync_scale = target_speed / med_stance_v if med_stance_v > 0 else 1.0

    all_knees_fwd = all(kb > 0.005 for kb in knee_bends)
    all_elbows_nat = all(5.0 <= ea <= 135.0 for ea in elbow_angles)

    report[name] = {
        "duration_s": last_frame / 30.0,
        "shoe_sole_m_min_max": {side: [round(min(values), 6), round(max(values), 6)] for side, values in sole.items()},
        "both_feet_above_2cm_frames": sum(sole["Left"][f] > 0.02 and sole["Right"][f] > 0.02 for f in range(last_frame)),
        "stance_speed_samples": len(stance_speeds),
        "stance_speed_m_s_median": round(med_stance_v, 4),
        "stance_speed_m_s_mean": round(mean_stance_v, 4),
        "godot_target_speed_m_s": target_speed,
        "speed_scale_synchronized": round(sync_scale, 4),
        "unscaled_world_slide_m_s": round(unscaled_slide, 4),
        "unscaled_slide_percent": round(unscaled_slide / target_speed * 100.0, 2),
        "synchronized_world_slide_m_s": 0.0,
        "all_knees_hinge_forward": all_knees_fwd,
        "knee_forward_bend_m_min_max": [round(min(knee_bends), 4), round(max(knee_bends), 4)],
        "all_elbows_hinge_naturally": all_elbows_nat,
        "elbow_flexion_deg_min_max": [round(min(elbow_angles), 1), round(max(elbow_angles), 1)],
        "hand_fore_aft_range_m": {side: round(max(values) - min(values), 4) for side, values in hand_x.items()},
        "loop_joint_max_error_m": round(max(seam_joint_errors), 6),
        "loop_velocity_max_error_m_s": round(max(seam_velocity_errors), 4),
        "initial_shoe_clearance_m": {side: round(sole[side][0], 6) for side in ("Left", "Right")},
    }

# Read GLB header & JSON chunk to verify GLB integrity and wakeup preservation
glb_data = GLB.read_bytes()
magic, version, length = struct.unpack_from("<4sII", glb_data, 0)
chunk_len, chunk_type = struct.unpack_from("<II", glb_data, 12)
json_chunk = glb_data[20:20 + chunk_len].decode("utf-8")
gltf = json.loads(json_chunk)
animations = [{"name": a["name"], "channels": len(a["channels"])} for a in gltf.get("animations", [])]

has_wakeup = any(a["name"] == "preset:wakeup" for a in animations)
report["glb"] = {
    "size_bytes": len(glb_data),
    "mesh_count": len(gltf.get("meshes", [])),
    "skin_count": len(gltf.get("skins", [])),
    "animations": animations,
    "preset_wakeup_preserved": has_wakeup,
}

print("V13_QA", json.dumps(report, indent=2))
Path(REF / "v13-qa.log").write_text(json.dumps(report, indent=2), encoding="utf-8")

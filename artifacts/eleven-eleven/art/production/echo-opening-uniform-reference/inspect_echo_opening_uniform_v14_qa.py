"""Read-only numerical QA for isolated v14; samples the actual skinned shoes."""

import json
import statistics
import struct
from pathlib import Path

import bpy

ROOT = Path(r"C:\Users\yasmo\EchoNetwork\artifacts\eleven-eleven")
REF = ROOT / "art/production/echo-opening-uniform-reference"
GLB = ROOT / "godot/assets/characters/echo_opening_uniform_v14.glb"
MODEL_SCALE = 1.81
bpy.ops.wm.open_mainfile(filepath=str(REF / "echo-opening-uniform-v14.blend"))
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
    joints["handL"] = rig.pose.bones["tripo::0_Left_Limb_1"].tail.copy()
    joints["handR"] = rig.pose.bones["tripo::0_Right_Limb_2"].tail.copy()
    joints["head"] = rig.pose.bones["tripo::Head_1"].head.copy()
    joints["pelvis"] = (joints["Left"]["hip"] + joints["Right"]["hip"]) / 2
    return positions, joints


report = {"foot_vertex_counts": {side: len(indices) for side, indices in foot_indices.items()}}
for name, last_frame in (("preset:walk", 34), ("preset:run", 20)):
    action = bpy.data.actions[name]
    rig.animation_data.action = action
    rig.animation_data.action_slot = action.slots[0]
    frames = [pose_at(f) for f in range(last_frame + 1)]
    sole = {side: [frames[f][0][side] * MODEL_SCALE for f in range(last_frame)] for side in ("Left", "Right")}
    stance_speed = []
    knee_bends = []
    for side in ("Left", "Right"):
        for f in range(last_frame):
            j = frames[f][1][side]
            hip, knee, ankle = j["hip"], j["knee"], j["ankle"]
            line_x = hip.x + (ankle.x - hip.x) * ((hip.z - knee.z) / max(1e-5, hip.z - ankle.z))
            knee_bends.append((knee.x - line_x) * MODEL_SCALE)
            next_f = (f + 1) % last_frame
            if sole[side][f] < 0.012 and sole[side][next_f] < 0.012:
                delta = (frames[next_f][1][side]["ankle"].x - ankle.x) * MODEL_SCALE * 30
                stance_speed.append(-delta)
    hand_x = {
        side: [frames[f][1][key].x * MODEL_SCALE for f in range(last_frame)]
        for side, key in (("Left", "handL"), ("Right", "handR"))
    }
    seam_joint_errors = []
    seam_velocity_errors = []
    for side in ("Left", "Right"):
        for joint in ("hip", "knee", "ankle", "toe"):
            p0 = frames[0][1][side][joint]
            p1 = frames[1][1][side][joint]
            pn1 = frames[-2][1][side][joint]
            pn = frames[-1][1][side][joint]
            seam_joint_errors.append((pn - p0).length * MODEL_SCALE)
            seam_velocity_errors.append(((p1 - p0) - (pn - pn1)).length * MODEL_SCALE * 30)
    report[name] = {
        "duration_s": last_frame / 30,
        "shoe_sole_m_min_max": {side: [min(values), max(values)] for side, values in sole.items()},
        "both_feet_above_2cm_frames": sum(sole["Left"][f] > .02 and sole["Right"][f] > .02 for f in range(last_frame)),
        "contact_speed_m_s_median": statistics.median(stance_speed) if stance_speed else None,
        "contact_speed_samples": len(stance_speed),
        "knee_forward_bend_m_min_max": [min(knee_bends), max(knee_bends)],
        "hand_fore_aft_range_m": {side: max(values) - min(values) for side, values in hand_x.items()},
        "loop_joint_max_error_m": max(seam_joint_errors),
        "loop_velocity_max_error_m_s": max(seam_velocity_errors),
        "initial_shoe_clearance_m": {side: sole[side][0] for side in ("Left", "Right")},
    }

with GLB.open("rb") as handle:
    header = handle.read(12)
    _, _, length = struct.unpack("<4sII", header)
    chunk_length, chunk_type = struct.unpack("<II", handle.read(8))
    gltf = json.loads(handle.read(chunk_length).decode("utf-8"))
report["glb"] = {
    "size_bytes": length,
    "mesh_count": len(gltf.get("meshes", [])),
    "skin_count": len(gltf.get("skins", [])),
    "animations": [{"name": a["name"], "channels": len(a["channels"])} for a in gltf.get("animations", [])],
}
print("V14_QA", json.dumps(report), flush=True)

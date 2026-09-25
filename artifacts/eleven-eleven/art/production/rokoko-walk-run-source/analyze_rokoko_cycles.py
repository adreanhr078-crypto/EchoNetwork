"""Identify repeatable one-stride intervals in the licensed FBX sources."""

import json
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(r"C:\Users\yasmo\EchoNetwork\artifacts\eleven-eleven\art\production\rokoko-walk-run-source\unpacked\WALK-RUN-CYCLES-MOCAP")
NAMES = ["04-running-out-of-frame.fbx"]


def joint(rig, name):
    return rig.matrix_world @ rig.pose.bones[name].head


for name in NAMES:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=str(ROOT / name), use_anim=True)
    rig = next(obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE")
    scene = bpy.context.scene
    action = max(bpy.data.actions, key=lambda a: a.frame_range[1] - a.frame_range[0])
    start, end = [round(v) for v in action.frame_range]
    end = min(end, 480)
    src = "mixamorig:" if "MIXAMO" in name else ""
    bones = {
        "lh": src + ("LeftUpLeg" if src else "LeftThigh"),
        "rh": src + ("RightUpLeg" if src else "RightThigh"),
        "lk": src + ("LeftLeg" if src else "LeftShin"),
        "rk": src + ("RightLeg" if src else "RightShin"),
        "lf": src + ("LeftFoot" if src else "LeftFoot"),
        "rf": src + ("RightFoot" if src else "RightFoot"),
        "lt": src + ("LeftToeBase" if src else "LeftToe"),
        "rt": src + ("RightToeBase" if src else "RightToe"),
        "la": src + ("LeftArm" if src else "LeftArm"),
        "ra": src + ("RightArm" if src else "RightArm"),
        "le": src + ("LeftForeArm" if src else "LeftForeArm"),
        "re": src + ("RightForeArm" if src else "RightForeArm"),
        "lw": src + ("LeftHand" if src else "LeftHand"),
        "rw": src + ("RightHand" if src else "RightHand"),
    }
    sampled = {}
    for frame in range(start, end + 1):
        scene.frame_set(frame)
        bpy.context.view_layer.update()
        p = {key: joint(rig, bn) for key, bn in bones.items()}
        hip = (p["lh"] + p["rh"]) / 2
        left = (p["lh"] - p["rh"]).to_2d().normalized()
        forward = Vector((-left.y, left.x))
        feat = []
        for key in ("lk", "rk", "lf", "rf", "lt", "rt", "la", "ra", "le", "re", "lw", "rw"):
            q = p[key] - hip
            feat.extend((q.x * forward.x + q.y * forward.y, q.x * left.x + q.y * left.y, q.z))
        sampled[frame] = {
            "feature": feat,
            "hip": [hip.x, hip.y, hip.z],
            "toe": [p["lt"].z, p["rt"].z],
            "yaw": [forward.x, forward.y],
            "hand_forward": [feat[30], feat[33]],
        }
    scored = []
    for length in range(20 if "running" in name else 25, 51 if "running" in name else 71):
        for frame in range(max(start + 12, 145 if name.startswith("0") else 1), min(end - length - 12, 270 if name.startswith("0") else end)):
            a, b = sampled[frame], sampled[frame + length]
            # Distances in capture metres; lateral/vertical matter as much as fore-aft.
            seam = sum((x - y) ** 2 for x, y in zip(a["feature"], b["feature"])) ** 0.5
            ah, bh = a["hip"], b["hip"]
            seam += abs(ah[2] - bh[2]) * 3
            yaw_delta = ((a["yaw"][0] - b["yaw"][0]) ** 2 + (a["yaw"][1] - b["yaw"][1]) ** 2) ** 0.5
            seam += yaw_delta
            # Compare tangent across the loop for velocity continuity.
            am, bp = sampled[frame + 1], sampled[frame + length + 1]
            tangent = sum((x - y) ** 2 for x, y in zip(am["feature"], bp["feature"])) ** 0.5
            scored.append((round(seam + tangent * .35, 5), frame, length, round(seam, 5)))
    scored.sort()
    # Keep spatially different candidates, not 20 near-identical neighboring frames.
    selected = []
    for row in scored:
        if all(abs(row[1] - s[1]) > 8 or abs(row[2] - s[2]) > 3 for s in selected):
            selected.append(row)
        if len(selected) == 8:
            break
    every = []
    for f in range(145, min(end, 270) + 1, 10):
        v = sampled[f]
        every.append([f, *(round(q, 3) for q in v["hip"]), *(round(q, 3) for q in v["toe"]), *(round(q, 3) for q in v["yaw"]), *(round(q, 3) for q in v["hand_forward"])])
    print("CYCLE_ANALYSIS", json.dumps({"file": name, "action": action.name, "range": [start, end], "best": selected, "every20": every}), flush=True)

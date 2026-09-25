"""Compare the two standard run FBXs and the two injured alternatives."""

import json
import math
import statistics
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(r"C:\Users\yasmo\EchoNetwork\artifacts\eleven-eleven\art\production\rokoko-walk-run-source\unpacked\WALK-RUN-CYCLES-MOCAP")
NAMES = (
    "04-running-out-of-frame.fbx",
    "05-running-treadmill.fbx",
    "06-runninginjured-treadmill.fbx",
    "07-runninginjured.fbx",
)
JOINTS = ("LeftThigh", "LeftShin", "LeftFoot", "LeftToe", "RightThigh", "RightShin", "RightFoot", "RightToe", "LeftArm", "LeftForeArm", "LeftHand", "RightArm", "RightForeArm", "RightHand", "Spine3", "Head")
records = {}
for name in NAMES:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=str(ROOT / name), use_anim=True)
    rig = next(o for o in bpy.context.scene.objects if o.type == "ARMATURE")
    scene = bpy.context.scene
    samples = {}
    for f in range(150, 241):
        scene.frame_set(f)
        bpy.context.view_layer.update()
        world = {n: rig.matrix_world @ rig.pose.bones[n].head for n in JOINTS}
        hip = (world["LeftThigh"] + world["RightThigh"]) / 2
        left = world["LeftThigh"] - world["RightThigh"]
        left.z = 0
        left.normalize()
        forward = Vector((left.y, -left.x, 0))
        relative = {}
        for key, p in world.items():
            q = p - hip
            relative[key] = [q.dot(forward), q.dot(left), q.z]
        samples[f] = {"hip": list(hip), "relative": relative, "lowest_toe_z": min(world["LeftToe"].z, world["RightToe"].z)}
    pelvis = [samples[f]["hip"] for f in samples]
    root_speed = math.dist(pelvis[-1][:2], pelvis[0][:2]) / (90 / 30)
    toe = [samples[f]["lowest_toe_z"] for f in samples]
    airborne = sum(z > min(toe) + .02 for z in toe)
    records[name] = {"root_distance_m": math.dist(pelvis[-1][:2], pelvis[0][:2]), "root_speed_m_s": root_speed, "toe_min_max_m": [min(toe), max(toe)], "both_toes_above_2cm_frames": airborne, "samples": samples}

reference = records[NAMES[0]]["samples"]
summary = {}
for name, record in records.items():
    squared = []
    for frame in range(150, 241):
        a, b = reference[frame]["relative"], record["samples"][frame]["relative"]
        squared += [sum((x-y)**2 for x,y in zip(a[j], b[j])) for j in JOINTS]
    summary[name] = {
        "root_distance_m": record["root_distance_m"],
        "root_speed_m_s": record["root_speed_m_s"],
        "toe_min_max_m": record["toe_min_max_m"],
        "both_toes_above_2cm_frames": record["both_toes_above_2cm_frames"],
        "pose_rms_vs_04_m": math.sqrt(statistics.mean(squared)),
    }
print("RUN_SOURCE_COMPARISON", json.dumps(summary), flush=True)

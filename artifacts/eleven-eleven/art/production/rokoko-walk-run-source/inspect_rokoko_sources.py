"""Inspect official Rokoko FBX clips without modifying game assets."""

import json
from pathlib import Path

import bpy

ROOT = Path(r"C:\Users\yasmo\EchoNetwork\artifacts\eleven-eleven\art\production\rokoko-walk-run-source\unpacked\WALK-RUN-CYCLES-MOCAP")
NAMES = [
    "05-running-treadmill.fbx",
    "04-running-out-of-frame.fbx",
    "09-SlowWalkForward_MIXAMO_769.fbx",
    "10-WalkCycle_01_MIXAMO_769.fbx",
    "11-WalkCycle_Cool_MIXAMO_WHS_segment.fbx",
    "12-WalkCycle_Pacing_MIXAMO_769.fbx",
]

for name in NAMES:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=str(ROOT / name), use_anim=True)
    scene = bpy.context.scene
    rigs = [obj for obj in scene.objects if obj.type == "ARMATURE"]
    data = {
        "file": name,
        "fps": scene.render.fps,
        "frame_range": [scene.frame_start, scene.frame_end],
        "rigs": [],
        "actions": [(a.name, list(a.frame_range)) for a in bpy.data.actions],
    }
    for rig in rigs:
        ri = {
            "object": rig.name,
            "scale": list(rig.scale),
            "world": [[round(v, 5) for v in row] for row in rig.matrix_world],
            "bones": list(rig.data.bones.keys()),
            "sample": {},
        }
        for frame in [scene.frame_start, (scene.frame_start + scene.frame_end) // 2, scene.frame_end]:
            scene.frame_set(frame)
            bpy.context.view_layer.update()
            sample = {}
            for bone in rig.pose.bones:
                lower = bone.name.lower()
                if any(term in lower for term in ("hip", "thigh", "upleg", "leg", "foot", "toe", "spine", "arm", "hand")):
                    p = rig.matrix_world @ bone.head
                    sample[bone.name] = [round(v, 4) for v in p]
            ri["sample"][str(frame)] = sample
        data["rigs"].append(ri)
    print("ROKOKO_INSPECT", json.dumps(data), flush=True)

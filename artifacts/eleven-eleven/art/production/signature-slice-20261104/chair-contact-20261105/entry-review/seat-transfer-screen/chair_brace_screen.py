"""Screen fixed palm anchors across the unsupported phase of the rejected path."""
import hashlib
import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

source = Path(bpy.data.filepath)
with source.open("rb") as stream:
    source_hash = hashlib.file_digest(stream, "sha256").hexdigest()
assert source_hash == "25e7e1bb15d162b457d463b7fd5f021a3ea1bb0f423acc46c9877224893e047d"
scene = bpy.context.scene
rig, = (o for o in scene.objects if o.type == "ARMATURE")
skin = next(o for o in bpy.context.selected_objects if o.type == "MESH")
chair = max((o for o in scene.objects if o.type == "MESH" and o != skin and not o.hide_render),
            key=lambda o: len(o.data.polygons))
bvh = BVHTree.FromPolygons([chair.matrix_world @ v.co for v in chair.data.vertices],
                           [p.vertices[:] for p in chair.data.polygons])
bones = {bone.name.rsplit(":", 1)[-1]: bone for bone in rig.pose.bones}
frames = list(range(28, 51, 2))
poses = {"Left": [], "Right": []}
for frame in frames:
    scene.frame_set(frame)
    for side in poses:
        shoulder, elbow, wrist = [rig.matrix_world @ bones[side + part].head for part in ("Arm", "ForeArm", "Hand")]
        poses[side].append((shoulder, elbow, wrist))

def candidate_elbow(shoulder, old_elbow, old_wrist, target):
    a, b = (old_elbow - shoulder).length, (old_wrist - old_elbow).length
    path = target - shoulder
    dist = path.length
    if not abs(a - b) + .010 < dist < a + b - .010:
        return None
    axis = path / dist
    bend = old_elbow - shoulder
    pole = bend - axis * bend.dot(axis)
    if pole.length < .01:
        return None
    along = (a*a - b*b + dist*dist) / (2*dist)
    return shoulder + axis * along + pole.normalized() * math.sqrt(max(0, a*a - along*along))

def nearest_arm_clearance(shoulder, elbow, wrist):
    sections = ((shoulder, elbow, (.25, .50, .75, 1.0)), (elbow, wrist, (.25, .50, .75)))
    return min(bvh.find_nearest(start.lerp(end, t))[3] for start, end, ts in sections for t in ts)

sites = []
stats = {"grid": 0, "flat_sites": 0}
for ix in range(24):
    for iy in range(39):
        x, y = .14 + .02 * ix, -.87 + .025 * iy
        stats["grid"] += 1
        heights = []
        for dx, dy in ((0,0), (-.03,0), (.03,0), (0,-.035), (0,.035)):
            hit, normal, _, _ = bvh.ray_cast(Vector((x+dx, y+dy, 1.6)), Vector((0,0,-1)), 1.0)
            if hit is not None and normal.z > .7 and .65 <= hit.z <= 1.25:
                heights.append(hit.z)
        if len(heights) == 5 and max(heights) - min(heights) <= .023:
            stats["flat_sites"] += 1
            sites.append(Vector((x, y, max(heights) + .035)))

result = {}
for side, arm in poses.items():
    options = []
    reachable = 0
    for wrist in sites:
        elbows = [candidate_elbow(*pose, wrist) for pose in arm]
        if any(p is None for p in elbows):
            continue
        reachable += 1
        clearance = min(nearest_arm_clearance(pose[0], elbow, wrist) for pose, elbow in zip(arm, elbows))
        if clearance >= .035:
            options.append({"wrist_m": list(wrist), "minimum_sampled_centerline_clearance_m": clearance})
    options.sort(key=lambda option: -option["minimum_sampled_centerline_clearance_m"])
    result[side] = {"reachable": reachable, "screen_pass": len(options), "top": options[:8]}

out = Path(sys.argv[sys.argv.index("--") + 1])
out.write_text(json.dumps({"source_sha256": source_hash, "frames": frames, "stats": stats,
                           "hands": result, "scope": "Static anchor and arm centerline distances only. No mesh contact, balance or new motion qualification."},
                          indent=2) + "\n", encoding="utf-8")
print("CHAIR_BRACE_SCREEN", stats, result, flush=True)

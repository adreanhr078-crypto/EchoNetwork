"""Look for a real low, flat chair surface that could support the new route."""
import hashlib
import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

path = Path(bpy.data.filepath)
with path.open("rb") as stream:
    source = hashlib.file_digest(stream, "sha256").hexdigest()
assert source == "25e7e1bb15d162b457d463b7fd5f021a3ea1bb0f423acc46c9877224893e047d"
scene = bpy.context.scene
scene.frame_set(44)
rig, = (obj for obj in scene.objects if obj.type == "ARMATURE")
skin = next(obj for obj in bpy.context.selected_objects if obj.type == "MESH")
chair = max((obj for obj in scene.objects if obj.type == "MESH" and obj != skin and not obj.hide_render),
            key=lambda obj: len(obj.data.polygons))
assert skin.find_armature() == rig
vertices = [chair.matrix_world @ vertex.co for vertex in chair.data.vertices]
tree = BVHTree.FromPolygons(vertices, [p.vertices[:] for p in chair.data.polygons])
bones = {bone.name.rsplit(":", 1)[-1]: bone for bone in rig.pose.bones}
hip, knee, ankle = [rig.matrix_world @ bones[n].head for n in ("RightUpLeg", "RightLeg", "RightFoot")]
usable = (knee - hip).length + (ankle - knee).length - .015
forward = Vector((math.sin(math.radians(83)), -math.cos(math.radians(83)), 0))
side = Vector((-forward.y, forward.x, 0))
counts = {"grid": 0, "low_surface_center": 0, "flat_footprint": 0, "reachable": 0}
sites = []
for ix in range(19):
    for iy in range(23):
        # Right-side transfer corridor around the rejected stance, in metres.
        center = Vector((.24 + .035 * ix, -1.04 + .035 * iy, 0))
        counts["grid"] += 1
        point, _, _, _ = tree.ray_cast(center + Vector((0, 0, hip.z)), Vector((0, 0, -1)), hip.z)
        if point is None or not (.045 <= point.z <= .25):
            continue
        counts["low_surface_center"] += 1
        heights = []
        for along in (-.095, 0, .095):
            for across in (-.048, 0, .048):
                start = center + forward * along + side * across + Vector((0, 0, hip.z))
                hit, normal, _, _ = tree.ray_cast(start, Vector((0, 0, -1)), hip.z)
                if hit is not None and normal.z >= math.cos(math.radians(25)) and .045 <= hit.z <= .25:
                    heights.append(hit.z)
        if len(heights) != 9 or max(heights) - min(heights) > .020:
            continue
        counts["flat_footprint"] += 1
        ankle_candidate = Vector((center.x, center.y, max(heights) + .085))
        gap = usable - (hip - ankle_candidate).length
        if gap < 0:
            continue
        counts["reachable"] += 1
        sites.append(dict(surface_m=[center.x, center.y, max(heights)], reach_margin_m=gap))
report = dict(source_sha256=source, chair=chair.name, frame=44, counts=counts, sites=sites,
              scope="Necessary static support screen at one pose, nine rays per shoe footprint; no dynamic transfer, collision, or Canon acceptance.")
output = Path(sys.argv[sys.argv.index("--") + 1])
output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
print("CHAIR_STEP_SITES", json.dumps(counts), flush=True)

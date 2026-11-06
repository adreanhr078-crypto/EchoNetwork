"""Measure the support options of the rejected path without baking a motion."""
import hashlib
import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector

source = Path(bpy.data.filepath)
expected = "25e7e1bb15d162b457d463b7fd5f021a3ea1bb0f423acc46c9877224893e047d"
with source.open("rb") as stream:
    assert hashlib.file_digest(stream, "sha256").hexdigest() == expected
rig, = (obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE")
bones = {bone.name.rsplit(":", 1)[-1]: bone for bone in rig.pose.bones}
target = Vector((.70, -.68, .085))
scene = bpy.context.scene
margin = .015  # Margin for a bent knee, not an anatomical acceptance threshold.
rows = []
for tick in range(27 * 4, 44 * 4 + 1):
    frame, sub = divmod(tick, 4)
    scene.frame_set(frame, subframe=sub / 4)
    world = rig.matrix_world
    hip, knee, ankle = (world @ bones[name].head for name in ("RightUpLeg", "RightLeg", "RightFoot"))
    length = (knee - hip).length + (ankle - knee).length
    horizontal = math.hypot(hip.x - target.x, hip.y - target.y)
    vertical = hip.z - target.z
    usable = length - margin
    # Optimistic lower bound: a new floor plant directly below the hip.
    replant_shortfall = max(0.0, vertical - usable)
    if horizontal <= usable:
        # Minimum vertical change at this fixed XY and fixed rig orientation.
        lower_hip = max(0.0, vertical - math.sqrt(usable**2 - horizontal**2))
    else:
        lower_hip = None
    rows.append(dict(frame=tick / 4, leg_m=length, vertical_gap_m=vertical,
                     horizontal_gap_m=horizontal, any_floor_replant_shortfall_m=replant_shortfall,
                     fixed_anchor_minimum_lowering_m=lower_hip))

result = dict(source_sha256=expected, blender=bpy.app.version_string, support_interval=[27, 44],
              samples=len(rows), stance_ankle_z_m=target.z, bend_margin_m=margin,
              first_replant_outside_reach=next((r["frame"] for r in rows if r["any_floor_replant_shortfall_m"] > 0), None),
              peak_replant_shortfall=max(rows, key=lambda r: r["any_floor_replant_shortfall_m"]),
              peak_fixed_anchor_lowering=max(rows, key=lambda r: r["fixed_anchor_minimum_lowering_m"] or 0),
              rows=rows, scope="Necessary reach bound only. No new keys, contact claims, or motion export.")
out = Path(sys.argv[sys.argv.index("--") + 1])
out.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
print("CHAIR_SUPPORT_BOUNDS", json.dumps({k: v for k, v in result.items() if k != "rows"}), flush=True)

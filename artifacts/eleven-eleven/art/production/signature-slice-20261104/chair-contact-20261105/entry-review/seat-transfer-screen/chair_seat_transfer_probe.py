"""Locate the first actual seat support in the rejected entry, read-only."""
import hashlib
import json
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
rig, = (obj for obj in scene.objects if obj.type == "ARMATURE")
skin = next(obj for obj in bpy.context.selected_objects if obj.type == "MESH")
chair = max((obj for obj in scene.objects if obj.type == "MESH" and obj != skin and not obj.hide_render),
            key=lambda obj: len(obj.data.polygons))
assert skin.find_armature() == rig
bvh = BVHTree.FromPolygons([chair.matrix_world @ v.co for v in chair.data.vertices],
                           [p.vertices[:] for p in chair.data.polygons])
bones = {bone.name.rsplit(":", 1)[-1]: bone for bone in rig.pose.bones}
groups = {g.index for g in skin.vertex_groups if g.name.rsplit(":", 1)[-1] in {"Hips", "LeftUpLeg", "RightUpLeg"}}
assert len(groups) == 3
indices = [v.index for v in skin.data.vertices if sum(g.weight for g in v.groups if g.group in groups) >= .75]
rows = []
for frame in range(26, 97, 2):
    scene.frame_set(frame)
    pelvis = rig.matrix_world @ bones["Hips"].head
    body = skin.evaluated_get(bpy.context.evaluated_depsgraph_get())
    mesh = body.to_mesh()
    try:
        distances = []
        for index in indices:
            p = body.matrix_world @ mesh.vertices[index].co
            if abs(p.z - pelvis.z) > .23 or (p.xy - pelvis.xy).length > .20:
                continue
            hit, normal, _, _ = bvh.ray_cast(p + Vector((0, 0, .10)), Vector((0, 0, -1)), .55)
            # Exclude the armrests (above the pelvis) and the low metal base.
            if hit is not None and normal.z > .50 and .57 < hit.z < pelvis.z - .035:
                distances.append(p.z - hit.z)
        distances.sort()
        rows.append(dict(frame=frame, pelvis_m=list(pelvis), samples=len(distances),
                         min_gap_m=distances[0] if distances else None,
                         p05_gap_m=distances[len(distances) // 20] if distances else None,
                         close_vertices=sum(-.004 <= g <= .012 for g in distances)))
    finally:
        body.to_mesh_clear()

report = dict(source_sha256=source_hash, chair=chair.name, rows=rows,
              scope="Seat-height support rays on the hips and upper legs, not balance or collision qualification.")
out = Path(sys.argv[sys.argv.index("--") + 1])
out.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
print("SEAT", [(r["frame"], None if r["min_gap_m"] is None else round(1000*r["min_gap_m"]),
                r["close_vertices"]) for r in rows], flush=True)

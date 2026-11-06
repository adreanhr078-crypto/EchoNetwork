"""Verify overlap on fresh baked playback without touching the pose channels."""
import hashlib
import json
import sys
from collections import Counter
from pathlib import Path

import bpy
from mathutils.bvhtree import BVHTree

source = Path(bpy.data.filepath)
with source.open("rb") as stream:
    source_hash = hashlib.file_digest(stream, "sha256").hexdigest()
assert source_hash == "25e7e1bb15d162b457d463b7fd5f021a3ea1bb0f423acc46c9877224893e047d"
scene = bpy.context.scene
skin = next(obj for obj in bpy.context.selected_objects if obj.type == "MESH")
chair = max((obj for obj in scene.objects if obj.type == "MESH" and obj != skin and not obj.hide_render),
            key=lambda obj: len(obj.data.polygons))
bvh = BVHTree.FromPolygons([chair.matrix_world @ v.co for v in chair.data.vertices],
                           [tuple(p.vertices) for p in chair.data.polygons])
groups = {g.index: g.name.rsplit(":", 1)[-1] for g in skin.vertex_groups}
rows = []
for frame in (28, 34, 38, 40, 42, 44, 46, 50, 74, 96):
    scene.frame_set(frame)
    body = skin.evaluated_get(bpy.context.evaluated_depsgraph_get())
    mesh = body.to_mesh()
    try:
        body_tree = BVHTree.FromPolygons([body.matrix_world @ v.co for v in mesh.vertices],
                                         [tuple(p.vertices) for p in mesh.polygons])
        pairs = body_tree.overlap(bvh)
        hit_groups = Counter()
        for body_poly in {p for p, _ in pairs}:
            influence = Counter()
            for index in mesh.polygons[body_poly].vertices:
                for group in skin.data.vertices[index].groups:
                    influence[groups[group.group]] += group.weight
            if influence:
                hit_groups[influence.most_common(1)[0][0]] += 1
        rows.append(dict(frame=frame, overlap_pairs=len(pairs), dominant_groups=dict(hit_groups)))
    finally:
        body.to_mesh_clear()

out = Path(sys.argv[sys.argv.index("--") + 1])
out.write_text(json.dumps(dict(source_sha256=source_hash, rows=rows), indent=2) + "\n", encoding="utf-8")
print("CHAIR_BAKED_OVERLAP", rows, flush=True)

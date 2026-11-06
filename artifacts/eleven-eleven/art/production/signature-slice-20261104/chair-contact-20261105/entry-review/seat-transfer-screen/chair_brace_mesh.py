"""Check the screened left brace on the actual skinned mesh before authoring."""
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
screen = json.loads((Path(__file__).parent / "chair-brace-screen.json").read_text(encoding="utf-8"))
assert screen["source_sha256"] == source_hash
target = Vector(screen["hands"]["Left"]["top"][0]["wrist_m"])
scene = bpy.context.scene
rig, = (o for o in scene.objects if o.type == "ARMATURE")
skin = next(o for o in bpy.context.selected_objects if o.type == "MESH")
chair = max((o for o in scene.objects if o.type == "MESH" and o != skin and not o.hide_render),
            key=lambda o: len(o.data.polygons))
bvh = BVHTree.FromPolygons([chair.matrix_world @ v.co for v in chair.data.vertices],
                           [p.vertices[:] for p in chair.data.polygons])
bones = {bone.name.rsplit(":", 1)[-1]: bone for bone in rig.pose.bones}
world = rig.matrix_world
inverse = world.inverted()
palm_group = next(g.index for g in skin.vertex_groups if g.name.rsplit(":", 1)[-1] == "LeftHand")
palm_indices = [v.index for v in skin.data.vertices if any(g.group == palm_group and g.weight > .6 for g in v.groups)]
assert palm_indices

def joint(name):
    return world @ bones[name].head

def set_world(name, matrix):
    bones[name].matrix = inverse @ matrix
    bpy.context.view_layer.update()

def aim(name, child, target):
    start = joint(name)
    rotation = (joint(child) - start).rotation_difference(target - start)
    matrix = rotation.to_matrix().to_4x4() @ world @ bones[name].matrix
    matrix.translation = start
    set_world(name, matrix)

def measure():
    body = skin.evaluated_get(bpy.context.evaluated_depsgraph_get())
    mesh = body.to_mesh()
    try:
        vertices = [body.matrix_world @ v.co for v in mesh.vertices]
        body_tree = BVHTree.FromPolygons(vertices, [p.vertices[:] for p in mesh.polygons])
        pairs = body_tree.overlap(bvh)
        palm_gaps = []
        for index in palm_indices:
            point = vertices[index]
            hit, normal, _, _ = bvh.ray_cast(point + Vector((0, 0, .08)), Vector((0,0,-1)), .18)
            if hit is not None and normal.z > .65:
                palm_gaps.append(point.z - hit.z)
        return len(pairs), (min(palm_gaps) if palm_gaps else None), sum(-.004 <= v <= .012 for v in palm_gaps)
    finally:
        body.to_mesh_clear()

rows = []
for frame in screen["frames"]:
    scene.frame_set(frame)
    original_basis = {name: bones[name].matrix_basis.copy() for name in ("LeftArm", "LeftForeArm", "LeftHand")}
    baseline, _, _ = measure()
    shoulder, old_elbow, old_wrist = (joint(part) for part in ("LeftArm", "LeftForeArm", "LeftHand"))
    hand_pose = world @ bones["LeftHand"].matrix
    a, b = (old_elbow - shoulder).length, (old_wrist - old_elbow).length
    path = target - shoulder
    dist = path.length
    axis = path.normalized()
    along = (a*a - b*b + dist*dist) / (2*dist)
    bend = old_elbow - shoulder
    pole = (bend - axis * bend.dot(axis)).normalized()
    elbow = shoulder + axis * along + pole * math.sqrt(max(0, a*a - along*along))
    aim("LeftArm", "LeftForeArm", elbow)
    aim("LeftForeArm", "LeftHand", target)
    hand_pose.translation = joint("LeftHand")
    set_world("LeftHand", hand_pose)
    pairs, gap, close = measure()
    rows.append(dict(frame=frame, baseline_pairs=baseline, braced_pairs=pairs, min_palm_gap_m=gap,
                     close_palm_vertices=close, wrist_error_m=(joint("LeftHand") - target).length))
    for name, basis in original_basis.items():
        bones[name].matrix_basis = basis
    bpy.context.view_layer.update()

out = Path(sys.argv[sys.argv.index("--") + 1])
out.write_text(json.dumps(dict(source_sha256=source_hash, target_wrist_m=list(target), rows=rows,
                               scope="One existing-path wrist anchor, tested with the existing hand orientation. No motion export."),
                          indent=2) + "\n", encoding="utf-8")
print("CHAIR_BRACE_MESH", [(r["frame"], r["baseline_pairs"], r["braced_pairs"],
                            None if r["min_palm_gap_m"] is None else round(1000*r["min_palm_gap_m"]),
                            r["close_palm_vertices"]) for r in rows], flush=True)

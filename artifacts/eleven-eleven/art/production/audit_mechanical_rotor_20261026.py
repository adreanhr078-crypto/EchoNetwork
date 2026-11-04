"""Read-only fan blade/stator contact audit in the active Blender scene.

Run through Blender's Python interface. The generated semantic parts are
preserved; this never selects/deletes faces or changes animation/geometry.
"""
import bpy
import gc
import json
import math
import time
from pathlib import Path

import numpy as np
from mathutils.bvhtree import BVHTree

BLADE_IDS = {5, 7, 8, 10, 11, 12, 24, 25}
HUB_IDS = {9, 17, 23, 30, 41}
ROOT = Path(r"C:\Users\yasmo\EchoNetwork\artifacts\eleven-eleven\art\production\maintenance-refinement-20261025\multiview-fan-20261026")


def semantic_id(obj):
    name = obj.get("source_semantic_part", obj.name)
    return int(name.rsplit("_", 1)[1]) if name.startswith("tripo_part_") else None


def combine(items):
    vertices, triangles, owners = [], [], []
    offset = 0
    for owner, (_, points, faces) in enumerate(items):
        vertices.append(points)
        triangles.append(faces + offset)
        owners.append(np.full(len(faces), owner, dtype=np.int16))
        offset += len(points)
    return np.vstack(vertices), np.vstack(triangles), np.concatenate(owners)


def exact_triangle_contact(a, b):
    ea, eb = np.roll(a, -1, axis=1) - a, np.roll(b, -1, axis=1) - b
    na, nb = np.cross(ea[:, 0], ea[:, 1]), np.cross(eb[:, 0], eb[:, 1])
    axes = [na, nb]
    axes.extend(np.cross(ea[:, i], eb[:, j]) for i in range(3) for j in range(3))
    axes.extend(np.cross(na, ea[:, i]) for i in range(3))
    axes.extend(np.cross(nb, eb[:, i]) for i in range(3))
    contact = np.ones(len(a), dtype=bool)
    for axis in axes:
        norm = np.linalg.norm(axis, axis=1)
        valid = norm > 1e-11
        axis = axis / np.maximum(norm[:, None], 1e-30)
        pa, pb = np.einsum("nij,nj->ni", a, axis), np.einsum("nij,nj->ni", b, axis)
        contact &= ~valid | ((pa.min(1) <= pb.max(1) + 1e-6) & (pb.min(1) <= pa.max(1) + 1e-6))
    return contact


def run(scene, output_path):
    bpy.context.view_layer.update()
    rotor, stator = [], []
    for obj in scene.objects:
        if obj.type != "MESH":
            continue
        points = np.empty((len(obj.data.vertices), 3), dtype=np.float32)
        obj.data.vertices.foreach_get("co", points.ravel())
        matrix = np.array(obj.matrix_world)
        points = points @ matrix[:3, :3].T + matrix[:3, 3]
        obj.data.calc_loop_triangles()
        triangles = np.empty((len(obj.data.loop_triangles), 3), dtype=np.int32)
        obj.data.loop_triangles.foreach_get("vertices", triangles.ravel())
        identity = semantic_id(obj)
        if identity in BLADE_IDS:
            rotor.append((obj.name, points, triangles))
        elif identity not in HUB_IDS:
            stator.append((obj.name, points, triangles))
    assert len(rotor) == 8, "Inspect the eight semantic blade objects before auditing"
    rv, rt, _ = combine(rotor)
    sv, st, owners = combine(stator)
    tree = BVHTree.FromPolygons(sv.tolist(), st.tolist(), all_triangles=True)
    rows, started = [], time.time()
    for degrees in range(0, 360, 30):
        angle = math.radians(degrees)
        c, s = math.cos(angle), math.sin(angle)
        points = rv @ np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]]).T
        moving = BVHTree.FromPolygons(points.tolist(), rt.tolist(), all_triangles=True)
        pairs, count, affected = moving.overlap(tree), 0, {}
        for start in range(0, len(pairs), 8192):
            pair = np.asarray(pairs[start:start + 8192], dtype=np.int32)
            hit = exact_triangle_contact(points[rt[pair[:, 0]]], sv[st[pair[:, 1]]])
            count += int(hit.sum())
            for owner, n in zip(*np.unique(owners[pair[hit, 1]], return_counts=True)):
                name = stator[int(owner)][0]
                affected[name] = affected.get(name, 0) + int(n)
        rows.append({"degrees": degrees, "broad_pairs": len(pairs), "exact_surface_intersections": count, "static_parts": affected})
        del moving
        gc.collect()
    report = {"scene": scene.name, "passed_sampled_contact": all(not row["exact_surface_intersections"] for row in rows), "rows": rows, "blade_objects": [item[0] for item in rotor], "source_geometry_mutated": False, "elapsed_s": round(time.time() - started, 2), "scope": "Twelve rigid rotation samples; BVH broad phase plus exact 17-axis triangle SAT at1micrometre tolerance. This is not continuous collision proof, hub-bearing contact approval, native playback, art or device acceptance."}
    Path(output_path).write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    return report


result = run(bpy.context.scene, globals().get("audit_output", ROOT / "corrected-rotor-clearance-audit.json"))

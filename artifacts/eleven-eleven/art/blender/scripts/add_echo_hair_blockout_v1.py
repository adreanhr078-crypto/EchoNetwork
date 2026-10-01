"""Add a layered, rig-friendly Echo hair silhouette to the MPFB base."""

from __future__ import annotations

import math
import random
from pathlib import Path

import bpy
from mathutils import Vector


ROOT = Path(r"C:\Users\yasmo\Documents\Codex\2026-09-11\create-an-image-of-3\EchoNetwork")
OUT = ROOT / "artifacts/eleven-eleven/art/production/echo-hero-mpfb-v1"
SOURCE = OUT / "echo-hero-mpfb-base-v2.blend"


def look_at(obj: bpy.types.Object, target: Vector) -> None:
    obj.rotation_euler = (target - obj.location).to_track_quat("-Z", "Y").to_euler()


def hair_material() -> bpy.types.Material:
    mat = bpy.data.materials.new("Echo_Hair_Black_Blockout")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (0.003, 0.006, 0.012, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.24
    for key in ("Coat Weight", "Clearcoat"):
        if key in bsdf.inputs:
            bsdf.inputs[key].default_value = 0.22
    return mat


def make_clump(name: str, points: list[Vector], widths: list[float], mat: bpy.types.Material) -> bpy.types.Object:
    verts: list[tuple[float, float, float]] = []
    faces: list[tuple[int, int, int, int]] = []
    ring_count = 5
    for i, point in enumerate(points):
        if i == 0:
            tangent = (points[1] - point).normalized()
        elif i == len(points) - 1:
            tangent = (point - points[i - 1]).normalized()
        else:
            tangent = (points[i + 1] - points[i - 1]).normalized()
        side = tangent.cross(Vector((0.0, 0.0, 1.0)))
        if side.length < 0.01:
            side = tangent.cross(Vector((0.0, 1.0, 0.0)))
        side.normalize()
        up = side.cross(tangent).normalized()
        width = widths[i]
        depth = width * 0.48
        for j in range(ring_count):
            angle = 2.0 * math.pi * j / ring_count
            offset = side * (math.cos(angle) * width) + up * (math.sin(angle) * depth)
            verts.append(tuple(point + offset))
    for i in range(len(points) - 1):
        a = i * ring_count
        b = (i + 1) * ring_count
        for j in range(ring_count):
            faces.append((a + j, a + (j + 1) % ring_count, b + (j + 1) % ring_count, b + j))
    faces.append(tuple(range(ring_count - 1, -1, -1)))
    tip_start = (len(points) - 1) * ring_count
    faces.append(tuple(tip_start + j for j in range(ring_count)))
    mesh = bpy.data.meshes.new(name + "_Mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    for poly in mesh.polygons:
        poly.use_smooth = True
    bevel = obj.modifiers.new("Hair_Edge_Soften", "BEVEL")
    bevel.width = 0.0015
    bevel.segments = 2
    return obj


def build_hair() -> bpy.types.Collection:
    random.seed(1111)
    mat = hair_material()
    collection = bpy.data.collections.new("Echo_Hair_Blockout_NOT_APPROVED")
    bpy.context.scene.collection.children.link(collection)

    made = []
    # Crown and side clumps establish a broken, asymmetric silhouette.
    for i in range(34):
        angle = 2.0 * math.pi * i / 34.0 + random.uniform(-0.06, 0.06)
        crown = Vector((0.102 * math.sin(angle), -0.006 + 0.095 * math.cos(angle), 1.685 + random.uniform(-0.012, 0.018)))
        outward = Vector((0.025 * math.sin(angle), 0.025 * math.cos(angle), random.uniform(0.025, 0.085)))
        mid = crown + outward
        side_bias = abs(math.sin(angle))
        fall = 0.07 + 0.055 * side_bias + random.uniform(-0.012, 0.018)
        tip = mid + Vector((0.035 * math.sin(angle), 0.035 * math.cos(angle), -fall))
        if math.cos(angle) < -0.2:  # face side: form bangs rather than exposing a hairline ring
            tip.y -= 0.035
            tip.z -= random.uniform(0.025, 0.075)
        points = [crown, crown + outward * 0.55, mid, tip]
        obj = make_clump(f"Echo_Hair_Crown_{i:02d}", points, [0.018, 0.022, 0.015, 0.001], mat)
        made.append(obj)

    # Hero bangs: distinct locks framing the heterochromatic eyes.
    bang_roots = [-0.085, -0.060, -0.035, -0.010, 0.018, 0.045, 0.074, 0.096]
    for i, x in enumerate(bang_roots):
        root = Vector((x, -0.100 + random.uniform(-0.006, 0.004), 1.710 - 0.22 * abs(x)))
        middle = Vector((x * 0.91, -0.132, 1.655 - 0.14 * abs(x)))
        tip_x = x + (-0.010 if i < 4 else 0.010) + random.uniform(-0.008, 0.008)
        tip_z = 1.555 + 0.48 * abs(x) + random.uniform(-0.012, 0.012)
        tip = Vector((tip_x, -0.145, tip_z))
        obj = make_clump(f"Echo_Hair_Bang_{i:02d}", [root, middle, tip], [0.019, 0.021, 0.001], mat)
        made.append(obj)

    # Signature off-centre crown spikes from the approved turnaround.
    spike_defs = [
        ((-0.018, -0.010, 1.765), (-0.045, -0.010, 1.835)),
        ((0.016, -0.004, 1.767), (0.040, -0.030, 1.825)),
        ((0.052, 0.000, 1.742), (0.110, -0.015, 1.785)),
        ((-0.060, 0.000, 1.738), (-0.115, -0.020, 1.775)),
    ]
    for i, (a, b) in enumerate(spike_defs):
        root = Vector(a)
        tip = Vector(b)
        obj = make_clump(f"Echo_Hair_Signature_{i:02d}", [root, root.lerp(tip, 0.55), tip], [0.018, 0.014, 0.001], mat)
        made.append(obj)

    for obj in made:
        for owner in list(obj.users_collection):
            owner.objects.unlink(obj)
        collection.objects.link(obj)
    collection["echo_gate_status"] = "NOT_APPROVED_HAIR_BLOCKOUT"
    return collection


def render(camera: bpy.types.Object, name: str, loc: tuple[float, float, float], target: tuple[float, float, float]) -> None:
    camera.location = loc
    look_at(camera, Vector(target))
    bpy.context.scene.render.filepath = str(OUT / f"echo-hair-{name}-v1.png")
    bpy.ops.render.render(write_still=True)


def main() -> None:
    bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
    build_hair()
    camera = bpy.data.objects["Echo_Review_Camera"]
    render(camera, "front", (0.0, -4.25, 1.18), (0.0, 0.0, 0.94))
    render(camera, "three-quarter", (2.55, -3.55, 1.28), (0.0, 0.0, 0.98))
    render(camera, "close", (0.0, -1.15, 1.61), (0.0, -0.005, 1.56))
    bpy.context.scene["echo_pipeline_note"] = "Hair silhouette blockout; requires artist refinement and deformation gate"
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT / "echo-hero-mpfb-hair-v1.blend"))


if __name__ == "__main__":
    main()

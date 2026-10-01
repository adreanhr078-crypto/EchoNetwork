"""Echo identity pass: facial ratios, eyes, brows and smooth layered hair.

The output remains a review candidate.  It is deliberately kept outside Godot
until the four-angle identity gate and deformation gate pass.
"""

from __future__ import annotations

import math
import random
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector
from bl_ext.blender_org.mpfb.services.targetservice import TargetService


ROOT = Path(r"C:\Users\yasmo\Documents\Codex\2026-09-11\create-an-image-of-3\EchoNetwork")
OUT = ROOT / "artifacts/eleven-eleven/art/production/echo-identity-pass-v1"
SOURCE = ROOT / "artifacts/eleven-eleven/art/production/echo-hero-mpfb-v1/echo-hero-mpfb-base-v2.blend"
OUT.mkdir(parents=True, exist_ok=True)


def look_at(obj: bpy.types.Object, target: Vector) -> None:
    obj.rotation_euler = (target - obj.location).to_track_quat("-Z", "Y").to_euler()


def mat_principled(name: str, base, roughness: float, metallic: float = 0.0) -> bpy.types.Material:
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*base, 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    return mat


def set_shape(human: bpy.types.Object, name: str, value: float) -> None:
    keys = human.data.shape_keys.key_blocks
    if name not in keys:
        raise RuntimeError(f"Required MPFB target missing: {name}")
    keys[name].value = value


def add_uv(name: str, loc, scale, material, segments=64, rings=32) -> bpy.types.Object:
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, location=loc)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(material)
    for poly in obj.data.polygons:
        poly.use_smooth = True
    return obj


def catmull(points: list[Vector], samples_per_segment: int = 4) -> list[Vector]:
    padded = [points[0], *points, points[-1]]
    result: list[Vector] = []
    for i in range(1, len(padded) - 2):
        p0, p1, p2, p3 = padded[i - 1:i + 3]
        for step in range(samples_per_segment):
            t = step / samples_per_segment
            t2, t3 = t * t, t * t * t
            result.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2*p0 - 5*p1 + 4*p2 - p3) * t2 + (-p0 + 3*p1 - 3*p2 + p3) * t3))
    result.append(points[-1])
    return result


def make_lock(name: str, controls: list[Vector], root_width: float, max_width: float, material: bpy.types.Material, flatten=0.40) -> bpy.types.Object:
    points = catmull(controls, 4)
    verts = []
    faces = []
    prior_side = Vector((1.0, 0.0, 0.0))
    for i, point in enumerate(points):
        u = i / max(1, len(points) - 1)
        if u < 0.28:
            width = root_width + (max_width - root_width) * (u / 0.28)
        else:
            width = max_width * max(0.045, ((1.0 - u) / 0.72) ** 0.72)
        tangent = (points[min(i + 1, len(points)-1)] - points[max(i - 1, 0)]).normalized()
        side = tangent.cross(Vector((0.0, 0.0, 1.0)))
        if side.length < 0.02:
            side = prior_side
        side.normalize()
        prior_side = side
        # A sculptable anime hair lock is a thin ribbon, not a round tube.  The
        # slightly asymmetric center offset prevents a sterile card-grid read.
        center = point + side * (math.sin(u * math.pi) * width * 0.06)
        verts.append(tuple(center - side * width))
        verts.append(tuple(center + side * width))
    for i in range(len(points) - 1):
        a, b = i * 2, (i + 1) * 2
        faces.append((a, a + 1, b + 1, b))
    mesh = bpy.data.meshes.new(name + "_Mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(material)
    for poly in obj.data.polygons:
        poly.use_smooth = True
    solid = obj.modifiers.new("Hair_Ribbon_Thickness", "SOLIDIFY")
    solid.thickness = max(0.0009, max_width * flatten * 0.18)
    solid.offset = 0.0
    bevel = obj.modifiers.new("Micro_Edge_Soften", "BEVEL")
    bevel.width = 0.0008
    bevel.segments = 2
    return obj


def make_scalp(material: bpy.types.Material) -> bpy.types.Object:
    scalp = add_uv("Echo_Hair_Scalp", (0.0, 0.002, 1.674), (0.122, 0.112, 0.139), material, 96, 64)
    bm = bmesh.new()
    bm.from_mesh(scalp.data)
    remove = []
    for vert in bm.verts:
        world = scalp.matrix_world @ vert.co
        if world.z < 1.548 or (world.z < 1.610 and world.y < -0.005):
            remove.append(vert)
    bmesh.ops.delete(bm, geom=remove, context="VERTS")
    bm.to_mesh(scalp.data)
    bm.free()
    solid = scalp.modifiers.new("Scalp_Thickness", "SOLIDIFY")
    solid.thickness = 0.003
    solid.offset = 0.0
    return scalp


def build_hair(material: bpy.types.Material) -> bpy.types.Collection:
    random.seed(1111)
    col = bpy.data.collections.new("Echo_Hair_Identity_v1_NOT_APPROVED")
    bpy.context.scene.collection.children.link(col)
    objects = [make_scalp(material)]

    # Dense crown shell. Every root intersects the scalp; no floating spikes.
    for ring, count in ((0, 8), (1, 12), (2, 14)):
        radius = (0.042, 0.078, 0.106)[ring]
        root_z = (1.787, 1.744, 1.696)[ring]
        for i in range(count):
            angle = 2 * math.pi * (i + 0.35 * ring) / count + random.uniform(-0.035, 0.035)
            root = Vector((radius * math.sin(angle), 0.002 + radius * 0.78 * math.cos(angle), root_z + random.uniform(-0.006, 0.006)))
            outward = Vector((math.sin(angle), 0.78 * math.cos(angle), 0.0)).normalized()
            mid1 = root + outward * random.uniform(0.018, 0.032) + Vector((0, 0, random.uniform(0.008, 0.026)))
            mid2 = mid1 + outward * random.uniform(0.026, 0.044) + Vector((0, 0, -random.uniform(0.025, 0.055)))
            drop = 0.026 + 0.052 * abs(math.sin(angle)) + 0.016 * max(0.0, -math.cos(angle))
            tip = mid2 + outward * random.uniform(0.014, 0.030) + Vector((0, 0, -drop))
            objects.append(make_lock(f"Echo_Crown_{ring}_{i:02d}", [root, mid1, mid2, tip], 0.014, 0.024, material, 0.20))

    # Overlapping face-framing bangs, matching the approved reference rhythm.
    xs = [-0.103, -0.080, -0.057, -0.034, -0.011, 0.014, 0.040, 0.067, 0.092, 0.112]
    for i, x in enumerate(xs):
        root = Vector((x * 0.70, -0.086, 1.752 - abs(x) * 0.20))
        sweep = (-0.012 if i < 6 else 0.012) + random.uniform(-0.005, 0.005)
        mid1 = Vector((x * 0.82, -0.118, 1.704 - abs(x) * 0.23))
        mid2 = Vector((x + sweep, -0.137, 1.644 - abs(x) * 0.12))
        tip_z = 1.578 + abs(x) * 0.34 + random.uniform(-0.008, 0.008)
        tip = Vector((x + sweep * 1.5, -0.142, tip_z))
        objects.append(make_lock(f"Echo_Bang_{i:02d}", [root, mid1, mid2, tip], 0.015, 0.026, material, 0.17))

    # Long temple layers and restrained signature crown flicks.
    for side in (-1.0, 1.0):
        for i in range(3):
            root = Vector((side * (0.083 + i*0.006), -0.025 + i*0.018, 1.705 - i*0.012))
            mid = root + Vector((side*0.035, -0.018, -0.045))
            tip = mid + Vector((side*0.026, -0.010, -0.052 - i*0.008))
            objects.append(make_lock(f"Echo_Temple_{'L' if side < 0 else 'R'}_{i}", [root, root.lerp(mid, .45), mid, tip], .013, .021, material, .19))
    flicks = [(-0.028, -0.01, 1.790, -0.045, -0.015, 1.835), (0.022, 0.0, 1.792, 0.048, -0.012, 1.827)]
    for i, values in enumerate(flicks):
        root = Vector(values[:3]); tip = Vector(values[3:])
        objects.append(make_lock(f"Echo_Crown_Flick_{i}", [root, root.lerp(tip, .35), root.lerp(tip, .72), tip], .008, .012, material, .34))

    for obj in objects:
        for old in list(obj.users_collection):
            old.objects.unlink(obj)
        col.objects.link(obj)
    col["quality_status"] = "IDENTITY_REVIEW_ONLY"
    return col


def build_eye_detail() -> None:
    white = mat_principled("Echo_Sclera", (0.82, 0.86, 0.88), 0.20)
    black = mat_principled("Echo_Pupil", (0.002, 0.003, 0.006), 0.16)
    shine = mat_principled("Echo_Eye_Highlight", (1.0, 1.0, 1.0), 0.06)
    for side in ("L", "R"):
        eye = bpy.data.objects[f"Echo_Eye_{side}_Review"]
        eye.data.materials.clear(); eye.data.materials.append(white)
        x = -0.032 if side == "L" else 0.032
        add_uv(f"Echo_Pupil_{side}", (x, -0.1355, 1.605), (0.0058, 0.0018, 0.0068), black, 48, 24)
        hx = x - 0.0022
        add_uv(f"Echo_Highlight_{side}", (hx, -0.1374, 1.608), (0.0018, 0.0008, 0.0020), shine, 32, 16)


def build_brows(hair_mat: bpy.types.Material) -> None:
    for side in (-1.0, 1.0):
        inner = Vector((side*0.010, -0.143, 1.641))
        arch = Vector((side*0.040, -0.146, 1.650))
        outer = Vector((side*0.071, -0.140, 1.640))
        make_lock(f"Echo_Brow_{'L' if side < 0 else 'R'}", [inner, arch, outer], .0032, .0045, hair_mat, .18)


def render(camera, name, loc, target) -> None:
    camera.location = loc
    look_at(camera, Vector(target))
    bpy.context.scene.render.filepath = str(OUT / f"echo-identity-{name}-v1.png")
    bpy.ops.render.render(write_still=True)


def main() -> None:
    bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
    human = bpy.data.objects["Echo_MPF_Base_High_NOT_APPROVED"]
    # The 4K synchronized head reference shows a longer, sharper lower face than
    # the first pass. Load corrective targets while retaining their shape keys.
    if "chin-height-incr" not in human.data.shape_keys.key_blocks:
        TargetService.bulk_load_targets(human, [
            {"target": "chin-height-incr", "value": 0.16},
            {"target": "chin-prominent-incr", "value": 0.08},
            {"target": "head-scale-depth-decr", "value": 0.08},
        ])
    human.data.shape_keys.key_blocks["chin-height-decr"].value = 0.0
    for name, value in {
        "head-scale-vert-incr": 0.10,
        "head-scale-horiz-incr": 0.04,
        "head-invertedtriangular": 0.24,
        "chin-width-decr": 0.36,
        "chin-height-decr": 0.14,
        "chin-triangle": 0.22,
        "l-eye-scale-incr": 0.43,
        "r-eye-scale-incr": 0.43,
        "l-eye-height1-incr": 0.10,
        "r-eye-height1-incr": 0.10,
        "l-eye-height2-incr": 0.07,
        "r-eye-height2-incr": 0.07,
        "l-eye-corner2-up": 0.18,
        "r-eye-corner2-up": 0.18,
        "nose-scale-horiz-decr": 0.28,
        "nose-scale-depth-decr": 0.21,
        "mouth-scale-horiz-decr": 0.13,
        "chin-height-incr": 0.16,
        "chin-prominent-incr": 0.08,
        "head-scale-depth-decr": 0.08,
    }.items():
        set_shape(human, name, value)

    build_eye_detail()
    # Warmer skin keeps the close-up legible under the cool rim lights.
    skin = human.data.materials[0]
    skin_bsdf = skin.node_tree.nodes.get("Principled BSDF")
    skin_bsdf.inputs["Base Color"].default_value = (0.46, 0.285, 0.235, 1.0)
    skin_bsdf.inputs["Roughness"].default_value = 0.48
    hair = mat_principled("Echo_Hair_Deep_Black", (0.002, 0.005, 0.012), 0.38)
    build_brows(hair)
    build_hair(hair)

    scene = bpy.context.scene
    scene.render.resolution_x = 1200
    scene.render.resolution_y = 1600
    camera = bpy.data.objects["Echo_Review_Camera"]
    render(camera, "front", (0.0, -4.25, 1.18), (0.0, 0.0, 0.94))
    render(camera, "three-quarter", (2.55, -3.55, 1.28), (0.0, 0.0, 0.98))
    render(camera, "profile", (4.25, 0.0, 1.22), (0.0, 0.0, 0.96))
    render(camera, "close", (0.0, -1.15, 1.61), (0.0, -0.005, 1.56))
    human["echo_gate_status"] = "IDENTITY_REVIEW_NOT_APPROVED"
    scene["echo_identity_pass"] = "face ratios + layered eyes + broad smooth hair masses v2"
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT / "echo-identity-pass-v2.blend"))


if __name__ == "__main__":
    main()

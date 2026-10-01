"""Echo identity pass v3: cohesive sculpted hair masses and eye cleanup.

This pass is still evidence-only. It never replaces the Godot proxy unless the
four-angle identity and deformation gates are explicitly approved.
"""

from __future__ import annotations

import math
from pathlib import Path

import bpy
from mathutils import Vector


ROOT = Path(r"C:\Users\yasmo\Documents\Codex\2026-09-11\create-an-image-of-3\EchoNetwork")
SOURCE = ROOT / "artifacts/eleven-eleven/art/production/echo-identity-pass-v1/echo-identity-pass-v2.blend"
OUT = ROOT / "artifacts/eleven-eleven/art/production/echo-identity-pass-v3"
OUT.mkdir(parents=True, exist_ok=True)


def look_at(obj: bpy.types.Object, target: Vector) -> None:
    obj.rotation_euler = (target - obj.location).to_track_quat("-Z", "Y").to_euler()


def material(name: str, color, roughness: float, metallic: float = 0.0):
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    return mat


def catmull(points: list[Vector], steps: int = 7) -> list[Vector]:
    padded = [points[0], *points, points[-1]]
    out = []
    for i in range(1, len(padded) - 2):
        p0, p1, p2, p3 = padded[i - 1:i + 3]
        for j in range(steps):
            t = j / steps
            t2, t3 = t * t, t * t * t
            out.append(0.5 * ((2*p1) + (-p0+p2)*t + (2*p0-5*p1+4*p2-p3)*t2 + (-p0+3*p1-3*p2+p3)*t3))
    out.append(points[-1])
    return out


def clump(name: str, controls, width: float, depth: float, mat, sides: int = 8):
    """Create one closed, tapered, subdivision-ready anime hair mass."""
    points = catmull([Vector(p) for p in controls])
    verts, faces = [], []
    previous_side = Vector((1, 0, 0))
    for i, point in enumerate(points):
        u = i / (len(points) - 1)
        tangent = (points[min(i + 1, len(points)-1)] - points[max(i - 1, 0)]).normalized()
        side = tangent.cross(Vector((0, 0, 1)))
        if side.length < 0.01:
            side = previous_side
        side.normalize()
        normal = tangent.cross(side).normalized()
        previous_side = side
        # Broad root, gentle middle, razor taper only in the final 25%.
        taper = 1.0 if u < 0.32 else (1.0 - ((u - 0.32) / 0.68) ** 1.7)
        taper = max(0.055, taper)
        bulge = 0.82 + 0.22 * math.sin(math.pi * u)
        for s in range(sides):
            a = 2 * math.pi * s / sides
            verts.append(tuple(point + side * math.cos(a) * width * taper * bulge + normal * math.sin(a) * depth * taper))
    for i in range(len(points) - 1):
        for s in range(sides):
            a = i*sides+s
            b = i*sides+(s+1) % sides
            c = (i+1)*sides+(s+1) % sides
            d = (i+1)*sides+s
            faces.append((a, b, c, d))
    faces.append(tuple(reversed(range(sides))))
    last = (len(points)-1)*sides
    faces.append(tuple(last+s for s in range(sides)))
    mesh = bpy.data.meshes.new(name + "_Mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    for poly in obj.data.polygons:
        poly.use_smooth = True
    bevel = obj.modifiers.new("Clump edge continuity", "BEVEL")
    bevel.width = 0.0012
    bevel.segments = 2
    return obj


def build_hair(mat):
    old = bpy.data.collections.get("Echo_Hair_Identity_v1_NOT_APPROVED")
    if old:
        old.hide_render = True
        old.hide_viewport = True
    col = bpy.data.collections.new("Echo_Hair_Sculpted_Masses_v3_REVIEW")
    bpy.context.scene.collection.children.link(col)

    # Deliberately authored large masses: silhouette first, micro-strands later.
    specs = [
        ("Crown_Center", [(0,-.005,1.790),(0,-.018,1.825),(-.010,-.050,1.805),(-.018,-.108,1.705)], .047,.018),
        ("Crown_Left", [(-.030,.000,1.785),(-.070,-.005,1.805),(-.103,-.035,1.760),(-.125,-.070,1.675)], .044,.019),
        ("Crown_Right", [(.030,.000,1.785),(.070,-.002,1.807),(.106,-.030,1.765),(.128,-.060,1.690)], .044,.019),
        ("Back_Left", [(-.055,.050,1.775),(-.110,.060,1.755),(-.145,.035,1.690),(-.155,-.005,1.600)], .050,.022),
        ("Back_Right", [(.055,.050,1.775),(.110,.060,1.755),(.145,.035,1.690),(.155,-.005,1.605)], .050,.022),
        ("Bang_Long_Left", [(-.050,-.070,1.770),(-.080,-.105,1.730),(-.075,-.135,1.660),(-.055,-.145,1.565)], .034,.012),
        ("Bang_Left", [(-.020,-.080,1.785),(-.045,-.115,1.740),(-.042,-.142,1.680),(-.028,-.148,1.610)], .032,.011),
        ("Bang_Center", [(0,-.083,1.785),(-.006,-.120,1.740),(.002,-.145,1.685),(.012,-.149,1.625)], .030,.010),
        ("Bang_Right", [(.028,-.078,1.780),(.050,-.112,1.735),(.052,-.140,1.680),(.045,-.146,1.615)], .033,.011),
        ("Bang_Long_Right", [(.055,-.066,1.765),(.090,-.095,1.720),(.097,-.126,1.655),(.080,-.140,1.575)], .036,.012),
        ("Temple_Left", [(-.105,-.010,1.720),(-.135,-.030,1.675),(-.145,-.050,1.615),(-.132,-.065,1.545)], .030,.012),
        ("Temple_Right", [(.105,-.005,1.720),(.138,-.025,1.680),(.150,-.045,1.620),(.138,-.060,1.550)], .030,.012),
    ]
    objects = [clump("Echo_"+n, pts, w, d, mat) for n,pts,w,d in specs]
    for obj in objects:
        for current in list(obj.users_collection):
            current.objects.unlink(obj)
        col.objects.link(obj)
    col["quality_status"] = "FOUR_ANGLE_REVIEW_REQUIRED"
    return col


def cleanup_eyes():
    # Retain the rigged eyeballs but remove the tiny, cross-eyed review pupils.
    for prefix in ("Echo_Pupil_", "Echo_Highlight_"):
        for obj in [o for o in bpy.data.objects if o.name.startswith(prefix)]:
            bpy.data.objects.remove(obj, do_unlink=True)
    iris = material("Echo_Iris_Graphite", (.018,.035,.060), .22)
    pupil = material("Echo_Pupil_Black", (.001,.002,.004), .16)
    glint = material("Echo_Catchlight", (1.0,.96,.88), .08)
    for side, x in (("L", -.032),("R", .032)):
        bpy.ops.mesh.primitive_uv_sphere_add(segments=64, ring_count=32, location=(x,-.1363,1.605))
        i = bpy.context.object; i.name=f"Echo_Iris_{side}_v3"; i.scale=(.0115,.0015,.0135); i.data.materials.append(iris)
        bpy.ops.mesh.primitive_uv_sphere_add(segments=48, ring_count=24, location=(x,-.1380,1.6045))
        p = bpy.context.object; p.name=f"Echo_Pupil_{side}_v3"; p.scale=(.0047,.0008,.0060); p.data.materials.append(pupil)
        bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=16, location=(x-.0030,-.1390,1.6100))
        h = bpy.context.object; h.name=f"Echo_Catchlight_{side}_v3"; h.scale=(.0022,.0005,.0025); h.data.materials.append(glint)


def render(camera, name, loc, target):
    camera.location = loc
    look_at(camera, Vector(target))
    bpy.context.scene.render.filepath = str(OUT / f"echo-identity-v3-{name}.png")
    bpy.ops.render.render(write_still=True)


def main():
    bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
    human = bpy.data.objects["Echo_MPF_Base_High_NOT_APPROVED"]
    # More decisive silhouette correction while keeping all changes reversible.
    for key, value in {
        "head-invertedtriangular": .34,
        "chin-width-decr": .46,
        "chin-triangle": .30,
        "l-eye-scale-incr": .36,
        "r-eye-scale-incr": .36,
        "l-eye-corner2-up": .23,
        "r-eye-corner2-up": .23,
        "nose-scale-horiz-decr": .36,
        "nose-scale-depth-decr": .30,
        "mouth-scale-horiz-decr": .08,
    }.items():
        human.data.shape_keys.key_blocks[key].value = value
    cleanup_eyes()
    hair = material("Echo_Hair_Ink_v3", (.003,.008,.018), .31, .04)
    build_hair(hair)
    scene = bpy.context.scene
    scene.render.resolution_x = 1400
    scene.render.resolution_y = 1600
    scene.render.resolution_percentage = 100
    camera = bpy.data.objects["Echo_Review_Camera"]
    render(camera,"front",(0,-2.15,1.46),(0,-.005,1.53))
    render(camera,"three-quarter",(.88,-1.75,1.48),(0,-.002,1.54))
    render(camera,"profile",(1.95,0,1.48),(0,0,1.54))
    render(camera,"close",(0,-1.02,1.61),(0,-.008,1.61))
    human["echo_gate_status"] = "IDENTITY_V3_REVIEW_NOT_APPROVED"
    scene["echo_identity_pass"] = "v3 cohesive sculpted clumps + corrected eye convergence"
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT / "echo-identity-pass-v3.blend"))


if __name__ == "__main__":
    main()

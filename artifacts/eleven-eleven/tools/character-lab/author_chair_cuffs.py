"""Fit and animate an isolated pair of restraint cuffs around the reviewed wrists."""
from pathlib import Path
import argparse
import hashlib
import json
import math
import sys

import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

APP = Path(__file__).resolve().parents[2]
REFERENCE = APP / "art/production/signature-slice-20261104/chair-contact-20261105"
SIDES = (("Left", 1, 8), ("Right", -1, 12))
STEPS = 28
HINGE_Z = 1.088


def sha(path):
    with path.open("rb") as file:
        return hashlib.file_digest(file, "sha256").hexdigest()


def tree(obj, mesh):
    return BVHTree.FromPolygons([obj.matrix_world @ v.co for v in mesh.vertices],
                               [tuple(f.vertices) for f in mesh.polygons])


def material(name, color, metal):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    mat.use_nodes = True
    surface = mat.node_tree.nodes.get("Principled BSDF")
    surface.inputs["Base Color"].default_value = (*color, 1)
    surface.inputs["Metallic"].default_value = metal
    surface.inputs["Roughness"].default_value = .31
    return mat


def hinge_cuff(name, sign, frame_start, steel):
    center, depth, z = .446, .114, HINGE_Z
    radius, rise, width = .074, .108, .030
    pivot = Vector(((center + radius) * sign, depth, z))
    vertices, faces = [], []
    for i in range(STEPS + 1):
        t = math.pi * i / STEPS
        c, s = math.cos(t), max(0, math.sin(t))
        x = math.copysign(abs(c)**.65, c)
        height = s**.55
        for outer, y in ((0,-1), (0,1), (1,1), (1,-1)):
            point = Vector(((center + (radius + outer*.006)*x)*sign,
                            depth + width*y/2, z + (rise + outer*.006)*height))
            vertices.append(point - pivot)
        if i:
            for j in range(4):
                k = (j+1)%4
                faces.append((4*i+j, 4*i+k, 4*(i-1)+k, 4*(i-1)+j))
    faces.extend(((0,3,2,1),tuple(4*STEPS+j for j in range(4))))
    if sign < 0:
        faces = [tuple(reversed(face)) for face in faces]
    mesh = bpy.data.meshes.new(name + " Cuff band")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name + "Cuff", mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj.location = pivot
    obj.data.materials.append(steel)
    for frame in range(61):
        progress = min(1, max(0, (frame-frame_start)/28))
        eased = progress**2 * (3 - 2*progress)
        obj.rotation_euler.y = sign * math.radians(94) * (1-eased)
        obj.keyframe_insert(data_path="rotation_euler", frame=frame)
    return obj


def mount(name, sign, graphite):
    bpy.ops.mesh.primitive_cube_add(size=1, location=(.447*sign,.114,1.072))
    obj = bpy.context.object
    obj.name = name+"Mount"
    obj.dimensions = (.164,.046,.012)
    obj.data.materials.append(graphite)
    return obj


def bracket_pin(name, x, radius, graphite):
    bpy.ops.mesh.primitive_cylinder_add(vertices=20, radius=radius, depth=.045,
        location=(x,.114,HINGE_Z), rotation=(math.pi/2,0,0))
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(graphite)
    return obj


def capture(scene, out):
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "MATERIAL"
    scene.display.shading.show_cavity = True
    scene.display.shading.show_shadows = True
    scene.render.resolution_x, scene.render.resolution_y = 960, 600
    scene.render.resolution_percentage = 100
    camera = bpy.data.objects.new("Restraint review", bpy.data.cameras.new("Restraint review"))
    scene.collection.objects.link(camera)
    scene.camera = camera
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 1.26
    camera.location = (1.30,-2.2,1.88)
    camera.rotation_euler = (Vector((0,.16,1.17))-camera.location).to_track_quat("-Z","Y").to_euler()
    for frame, label in ((0,"open"), (22,"closing"), (45,"latched")):
        scene.frame_set(frame)
        scene.render.filepath = str(out / (label+".png"))
        bpy.ops.render.render(write_still=True)


def run(blend, out):
    out.mkdir(parents=True, exist_ok=True)
    parent = json.loads((REFERENCE/"blender-contact.json").read_text())
    assert sha(blend) == parent["blend_sha256"]
    scene = bpy.context.scene
    assert scene.render.fps == 30 and scene.frame_start == 0 and scene.frame_end == 60
    actor = next(o for o in scene.objects if o.type == "MESH" and not o.hide_render and any(m.type == "ARMATURE" for m in o.modifiers))
    chair = next(o for o in scene.objects if o.type == "MESH" and not o.hide_render and not o.modifiers)
    chair_tree = tree(chair, chair.data)
    steel = material("Brushed clinical alloy", (.48,.56,.62), .72)
    graphite = material("Graphite restraint bracket", (.068,.083,.105), .43)
    moving = [hinge_cuff(*side, steel) for side in SIDES]
    fixed = []
    for name, sign, _ in SIDES:
        fixed.extend((mount(name, sign, graphite),
                      bracket_pin(name+"HingePin", .520*sign, .012, graphite),
                      bracket_pin(name+"LatchPin", .372*sign, .010, graphite)))

    frames = []
    for frame in range(61):
        scene.frame_set(frame)
        evaluated = actor.evaluated_get(bpy.context.evaluated_depsgraph_get())
        skin = evaluated.to_mesh()
        try:
            skin_tree = tree(evaluated, skin)
            record = {"frame":frame}
            for obj in moving + fixed:
                probe = tree(obj, obj.data)
                side = {"skin_triangle_pairs":len(probe.overlap(skin_tree))}
                if obj in moving:
                    side["chair_triangle_pairs"] = len(probe.overlap(chair_tree))
                    side["hinge_angle_deg"] = math.degrees(obj.rotation_euler.y)
                    end = obj.matrix_world @ obj.data.vertices[4*STEPS].co
                    side["latch_tip"] = list(end)
                    side["nearest_skin_vertex_clearance_m"] = min(
                        skin_tree.find_nearest(obj.matrix_world @ v.co)[3] for v in obj.data.vertices)
                record[obj.name] = side
            frames.append(record)
        finally:
            evaluated.to_mesh_clear()

    assert sha(blend) == parent["blend_sha256"]
    max_skin = max(v["skin_triangle_pairs"] for f in frames for k,v in f.items() if k != "frame")
    max_chair = max(f[obj.name]["chair_triangle_pairs"] for f in frames for obj in moving)
    closed_clearance = {obj.name: min(f[obj.name]["nearest_skin_vertex_clearance_m"] for f in frames[40:]) for obj in moving}
    passed = max_skin == max_chair == 0 and all(.001 <= c <= .025 for c in closed_clearance.values())
    output = {"status":"PASS_BLENDER_CUFF_CONTACT" if passed else "FAIL_CUFF_CONTACT",
              "parent_blend_sha256":parent["blend_sha256"], "chair_sha256":next(v for k,v in parent["sources"].items() if "chair" in k),
              "scope":"Two cuff props, fixed actor and chair sources. 61 sampled triangle overlap checks; mounts may contact the chair.",
              "fps":30,"max_skin_triangle_pairs":max_skin,"max_moving_chair_triangle_pairs":max_chair,
              "latched_min_skin_clearance_m":closed_clearance,
              "local_latch_tips":{obj.name:list(obj.data.vertices[4*STEPS].co) for obj in moving},
              "frames":frames}
    if passed:
        capture(scene,out)
        scene.frame_set(0)
        bpy.ops.object.select_all(action="DESELECT")
        for obj in moving + fixed:
            obj.select_set(True)
        asset = out/"cuffs.glb"
        bpy.ops.export_scene.gltf(filepath=str(asset), export_format="GLB", use_selection=True,
                                   export_animation_mode="SCENE", export_anim_scene_split_object=False,
                                   export_force_sampling=True,
                                   export_optimize_animation_size=False, export_frame_range=True)
        output["cuff_glb_sha256"] = sha(asset)
    (out/"blender-cuff-review.json").write_text(json.dumps(output,indent=2)+"\n",encoding="utf-8")
    print("CUFF_REVIEW",output["status"],max_skin,max_chair,closed_clearance,flush=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("blend", type=Path)
    parser.add_argument("out", type=Path)
    args=parser.parse_args(sys.argv[sys.argv.index("--")+1:])
    run(args.blend,args.out)

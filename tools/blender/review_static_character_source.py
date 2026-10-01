"""Create non-destructive visual and structural evidence for a static source GLB."""

import argparse
import json
import sys
from pathlib import Path

import bpy
from mathutils import Vector


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--blend", required=True)
    return parser.parse_args(sys.argv[sys.argv.index("--") + 1 :])


def evaluated_bounds(meshes):
    depsgraph = bpy.context.evaluated_depsgraph_get()
    points = []
    for obj in meshes:
        evaluated = obj.evaluated_get(depsgraph)
        mesh = evaluated.to_mesh()
        points.extend(evaluated.matrix_world @ vertex.co for vertex in mesh.vertices)
        evaluated.to_mesh_clear()
    lo = Vector(min(point[i] for point in points) for i in range(3))
    hi = Vector(max(point[i] for point in points) for i in range(3))
    return lo, hi


def add_area(name, location, energy, size, target):
    bpy.ops.object.light_add(type="AREA", location=location)
    light = bpy.context.object
    light.name = name
    light.data.energy = energy
    light.data.shape = "DISK"
    light.data.size = size
    light.rotation_euler = (target - light.location).to_track_quat("-Z", "Y").to_euler()


def render_view(scene, camera, output, name, position, target, ortho_scale, resolution):
    camera.location = position
    camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera.data.ortho_scale = ortho_scale
    scene.render.resolution_x, scene.render.resolution_y = resolution
    scene.render.filepath = str(output / f"{name}.png")
    bpy.ops.render.render(write_still=True)


def main():
    args = parse_args()
    source = Path(args.input).resolve()
    output = Path(args.output).resolve()
    blend = Path(args.blend).resolve()
    output.mkdir(parents=True, exist_ok=True)
    blend.parent.mkdir(parents=True, exist_ok=True)

    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(source))
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    if not meshes:
        raise RuntimeError("Imported source contains no meshes")

    triangle_count = 0
    vertex_count = 0
    for obj in meshes:
        obj.data.calc_loop_triangles()
        triangle_count += len(obj.data.loop_triangles)
        vertex_count += len(obj.data.vertices)

    materials = {
        slot.material.name
        for obj in meshes
        for slot in obj.material_slots
        if slot.material
    }
    images = [image for image in bpy.data.images if image.size[0] and image.size[1]]
    armatures = [obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE"]
    lo, hi = evaluated_bounds(meshes)
    size = hi - lo
    center = (lo + hi) * 0.5

    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.image_settings.file_format = "PNG"
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = False
    scene.world = bpy.data.worlds.new("EchoSourceReviewWorld")
    scene.world.use_nodes = True
    background = scene.world.node_tree.nodes.get("Background")
    background.inputs["Color"].default_value = (0.018, 0.024, 0.035, 1.0)
    background.inputs["Strength"].default_value = 0.24

    distance = max(size.x, size.y, size.z) * 2.2
    add_area("Key", center + Vector((2.6, -3.8, 3.4)), 1150, 3.0, center)
    add_area("Fill", center + Vector((-2.8, -1.5, 1.7)), 620, 2.5, center)
    add_area("Rim", center + Vector((1.4, 3.2, 3.0)), 920, 2.2, center)

    bpy.ops.object.camera_add()
    camera = bpy.context.object
    camera.name = "EchoSourceReviewCamera"
    camera.data.type = "ORTHO"
    camera.data.lens = 70
    scene.camera = camera

    full_scale = max(size.z * 1.08, size.x * 1.34)
    render_view(scene, camera, output, "front", center + Vector((0, -distance, 0)), center, full_scale, (768, 1024))
    render_view(scene, camera, output, "three_quarter", center + Vector((distance * 0.55, -distance, 0)), center, full_scale, (768, 1024))
    render_view(scene, camera, output, "side", center + Vector((distance, 0, 0)), center, full_scale, (768, 1024))
    render_view(scene, camera, output, "back", center + Vector((0, distance, 0)), center, full_scale, (768, 1024))

    head_center = Vector((center.x, center.y, lo.z + size.z * 0.885))
    render_view(
        scene,
        camera,
        output,
        "face_closeup",
        head_center + Vector((0, -distance, 0)),
        head_center,
        size.z * 0.27,
        (1024, 1024),
    )

    bpy.ops.wm.save_as_mainfile(filepath=str(blend), check_existing=False)
    report = {
        "source": str(source),
        "blend": str(blend),
        "mesh_count": len(meshes),
        "triangle_count": triangle_count,
        "vertex_count": vertex_count,
        "material_count": len(materials),
        "image_count": len(images),
        "image_sizes": sorted({f"{int(image.size[0])}x{int(image.size[1])}" for image in images}),
        "armature_count": len(armatures),
        "dimensions": [round(value, 6) for value in size],
        "bounds_min": [round(value, 6) for value in lo],
        "bounds_max": [round(value, 6) for value in hi],
    }
    (output / "source-report.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    print("TRIPO_SOURCE_REVIEW=" + json.dumps(report), flush=True)


if __name__ == "__main__":
    main()

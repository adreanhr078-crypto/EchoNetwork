"""Inspect and render a rigged character GLB without modifying the source asset."""

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
    if not points:
        raise RuntimeError("No evaluated mesh vertices were found")
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


def action_frame_range(actions):
    ranges = [tuple(action.frame_range) for action in actions if action.frame_range[1] > action.frame_range[0]]
    if not ranges:
        return 1, 1
    return int(min(item[0] for item in ranges)), int(max(item[1] for item in ranges))


def bone_motion_report(armatures, frames):
    report = {}
    for armature in armatures:
        samples = {}
        for frame in frames:
            bpy.context.scene.frame_set(frame)
            samples[str(frame)] = {
                bone.name: [round(value, 6) for row in bone.matrix for value in row]
                for bone in armature.pose.bones
            }
        changing = []
        if len(frames) > 1:
            first = samples[str(frames[0])]
            for bone_name, first_matrix in first.items():
                if any(samples[str(frame)][bone_name] != first_matrix for frame in frames[1:]):
                    changing.append(bone_name)
        report[armature.name] = {
            "bone_count": len(armature.data.bones),
            "changing_bone_count": len(changing),
            "changing_bones": changing,
        }
    return report


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
    armatures = [obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE"]
    actions = list(bpy.data.actions)
    if not meshes:
        raise RuntimeError("Imported GLB contains no meshes")
    if not armatures:
        raise RuntimeError("Imported GLB contains no armature")

    weighted_meshes = [
        obj for obj in meshes if any(modifier.type == "ARMATURE" for modifier in obj.modifiers)
    ]
    review_meshes = weighted_meshes or meshes
    for obj in meshes:
        if obj not in review_meshes:
            obj.hide_render = True

    start, end = action_frame_range(actions)
    frames = sorted({start, int(round((start + end) * 0.5)), end})
    scene = bpy.context.scene
    scene.frame_start = start
    scene.frame_end = end
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.image_settings.file_format = "PNG"
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = False
    scene.world = bpy.data.worlds.new("EchoRigReviewWorld")
    scene.world.use_nodes = True
    background = scene.world.node_tree.nodes.get("Background")
    background.inputs["Color"].default_value = (0.018, 0.024, 0.035, 1.0)
    background.inputs["Strength"].default_value = 0.24

    bounds_by_frame = {}
    for frame in frames:
        scene.frame_set(frame)
        lo, hi = evaluated_bounds(review_meshes)
        bounds_by_frame[str(frame)] = {
            "min": [round(value, 6) for value in lo],
            "max": [round(value, 6) for value in hi],
            "dimensions": [round(value, 6) for value in hi - lo],
        }

    scene.frame_set(frames[0])
    lo, hi = evaluated_bounds(review_meshes)
    size = hi - lo
    center = (lo + hi) * 0.5
    distance = max(size.x, size.y, size.z) * 2.2
    add_area("Key", center + Vector((2.6, -3.8, 3.4)), 1150, 3.0, center)
    add_area("Fill", center + Vector((-2.8, -1.5, 1.7)), 620, 2.5, center)
    add_area("Rim", center + Vector((1.4, 3.2, 3.0)), 920, 2.2, center)

    bpy.ops.object.camera_add()
    camera = bpy.context.object
    camera.name = "EchoRigReviewCamera"
    camera.data.type = "ORTHO"
    camera.data.lens = 70
    scene.camera = camera
    full_scale = max(size.z * 1.08, size.x * 1.34)

    action_previews = []
    primary_armature = armatures[0]
    primary_armature.animation_data_create()
    if primary_armature.animation_data:
        for track in primary_armature.animation_data.nla_tracks:
            track.mute = True

    for action in actions:
        action_start = int(round(action.frame_range[0]))
        action_end = int(round(action.frame_range[1]))
        if action_end <= action_start:
            continue
        primary_armature.animation_data.action = action
        action_frames = sorted(
            {action_start, int(round((action_start + action_end) * 0.5)), action_end}
        )
        preview_frame = action_frames[len(action_frames) // 2]
        scene.frame_set(preview_frame)
        action_lo, action_hi = evaluated_bounds(review_meshes)
        safe_name = "".join(character if character.isalnum() else "_" for character in action.name)
        render_view(
            scene,
            camera,
            output,
            f"action_{safe_name}_mid",
            center + Vector((distance * 0.42, -distance, 0)),
            center,
            full_scale,
            (768, 1024),
        )
        action_previews.append(
            {
                "name": action.name,
                "frames": action_frames,
                "mid_dimensions": [round(value, 6) for value in action_hi - action_lo],
                "bone_motion": bone_motion_report([primary_armature], action_frames),
            }
        )

    for frame in frames:
        scene.frame_set(frame)
        render_view(
            scene,
            camera,
            output,
            f"idle_frame_{frame:04d}",
            center + Vector((distance * 0.42, -distance, 0)),
            center,
            full_scale,
            (768, 1024),
        )

    scene.frame_set(frames[len(frames) // 2])
    head_center = Vector((center.x, center.y, lo.z + size.z * 0.885))
    render_view(
        scene,
        camera,
        output,
        "idle_face_closeup",
        head_center + Vector((0, -distance, 0)),
        head_center,
        size.z * 0.27,
        (1024, 1024),
    )

    triangle_count = 0
    vertex_count = 0
    weighted_mesh_count = 0
    for obj in meshes:
        obj.data.calc_loop_triangles()
        triangle_count += len(obj.data.loop_triangles)
        vertex_count += len(obj.data.vertices)
        if any(modifier.type == "ARMATURE" for modifier in obj.modifiers):
            weighted_mesh_count += 1

    images = [image for image in bpy.data.images if image.size[0] and image.size[1]]
    report = {
        "source": str(source),
        "blend": str(blend),
        "mesh_count": len(meshes),
        "mesh_names": [obj.name for obj in meshes],
        "triangle_count": triangle_count,
        "vertex_count": vertex_count,
        "weighted_mesh_count": weighted_mesh_count,
        "armature_count": len(armatures),
        "bone_count": sum(len(item.data.bones) for item in armatures),
        "actions": [
            {
                "name": action.name,
                "frame_range": [round(value, 3) for value in action.frame_range],
                "slot_count": len(action.slots),
            }
            for action in actions
        ],
        "sample_frames": frames,
        "bone_motion": bone_motion_report(armatures, frames),
        "action_previews": action_previews,
        "bounds_by_frame": bounds_by_frame,
        "image_sizes": sorted({f"{int(image.size[0])}x{int(image.size[1])}" for image in images}),
    }
    bpy.ops.wm.save_as_mainfile(filepath=str(blend), check_existing=False)
    (output / "rig-report.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    print("TRIPO_RIG_REVIEW=" + json.dumps(report), flush=True)


if __name__ == "__main__":
    main()

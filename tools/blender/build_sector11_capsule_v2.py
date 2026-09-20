"""Build the Sector 11 wake capsule from the approved Tripo retopology source.

The source contains an exploded presentation layout. This script keeps the
cohesive central shell, removes detached presentation pieces, authors a proper
hinged glass door, applies a restrained Sector 11 material hierarchy, and
exports a deterministic runtime GLB with the CAPSULE_OPEN clip.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import bpy
from mathutils import Vector


DETACHED_PRESENTATION_PARTS = {
    "tripo_part_0",
    "tripo_part_1",
    "tripo_part_8",
    "tripo_part_9",
    "tripo_part_29",
    "tripo_part_32",
    "tripo_part_42",
    "tripo_part_61",
}

SIGNAL_PARTS = {
    "tripo_part_45",
    "tripo_part_48",
    "tripo_part_52",
    "tripo_part_53",
    "tripo_part_54",
    "tripo_part_55",
    "tripo_part_57",
    "tripo_part_58",
    "tripo_part_59",
    "tripo_part_60",
}

INTERIOR_PARTS = {
    "tripo_part_12",
    "tripo_part_14",
    "tripo_part_17",
    "tripo_part_19",
    "tripo_part_21",
    "tripo_part_25",
    "tripo_part_26",
}

STEEL_PARTS = {
    "tripo_part_2",
    "tripo_part_3",
    "tripo_part_5",
    "tripo_part_10",
    "tripo_part_13",
    "tripo_part_30",
    "tripo_part_39",
    "tripo_part_40",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--report", required=True)
    parser.add_argument("--target-height", type=float, default=2.8)
    parser.add_argument("--target-triangles", type=int, default=73000)
    script_args = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    return parser.parse_args(script_args)


def make_material(
    name: str,
    color: tuple[float, float, float, float],
    metallic: float,
    roughness: float,
    emission: tuple[float, float, float, float] | None = None,
    emission_strength: float = 0.0,
    transmission: float = 0.0,
    alpha: float = 1.0,
) -> bpy.types.Material:
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    bsdf = material.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    if emission is not None:
        bsdf.inputs["Emission Color"].default_value = emission
        bsdf.inputs["Emission Strength"].default_value = emission_strength
    if transmission > 0.0:
        bsdf.inputs["Transmission Weight"].default_value = transmission
        bsdf.inputs["IOR"].default_value = 1.46
    if alpha < 1.0:
        bsdf.inputs["Alpha"].default_value = alpha
        material.surface_render_method = "DITHERED"
        material.use_transparency_overlap = False
    return material


def create_beveled_box(
    name: str,
    location: tuple[float, float, float],
    scale: tuple[float, float, float],
    material: bpy.types.Material,
    bevel: float,
    parent: bpy.types.Object | None = None,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cube_add(location=location)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    bevel_modifier = obj.modifiers.new("Edge softening", "BEVEL")
    bevel_modifier.width = bevel
    bevel_modifier.segments = 3
    bevel_modifier.limit_method = "ANGLE"
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=bevel_modifier.name)
    obj.data.materials.append(material)
    obj.parent = parent
    return obj


def world_bounds(objects: list[bpy.types.Object]) -> tuple[Vector, Vector]:
    points = [obj.matrix_world @ Vector(corner) for obj in objects for corner in obj.bound_box]
    return (
        Vector((min(p.x for p in points), min(p.y for p in points), min(p.z for p in points))),
        Vector((max(p.x for p in points), max(p.y for p in points), max(p.z for p in points))),
    )


def normalize_meshes(objects: list[bpy.types.Object], target_height: float) -> tuple[Vector, Vector, float]:
    minimum, maximum = world_bounds(objects)
    center_xy = Vector(((minimum.x + maximum.x) * 0.5, (minimum.y + maximum.y) * 0.5, minimum.z))
    scale = target_height / max(maximum.z - minimum.z, 0.001)
    for obj in objects:
        matrix = obj.matrix_world.copy()
        for vertex in obj.data.vertices:
            world_coordinate = matrix @ vertex.co
            vertex.co = (world_coordinate - center_xy) * scale
        obj.matrix_world.identity()
    return minimum, maximum, scale


def mesh_triangle_count(obj: bpy.types.Object) -> int:
    obj.data.calc_loop_triangles()
    return len(obj.data.loop_triangles)


def assign_material(obj: bpy.types.Object, materials: dict[str, bpy.types.Material]) -> None:
    obj.data.materials.clear()
    if obj.name in SIGNAL_PARTS:
        material = materials["signal"]
    elif obj.name in INTERIOR_PARTS:
        material = materials["interior"]
    elif obj.name in STEEL_PARTS:
        material = materials["steel"]
    else:
        dimensions = Vector(obj.dimensions)
        if dimensions.z > 1.2 and min(dimensions.x, dimensions.y) < 0.16:
            material = materials["rubber"]
        else:
            material = materials["graphite"]
    obj.data.materials.append(material)
    for polygon in obj.data.polygons:
        polygon.use_smooth = True


def add_capsule_door(materials: dict[str, bpy.types.Material]) -> bpy.types.Object:
    hinge = bpy.data.objects.new("CAPSULE_DOOR_HINGE", None)
    hinge.location = (-0.72, -0.38, 1.48)
    bpy.context.scene.collection.objects.link(hinge)

    frame_depth = 0.055
    create_beveled_box(
        "Door_Frame_Left",
        (0.055, 0.0, 0.0),
        (0.055, frame_depth, 1.02),
        materials["steel"],
        0.035,
        hinge,
    )
    create_beveled_box(
        "Door_Frame_Right",
        (1.385, 0.0, 0.0),
        (0.055, frame_depth, 1.02),
        materials["steel"],
        0.035,
        hinge,
    )
    create_beveled_box(
        "Door_Frame_Top",
        (0.72, 0.0, 0.985),
        (0.72, frame_depth, 0.055),
        materials["steel"],
        0.035,
        hinge,
    )
    create_beveled_box(
        "Door_Frame_Bottom",
        (0.72, 0.0, -0.985),
        (0.72, frame_depth, 0.055),
        materials["steel"],
        0.035,
        hinge,
    )
    create_beveled_box(
        "Door_Glass",
        (0.72, 0.0, 0.0),
        (0.64, 0.018, 0.91),
        materials["glass"],
        0.085,
        hinge,
    )
    create_beveled_box(
        "Door_Signal",
        (1.30, -0.072, 0.0),
        (0.018, 0.012, 0.70),
        materials["door_signal"],
        0.012,
        hinge,
    )

    hinge.rotation_euler.z = 0.0
    hinge.keyframe_insert(data_path="rotation_euler", index=2, frame=1)
    hinge.rotation_euler.z = -1.92
    hinge.keyframe_insert(data_path="rotation_euler", index=2, frame=42)
    action = hinge.animation_data.action
    action.name = "CAPSULE_OPEN"
    return hinge


def main() -> None:
    args = parse_args()
    source = Path(args.input).resolve()
    output = Path(args.output).resolve()
    report_path = Path(args.report).resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    report_path.parent.mkdir(parents=True, exist_ok=True)

    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    bpy.ops.import_scene.gltf(filepath=str(source))

    imported_meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    removed = []
    for obj in imported_meshes:
        if obj.name in DETACHED_PRESENTATION_PARTS:
            removed.append(obj.name)
            bpy.data.objects.remove(obj, do_unlink=True)

    shell_meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    if not shell_meshes:
        raise RuntimeError("No central capsule shell remained after cleanup")
    source_triangles = sum(mesh_triangle_count(obj) for obj in shell_meshes)
    original_minimum, original_maximum, normalization_scale = normalize_meshes(
        shell_meshes, args.target_height
    )

    materials = {
        "graphite": make_material("M_Capsule_Graphite", (0.018, 0.030, 0.042, 1.0), 0.78, 0.24),
        "steel": make_material("M_Capsule_Steel", (0.12, 0.17, 0.20, 1.0), 0.92, 0.17),
        "rubber": make_material("M_Capsule_Rubber", (0.006, 0.010, 0.015, 1.0), 0.04, 0.72),
        "interior": make_material("M_Capsule_Interior", (0.008, 0.028, 0.034, 1.0), 0.18, 0.48),
        "signal": make_material(
            "M_Capsule_Signal",
            (0.004, 0.035, 0.042, 1.0),
            0.35,
            0.26,
            (0.0, 0.12, 0.14, 1.0),
            0.06,
        ),
        "door_signal": make_material(
            "M_Capsule_DoorSignal",
            (0.004, 0.24, 0.28, 1.0),
            0.28,
            0.20,
            (0.0, 0.74, 0.86, 1.0),
            1.35,
        ),
        "glass": make_material(
            "M_Capsule_Glass",
            (0.025, 0.16, 0.20, 1.0),
            0.05,
            0.08,
            (0.0, 0.17, 0.23, 1.0),
            0.18,
            transmission=0.78,
            alpha=0.32,
        ),
    }

    target_shell_triangles = max(args.target_triangles - 3500, 1000)
    decimation_ratio = min(1.0, target_shell_triangles / max(source_triangles, 1))
    for obj in shell_meshes:
        assign_material(obj, materials)
        if mesh_triangle_count(obj) > 120 and decimation_ratio < 0.995:
            modifier = obj.modifiers.new("Runtime decimation", "DECIMATE")
            modifier.ratio = decimation_ratio
            modifier.use_collapse_triangulate = True
            bpy.context.view_layer.objects.active = obj
            bpy.ops.object.modifier_apply(modifier=modifier.name)

    # Join only the shell so the authored door keeps an independent transform.
    bpy.ops.object.select_all(action="DESELECT")
    for obj in shell_meshes:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = shell_meshes[0]
    bpy.ops.object.join()
    shell = bpy.context.active_object
    shell.name = "Sector11_Capsule_Shell"

    hinge = add_capsule_door(materials)

    scene = bpy.context.scene
    scene.frame_start = 1
    scene.frame_end = 42
    scene.render.fps = 24
    scene.render.fps_base = 1.0

    # Keep the runtime's default state open while preserving the closed first key.
    scene.frame_set(42)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(
        filepath=str(output),
        export_format="GLB",
        export_animations=True,
        export_animation_mode="ACTIONS",
        export_frame_range=True,
        export_yup=True,
        export_apply=True,
        export_materials="EXPORT",
        export_cameras=False,
        export_lights=False,
    )

    runtime_meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    runtime_triangles = sum(mesh_triangle_count(obj) for obj in runtime_meshes)
    report = {
        "source": str(source),
        "output": str(output),
        "removedPresentationParts": sorted(removed),
        "sourceShellTriangles": source_triangles,
        "runtimeTriangles": runtime_triangles,
        "runtimeMeshes": len(runtime_meshes),
        "materials": sorted(material.name for material in materials.values()),
        "animation": {
            "name": hinge.animation_data.action.name,
            "frames": [1, 42],
            "fps": 24,
        },
        "originalBounds": {
            "min": list(original_minimum),
            "max": list(original_maximum),
        },
        "normalizationScale": normalization_scale,
        "targetHeightMeters": args.target_height,
        "signalTreatment": "integrated emissive shell details and one restrained door strip",
    }
    report_path.write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(json.dumps(report))


if __name__ == "__main__":
    main()

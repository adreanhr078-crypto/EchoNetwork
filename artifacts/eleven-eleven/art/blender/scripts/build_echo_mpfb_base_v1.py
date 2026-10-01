"""Build Echo's first production-grade anatomical base with MPFB.

This file deliberately produces a neutral clay review asset.  It is not the
approved Echo hero and must not be imported into Godot until the identity and
deformation gates pass.
"""

from __future__ import annotations

import math
from pathlib import Path

import bpy
from mathutils import Vector

from bl_ext.blender_org.mpfb.services.humanservice import HumanService
from bl_ext.blender_org.mpfb.services.targetservice import TargetService


ROOT = Path(r"C:\Users\yasmo\Documents\Codex\2026-09-11\create-an-image-of-3\EchoNetwork")
OUT = ROOT / "artifacts/eleven-eleven/art/production/echo-hero-mpfb-v1"
OUT.mkdir(parents=True, exist_ok=True)


def clear_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for datablocks in (bpy.data.materials, bpy.data.cameras, bpy.data.lights):
        for block in list(datablocks):
            if block.users == 0:
                datablocks.remove(block)


def look_at(obj: bpy.types.Object, target: Vector) -> None:
    obj.rotation_euler = (target - obj.location).to_track_quat("-Z", "Y").to_euler()


def material(name: str, color: tuple[float, float, float, float], roughness: float, specular: float) -> bpy.types.Material:
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Roughness"].default_value = roughness
    for input_name in ("IOR Level", "Specular IOR Level", "Specular"):
        if input_name in bsdf.inputs:
            bsdf.inputs[input_name].default_value = specular
            break
    return mat


def add_eye(name: str, loc: tuple[float, float, float], scale: tuple[float, float, float], eye_mat: bpy.types.Material) -> bpy.types.Object:
    bpy.ops.mesh.primitive_uv_sphere_add(segments=64, ring_count=32, location=loc)
    eye = bpy.context.object
    eye.name = name
    eye.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    eye.data.materials.append(eye_mat)
    bpy.ops.object.shade_smooth()
    return eye


def add_floor() -> None:
    bpy.ops.mesh.primitive_plane_add(size=12.0, location=(0.0, 0.0, 0.0))
    floor = bpy.context.object
    floor.name = "Review_Floor"
    floor.data.materials.append(material("ReviewFloor", (0.055, 0.065, 0.085, 1.0), 0.32, 0.32))


def add_area(name: str, loc: tuple[float, float, float], energy: float, color: tuple[float, float, float], size: float, target: Vector) -> None:
    data = bpy.data.lights.new(name, "AREA")
    data.energy = energy
    data.color = color
    data.shape = "DISK"
    data.size = size
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    obj.location = loc
    look_at(obj, target)


def setup_world() -> None:
    world = bpy.data.worlds.new("Echo_Review_World") if not bpy.data.worlds else bpy.data.worlds[0]
    bpy.context.scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    bg.inputs["Color"].default_value = (0.015, 0.022, 0.035, 1.0)
    bg.inputs["Strength"].default_value = 0.16


def setup_camera() -> bpy.types.Object:
    data = bpy.data.cameras.new("Echo_Review_Camera")
    data.lens = 72
    data.sensor_width = 36
    data.dof.use_dof = False
    camera = bpy.data.objects.new("Echo_Review_Camera", data)
    bpy.context.collection.objects.link(camera)
    bpy.context.scene.camera = camera
    return camera


def render_view(camera: bpy.types.Object, name: str, loc: tuple[float, float, float], target: tuple[float, float, float]) -> None:
    camera.location = loc
    look_at(camera, Vector(target))
    bpy.context.scene.render.filepath = str(OUT / f"echo-mpfb-{name}-v2.png")
    bpy.ops.render.render(write_still=True)


def main() -> None:
    clear_scene()

    macro = TargetService.get_default_macro_info_dict()
    macro.update({
        "gender": 1.0,
        "age": 0.43,
        "muscle": 0.43,
        "weight": 0.40,
        "proportions": 0.61,
        "height": 0.53,
        "cupsize": 0.0,
        "firmness": 0.5,
        "race": {"asian": 0.78, "caucasian": 0.22, "african": 0.0},
    })
    human = HumanService.create_human(
        mask_helpers=True,
        detailed_helpers=True,
        extra_vertex_groups=True,
        feet_on_ground=True,
        scale=0.1,
        macro_detail_dict=macro,
    )
    human.name = "Echo_MPF_Base_High_NOT_APPROVED"
    human.data.name = "Echo_MPF_Base_High_Mesh"

    # Non-destructive MPFB target stack: youthful anime proportions without
    # destroying production topology. Values are intentionally restrained; the
    # dedicated likeness sculpt will be judged against the canon turnaround.
    TargetService.bulk_load_targets(human, [
        {"target": "head-scale-vert-incr", "value": 0.13},
        {"target": "head-scale-horiz-incr", "value": 0.06},
        {"target": "head-invertedtriangular", "value": 0.18},
        {"target": "chin-width-decr", "value": 0.24},
        {"target": "chin-height-decr", "value": 0.10},
        {"target": "chin-triangle", "value": 0.14},
        {"target": "l-eye-scale-incr", "value": 0.42},
        {"target": "r-eye-scale-incr", "value": 0.42},
        {"target": "l-eye-height1-incr", "value": 0.16},
        {"target": "r-eye-height1-incr", "value": 0.16},
        {"target": "l-eye-height2-incr", "value": 0.12},
        {"target": "r-eye-height2-incr", "value": 0.12},
        {"target": "l-eye-corner2-up", "value": 0.08},
        {"target": "r-eye-corner2-up", "value": 0.08},
        {"target": "nose-scale-horiz-decr", "value": 0.16},
        {"target": "nose-scale-depth-decr", "value": 0.12},
        {"target": "mouth-scale-horiz-decr", "value": 0.10},
    ])

    # Normalize to Echo's currently approved design height while preserving MPFB
    # topology and shape keys.  Stylized facial work remains a later sculpt pass.
    height = human.dimensions.z
    uniform = 1.72 / height
    human.scale = (uniform, uniform, uniform)
    bpy.context.view_layer.objects.active = human
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)

    clay = material("Echo_Anatomy_Clay", (0.42, 0.31, 0.28, 1.0), 0.48, 0.28)
    suit = material("Echo_Blocking_Bodysuit", (0.012, 0.017, 0.026, 1.0), 0.31, 0.42)
    if len(human.data.materials) == 0:
        human.data.materials.append(clay)
    else:
        for i in range(len(human.data.materials)):
            human.data.materials[i] = clay
    human.data.materials.append(suit)

    # Neutral coverage for review; this is not final clothing. Keeping the head
    # and hands visible makes facial/proportion errors easy to judge while
    # avoiding presentation bias from an unfinished nude base.
    for polygon in human.data.polygons:
        center = sum((human.data.vertices[i].co for i in polygon.vertices), Vector()) / len(polygon.vertices)
        is_head = center.z > 1.405
        is_hand = abs(center.x) > 0.66 and 0.82 < center.z < 1.28
        polygon.material_index = 0 if (is_head or is_hand) else len(human.data.materials) - 1

    for polygon in human.data.polygons:
        polygon.use_smooth = True
    subdiv = human.modifiers.new("Review_Subdivision", "SUBSURF")
    subdiv.levels = 1
    subdiv.render_levels = 2
    subdiv.show_only_control_edges = True

    # Review-only eye volumes. They are intentionally separate meshes so the
    # final anime eye proportions can be iterated without damaging face topology.
    eye_mat = material("Echo_Eye_Review", (0.025, 0.055, 0.075, 1.0), 0.18, 0.5)
    # MPFB faces -Y. Eye centers are conservative; close-up review will reveal
    # any required adjustment before the dedicated facial sculpt pass.
    z_eye = 1.605
    add_eye("Echo_Eye_L_Review", (-0.032, -0.111, z_eye), (0.030, 0.020, 0.022), eye_mat)
    add_eye("Echo_Eye_R_Review", (0.032, -0.111, z_eye), (0.030, 0.020, 0.022), eye_mat)
    cyan = material("Echo_Iris_Cyan_Review", (0.01, 0.55, 0.92, 1.0), 0.20, 0.55)
    red = material("Echo_Iris_Red_Review", (0.92, 0.025, 0.018, 1.0), 0.20, 0.55)
    add_eye("Echo_Iris_L_Review", (-0.032, -0.132, z_eye), (0.012, 0.003, 0.012), red)
    add_eye("Echo_Iris_R_Review", (0.032, -0.132, z_eye), (0.012, 0.003, 0.012), cyan)

    # A game-oriented skeleton is added now to validate that the base remains
    # deformable.  It is hidden from review renders and not yet an approved rig.
    rig = HumanService.add_builtin_rig(human, "game_engine", import_weights=True)
    rig.name = "Echo_Game_Rig_Foundation_NOT_APPROVED"
    rig.hide_render = True
    rig.show_in_front = True

    add_floor()
    setup_world()
    camera = setup_camera()
    target = Vector((0.0, 0.0, 1.05))
    add_area("Key_Softbox", (-2.5, -3.2, 3.2), 920.0, (0.72, 0.86, 1.0), 2.1, target)
    add_area("Fill_Softbox", (2.5, -2.4, 2.2), 520.0, (1.0, 0.72, 0.63), 1.8, target)
    add_area("Rim_Softbox", (0.5, 2.2, 2.8), 1050.0, (0.22, 0.62, 1.0), 1.5, target)

    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 1200
    scene.render.resolution_y = 1600
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.film_transparent = False
    scene.render.image_settings.color_depth = "8"
    scene.render.resolution_percentage = 100
    scene.view_settings.look = "AgX - Medium High Contrast"

    render_view(camera, "front", (0.0, -4.25, 1.18), (0.0, 0.0, 0.94))
    render_view(camera, "three-quarter", (2.55, -3.55, 1.28), (0.0, 0.0, 0.98))
    render_view(camera, "profile", (4.25, 0.0, 1.22), (0.0, 0.0, 0.96))
    render_view(camera, "close", (0.0, -1.15, 1.61), (0.0, -0.005, 1.56))

    human["echo_gate_status"] = "NOT_APPROVED_ANATOMY_BASE"
    human["echo_canon_reference"] = "11.11 manhwa + approved Higgsfield turnaround"
    human["echo_height_m"] = 1.72
    scene["echo_pipeline_note"] = "MPFB anatomy foundation; requires anime face, hair, coat, materials and deformation gates"
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT / "echo-hero-mpfb-base-v2.blend"))


if __name__ == "__main__":
    main()

"""Build the Sector 11 wake capsule runtime asset from high and retopologized sources.

The Tripo high mesh is kept only as a geometric detail source.  The retopologized
body receives UVs and a tangent-space normal bake, while authored glass, frame,
lights, hinges, and service panels provide the readable game/cinematic layers.
"""

import argparse
import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--high", required=True)
    parser.add_argument("--low", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--blend", required=True)
    parser.add_argument("--review", required=True)
    parser.add_argument("--report", required=True)
    parser.add_argument("--resolution", type=int, default=4096)
    return parser.parse_args(sys.argv[sys.argv.index("--") + 1 :])


def import_single_mesh(path, name):
    before = set(bpy.context.scene.objects)
    bpy.ops.import_scene.gltf(filepath=str(path))
    meshes = [obj for obj in bpy.context.scene.objects if obj not in before and obj.type == "MESH"]
    if not meshes:
        raise RuntimeError(f"No mesh imported from {path}")
    bpy.ops.object.select_all(action="DESELECT")
    for obj in meshes:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    if len(meshes) > 1:
        bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    obj.name = name
    return obj


def material(name, color, metallic=0.0, roughness=0.45, transmission=0.0, emission=None):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    if "Transmission Weight" in bsdf.inputs:
        bsdf.inputs["Transmission Weight"].default_value = transmission
    if transmission > 0.0:
        bsdf.inputs["Alpha"].default_value = 0.24
        bsdf.inputs["IOR"].default_value = 1.46
        mat.diffuse_color = (*color, 0.24)
        if hasattr(mat, "surface_render_method"):
            mat.surface_render_method = "DITHERED"
    if emission:
        bsdf.inputs["Emission Color"].default_value = (*emission[0], 1.0)
        bsdf.inputs["Emission Strength"].default_value = emission[1]
    return mat


def add_box(name, location, scale, mat, bevel=0.035):
    bpy.ops.mesh.primitive_cube_add(location=location)
    obj = bpy.context.object
    obj.name = name
    obj.scale = (scale[0] * 0.5, scale[1] * 0.5, scale[2] * 0.5)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    modifier = obj.modifiers.new("PrecisionBevel", "BEVEL")
    modifier.width = bevel
    modifier.segments = 3
    obj.data.materials.append(mat)
    return obj


def add_cylinder(name, location, radius, depth, mat, rotation=(0, 0, 0), vertices=32):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(mat)
    bevel = obj.modifiers.new("EdgeBevel", "BEVEL")
    bevel.width = min(radius * 0.18, 0.025)
    bevel.segments = 3
    return obj


def aim(camera, target):
    camera.rotation_euler = (Vector(target) - camera.location).to_track_quat("-Z", "Y").to_euler()


def bake_detail(high, low, image, material_slot):
    bpy.context.scene.render.engine = "BLENDER_EEVEE"
    # Baking is intentionally attempted through Cycles; Blender switches only for this stage.
    bpy.context.scene.render.engine = "BLENDER_EEVEE_NEXT" if hasattr(bpy.types, "EEVEE_NEXT") else "BLENDER_EEVEE"
    try:
        bpy.context.scene.render.engine = "CYCLES"
    except Exception:
        return False, "Cycles unavailable"

    bpy.context.scene.cycles.samples = 1
    bpy.context.scene.render.bake.use_selected_to_active = True
    bpy.context.scene.render.bake.use_cage = False
    bpy.context.scene.render.bake.cage_extrusion = 0.018
    bpy.context.scene.render.bake.margin = 24
    bpy.context.scene.render.bake.normal_space = "TANGENT"

    bpy.ops.object.select_all(action="DESELECT")
    high.hide_render = False
    high.select_set(True)
    low.select_set(True)
    bpy.context.view_layer.objects.active = low
    material_slot.node_tree.nodes.active = material_slot.node_tree.nodes[image.name]
    try:
        bpy.ops.object.bake(type="NORMAL")
        return True, "ok"
    except Exception as exc:
        return False, str(exc)


def main():
    args = parse_args()
    high_path = Path(args.high).resolve()
    low_path = Path(args.low).resolve()
    output = Path(args.output).resolve()
    blend = Path(args.blend).resolve()
    review = Path(args.review).resolve()
    report_path = Path(args.report).resolve()
    for path in (output.parent, blend.parent, review, report_path.parent):
        path.mkdir(parents=True, exist_ok=True)

    bpy.ops.wm.read_factory_settings(use_empty=True)
    high = import_single_mesh(high_path, "WakeCapsule_HighDetail_BakeSource")
    low = import_single_mesh(low_path, "Sector11_WakeCapsule_RuntimeBody")

    # Normalize the approximately one-metre Tripo output to a believable 2.45 m hero prop.
    factor = 2.45 / max(low.dimensions.z, 0.001)
    for obj in (high, low):
        obj.scale = (factor, factor, factor)
        bpy.context.view_layer.objects.active = obj
        obj.select_set(True)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        obj.select_set(False)

    # Generate deterministic runtime UVs on the clean mesh.
    bpy.context.view_layer.objects.active = low
    low.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(66.0), island_margin=0.006)
    bpy.ops.object.mode_set(mode="OBJECT")

    gunmetal = material("M_S11_Gunmetal", (0.028, 0.047, 0.064), metallic=0.68, roughness=0.36)
    gunmetal.node_tree.nodes.new("ShaderNodeTexImage").name = "S11_NormalBake"
    image = bpy.data.images.new("S11_NormalBake", width=args.resolution, height=args.resolution, alpha=False, float_buffer=False)
    image.colorspace_settings.name = "Non-Color"
    image.filepath_raw = str(output.parent / f"Sector11_WakeCapsule_Normal_{args.resolution}.png")
    image.file_format = "PNG"
    tex_node = gunmetal.node_tree.nodes["S11_NormalBake"]
    tex_node.image = image
    normal_node = gunmetal.node_tree.nodes.new("ShaderNodeNormalMap")
    gunmetal.node_tree.links.new(tex_node.outputs["Color"], normal_node.inputs["Color"])
    gunmetal.node_tree.links.new(normal_node.outputs["Normal"], gunmetal.node_tree.nodes["Principled BSDF"].inputs["Normal"])
    low.data.materials.clear()
    low.data.materials.append(gunmetal)

    baked, bake_message = bake_detail(high, low, image, gunmetal)
    if baked:
        image.save()
    high.hide_render = True
    high.hide_set(True)

    ceramic = material("M_S11_Ceramic", (0.30, 0.37, 0.42), metallic=0.12, roughness=0.42)
    dark = material("M_S11_DarkTrim", (0.008, 0.014, 0.022), metallic=0.75, roughness=0.22)
    glass = material("M_S11_CondensationGlass", (0.018, 0.12, 0.17), metallic=0.0, roughness=0.16, transmission=0.94)
    cyan = material("M_S11_CyanMedical", (0.01, 0.18, 0.22), roughness=0.22, emission=((0.0, 0.72, 1.0), 8.0))
    red = material("M_S11_EmergencyRed", (0.30, 0.01, 0.012), roughness=0.25, emission=((1.0, 0.015, 0.008), 7.0))

    # Main opening is on -Y.  Authored layers keep the silhouette readable at gameplay distance.
    center_x = (low.bound_box[0][0] + low.bound_box[6][0]) * 0.5
    front_y = min(v[1] for v in low.bound_box) - 0.018
    add_box("WakeHatch_Glass", (center_x, front_y - 0.018, 1.24), (0.79, 0.035, 1.64), glass, 0.095)
    add_box("HatchFrame_Left", (center_x - 0.445, front_y, 1.24), (0.095, 0.105, 1.78), dark, 0.035)
    add_box("HatchFrame_Right", (center_x + 0.445, front_y, 1.24), (0.095, 0.105, 1.78), dark, 0.035)
    add_box("HatchFrame_Top", (center_x, front_y, 2.09), (0.86, 0.105, 0.10), dark, 0.035)
    add_box("HatchFrame_Bottom", (center_x, front_y, 0.39), (0.86, 0.105, 0.10), dark, 0.035)

    add_box("CeramicPanel_Left", (center_x - 0.60, front_y + 0.055, 1.42), (0.16, 0.10, 0.86), ceramic, 0.045)
    add_box("CeramicPanel_Right", (center_x + 0.60, front_y + 0.055, 1.42), (0.16, 0.10, 0.86), ceramic, 0.045)
    add_box("MedicalLight_Left", (center_x - 0.51, front_y - 0.065, 1.32), (0.025, 0.022, 1.28), cyan, 0.01)
    add_box("MedicalLight_Right", (center_x + 0.51, front_y - 0.065, 1.32), (0.025, 0.022, 1.28), cyan, 0.01)
    add_box("StatusBar_Top", (center_x, front_y - 0.07, 2.20), (0.42, 0.025, 0.035), cyan, 0.008)
    add_box("EmergencyStatus", (center_x + 0.50, front_y - 0.075, 2.20), (0.09, 0.03, 0.035), red, 0.008)

    for z in (0.64, 1.82):
        add_cylinder("HatchHinge", (center_x + 0.51, front_y + 0.005, z), 0.052, 0.22, dark, rotation=(math.pi / 2, 0, 0), vertices=24)
    add_cylinder("ReleaseWheel", (center_x - 0.49, front_y - 0.07, 0.58), 0.105, 0.07, ceramic, rotation=(math.pi / 2, 0, 0), vertices=40)
    add_cylinder("ReleaseHub", (center_x - 0.49, front_y - 0.115, 0.58), 0.042, 0.09, red, rotation=(math.pi / 2, 0, 0), vertices=24)

    runtime_meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH" and obj != high]
    for obj in runtime_meshes:
        obj["eleven_eleven_asset"] = "sector11_wake_capsule"
        obj["eleven_eleven_stage"] = "G0_RUNTIME_CANDIDATE"

    # Presentation scene used as visual evidence, excluded from export by selection.
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE_NEXT" if hasattr(bpy.types, "EEVEE_NEXT") else "BLENDER_EEVEE"
    scene.render.image_settings.file_format = "PNG"
    scene.render.resolution_x = 1080
    scene.render.resolution_y = 1350
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = False
    scene.world = bpy.data.worlds.new("Sector11ReviewWorld")
    scene.world.use_nodes = True
    scene.world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.003, 0.007, 0.014, 1.0)
    scene.world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.12

    for name, loc, energy, color, size in (
        ("Key", (3.8, -5.5, 4.4), 1200, (0.45, 0.72, 1.0), 3.0),
        ("Fill", (-3.5, -2.5, 2.2), 650, (0.14, 0.42, 0.65), 2.5),
        ("Rim", (1.8, 3.5, 3.7), 1100, (0.02, 0.85, 1.0), 2.2),
    ):
        bpy.ops.object.light_add(type="AREA", location=loc)
        light = bpy.context.object
        light.name = name
        light.data.energy = energy
        light.data.color = color
        light.data.shape = "DISK"
        light.data.size = size
        aim(light, (center_x, 0, 1.25))

    bpy.ops.object.camera_add(location=(3.35, -5.4, 2.65))
    camera = bpy.context.object
    camera.data.lens = 60
    aim(camera, (center_x, 0, 1.25))
    scene.camera = camera
    scene.render.filepath = str(review / "hero_three_quarter.png")
    bpy.ops.render.render(write_still=True)
    camera.location = (center_x, -5.6, 1.36)
    camera.data.lens = 68
    aim(camera, (center_x, 0, 1.3))
    scene.render.filepath = str(review / "hero_front.png")
    bpy.ops.render.render(write_still=True)

    bpy.ops.wm.save_as_mainfile(filepath=str(blend), check_existing=False)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in runtime_meshes:
        obj.hide_set(False)
        obj.hide_render = False
        obj.select_set(True)
    bpy.context.view_layer.objects.active = low
    bpy.ops.export_scene.gltf(
        filepath=str(output), export_format="GLB", use_selection=True,
        export_animations=False, export_tangents=True, export_yup=True,
    )

    triangles = 0
    vertices = 0
    for obj in runtime_meshes:
        obj.data.calc_loop_triangles()
        triangles += len(obj.data.loop_triangles)
        vertices += len(obj.data.vertices)
    report = {
        "high_source": str(high_path), "low_source": str(low_path),
        "runtime_output": str(output), "blend": str(blend),
        "normal_resolution": args.resolution, "normal_bake_succeeded": baked,
        "normal_bake_message": bake_message, "runtime_mesh_count": len(runtime_meshes),
        "runtime_triangles": triangles, "runtime_vertices": vertices,
        "dimensions_m": [round(v, 4) for v in low.dimensions],
        "status": "G0_RUNTIME_CANDIDATE_NOT_FINAL_GATE",
    }
    report_path.write_text(json.dumps(report, indent=2), encoding="utf-8")
    print("WAKE_CAPSULE_RUNTIME=" + json.dumps(report), flush=True)


if __name__ == "__main__":
    main()

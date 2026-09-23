from pathlib import Path
import math

import bpy
from mathutils import Vector


ROOT = Path(__file__).resolve().parent


def make_material(name, color, metallic=0.0, roughness=0.5, emission=None, strength=0.0):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1.0)
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (*color, 1.0)
    shader.inputs["Metallic"].default_value = metallic
    shader.inputs["Roughness"].default_value = roughness
    if emission is not None:
        socket = "Emission Color" if "Emission Color" in shader.inputs else "Emission"
        shader.inputs[socket].default_value = (*emission, 1.0)
        shader.inputs["Emission Strength"].default_value = strength
    return mat


def box(name, size, location, mat, bevel=0.025):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    if bevel:
        modifier = obj.modifiers.new("Machined edge radius", "BEVEL")
        modifier.width = bevel
        modifier.segments = 3
        modifier.limit_method = "ANGLE"
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    return obj


def cylinder(name, radius, depth, location, mat, bevel=0.008):
    bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=radius, depth=depth, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(mat)
    if bevel:
        modifier = obj.modifiers.new("Coupling chamfer", "BEVEL")
        modifier.width = bevel
        modifier.segments = 2
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    return obj


def aim_at(obj, target):
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat("-Z", "Z").to_euler()


def make_module():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)

    ceramic = make_material("Ceiling ceramic | abyss blue", (0.075, 0.105, 0.15), 0.62, 0.34)
    edge = make_material("Frame titanium | cold steel", (0.27, 0.36, 0.45), 0.78, 0.27)
    recess = make_material("Vent recess | graphite", (0.012, 0.022, 0.036), 0.44, 0.48)
    diffuser = make_material("Medical diffuser | ice cyan", (0.015, 0.2, 0.28), 0.24, 0.2, (0.08, 0.52, 0.72), 1.65)
    amber = make_material("Service alert | amber", (0.52, 0.18, 0.04), 0.24, 0.3, (0.9, 0.2, 0.03), 0.82)
    objects = []

    # Authored in Y-up game-local coordinates; export conversion below preserves it.
    objects.append(box("Light cassette shell", (3.55, 0.28, 4.75), (0, 0, 0), ceramic, 0.09))
    for x in (-1.73, 1.73):
        objects.append(box("Outer titanium edge", (0.11, 0.16, 4.86), (x, -0.03, 0), edge, 0.025))
    for z in (-2.31, 2.31):
        objects.append(box("End retainer", (3.28, 0.1, 0.13), (0, -0.12, z), edge, 0.025))

    objects.append(box("Diffuser shadow reveal", (1.42, 0.055, 3.68), (0, -0.168, 0), recess, 0.08))
    objects.append(box("Central medical diffuser", (1.17, 0.035, 3.38), (0, -0.207, 0), diffuser, 0.07))
    for x in (-0.78, 0.78):
        objects.append(box("Cyan light guide", (0.045, 0.032, 3.05), (x, -0.208, 0), diffuser, 0.014))

    # Recessed ventilation banks, split by the light cassette.
    for side in (-1.0, 1.0):
        bank_x = side * 1.28
        objects.append(box("Vent bank gasket", (0.6, 0.035, 3.45), (bank_x, -0.158, 0), recess, 0.035))
        for slat in range(5):
            x = bank_x - 0.21 + slat * 0.105
            objects.append(box("Ventilation slat", (0.035, 0.045, 3.17), (x, -0.193, 0), edge, 0.012))
        objects.append(box("Amber status window", (0.16, 0.035, 0.22), (side * 1.42, -0.19, -1.94), amber, 0.02))
        objects.append(box("Service key slot", (0.24, 0.035, 0.12), (side * 1.36, -0.19, 1.97), recess, 0.015))
        for z in (-2.05, 2.05):
            objects.append(cylinder("Ceiling hanger socket", 0.09, 0.1, (side * 1.52, -0.205, z), edge))

    for x in (-1.48, 1.48):
        for z in (-2.15, -1.72, 1.72, 2.15):
            objects.append(cylinder("Flush retainer", 0.035, 0.024, (x, -0.205, z), amber if abs(z) > 2.0 else edge, 0.004))

    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = next(obj for obj in objects if obj.type == "MESH")
    bpy.ops.object.join()
    module = bpy.context.object
    module.name = "Sector11CeilingLightTile"
    module.data.name = "Sector11CeilingLightTileMesh"
    bpy.context.scene.cursor.location = (0, 0, 0)
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
    module.location = (0, 0, 0)
    # Leave a clear structural crossbeam gap between adjacent ceiling tiles.
    module.scale.z = 0.84
    module.rotation_euler.x = math.pi * 0.5
    bpy.context.view_layer.objects.active = module
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    bpy.ops.object.select_all(action="DESELECT")
    module.select_set(True)
    bpy.context.view_layer.objects.active = module
    bpy.ops.export_scene.gltf(filepath=str(ROOT / "sector11_ceiling_tile_v1.glb"), export_format="GLB", use_selection=True, export_apply=True, export_yup=True)
    return module


def render_preview(module):
    # After the Y-up export rotation the finished fixture faces Blender -Z;
    # preview from below so the light, vents, and service details are visible.
    bpy.ops.object.camera_add(location=(5.2, -7.0, -6.2))
    camera = bpy.context.object
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 8.0
    aim_at(camera, (0, 0, 0))
    bpy.context.scene.camera = camera
    for name, location, energy, color, size in [
        ("Cool key", (2, -4, -7), 1450, (0.56, 0.78, 1.0), 6),
        ("Warm fill", (-5, -1, -4), 850, (1.0, 0.54, 0.3), 5),
        ("Cyan rim", (1, 5, -4), 1250, (0.1, 0.66, 1.0), 5),
    ]:
        bpy.ops.object.light_add(type="AREA", location=location)
        light = bpy.context.object
        light.name = name
        light.data.energy = energy
        light.data.color = color
        light.data.shape = "DISK"
        light.data.size = size
        aim_at(light, (0, 0, 0))
    world = bpy.context.scene.world
    world.use_nodes = True
    world.node_tree.nodes.get("Background").inputs["Color"].default_value = (0.012, 0.019, 0.032, 1)
    world.node_tree.nodes.get("Background").inputs["Strength"].default_value = 0.26
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 10
    scene.cycles.use_denoising = True
    scene.render.resolution_x = 1100
    scene.render.resolution_y = 800
    scene.render.resolution_percentage = 100
    scene.view_settings.view_transform = "AgX"
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = str(ROOT / "sector11-ceiling-tile-v1.png")
    bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    module = make_module()
    render_preview(module)
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT / "sector11-ceiling-tile-v1.blend"))
    print("SECTOR11_CEILING_TILE_READY")

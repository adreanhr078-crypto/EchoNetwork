from pathlib import Path
import math

import bpy
from mathutils import Vector


ROOT = Path(__file__).resolve().parent
ROOT.mkdir(parents=True, exist_ok=True)


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for collection in list(bpy.data.collections):
        if collection.name != "Collection":
            bpy.data.collections.remove(collection)


def make_material(name, color, metallic=0.0, roughness=0.5, emission=None, emission_strength=0.0):
    material = bpy.data.materials.new(name)
    material.diffuse_color = (*color, 1.0)
    material.use_nodes = True
    shader = material.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (*color, 1.0)
    shader.inputs["Metallic"].default_value = metallic
    shader.inputs["Roughness"].default_value = roughness
    if emission is not None:
        if "Emission Color" in shader.inputs:
            shader.inputs["Emission Color"].default_value = (*emission, 1.0)
        elif "Emission" in shader.inputs:
            shader.inputs["Emission"].default_value = (*emission, 1.0)
        if "Emission Strength" in shader.inputs:
            shader.inputs["Emission Strength"].default_value = emission_strength
    return material


def assign_material(obj, material):
    obj.data.materials.append(material)
    return obj


def bevel_mesh(obj, width=0.035, segments=3):
    if width > 0:
        modifier = obj.modifiers.new("Soft machined edges", "BEVEL")
        modifier.width = width
        modifier.segments = segments
        modifier.limit_method = "ANGLE"
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    return obj


def box(name, size, location, material, bevel=0.035):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    assign_material(obj, material)
    return bevel_mesh(obj, bevel)


def cylinder(name, radius, depth, location, material, rotation=(0.0, 0.0, 0.0), vertices=24, bevel=0.012):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    assign_material(obj, material)
    return bevel_mesh(obj, bevel, 2)


def sphere(name, radius, location, material):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=8, radius=radius, location=location)
    obj = bpy.context.object
    obj.name = name
    assign_material(obj, material)
    return obj


def text_mesh(body, location, size, material):
    bpy.ops.object.text_add(location=location)
    obj = bpy.context.object
    obj.name = "Marking - " + body
    obj.data.body = body
    obj.data.size = size
    obj.data.align_x = "CENTER"
    obj.data.align_y = "CENTER"
    obj.data.extrude = 0.001
    assign_material(obj, material)
    bpy.ops.object.convert(target="MESH")
    return bpy.context.object


def join_module(name, objects):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        if obj and obj.name in bpy.context.scene.objects:
            obj.select_set(True)
    active = next(obj for obj in objects if obj and obj.name in bpy.context.scene.objects and obj.type == "MESH")
    bpy.context.view_layer.objects.active = active
    bpy.ops.object.join()
    module = bpy.context.object
    module.name = name
    module.data.name = name + "Mesh"
    bpy.context.scene.cursor.location = (0.0, 0.0, 0.0)
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
    module.location = (0.0, 0.0, 0.0)
    module.rotation_euler = (0.0, 0.0, 0.0)
    return module


def export_glb(obj, path):
    # The geometry is authored in Y-up for clarity, while Blender's native
    # scene is Z-up. Rotate the joined mesh so glTF's Y-up conversion leaves
    # the wall modules upright in Godot.
    obj.rotation_euler.x = math.pi * 0.5
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.export_scene.gltf(
        filepath=str(path),
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_yup=True,
    )


def build_observation_module(m):
    objects = []
    objects.append(box("Observation shell", (5.65, 7.2, 0.48), (0, 3.6, 0), m["shell"], 0.085))
    objects.append(box("Outer frame left", (0.22, 6.9, 0.22), (-2.62, 3.6, 0.34), m["steel"], 0.035))
    objects.append(box("Outer frame right", (0.22, 6.9, 0.22), (2.62, 3.6, 0.34), m["steel"], 0.035))
    objects.append(box("Upper lintel", (5.2, 0.2, 0.2), (0, 6.82, 0.34), m["steel"], 0.035))
    objects.append(box("Lower sill", (5.2, 0.26, 0.22), (0, 0.34, 0.34), m["steel"], 0.04))

    objects.append(box("Viewing glass", (3.78, 3.42, 0.045), (0, 3.9, 0.282), m["glass"], 0.045))
    for x in (-1.99, 1.99):
        objects.append(box("Window gasket", (0.08, 3.64, 0.08), (x, 3.9, 0.34), m["rubber"], 0.018))
    for y in (2.06, 5.74):
        objects.append(box("Window gasket", (4.05, 0.08, 0.08), (0, y, 0.34), m["rubber"], 0.018))
    objects.append(box("Horizontal viewing mullion", (3.85, 0.1, 0.1), (0, 3.48, 0.39), m["steel"], 0.018))

    for x in (-2.4, 2.4):
        cylinder("Coolant return", 0.075, 6.4, (x, 3.6, 0.39), m["steel"], rotation=(math.pi * 0.5, 0, 0), bevel=0.02)
        for y in (0.65, 6.45):
            cylinder("Conduit collar", 0.13, 0.1, (x, y, 0.39), m["signal"], rotation=(math.pi * 0.5, 0, 0), bevel=0.015)

    objects.append(box("Observation console body", (3.65, 1.03, 0.2), (0, 1.28, 0.39), m["steel"], 0.065))
    objects.append(box("Observation console glass", (2.85, 0.54, 0.045), (0, 1.36, 0.51), m["screen"], 0.035))
    objects.append(box("Console cyan readout", (1.48, 0.045, 0.022), (0, 1.46, 0.54), m["cyan"], 0.006))
    objects.append(box("Console amber readout", (0.78, 0.04, 0.022), (0, 1.23, 0.54), m["amber"], 0.006))
    for x in (-1.46, -1.12, 1.12, 1.46):
        objects.append(sphere("Console key", 0.055, (x, 1.15, 0.54), m["signal"]))

    objects.append(box("Bay ID plate", (2.5, 0.33, 0.09), (0, 6.08, 0.36), m["rubber"], 0.035))
    objects.append(text_mesh("OBSERVATION  //  04", (0, 6.08, 0.414), 0.18, m["cyan"]))
    for x in (-2.38, 2.38):
        for y in (0.65, 1.0, 6.15, 6.5):
            objects.append(cylinder("Fastener", 0.045, 0.035, (x, y, 0.48), m["amber"] if y > 6 else m["steel"], vertices=16, bevel=0.008))
    objects.append(box("Amber service marker", (0.08, 0.42, 0.055), (2.41, 5.42, 0.46), m["amber"], 0.012))
    objects.append(box("Cyan service marker", (0.08, 0.42, 0.055), (-2.41, 5.42, 0.46), m["cyan"], 0.012))

    return join_module("Sector11ObservationModule", objects)


def build_service_module(m):
    objects = []
    objects.append(box("Service shell", (5.65, 7.2, 0.48), (0, 3.6, 0), m["shell"], 0.085))
    for x in (-2.62, 2.62):
        objects.append(box("Service edge rail", (0.22, 6.9, 0.22), (x, 3.6, 0.34), m["steel"], 0.035))

    objects.append(box("Hatch recess", (3.9, 4.55, 0.16), (0, 3.85, 0.32), m["rubber"], 0.065))
    objects.append(box("Hatch door", (3.47, 4.12, 0.13), (0, 3.85, 0.44), m["armor"], 0.08))
    for x in (-1.82, 1.82):
        objects.append(box("Hatch rail", (0.12, 4.27, 0.11), (x, 3.85, 0.55), m["steel"], 0.025))
    for y in (1.62, 6.08):
        objects.append(box("Hatch rail", (3.76, 0.12, 0.11), (0, y, 0.55), m["steel"], 0.025))

    for i in range(6):
        y = 5.15 + i * 0.13
        objects.append(box("Intake louvre", (1.7, 0.045, 0.08), (-0.25, y, 0.58), m["steel"], 0.012))
    objects.append(box("Status display surround", (1.18, 0.88, 0.12), (1.06, 5.08, 0.58), m["rubber"], 0.045))
    objects.append(box("Status display glass", (0.93, 0.62, 0.05), (1.06, 5.08, 0.66), m["screen"], 0.03))
    for i in range(4):
        y = 4.89 + i * 0.12
        objects.append(box("Status graph line", (0.65 - i * 0.07, 0.025, 0.02), (1.06, y, 0.70), m["cyan"], 0.004))

    cylinder("Pressure gauge rim", 0.3, 0.1, (1.06, 3.55, 0.62), m["steel"], vertices=32, bevel=0.018)
    cylinder("Pressure gauge face", 0.235, 0.035, (1.06, 3.55, 0.69), m["screen"], vertices=32, bevel=0.008)
    objects.append(box("Gauge needle", (0.025, 0.16, 0.025), (1.06, 3.59, 0.72), m["amber"], 0.004))
    objects.append(box("Warning plate", (1.2, 0.26, 0.06), (0, 6.55, 0.42), m["rubber"], 0.02))
    objects.append(text_mesh("LIFE SUPPORT  //  11", (0, 6.55, 0.46), 0.16, m["amber"]))

    for x in (-2.25, 2.25):
        cylinder("External coolant line", 0.06, 5.8, (x, 3.62, 0.45), m["steel"], rotation=(math.pi * 0.5, 0, 0), bevel=0.015)
        for y in (0.82, 6.42):
            cylinder("Coolant coupling", 0.12, 0.11, (x, y, 0.45), m["cyan"], rotation=(math.pi * 0.5, 0, 0), bevel=0.012)
    for x in (-1.6, 1.6):
        for y in (1.9, 2.25, 5.45, 5.8):
            cylinder("Hatch fastener", 0.05, 0.045, (x, y, 0.64), m["amber"], vertices=16, bevel=0.006)

    objects.append(box("Emergency lever housing", (0.46, 0.92, 0.14), (-1.2, 3.8, 0.59), m["rubber"], 0.04))
    objects.append(box("Emergency lever", (0.1, 0.63, 0.17), (-1.2, 3.8, 0.7), m["amber"], 0.025))
    objects.append(box("Signal strip", (0.1, 0.58, 0.06), (2.33, 2.7, 0.55), m["cyan"], 0.015))

    return join_module("Sector11ServiceModule", objects)


def aim_at(obj, target, up_axis="Y"):
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat("-Z", up_axis).to_euler()


def setup_preview(observation, service):
    bpy.ops.object.select_all(action="DESELECT")
    observation.location.x = -3.1
    service.location.x = 3.1
    bpy.ops.mesh.primitive_plane_add(size=40, location=(0, 0, -0.08))
    floor = bpy.context.object
    floor.name = "Preview floor"
    floor_mat = make_material("Preview floor • charcoal", (0.025, 0.04, 0.065), 0.32, 0.52)
    assign_material(floor, floor_mat)

    bpy.ops.object.camera_add(location=(13.2, -12.0, 17.0))
    camera = bpy.context.object
    camera.name = "Product camera"
    aim_at(camera, (0, 0, 3.4), "Z")
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 16.2
    bpy.context.scene.camera = camera

    def area(name, location, energy, color, size):
        bpy.ops.object.light_add(type="AREA", location=location)
        light = bpy.context.object
        light.name = name
        light.data.energy = energy
        light.data.color = color
        light.data.shape = "DISK"
        light.data.size = size
        aim_at(light, (0, 0, 3.4))

    area("Cool key", (2, -9, 11), 1700, (0.58, 0.76, 1.0), 9)
    area("Warm fill", (-10, -7, 6), 950, (1.0, 0.56, 0.3), 7)
    area("Cyan rim", (1, 9, 8), 1450, (0.12, 0.68, 1.0), 8)

    world = bpy.context.scene.world
    world.color = (0.012, 0.02, 0.035)
    world.use_nodes = True
    world.node_tree.nodes.get("Background").inputs["Color"].default_value = (0.012, 0.02, 0.035, 1)
    world.node_tree.nodes.get("Background").inputs["Strength"].default_value = 0.32
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 16
    scene.cycles.use_denoising = True
    scene.render.resolution_x = 1400
    scene.render.resolution_y = 900
    scene.render.resolution_percentage = 100
    scene.view_settings.view_transform = "AgX"
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = str(ROOT / "sector11-modular-kit-v1.png")
    bpy.ops.render.render(write_still=True)


def main():
    clear_scene()
    m = {
        "shell": make_material("Containment ceramic • deep blue", (0.075, 0.11, 0.16), 0.48, 0.42),
        "armor": make_material("Machined armor • blue steel", (0.19, 0.27, 0.36), 0.78, 0.32),
        "steel": make_material("Brushed titanium", (0.28, 0.36, 0.45), 0.82, 0.29),
        "rubber": make_material("Recess • graphite", (0.025, 0.042, 0.064), 0.3, 0.58),
        "glass": make_material("Observation glass • smoked teal", (0.012, 0.12, 0.18), 0.32, 0.14, (0.0, 0.08, 0.13), 0.32),
        "screen": make_material("Diagnostics screen", (0.008, 0.045, 0.066), 0.18, 0.28, (0.0, 0.18, 0.26), 0.48),
        "cyan": make_material("Status cyan", (0.0, 0.36, 0.49), 0.32, 0.25, (0.0, 0.64, 0.92), 1.7),
        "amber": make_material("Hazard amber", (0.52, 0.2, 0.045), 0.38, 0.32, (1.0, 0.24, 0.035), 0.9),
        "signal": make_material("Soft indicator", (0.15, 0.5, 0.62), 0.4, 0.24, (0.1, 0.6, 1.0), 0.75),
    }

    observation = build_observation_module(m)
    export_glb(observation, ROOT / "sector11_observation_module_v1.glb")
    service = build_service_module(m)
    export_glb(service, ROOT / "sector11_service_module_v1.glb")
    setup_preview(observation, service)
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT / "sector11-modular-kit-v1.blend"))
    print("SECTOR11_KIT_READY", observation.name, service.name)


if __name__ == "__main__":
    main()

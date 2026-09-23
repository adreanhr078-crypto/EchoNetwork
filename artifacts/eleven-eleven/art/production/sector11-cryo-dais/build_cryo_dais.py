from pathlib import Path
import math

import bpy
from mathutils import Vector


ROOT = Path(__file__).resolve().parent
ROOT.mkdir(parents=True, exist_ok=True)


def material(name, color, metallic=0.0, roughness=0.5, emission=None, strength=0.0):
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


def cylinder(name, radius, depth, location, mat, vertices=32, bevel=0.008):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(mat)
    if bevel:
        modifier = obj.modifiers.new("Machined cap", "BEVEL")
        modifier.width = bevel
        modifier.segments = 2
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    return obj


def text_mesh(body, size, location, rotation, mat):
    bpy.ops.object.text_add(location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = "Engraving - " + body
    obj.data.body = body
    obj.data.size = size
    obj.data.align_x = "CENTER"
    obj.data.align_y = "CENTER"
    obj.data.extrude = 0.001
    obj.data.bevel_depth = 0.0005
    obj.data.materials.append(mat)
    bpy.ops.object.convert(target="MESH")
    return bpy.context.object


def aim_at(obj, target, up="Z"):
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat("-Z", up).to_euler()


def build():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    shell = material("Dais ceramic | midnight blue", (0.055, 0.085, 0.13), 0.62, 0.34)
    armor = material("Dais titanium | blue steel", (0.22, 0.31, 0.42), 0.78, 0.28)
    dark = material("Recess | graphite", (0.015, 0.026, 0.043), 0.45, 0.48)
    cyan = material("Neural guide | cyan", (0.0, 0.28, 0.37), 0.35, 0.24, (0.0, 0.5, 0.72), 1.25)
    amber = material("Caution | amber", (0.46, 0.15, 0.035), 0.28, 0.32, (0.8, 0.18, 0.025), 0.72)
    white = material("Engraving | frost", (0.46, 0.62, 0.72), 0.12, 0.4, (0.1, 0.24, 0.32), 0.32)
    objects = []

    # Open-frame docking rails surround the cryopod's footprint without lifting it.
    objects.append(box("Front docking beam", (3.55, 0.22, 0.12), (0, -1.22, 0.075), shell, 0.04))
    objects.append(box("Rear docking beam", (3.55, 0.22, 0.12), (0, 1.22, 0.075), shell, 0.04))
    for x in (-1.67, 1.67):
        objects.append(box("Side docking beam", (0.22, 2.42, 0.12), (x, 0, 0.075), shell, 0.04))
        objects.append(box("Raised titanium edge", (0.075, 2.12, 0.075), (x * 0.9, 0, 0.145), armor, 0.02))

    for x in (-1.26, 1.26):
        for y in (-0.83, 0.83):
            objects.append(box("Corner load plate", (0.52, 0.46, 0.045), (x, y, 0.05), armor, 0.035))
            objects.append(box("Isolation pad", (0.34, 0.28, 0.025), (x, y, 0.083), dark, 0.018))
            for dx in (-0.17, 0.17):
                for dy in (-0.12, 0.12):
                    objects.append(cylinder("Flush anchor bolt", 0.032, 0.018, (x + dx, y + dy, 0.108), armor, 16, 0.004))

    bpy.ops.mesh.primitive_torus_add(major_segments=96, minor_segments=12, major_radius=1.02, minor_radius=0.026, location=(0, 0, 0.036))
    guide_ring = bpy.context.object
    guide_ring.name = "Cryo synchronization ring"
    guide_ring.data.materials.append(cyan)
    objects.append(guide_ring)

    bpy.ops.mesh.primitive_torus_add(major_segments=96, minor_segments=8, major_radius=1.15, minor_radius=0.011, location=(0, 0, 0.025))
    outer_trace = bpy.context.object
    outer_trace.name = "Secondary floor trace"
    outer_trace.data.materials.append(armor)
    objects.append(outer_trace)

    # Short amber hazard bars sit on the player-facing beam.
    for index in range(9):
        x = -1.35 + index * 0.3375
        objects.append(box("Amber hazard inlay", (0.18, 0.045, 0.018), (x, -1.22, 0.145), amber, 0.008))
    objects.append(box("Control recess", (0.72, 0.28, 0.045), (0, -1.22, 0.16), dark, 0.028))
    objects.append(box("Control cyan readout", (0.43, 0.035, 0.018), (0, -1.22, 0.19), cyan, 0.008))
    objects.append(box("Control amber alert", (0.16, 0.028, 0.016), (0, -1.22, 0.19), amber, 0.006))

    # Vertical stencil faces the approach from Echo's side of the pod.
    objects.append(text_mesh("SUBJECT  EX-011  //  CRYO BAY", 0.075, (0, -1.342, 0.075), (math.pi * 0.5, 0, 0), white))

    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = next(obj for obj in objects if obj.type == "MESH")
    bpy.ops.object.join()
    root = bpy.context.object
    root.name = "Sector11CryoDockingDais"
    root.data.name = "Sector11CryoDockingDaisMesh"
    bpy.context.scene.cursor.location = (0, 0, 0)
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
    root.location = (0, 0, 0)
    root.rotation_euler = (0, 0, 0)
    bpy.ops.export_scene.gltf(filepath=str(ROOT / "sector11_cryo_dais_v1.glb"), export_format="GLB", use_selection=True, export_apply=True, export_yup=True)
    return root


def preview():
    floor_mat = material("Preview cyclorama", (0.025, 0.04, 0.063), 0.28, 0.52)
    bpy.ops.mesh.primitive_plane_add(size=18, location=(0, 0, -0.025))
    floor = bpy.context.object
    floor.name = "Preview floor"
    floor.data.materials.append(floor_mat)
    bpy.ops.object.camera_add(location=(5.8, -7.2, 6.2))
    camera = bpy.context.object
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 7.3
    aim_at(camera, (0, 0, 0.12))
    bpy.context.scene.camera = camera
    for name, loc, energy, color, size in [
        ("Cool key", (2, -4, 7), 1250, (0.58, 0.78, 1.0), 6),
        ("Warm fill", (-5, -1, 3), 780, (1.0, 0.54, 0.31), 5),
        ("Cyan rim", (1, 5, 4), 1150, (0.12, 0.68, 1.0), 5),
    ]:
        bpy.ops.object.light_add(type="AREA", location=loc)
        light = bpy.context.object
        light.name = name
        light.data.energy = energy
        light.data.color = color
        light.data.shape = "DISK"
        light.data.size = size
        aim_at(light, (0, 0, 0.12))
    world = bpy.context.scene.world
    world.use_nodes = True
    world.node_tree.nodes.get("Background").inputs["Color"].default_value = (0.012, 0.02, 0.035, 1)
    world.node_tree.nodes.get("Background").inputs["Strength"].default_value = 0.28
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 12
    scene.cycles.use_denoising = True
    scene.render.resolution_x = 1200
    scene.render.resolution_y = 850
    scene.render.resolution_percentage = 100
    scene.view_settings.view_transform = "AgX"
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = str(ROOT / "sector11-cryo-dais-v1.png")
    bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    build()
    preview()
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT / "sector11-cryo-dais-v1.blend"))
    print("SECTOR11_CRYO_DAIS_READY")

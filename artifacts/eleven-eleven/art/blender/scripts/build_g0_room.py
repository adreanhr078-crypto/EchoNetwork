"""Bounded G0 room material study. Authored in metres, Z-up; no Canon claims."""
import argparse
import math
import sys
from pathlib import Path
import bpy
from mathutils import Vector

parser = argparse.ArgumentParser()
parser.add_argument('--output', required=True)
args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:])
out = Path(args.output).resolve()
out.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)

def material(name, color, metal=0.0, rough=0.5, emission=0.0):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get('Principled BSDF')
    bsdf.inputs['Base Color'].default_value = (*color, 1)
    bsdf.inputs['Metallic'].default_value = metal
    bsdf.inputs['Roughness'].default_value = rough
    bsdf.inputs['Emission Color'].default_value = (*color, 1)
    bsdf.inputs['Emission Strength'].default_value = emission
    return mat

steel = material('ObsidianSteel', (0.038, 0.052, 0.07), 0.65, 0.34)
panel = material('SatinWallPanels', (0.12, 0.15, 0.18), 0.45, 0.48)
floor = material('DarkFloorCeramic', (0.065, 0.085, 0.095), 0.3, 0.25)
ivory = material('IvoryInset', (0.55, 0.58, 0.54), 0.15, 0.6)
cyan = material('GuidanceCyan', (0.12, 0.7, 0.8), 0.1, 0.35, 2)
amber = material('WarmPractical', (1.0, 0.48, 0.16), 0, 0.4, 3)
red = material('RestrainedSignal', (0.5, 0.018, 0.035), 0.1, 0.4, 2)

def box(name, loc, size, mat, bevel=0.025):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    if bevel:
        mod = obj.modifiers.new('Manufactured edge highlights', 'BEVEL')
        mod.width = bevel
        mod.segments = 2
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.modifier_apply(modifier=mod.name)
    return obj

# The central aisle stays clear for the existing G0 interaction positions.
for x in range(-3, 4):
    for y in range(-3, 4):
        box('FloorTile', (x*2, y*2, -0.055), (1.98, 1.98, 0.1), floor, 0.012)
for side in [-1, 1]:
    for y in [-6, -3, 0, 3, 6]:
        box('WallPanel', (side*7, y, 2), (0.18, 2.88, 4), panel)
        box('WallRib', (side*6.8, y-1.43, 2), (0.28, 0.12, 4), steel)
        box('RecessedIvory', (side*6.88, y, 2.5), (0.08, 1.8, 0.65), ivory)
        box('SignalRail', (side*6.75, y, 0.22), (0.08, 2.2, 0.045), cyan, 0.008)
    box('BackFlank', (side*4.65, 7, 2), (4.7, 0.2, 4), panel)
    box('DoorJamb', (side*1.35, 6.84, 1.8), (0.32, 0.4, 3.6), steel)
    box('DoorGuide', (side*1.15, 6.60, 1.8), (0.04, 0.03, 3.2), cyan, 0.005)
    box('SealedDoorLeaf', (side*0.53, 6.98, 1.65), (1.03, 0.15, 3.3), steel)
    for y in [-4, 0, 4]:
        box('OverheadLightHousing', (side*4.1, y, 3.83), (0.42, 2.0, 0.15), steel)
        box('OverheadDiffuser', (side*4.1, y, 3.74), (0.27, 1.75, 0.025), amber)
box('DoorLintel', (0, 6.85, 3.6), (3, 0.4, 0.28), steel)
box('DoorStatus', (0, 6.6, 3.57), (0.38, 0.025, 0.05), red, 0.005)
for y in [-5, 0, 5]:
    box('CeilingCrossbeam', (0, y, 3.98), (14, 0.24, 0.25), steel)
for side in [-1, 1]:
    for y in [-3, 3]:
        box('ServiceCabinet', (side*6.15, y, 0.75), (0.8, 1.55, 1.5), steel)
        for z in [0.45, 0.75, 1.05]:
            box('CabinetVent', (side*5.735, y, z), (0.025, 1.14, 0.04), ivory, 0)

# Batch static geometry by material to keep render submissions bounded.
for mat in [steel, panel, floor, ivory, cyan, amber, red]:
    bpy.ops.object.select_all(action='DESELECT')
    objects = [o for o in bpy.context.scene.objects if o.type == 'MESH' and o.data.materials and o.data.materials[0] == mat]
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    bpy.context.object.name = 'G0Room_' + mat.name
bpy.ops.export_scene.gltf(filepath=str(out/'g0-room.raw.glb'), export_format='GLB', export_cameras=False, export_lights=False)

def area(name, loc, energy, color, size):
    data = bpy.data.lights.new(name, 'AREA')
    data.energy, data.color, data.shape, data.size = energy, color, 'DISK', size
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    obj.location = loc
    return obj

for y in [-4, 1, 5]:
    area('Ceiling softbox', (0, y, 3.7), 600, (0.75, 0.83, 1), 5)
bpy.ops.object.camera_add(location=(5.6, -6.4, 2.25))
camera = bpy.context.object
camera.rotation_euler = (Vector((0, 5, 1.65))-camera.location).to_track_quat('-Z', 'Y').to_euler()
camera.data.lens = 24
scene = bpy.context.scene
scene.camera = camera
scene.render.engine = 'CYCLES'
scene.cycles.samples = 24
scene.cycles.use_denoising = True
scene.render.resolution_x, scene.render.resolution_y = 1280, 720
scene.render.resolution_percentage = 100
scene.world.color = (0.12, 0.12, 0.12)
scene.render.image_settings.file_format = 'PNG'
scene.render.filepath = str(out/'g0-room-review.png')
bpy.ops.wm.save_as_mainfile(filepath=str(out/'g0-room-study.blend'))
bpy.ops.render.render(write_still=True)
print('G0_ROOM_AUTHORED')

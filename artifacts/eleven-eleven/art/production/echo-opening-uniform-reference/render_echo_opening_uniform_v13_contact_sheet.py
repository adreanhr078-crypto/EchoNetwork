"""Render v13 phase and angle review frames."""

import math
from pathlib import Path

import bpy
from mathutils import Vector

REF = Path(r"C:\Users\yasmo\EchoNetwork\artifacts\eleven-eleven\art\production\echo-opening-uniform-reference")
BLEND = REF / "echo-opening-uniform-v13.blend"

bpy.ops.wm.open_mainfile(filepath=str(BLEND))
scene = bpy.context.scene
rig = bpy.data.objects["EchoOpeningUniformRig"]

for track in rig.animation_data.nla_tracks:
    track.mute = True

camera_data = bpy.data.cameras.new("V13ReviewCamera")
camera = bpy.data.objects.new("V13ReviewCamera", camera_data)
scene.collection.objects.link(camera)
camera_data.type = "ORTHO"
camera_data.ortho_scale = 1.82
scene.camera = camera

ground_material = bpy.data.materials.new("ReviewGround")
ground_material.diffuse_color = (0.12, 0.17, 0.21, 1.0)
bpy.ops.mesh.primitive_plane_add(size=4.0, location=(0.0, 0.0, -0.001))
ground = bpy.context.object
ground.name = "V13ReviewGround"
ground.data.materials.append(ground_material)

scene.render.engine = "BLENDER_WORKBENCH"
scene.display.shading.light = "STUDIO"
scene.display.shading.color_type = "MATERIAL"
scene.display.shading.show_cavity = True
scene.display.shading.cavity_type = "BOTH"
scene.display.shading.show_shadows = True
scene.render.resolution_x = 280
scene.render.resolution_y = 340
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"


def point_camera(degrees):
    angle = math.radians(degrees)
    target = Vector((0.0, 0.0, 0.49))
    camera.location = target + Vector((3.1 * math.cos(angle), 3.1 * math.sin(angle), 0.71))
    camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()


def render_pose(action_name, phase, cycle_frames, path):
    action = bpy.data.actions[action_name]
    rig.animation_data.action = action
    rig.animation_data.action_slot = action.slots[0]
    frame = phase * cycle_frames
    whole = math.floor(frame)
    scene.frame_set(whole, subframe=frame - whole)
    scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)


# 1. Render 12 Phase Frames (Walk 6 frames, Run 6 frames)
point_camera(225.0)
for row, (action_name, cycle) in enumerate((("preset:walk", 34), ("preset:run", 20))):
    for sample in range(6):
        frame_path = REF / f"v13-phase-frame-{row * 6 + sample:02d}.png"
        render_pose(action_name, sample / 6.0, cycle, frame_path)

# 2. Render 24 Angle Frames (Walk phase 0.0, Run phase 0.0, Run phase 0.5 across 8 angles)
for row, (action_name, phase, cycle) in enumerate((
    ("preset:walk", 0.0, 34),
    ("preset:run", 0.0, 20),
    ("preset:run", 0.5, 20),
)):
    for angle_index in range(8):
        point_camera(angle_index * 45.0)
        frame_path = REF / f"v13-angle-frame-{row * 8 + angle_index:02d}.png"
        render_pose(action_name, phase, cycle, frame_path)

print("V13_REVIEW_FRAMES", 36)

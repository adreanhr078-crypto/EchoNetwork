"""Render two complete v12 walk/run cycles from follow cameras for review."""

import os
from pathlib import Path
import math

import bpy
from mathutils import Vector


ROOT = Path(r"C:\Users\yasmo\EchoNetwork\artifacts\eleven-eleven")
REF = ROOT / "art/production/echo-opening-uniform-reference"
FRAMES = Path(os.environ["TEMP"]) / "echo_v12_motion_preview"
FRAMES.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(REF / "echo-opening-uniform-v12.blend"))
scene = bpy.context.scene
rig = bpy.data.objects["EchoOpeningUniformRig"]
for track in rig.animation_data.nla_tracks:
    track.mute = True

camera_data = bpy.data.cameras.new("V12MotionReviewCamera")
camera = bpy.data.objects.new("V12MotionReviewCamera", camera_data)
scene.collection.objects.link(camera)
camera_data.type = "ORTHO"
camera_data.ortho_scale = 1.82
scene.camera = camera

ground_material = bpy.data.materials.new("ReviewGround")
ground_material.diffuse_color = (0.12, 0.17, 0.21, 1.0)
bpy.ops.mesh.primitive_plane_add(size=20.0, location=(2.0, 0.0, -0.012))
ground = bpy.context.object
ground.name = "V12MotionReviewGround"
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

CLIPS = (
    ("walk", "preset:walk", 24, 48, 1.113846153846154 / 1.81),
    ("run", "preset:run", 12, 24, 5.688571428571428 / 1.81),
)

for label, action_name, cycle, frame_count, local_speed in CLIPS:
    action = bpy.data.actions[action_name]
    rig.animation_data.action = action
    rig.animation_data.action_slot = action.slots[0]
    for view, degrees in (("side-back", 225.0),):
        radians = math.radians(degrees)
        offset = Vector((3.1 * math.cos(radians), 3.1 * math.sin(radians), 0.71))
        for frame in range(frame_count):
            scene.frame_set(frame % cycle)
            rig.location.x = local_speed * frame / 24.0
            target = Vector((rig.location.x, 0.0, 0.49))
            camera.location = target + offset
            camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()
            scene.render.filepath = str(FRAMES / f"v12-{label}-{view}-{frame:03d}.png")
            bpy.ops.render.render(write_still=True)

print("V12_MOTION_PREVIEW_FRAMES", FRAMES, 72)

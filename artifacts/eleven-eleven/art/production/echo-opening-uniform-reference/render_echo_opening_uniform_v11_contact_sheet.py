"""Render the two v11 gait cycles for a quick silhouette and contact review."""

import math
from pathlib import Path

import bpy
from mathutils import Vector


ROOT = Path(r"C:\Users\yasmo\EchoNetwork\artifacts\eleven-eleven")
REF = ROOT / "art/production/echo-opening-uniform-reference"
bpy.ops.wm.open_mainfile(filepath=str(REF / "echo-opening-uniform-v11.blend"))
scene = bpy.context.scene
rig = bpy.data.objects["EchoOpeningUniformRig"]
for track in rig.animation_data.nla_tracks:
    track.mute = True

camera_data = bpy.data.cameras.new("V11GaitReviewCamera")
camera = bpy.data.objects.new("V11GaitReviewCamera", camera_data)
scene.collection.objects.link(camera)
camera.location = Vector((-2.7, -3.3, 1.05))
target = Vector((0.0, 0.0, 0.50))
direction = target - camera.location
camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
camera_data.type = "ORTHO"
camera_data.ortho_scale = 1.92
scene.camera = camera

scene.render.engine = "BLENDER_WORKBENCH"
scene.display.shading.light = "STUDIO"
scene.display.shading.color_type = "MATERIAL"
scene.display.shading.show_cavity = True
scene.display.shading.cavity_type = "BOTH"
scene.display.shading.show_shadows = True
scene.render.resolution_x = 320
scene.render.resolution_y = 380
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.film_transparent = False

for index, (action_name, cycle) in enumerate((('preset:walk', 24), ('preset:run', 12))):
    action = bpy.data.actions[action_name]
    rig.animation_data.action = action
    rig.animation_data.action_slot = action.slots[0]
    for sample in range(5):
        phase = sample / 5.0
        frame = phase * cycle
        whole_frame = math.floor(frame)
        scene.frame_set(whole_frame, subframe=frame - whole_frame)
        scene.render.filepath = str(REF / f"v11-gait-frame-{index * 5 + sample:02d}.png")
        bpy.ops.render.render(write_still=True)

print("V11_CONTACT_FRAMES", 10)

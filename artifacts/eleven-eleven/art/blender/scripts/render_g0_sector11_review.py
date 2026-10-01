import bpy
import math
import os
from mathutils import Vector


OUTPUT_DIR = os.path.abspath(
    os.path.join(os.path.dirname(__file__), "..", "review", "g0-sector11-r4")
)
os.makedirs(OUTPUT_DIR, exist_ok=True)


def point_camera(camera, target):
    camera.rotation_euler = (Vector(target) - camera.location).to_track_quat("-Z", "Y").to_euler()


scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x = 960
scene.render.resolution_y = 540
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.film_transparent = False
scene.render.image_settings.color_mode = "RGBA"
scene.render.image_settings.color_depth = "8"

camera = bpy.data.objects.get("G0_DeliveryCamera")
if camera is None:
    raise RuntimeError("G0_DeliveryCamera is missing")
scene.camera = camera

views = {
    "01_wake_to_door": ((5.8, -9.8, 2.25), (0.0, 4.5, 2.25), 30.0),
    "02_tube_gallery": ((3.2, -3.8, 2.0), (-4.3, 0.8, 2.4), 38.0),
    "03_door_return": ((-3.4, 9.0, 2.35), (0.0, -5.2, 2.1), 34.0),
}

for name, (location, target, lens) in views.items():
    camera.location = location
    camera.data.lens = lens
    point_camera(camera, target)
    scene.render.filepath = os.path.join(OUTPUT_DIR, f"{name}.png")
    bpy.ops.render.render(write_still=True)
    print(f"G0_REVIEW_RENDER={scene.render.filepath}")


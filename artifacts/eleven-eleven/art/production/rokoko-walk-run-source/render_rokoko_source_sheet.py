"""Quick side silhouettes of source clips for motion selection."""

from pathlib import Path

import bpy
from mathutils import Vector

BASE = Path(r"C:\Users\yasmo\EchoNetwork\artifacts\eleven-eleven\art\production\rokoko-walk-run-source")
ROOT = BASE / "unpacked/WALK-RUN-CYCLES-MOCAP"
OUT = BASE / "source-previews"
OUT.mkdir(exist_ok=True)
CLIPS = {
    "05-running-treadmill.fbx": [150, 160, 170, 180, 190, 200, 210, 220, 230],
    "08-Loop_HappyWalk_MIXAMO_769_segment.fbx": [5, 11, 17, 23, 29, 35, 41],
    "11-WalkCycle_Cool_MIXAMO_WHS_segment.fbx": [8, 17, 26, 35, 44, 53, 62],
    "02-walkforward.fbx": [150, 160, 170, 180, 190, 200, 210],
}

for name, frames in CLIPS.items():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=str(ROOT / name), use_anim=True)
    scene = bpy.context.scene
    rig = next(o for o in scene.objects if o.type == "ARMATURE")
    for obj in list(scene.objects):
        if obj.type in {"CAMERA", "LIGHT"} or (obj.type == "MESH" and obj.name == "Cube"):
            bpy.data.objects.remove(obj, do_unlink=True)
    bpy.ops.object.camera_add()
    camera = bpy.context.object
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 2.1
    scene.camera = camera
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.render.resolution_x = 240
    scene.render.resolution_y = 320
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = True
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "MATERIAL"
    scene.display.shading.show_shadows = True
    scene.display.shading.show_cavity = True
    prefix = "mixamorig:" if "MIXAMO" in name else ""
    left_name = prefix + ("LeftUpLeg" if prefix else "LeftThigh")
    right_name = prefix + ("RightUpLeg" if prefix else "RightThigh")
    for frame in frames:
        scene.frame_set(frame)
        bpy.context.view_layer.update()
        left = rig.matrix_world @ rig.pose.bones[left_name].head
        right = rig.matrix_world @ rig.pose.bones[right_name].head
        hip = (left + right) / 2
        sideways = (left - right).to_2d().normalized()
        eye = hip + Vector((sideways.x * 3.0, sideways.y * 3.0, 0.9))
        target = hip + Vector((0, 0, 0.15))
        camera.location = eye
        camera.rotation_euler = (target - eye).to_track_quat("-Z", "Y").to_euler()
        output = OUT / f"{name[:2]}_{frame:03d}.png"
        scene.render.filepath = str(output)
        bpy.ops.render.render(write_still=True)
        print("SHOT", output, flush=True)

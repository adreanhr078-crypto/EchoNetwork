"""Prepare a Blender sculpt workspace aligned to Echo's 4K head references."""

from pathlib import Path
import math

import bpy


ROOT = Path(r"C:\Users\yasmo\Documents\Codex\2026-09-11\create-an-image-of-3\EchoNetwork")
SOURCE = ROOT / "artifacts/eleven-eleven/art/production/echo-identity-pass-v1/echo-identity-pass-v2.blend"
REFS = ROOT / "artifacts/eleven-eleven/art/production/echo-higgsfield-turnaround/sculpt-views"
OUT = ROOT / "artifacts/eleven-eleven/art/production/echo-identity-pass-v1/echo-sculpt-workspace-v1.blend"


def image_empty(name, path, location, rotation, scale):
    image = bpy.data.images.load(str(path), check_existing=True)
    obj = bpy.data.objects.new(name, None)
    obj.empty_display_type = "IMAGE"
    obj.data = image
    obj.location = location
    obj.rotation_euler = rotation
    obj.scale = (scale, scale, scale)
    obj.color[3] = 0.46
    obj.empty_image_depth = "BACK"
    obj.hide_render = True
    bpy.context.collection.objects.link(obj)
    return obj


def main():
    bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
    ref_col = bpy.data.collections.new("Echo_4K_Sculpt_References")
    bpy.context.scene.collection.children.link(ref_col)
    refs = [
        image_empty(
            "REF_Echo_Front_4K",
            REFS / "echo-head-front-v1.png",
            (0.0, 0.34, 1.55),
            (math.radians(90), 0.0, 0.0),
            0.43,
        ),
        image_empty(
            "REF_Echo_Profile_4K",
            REFS / "echo-head-right-profile-v1.png",
            (-0.34, 0.0, 1.55),
            (math.radians(90), 0.0, math.radians(90)),
            0.43,
        ),
    ]
    for obj in refs:
        for old in list(obj.users_collection):
            old.objects.unlink(obj)
        ref_col.objects.link(obj)
    ref_col.hide_render = True

    hair_col = bpy.data.collections.get("Echo_Hair_Identity_v1_NOT_APPROVED")
    if hair_col:
        hair_col.hide_viewport = True
        hair_col.hide_render = True

    human = bpy.data.objects["Echo_MPF_Base_High_NOT_APPROVED"]
    bpy.context.view_layer.objects.active = human
    human.select_set(True)
    human["sculpt_reference_front"] = str(REFS / "echo-head-front-v1.png")
    human["sculpt_reference_profile"] = str(REFS / "echo-head-right-profile-v1.png")
    human["quality_gate"] = "MANUAL_LIKENESS_SCULPT_REQUIRED"

    scene = bpy.context.scene
    scene["workspace_purpose"] = "Echo manual head likeness sculpt against synchronized 4K front/profile"
    scene.tool_settings.use_mesh_automerge = False
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT))


if __name__ == "__main__":
    main()

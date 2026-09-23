import bpy
from pathlib import Path


ROOT = Path(r"C:\Users\yasmo\EchoNetwork\artifacts\eleven-eleven")
MOTION_SOURCE = ROOT / "art/production/tripo-out/echo-opening-uniform-motion-v1-80b1621a/model.glb"
FALL_SOURCE = ROOT / "art/production/tripo-out/echo-opening-uniform-recovery-v1-f813d9b6/model.glb"
GODOT_ASSET = ROOT / "godot/assets/characters/echo_opening_uniform_v1.glb"
BLEND_ASSET = ROOT / "art/production/echo-opening-uniform-reference/echo-opening-uniform-v1.blend"


def import_glb(path: Path):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(path))
    return set(bpy.data.objects) - before


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)

    motion_objects = import_glb(MOTION_SOURCE)
    armatures = [o for o in motion_objects if o.type == "ARMATURE"]
    meshes = [o for o in motion_objects if o.type == "MESH" and len(o.data.polygons) > 1000]
    if len(armatures) != 1 or len(meshes) != 1:
        raise RuntimeError(f"Expected one rigged body, got {len(armatures)} armatures and {len(meshes)} body meshes")
    armature, body = armatures[0], meshes[0]

    fall_objects = import_glb(FALL_SOURCE)
    fall_action = bpy.data.actions.get("preset:fall")
    if fall_action is None:
        raise RuntimeError("The retargeted fall animation was not found")
    fall_action.use_fake_user = True

    # The two Tripo retarget tasks use the same source rig. Transfer the fall
    # action to the main rig, then discard the duplicate geometry and armature.
    animation_data = armature.animation_data_create()
    fall_track = animation_data.nla_tracks.new()
    fall_track.name = "preset:fall"
    fall_strip = fall_track.strips.new("preset:fall", int(fall_action.frame_range[0]), fall_action)
    if hasattr(fall_strip, "action_slot") and fall_action.slots:
        fall_strip.action_slot = fall_action.slots[0]
    for obj in fall_objects:
        bpy.data.objects.remove(obj, do_unlink=True)

    # Tripo adds two non-character helper meshes. They are not part of the
    # authored body and must not ship into Godot.
    for obj in list(bpy.data.objects):
        if obj.type == "MESH" and obj is not body:
            bpy.data.objects.remove(obj, do_unlink=True)

    # Keep the authored rig and PBR maps, but bring the dense generated surface
    # inside the game's established character triangle budget.
    decimate = body.modifiers.new("Echo_Runtime_75k", "DECIMATE")
    decimate.ratio = 0.05
    armature_index = next((i for i, modifier in enumerate(body.modifiers) if modifier.type == "ARMATURE"), len(body.modifiers))
    decimate_index = list(body.modifiers).index(decimate)
    if decimate_index > armature_index:
        body.modifiers.move(decimate_index, armature_index)
    bpy.context.view_layer.objects.active = body
    body.select_set(True)
    bpy.ops.object.modifier_apply(modifier=decimate.name)
    body.select_set(False)

    for image in list(bpy.data.images):
        if image.source == "FILE" and image.has_data:
            image.pack()
    bpy.data.orphans_purge(do_recursive=True)

    body.name = "EchoOpeningUniformBody"
    body.data.name = "EchoOpeningUniformMesh"
    armature.name = "EchoOpeningUniformRig"
    armature.data.name = "EchoOpeningUniformSkeleton"
    for obj in bpy.context.scene.objects:
        obj.select_set(False)
    body.select_set(True)
    armature.select_set(True)
    bpy.context.view_layer.objects.active = armature

    GODOT_ASSET.parent.mkdir(parents=True, exist_ok=True)
    BLEND_ASSET.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND_ASSET))
    bpy.ops.export_scene.gltf(
        filepath=str(GODOT_ASSET),
        export_format="GLB",
        use_selection=True,
        export_animations=True,
        export_animation_mode="NLA_TRACKS",
        export_skins=True,
        export_image_format="JPEG",
        export_keep_originals=False,
        export_materials="EXPORT",
        export_apply=False,
    )
    triangle_count = sum(len(poly.vertices) - 2 for poly in body.data.polygons)
    print(f"OUTPUT={GODOT_ASSET}")
    print(f"TRIANGLES={triangle_count}")
    print(f"VERTICES={len(body.data.vertices)}")
    print(f"ANIMATIONS={[track.name for track in armature.animation_data.nla_tracks]}")
    print(f"BONES={len(armature.data.bones)}")
    print(f"TEXTURES={[(image.name, image.size[0], image.size[1]) for image in bpy.data.images if image.users > 0]}")


if __name__ == "__main__":
    main()

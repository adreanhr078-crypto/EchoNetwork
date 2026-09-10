"""Structural gate for a character GLB; never a visual/Canon approval."""

import argparse
import os
import sys

import bpy


REQUIRED_BONES = {
    "root",
    "hips",
    "spine_01",
    "spine_02",
    "neck",
    "head",
    "upper_arm.L",
    "lower_arm.L",
    "hand.L",
    "upper_arm.R",
    "lower_arm.R",
    "hand.R",
    "thigh.L",
    "shin.L",
    "foot.L",
    "toe.L",
    "thigh.R",
    "shin.R",
    "foot.R",
    "toe.R",
}
DEFAULT_REQUIRED_CLIPS = ("IDLE", "WALK", "RUN", "INTERACT")


def script_args():
    return sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []


def parse_args():
    parser = argparse.ArgumentParser(description="Validate 11.11 character GLB")
    parser.add_argument("--input", required=True)
    parser.add_argument("--identifier", required=True)
    parser.add_argument("--max-meshes", type=int, default=32)
    parser.add_argument("--max-materials", type=int, default=16)
    parser.add_argument("--max-triangles", type=int, default=80000)
    parser.add_argument("--max-bones", type=int, default=128)
    parser.add_argument("--required-clips", default=",".join(DEFAULT_REQUIRED_CLIPS))
    return parser.parse_args(script_args())


def mesh_triangles(mesh_object):
    mesh_object.data.calc_loop_triangles()
    return len(mesh_object.data.loop_triangles)


def validate_animated_pose(armature, action):
    """Reject named but stationary clips, including armature-object-only motion."""
    start, end = action.frame_range
    if end - start < 1:
        raise RuntimeError(f"Animation has no duration: {action.name}")
    armature.animation_data_create()
    for track in armature.animation_data.nla_tracks:
        track.mute = True
    armature.animation_data.action = action
    if action.slots:
        armature.animation_data.action_slot = action.slots[0]
    samples = []
    # Relative bone matrices exclude moving the entire rig as a rigid prop.
    for fraction in (0, 0.125, 0.25, 0.375, 0.5, 0.625, 0.75, 0.875, 1):
        frame = start + (end - start) * fraction
        bpy.context.scene.frame_set(int(frame), subframe=frame % 1)
        bpy.context.view_layer.update()
        samples.append(tuple(
            value
            for bone in armature.pose.bones if bone.parent
            for row in (bone.parent.matrix.inverted_safe() @ bone.matrix)
            for value in row
        ))
    if not samples[0] or not any(
        any(abs(value - initial) > 1e-5 for value, initial in zip(sample, samples[0]))
        for sample in samples[1:]
    ):
        raise RuntimeError(f"Animation has no changing bone pose: {action.name}")


def main():
    args = parse_args()
    source = os.path.abspath(args.input)
    if not os.path.isfile(source):
        raise FileNotFoundError(source)

    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=source)

    armatures = [obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE"]
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    if len(armatures) != 1:
        raise RuntimeError(f"Expected one armature, found {len(armatures)}")
    if not meshes:
        raise RuntimeError("Character has no meshes")
    if len(meshes) > args.max_meshes:
        raise RuntimeError(f"Mesh count {len(meshes)} exceeds {args.max_meshes}")

    bone_names = set(armatures[0].data.bones.keys())
    missing = sorted(REQUIRED_BONES - bone_names)
    if missing:
        raise RuntimeError(f"Missing required bones: {missing}")
    if len(bone_names) > args.max_bones:
        raise RuntimeError(f"Bone count {len(bone_names)} exceeds {args.max_bones}")

    root = armatures[0].data.bones["root"]
    disconnected = [name for name in REQUIRED_BONES - {"root"}
                    if root not in armatures[0].data.bones[name].parent_recursive]
    if disconnected:
        raise RuntimeError(f"Required bones are disconnected from root: {sorted(disconnected)}")

    compact_id = args.identifier.replace("-", "").upper()
    tattoo_meshes = [
        obj for obj in meshes
        if "SKINTATTOO" in obj.name.upper()
        and compact_id in obj.name.replace("-", "").upper()
    ]
    if not tattoo_meshes:
        raise RuntimeError(
            f"Missing direct-skin identifier tattoo mesh for {args.identifier}; "
            "the mark may not be baked into clothing or authoritative state"
        )

    material_names = {
        slot.material.name
        for mesh in meshes
        for slot in mesh.material_slots
        if slot.material
    }
    if len(material_names) > args.max_materials:
        raise RuntimeError(f"Material count {len(material_names)} exceeds {args.max_materials}")
    if not material_names:
        raise RuntimeError("Character has no assigned materials")

    triangle_count = sum(mesh_triangles(mesh) for mesh in meshes)
    if triangle_count > args.max_triangles:
        raise RuntimeError(f"Triangle count {triangle_count} exceeds {args.max_triangles}")

    action_names = {action.name.upper() for action in bpy.data.actions}
    required_clips = [name.strip().upper() for name in args.required_clips.split(",") if name.strip()]
    for clip in required_clips:
        matches = [action for action in bpy.data.actions
                   if action.name.upper().split("|")[-1] == clip]
        if not matches:
            raise RuntimeError(f"Missing runtime animation: {clip}")
        validate_animated_pose(armatures[0], matches[0])

    print(f"CHARACTER_GLB_VALID={source}")
    print(f"CHARACTER_IDENTIFIER_BINDING_PRESENT={args.identifier}")
    print("CHARACTER_VISUAL_CANON_AND_SKINNING_REVIEW=UNVERIFIED")
    print(f"CHARACTER_MESH_COUNT={len(meshes)}")
    print(f"CHARACTER_MATERIAL_COUNT={len(material_names)}")
    print(f"CHARACTER_TRIANGLE_COUNT={triangle_count}")
    print(f"CHARACTER_BONE_COUNT={len(bone_names)}")
    print(f"CHARACTER_ANIMATION_COUNT={len(action_names)}")


if __name__ == "__main__":
    main()

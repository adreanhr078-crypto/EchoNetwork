"""Prepare a NEW Tripo Echo for animation review, preserving all original meshes.

This creates editable master, rig contract and a separate review LOD outside the
live Godot project. No animation is generated or approved here.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import sys

import bpy
from mathutils import Matrix, Vector


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--app", type=Path, required=True)
    parser.add_argument("--source", type=Path, required=True)
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:])
    app = args.app.resolve()
    source = args.source.resolve()
    original_hash = hashlib.sha256(source.read_bytes()).hexdigest()
    output = app / "art/production/echo-master-character/prepared-v1"
    output.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(source))
    rigs = [o for o in bpy.context.scene.objects if o.type == "ARMATURE"]
    if len(rigs) != 1:
        raise ValueError("Expected a single target rig")
    rig = rigs[0]
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH" and
              any(m.type == "ARMATURE" and m.object == rig for m in o.modifiers)]
    if not meshes:
        raise ValueError("Tripo rig has no skinned character mesh")
    # The rig export also contains an unskinned Icosphere helper spanning -1..1 m.
    # It is not Echo: including it in bounds shrinks and lifts the character.
    for extra in [o for o in bpy.context.scene.objects if o.type == "MESH" and o not in meshes]:
        bpy.data.objects.remove(extra, do_unlink=True)
    bones = rig.data.bones
    required = ["mixamorig:Hips", "mixamorig:Head", "mixamorig:LeftUpLeg", "mixamorig:LeftLeg",
                "mixamorig:LeftFoot", "mixamorig:LeftToeBase", "mixamorig:RightUpLeg",
                "mixamorig:RightLeg", "mixamorig:RightFoot", "mixamorig:RightToeBase"]
    if any(name not in bones for name in required):
        raise ValueError("Target does not contain the requested humanoid bones")
    bounds = [o.matrix_world @ Vector(corner) for o in meshes for corner in o.bound_box]
    floor = min(v.z for v in bounds)
    height = max(v.z for v in bounds) - floor
    scale = 1.76 / height
    front = sum((rig.matrix_world @ bones[f"mixamorig:{side}ToeBase"].head_local -
                 rig.matrix_world @ bones[f"mixamorig:{side}Foot"].head_local for side in ("Left", "Right")), Vector())
    front.z = 0
    if front.length < 0.001:
        raise ValueError("Target forward axis cannot be established")
    # Blender +Y exports to Godot -Z.
    angle = math.pi / 2 - math.atan2(front.y, front.x)
    basis = Matrix.Rotation(angle, 4, "Z") @ Matrix.Scale(scale, 4)
    transform = Matrix.Translation(Vector((0, 0, -floor * scale))) @ basis
    roots = [o for o in bpy.context.scene.objects if o.parent is None]
    for root in roots:
        root.matrix_world = transform @ root.matrix_world
    rig.name = "EchoMasterRig"
    rig.data.name = "EchoMasterHumanoidSkeleton"
    # Preserve immutable, full-resolution 8K source as an editable master.
    bpy.ops.wm.save_as_mainfile(filepath=str(output / "echo-master-8k.blend"))
    rest = []
    for bone in rig.data.bones:
        world = rig.matrix_world @ bone.matrix_local
        rest.append({"name": bone.name, "godot_name": bone.name.replace(":", "_"),
                     "parent": bone.parent.name if bone.parent else None,
                     "world_matrix": [list(row) for row in world], "length_world_m": bone.length * rig.matrix_world.to_scale().x})
    final_bounds = [o.matrix_world @ Vector(corner) for o in meshes for corner in o.bound_box]
    final_floor = min(v.z for v in final_bounds)
    final_height = max(v.z for v in final_bounds) - final_floor
    if abs(final_floor) > 0.005 or abs(final_height - 1.76) > 0.01:
        raise ValueError(f"Prepared skinned Echo bounds invalid: floor={final_floor} height={final_height}")
    contract = {"schema_version": 1, "status": "new_target_requires_motion_and_visual_validation",
                "source_file": str(source.relative_to(app)), "source_sha256": original_hash,
                "rig": rig.name, "rig_hash": hashlib.sha256(json.dumps(rest, sort_keys=True).encode()).hexdigest(),
                "bones": rest, "height_m": final_height, "floor_m": final_floor,
                "forward_blender": "+Y", "forward_godot": "-Z",
                "up_blender": "+Z", "up_godot": "+Y", "uniform_source_scale": scale,
                "independent_finger_bones": False, "canonical_animation_approvals": 0}
    # Produce a review mesh with preserved skin groups and UVs. Keep high-poly master untouched.
    before = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in meshes)
    for mesh in meshes:
        bpy.context.view_layer.objects.active = mesh
        mesh.select_set(True)
        decimate = mesh.modifiers.new("ReviewLOD", "DECIMATE")
        decimate.ratio = min(1.0, 30000 / max(1, before))
        decimate.use_collapse_triangulate = True
        bpy.ops.object.modifier_apply(modifier=decimate.name)
        mesh.select_set(False)
    for image in bpy.data.images:
        if image.size[0] > 0 and image.type == "IMAGE":
            longest = max(image.size)
            if longest > 2048:
                ratio = 2048 / longest
                image.scale(max(1, round(image.size[0] * ratio)), max(1, round(image.size[1] * ratio)))
                image.pack()
    review_glb = output / "echo-master-review-lod.glb"
    bpy.ops.export_scene.gltf(filepath=str(review_glb), export_format="GLB", export_animations=False,
                               export_skins=True, export_yup=True)
    contract["review_lod"] = str(review_glb.relative_to(app))
    contract["review_triangles"] = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in meshes)
    contract["source_triangles"] = before
    contract["review_sha256"] = hashlib.sha256(review_glb.read_bytes()).hexdigest()
    (output / "EchoRigContract.json").write_text(json.dumps(contract, indent=2) + "\n", encoding="utf-8")
    if hashlib.sha256(source.read_bytes()).hexdigest() != original_hash:
        raise ValueError("Original source changed")
    print("ECHO_PREPARED " + json.dumps({"height": 1.76, "bones": len(rest), "source_triangles": before,
                                        "review_triangles": contract["review_triangles"], "source_preserved": True}), flush=True)


if __name__ == "__main__":
    main()

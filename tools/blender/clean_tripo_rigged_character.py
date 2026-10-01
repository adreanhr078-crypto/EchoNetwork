"""Create a structurally cleaned, non-destructive master from a Tripo rigged GLB."""

import argparse
import json
import sys
from pathlib import Path

import bpy


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--blend", required=True)
    parser.add_argument("--report", required=True)
    return parser.parse_args(sys.argv[sys.argv.index("--") + 1 :])


def main():
    args = parse_args()
    source = Path(args.input).resolve()
    output = Path(args.output).resolve()
    blend = Path(args.blend).resolve()
    report_path = Path(args.report).resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    blend.parent.mkdir(parents=True, exist_ok=True)
    report_path.parent.mkdir(parents=True, exist_ok=True)

    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(source))

    armatures = [obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE"]
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    weighted = [
        obj for obj in meshes if any(modifier.type == "ARMATURE" for modifier in obj.modifiers)
    ]
    if len(armatures) != 1 or len(weighted) != 1:
        raise RuntimeError(
            f"Expected one armature and one skinned mesh; found {len(armatures)} and {len(weighted)}"
        )

    removed_helpers = []
    for obj in list(meshes):
        if obj in weighted:
            continue
        removed_helpers.append(obj.name)
        bpy.data.objects.remove(obj, do_unlink=True)

    character = weighted[0]
    original_parent = character.parent.name if character.parent else None
    world_matrix = character.matrix_world.copy()
    character.parent = None
    character.matrix_world = world_matrix
    character.name = "Echo_G0_SkinnedMesh"
    armatures[0].name = "Echo_G0_Armature"

    character["eleven_eleven_status"] = "CANDIDATE_NOT_VISUAL_LOCK"
    character["detail_source"] = "Echo_Tripo_HD_v31_8K_Source.glb"
    character["quality_note"] = "Coat weights and face/hair materials require authored correction"

    bpy.ops.wm.save_as_mainfile(filepath=str(blend), check_existing=False)
    bpy.ops.export_scene.gltf(
        filepath=str(output),
        export_format="GLB",
        export_animations=True,
        export_animation_mode="ACTIONS",
        export_extra_animations=True,
        export_tangents=True,
        export_apply=False,
        export_yup=True,
    )

    character.data.calc_loop_triangles()
    report = {
        "source": str(source),
        "output": str(output),
        "blend": str(blend),
        "removed_helpers": removed_helpers,
        "removed_parent": original_parent,
        "triangles": len(character.data.loop_triangles),
        "vertices": len(character.data.vertices),
        "bones": len(armatures[0].data.bones),
        "actions": [action.name for action in bpy.data.actions],
        "tangents_requested": True,
        "visual_status": "CANDIDATE_NOT_VISUAL_LOCK",
    }
    report_path.write_text(json.dumps(report, indent=2), encoding="utf-8")
    print("TRIPO_CLEAN_MASTER=" + json.dumps(report), flush=True)


if __name__ == "__main__":
    main()

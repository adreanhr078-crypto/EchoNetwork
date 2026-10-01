"""Export a bounded Godot/GLB proof asset to a Unity-friendly FBX.

This is a migration bridge only. The original GLB is retained beside the FBX
so Unity can switch to glTFast or a later authored export without losing data.
"""

from __future__ import annotations

import argparse
import sys
import bpy


def export_one(source: str, destination: str) -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=source)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.fbx(
        filepath=destination,
        use_selection=True,
        object_types={"EMPTY", "MESH", "ARMATURE", "OTHER"},
        apply_unit_scale=True,
        apply_scale_options="FBX_SCALE_ALL",
        axis_forward="-Z",
        axis_up="Y",
        use_mesh_modifiers=True,
        add_leaf_bones=False,
        bake_anim=True,
        bake_anim_use_all_actions=True,
        bake_anim_use_nla_strips=False,
        path_mode="COPY",
        embed_textures=True,
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", required=True)
    parser.add_argument("--destination", required=True)
    blender_args = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    args = parser.parse_args(blender_args)
    export_one(args.source, args.destination)
    print(f"UNITY_FBX_EXPORT_OK source={args.source} destination={args.destination}")


if __name__ == "__main__":
    main()

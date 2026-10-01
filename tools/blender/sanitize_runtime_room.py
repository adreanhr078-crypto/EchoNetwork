"""Create a portable runtime derivative of a Higgsfield room study."""

import argparse
import os
import sys

import bpy


def script_args():
    return sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []


def parse_args():
    parser = argparse.ArgumentParser(description="Sanitize a room GLB for runtime delivery")
    parser.add_argument("--input", required=True)
    parser.add_argument("--output", required=True)
    return parser.parse_args(script_args())


def main():
    args = parse_args()
    source = os.path.abspath(args.input)
    output = os.path.abspath(args.output)
    if not os.path.isfile(source):
        raise FileNotFoundError(source)
    if os.path.normcase(source) == os.path.normcase(output):
        raise ValueError("Output must not overwrite the source study")
    os.makedirs(os.path.dirname(output), exist_ok=True)

    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=source)
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    if not meshes:
        raise RuntimeError("Higgsfield room contains no mesh objects")
    if bpy.data.actions or any(obj.type == "ARMATURE" for obj in bpy.context.scene.objects):
        raise ValueError("Static room sanitizer cannot flatten animated or rigged assets")

    # Removing a transformed parent first moves its children. Bake each evaluated
    # world transform before unlinking any hierarchy, preserving placement/scale.
    bpy.context.view_layer.update()
    world_matrices = {obj: obj.matrix_world.copy() for obj in meshes}
    for obj, matrix in world_matrices.items():
        obj.parent = None
        obj.matrix_world = matrix
    bpy.context.view_layer.update()

    # Cameras, lights and importer empties are study metadata; runtime owns these.
    for obj in list(bpy.context.scene.objects):
        if obj.type != "MESH":
            bpy.data.objects.remove(obj, do_unlink=True)

    bpy.ops.object.select_all(action="DESELECT")
    # Doors stay independently addressable for gameplay. Only static shell pieces
    # are batched; one mesh is not a sufficient correctness/performance criterion.
    static_meshes = [obj for obj in meshes if 'door' not in obj.name.lower()]
    for obj in static_meshes:
        obj.select_set(True)
    if static_meshes:
        bpy.context.view_layer.objects.active = static_meshes[0]
    if len(static_meshes) > 1:
        bpy.ops.object.join()
    if static_meshes:
        bpy.context.object.name = "Higgsfield_G0Room_Static"

    bpy.ops.export_scene.gltf(
        filepath=output,
        export_format="GLB",
        export_cameras=False,
        export_lights=False,
        export_animations=False,
        export_materials="EXPORT",
    )
    print("RUNTIME_ROOM_SANITIZED=" + output)
    print("RUNTIME_ROOM_SOURCE_MESHES=" + str(len(meshes)))
    print("RUNTIME_ROOM_MESHES=" + str(sum(o.type == 'MESH' for o in bpy.context.scene.objects)))


if __name__ == "__main__":
    main()

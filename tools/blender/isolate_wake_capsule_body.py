"""Split a Tripo capsule source into loose components and isolate the main body."""

import argparse
import json
import sys
from pathlib import Path

import bpy


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--blend", required=True)
    parser.add_argument("--body-output", required=True)
    parser.add_argument("--report", required=True)
    return parser.parse_args(sys.argv[sys.argv.index("--") + 1 :])


def triangle_count(obj):
    obj.data.calc_loop_triangles()
    return len(obj.data.loop_triangles)


def dimensions(obj):
    return [round(value, 6) for value in obj.dimensions]


def main():
    args = parse_args()
    source = Path(args.input).resolve()
    blend = Path(args.blend).resolve()
    body_output = Path(args.body_output).resolve()
    report_path = Path(args.report).resolve()
    blend.parent.mkdir(parents=True, exist_ok=True)
    body_output.parent.mkdir(parents=True, exist_ok=True)
    report_path.parent.mkdir(parents=True, exist_ok=True)

    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(source))
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    if not meshes:
        raise RuntimeError("Source contains no mesh")

    bpy.ops.object.select_all(action="DESELECT")
    for obj in meshes:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    if len(meshes) > 1:
        bpy.ops.object.join()

    joined = bpy.context.view_layer.objects.active
    joined.name = "WakeCapsule_Source_AllComponents"
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.separate(type="LOOSE")
    bpy.ops.object.mode_set(mode="OBJECT")

    components = [obj for obj in bpy.context.selected_objects if obj.type == "MESH"]
    components.sort(key=triangle_count, reverse=True)
    if not components:
        raise RuntimeError("Loose-part separation produced no components")

    body = components[0]
    body.name = "Sector11_WakeCapsule_HeroBody_Source"
    body["eleven_eleven_status"] = "SOURCE_ONLY_NOT_RUNTIME"
    body["source_task"] = "0e6b444a-ade2-49d2-8d41-bf728ddccb05"

    for index, obj in enumerate(components[1:], start=1):
        obj.name = f"WakeCapsule_DetachedComponent_{index:03d}"
        obj.hide_render = True
        obj.hide_set(True)

    bpy.ops.wm.save_as_mainfile(filepath=str(blend), check_existing=False)

    bpy.ops.object.select_all(action="DESELECT")
    body.hide_set(False)
    body.hide_render = False
    body.select_set(True)
    bpy.context.view_layer.objects.active = body
    bpy.ops.export_scene.gltf(
        filepath=str(body_output),
        export_format="GLB",
        use_selection=True,
        export_animations=False,
        export_tangents=False,
        export_yup=True,
    )

    report = {
        "source": str(source),
        "blend": str(blend),
        "body_output": str(body_output),
        "component_count": len(components),
        "total_triangles": sum(triangle_count(obj) for obj in components),
        "body_triangles": triangle_count(body),
        "body_vertices": len(body.data.vertices),
        "body_dimensions": dimensions(body),
        "top_components": [
            {
                "name": obj.name,
                "triangles": triangle_count(obj),
                "vertices": len(obj.data.vertices),
                "dimensions": dimensions(obj),
                "location": [round(value, 6) for value in obj.location],
            }
            for obj in components[:20]
        ],
    }
    report_path.write_text(json.dumps(report, indent=2), encoding="utf-8")
    print("WAKE_CAPSULE_ISOLATION=" + json.dumps(report), flush=True)


if __name__ == "__main__":
    main()

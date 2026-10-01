"""Repair degenerate runtime faces before exporting tangent-bearing capsule GLB."""

import argparse
import json
import sys
from pathlib import Path

import bmesh
import bpy


def args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--blend", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--report", required=True)
    return parser.parse_args(sys.argv[sys.argv.index("--") + 1 :])


def main():
    cfg = args()
    blend = Path(cfg.blend).resolve()
    output = Path(cfg.output).resolve()
    report_path = Path(cfg.report).resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.open_mainfile(filepath=str(blend))

    high = bpy.data.objects.get("WakeCapsule_HighDetail_BakeSource")
    runtime = [
        obj for obj in bpy.context.scene.objects
        if obj.type == "MESH" and obj != high and obj.get("eleven_eleven_asset") == "sector11_wake_capsule"
    ]
    body = bpy.data.objects.get("Sector11_WakeCapsule_RuntimeBody")
    if body is None:
        raise RuntimeError("Runtime body missing")

    bm = bmesh.new()
    bm.from_mesh(body.data)
    faces_before = len(bm.faces)
    bmesh.ops.dissolve_degenerate(bm, dist=1e-5, edges=list(bm.edges))
    bmesh.ops.triangulate(bm, faces=list(bm.faces))
    bm.normal_update()
    bm.to_mesh(body.data)
    bm.free()
    body.data.update()

    bpy.ops.object.select_all(action="DESELECT")
    for obj in runtime:
        obj.hide_set(False)
        obj.hide_render = False
        obj.select_set(True)
    bpy.context.view_layer.objects.active = body
    bpy.ops.export_scene.gltf(
        filepath=str(output), export_format="GLB", use_selection=True,
        export_animations=False, export_tangents=True, export_yup=True,
    )
    report = {
        "source_blend": str(blend), "output": str(output),
        "runtime_mesh_count": len(runtime), "body_faces_before": faces_before,
        "body_faces_after": len(body.data.polygons),
    }
    report_path.write_text(json.dumps(report, indent=2), encoding="utf-8")
    print("CAPSULE_TANGENT_REPAIR=" + json.dumps(report), flush=True)


if __name__ == "__main__":
    main()

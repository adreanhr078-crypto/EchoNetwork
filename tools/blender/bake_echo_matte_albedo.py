"""Bake a matte albedo correction for the non-destructive Echo hero candidate.

The Tripo source has useful 8K detail but includes bright, wet-looking baked
highlights in its base colour. This script bakes a corrected colour map while
leaving the original GLB untouched and retaining the skeleton/actions.
"""

import argparse
import json
import sys
from pathlib import Path

import bpy


def args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--blend", required=True)
    parser.add_argument("--report", required=True)
    parser.add_argument("--size", type=int, default=4096)
    return parser.parse_args(sys.argv[sys.argv.index("--") + 1 :])


def main():
    cfg = args()
    for path in (Path(cfg.output).parent, Path(cfg.blend).parent, Path(cfg.report).parent):
        path.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(Path(cfg.input).resolve()))
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    armatures = [obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE"]
    body = max(meshes, key=lambda obj: len(obj.data.polygons))
    material = body.material_slots[0].material
    nodes, links = material.node_tree.nodes, material.node_tree.links
    bsdf = nodes.get("Principled BSDF")
    if bsdf is None:
        raise RuntimeError("Echo material has no Principled BSDF")
    base_socket = bsdf.inputs["Base Color"]
    if not base_socket.is_linked:
        raise RuntimeError("Echo material has no base-colour texture")
    original = base_socket.links[0].from_socket

    # Build a temporary emission path. A gentle brightness lift keeps the dark
    # coat readable, while lower contrast suppresses baked white highlights.
    hsv = nodes.new("ShaderNodeHueSaturation")
    hsv.name = "Echo_MatteBake_HSV"
    hsv.inputs["Saturation"].default_value = 0.88
    hsv.inputs["Value"].default_value = 0.72
    curve = nodes.new("ShaderNodeBrightContrast")
    curve.name = "Echo_MatteBake_BrightContrast"
    curve.inputs["Bright"].default_value = -18.0
    curve.inputs["Contrast"].default_value = -34.0
    emission = nodes.new("ShaderNodeEmission")
    emission.name = "Echo_MatteBake_Emission"
    links.new(original, hsv.inputs["Color"])
    links.new(hsv.outputs["Color"], curve.inputs["Color"])
    links.new(curve.outputs["Color"], emission.inputs["Color"])
    output = nodes.get("Material Output")
    original_surface = output.inputs["Surface"].links[0].from_socket
    links.remove(output.inputs["Surface"].links[0])
    links.new(emission.outputs["Emission"], output.inputs["Surface"])

    image = bpy.data.images.new("Echo_MatteAlbedo", width=cfg.size, height=cfg.size, alpha=False)
    image.colorspace_settings.name = "sRGB"
    image_node = nodes.new("ShaderNodeTexImage")
    image_node.name = "Echo_MatteAlbedo_BakeTarget"
    image_node.image = image
    nodes.active = image_node
    for poly in body.data.polygons:
        poly.use_smooth = True

    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 1
    scene.render.image_settings.file_format = "PNG"
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = body
    body.select_set(True)
    bpy.ops.object.bake(type="EMIT", margin=12, use_clear=True)

    # Restore a simple exporter-compatible PBR graph using the baked map.
    links.remove(output.inputs["Surface"].links[0])
    links.new(original_surface, output.inputs["Surface"])
    links.remove(base_socket.links[0])
    links.new(image_node.outputs["Color"], base_socket)
    for name, value in (("Metallic", 0.0), ("Roughness", 0.72), ("Specular IOR Level", 0.22), ("Coat Weight", 0.0), ("Sheen Weight", 0.0)):
        socket = bsdf.inputs.get(name)
        if socket:
            socket.default_value = value
    image.pack()
    bpy.ops.wm.save_as_mainfile(filepath=str(Path(cfg.blend).resolve()), check_existing=False)
    bpy.ops.export_scene.gltf(
        filepath=str(Path(cfg.output).resolve()), export_format="GLB",
        export_animations=True, export_tangents=False, export_yup=True,
    )
    report = {
        "source": str(Path(cfg.input).resolve()),
        "output": str(Path(cfg.output).resolve()),
        "size": cfg.size,
        "material": material.name,
        "actions": sorted(action.name for action in bpy.data.actions),
        "armatures": len(armatures),
        "status": "HERO_MATTE_ALBEDO_CANDIDATE_REQUIRES_VISUAL_GATE",
    }
    Path(cfg.report).write_text(json.dumps(report, indent=2), encoding="utf-8")
    print("ECHO_MATTE_BAKE=" + json.dumps(report), flush=True)


if __name__ == "__main__":
    main()

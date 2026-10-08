"""Original reusable supply case, same 0.9m footprint as the live collider.

No text, icons, player logic, texture downloads or external dependencies.
All bevels are applied and material groups join into a single GLB mesh.
"""
import json
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parent
APP = ROOT.parents[2]
OUT = APP / ".tmp" / "opening-art-20261007"
OUT.mkdir(parents=True, exist_ok=True)


def material(name, color, metallic, roughness, emission=None):
    result = bpy.data.materials.new(name)
    result.diffuse_color = (*color, 1)
    result.use_nodes = True
    shader = result.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (*color, 1)
    shader.inputs["Metallic"].default_value = metallic
    shader.inputs["Roughness"].default_value = roughness
    if emission:
        shader.inputs["Emission Color"].default_value = (*emission, 1)
        shader.inputs["Emission Strength"].default_value = 0.5
    return result


def box(name, size, at, mat, bevel=0.012):
    bpy.ops.mesh.primitive_cube_add(size=1, location=at)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    if bevel:
        modifier = obj.modifiers.new("Machined radius", "BEVEL")
        modifier.width = bevel
        modifier.segments = 2
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    for polygon in obj.data.polygons:
        polygon.use_smooth = False
    return obj


bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
ceramic = material("Supply graphite ceramic", (0.18, 0.22, 0.27), 0.30, 0.48)
metal = material("Supply brushed titanium", (0.35, 0.41, 0.46), 0.68, 0.34)
rubber = material("Supply dark rubber", (0.035, 0.046, 0.055), 0.05, 0.78)
amber = material("Supply amber mechanism", (0.48, 0.19, 0.035), 0.35, 0.4, (0.6, 0.23, 0.045))

parts = [
    box("Ceramic body", (0.84, 0.84, 0.76), (0, 0, 0.43), ceramic, 0.05),
    box("Recessed lid", (0.78, 0.78, 0.07), (0, 0, 0.845), ceramic, 0.035),
    box("Lid gasket", (0.82, 0.82, 0.025), (0, 0, 0.796), rubber),
    box("Base buffer", (0.86, 0.86, 0.07), (0, 0, 0.045), rubber, 0.025),
]
for side in [-1, 1]:
    for edge in [-1, 1]:
        parts.append(box("Corner buffer", (0.065, 0.065, 0.76), (side*0.405, edge*0.405, 0.42), rubber))
    parts.append(box("Recessed grip well", (0.28, 0.018, 0.10), (0, side*0.426, 0.53), rubber, 0.008))
    parts.append(box("Titanium grip", (0.22, 0.032, 0.025), (0, side*0.430, 0.555), metal, 0.006))
    for latch_x in [-0.27, 0.27]:
        parts.append(box("Latch plate", (0.06, 0.025, 0.13), (latch_x, side*0.423, 0.765), metal, 0.007))
        parts.append(box("Amber latch indicator", (0.03, 0.009, 0.035), (latch_x, side*0.439, 0.782), amber, 0.003))
    parts.append(box("Stacking rail", (0.034, 0.69, 0.015), (side*0.28, 0, 0.888), metal, 0.004))

# Consolidate: four material surfaces rather than many independent meshes.
bpy.ops.object.select_all(action="DESELECT")
for obj in parts:
    obj.select_set(True)
bpy.context.view_layer.objects.active = parts[0]
bpy.ops.object.join()
case = bpy.context.object
case.name = "Sector11SupplyCase"
bpy.context.scene.cursor.location = (0, 0, 0)
bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
mesh = case.data
mesh.calc_loop_triangles()
triangles = len(mesh.loop_triangles)
bounds = [case.matrix_world @ Vector(corner) for corner in case.bound_box]
lo = [min(v[axis] for v in bounds) for axis in range(3)]
hi = [max(v[axis] for v in bounds) for axis in range(3)]
assert triangles <= 3500, triangles
assert all(hi[i]-lo[i] <= 0.9001 for i in range(3)), (lo, hi)
assert lo[2] >= -0.0001 and hi[2] <= 0.9001, (lo, hi)
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT / "sector11_supply_case_v1.blend"))
glb = OUT / "sector11_supply_case_v1.glb"
bpy.ops.export_scene.gltf(filepath=str(glb), export_format="GLB", use_selection=True,
                          export_animations=False, export_cameras=False, export_lights=False)

# Reimport the exact bytes; no claims based only on exporter success.
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(glb))
imported = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
assert len(imported) == 1, len(imported)
imported[0].data.calc_loop_triangles()
assert len(imported[0].data.loop_triangles) == triangles
report = {"status": "REIMPORT_PASS_REQUIRES_GODOT_VISUAL_REVIEW", "triangles": triangles,
          "mesh_count": 1, "materials": 4, "bounds_blender": [lo, hi], "glb_bytes": glb.stat().st_size,
          "physics": "existing collider retained; no physics exported", "source": str(ROOT / "sector11_supply_case_v1.blend")}
(OUT / "supply-case-validation.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
print(json.dumps(report))

"""Same measured perimeter from Tripo's existing packed-UV export.

Run in a fresh background Blender. Preserve the old sources and native colliders.
The raw triangle-position fingerprint must match before applying the established
2026-10-23 mask and piecewise fit. Only UV/material organization changes.
"""
import bpy
import bmesh
import hashlib
import json
import math
from pathlib import Path
from mathutils import Vector
from mathutils.kdtree import KDTree

APP = Path(__file__).resolve().parents[2]
KIT = APP / 'art/production/lab-clinical-kit-20261023/tripo'
SOURCE = KIT / 'lab-packed-existing-4k-20261024.glb'
ORIGINAL = KIT / 'lab-full-room-textured-8k.glb'
OUT = KIT / 'packed-perimeter-20261024'
OUT.mkdir(parents=True, exist_ok=True)


def clear_scene():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)


def fingerprint():
    bpy.context.view_layer.update()
    triangles = []
    exact = []
    for obj in bpy.context.scene.objects:
        if obj.type != 'MESH':
            continue
        obj.data.calc_loop_triangles()
        positions = [obj.matrix_world @ v.co for v in obj.data.vertices]
        for triangle in obj.data.loop_triangles:
            exact.append(tuple(tuple(float(c) for c in positions[i]) for i in triangle.vertices))
            points = [tuple(round(float(c), 6) for c in positions[i]) for i in triangle.vertices]
            triangles.append(tuple(sorted(points)))
    triangles.sort()
    return len(triangles), hashlib.sha256(repr(triangles).encode('ascii')).hexdigest(), exact


def bounds(triangles):
    lower = [math.inf] * 3
    upper = [-math.inf] * 3
    for triangle in triangles:
        for point in triangle:
            for axis in range(3):
                lower[axis] = min(lower[axis], point[axis])
                upper[axis] = max(upper[axis], point[axis])
    return Vector(lower), Vector(upper)


def compare_triangle_positions(original, packed):
    # Rounded fingerprints are sensitive to values crossing a rounding bin.
    # Match the actual three positions of every triangle, including duplicate
    # centroid candidates, before accepting a UV-only export. 1e-6 source units
    # is at most 42 micrometres after the established architectural fit.
    tolerance = 1e-6
    tree = KDTree(len(original))
    for index, points in enumerate(original):
        tree.insert(sum((Vector(p) for p in points), Vector()) / 3, index)
    tree.balance()
    maximum = 0.0
    for points in packed:
        vectors = [Vector(p) for p in points]
        centre = sum(vectors, Vector()) / 3
        candidates = tree.find_range(centre, tolerance)
        errors = [max(min((point - Vector(other)).length for other in original[index])
                      for point in vectors) for _, index, _ in candidates]
        error = min(errors, default=math.inf)
        assert error <= tolerance, ('Packed export changed triangle geometry', error, tuple(centre))
        maximum = max(maximum, error)
    return maximum


clear_scene()
bpy.ops.import_scene.gltf(filepath=str(ORIGINAL))
original_geometry = fingerprint()
clear_scene()
bpy.ops.import_scene.gltf(filepath=str(SOURCE))
packed_geometry = fingerprint()
assert original_geometry[0] == packed_geometry[0]
original_bounds = bounds(original_geometry[2])
packed_bounds = bounds(packed_geometry[2])
lower_offset = original_bounds[0] - packed_bounds[0]
upper_offset = original_bounds[1] - packed_bounds[1]
assert (lower_offset - upper_offset).length < 1e-6, ('Export changed extent', lower_offset, upper_offset)
origin_correction = (lower_offset + upper_offset) / 2
# Tripo's packed export rebases all parts by one shared translation. Restore
# the archived source datum; do not scale or fit away a geometry difference.
for obj in bpy.context.scene.objects:
    if obj.parent is None:
        obj.location += origin_correction
packed_geometry = fingerprint()
maximum_source_error = compare_triangle_positions(original_geometry[2], packed_geometry[2])
print('PACKED_RAW_GEOMETRY_MATCH', maximum_source_error, list(origin_correction), flush=True)

retained = []
triangles = 0
for obj in list(bpy.context.scene.objects):
    if obj.type != 'MESH':
        continue
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    # The packed export adds a translated parent and rebases each child.
    # Bake the verified WORLD transform, including the restored source datum,
    # before evaluating the original face mask in source coordinates.
    world_transform = obj.matrix_world.copy()
    obj.parent = None
    obj.matrix_world = world_transform
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    mesh = bmesh.new()
    mesh.from_mesh(obj.data)
    removed = []
    for face in mesh.faces:
        x, y, z = face.calc_center_median()
        perimeter = abs(x) > .335 or y > .385
        opening = any(v.co.y > .375 and abs(v.co.x) < .05 and v.co.z < .19 for v in face.verts)
        if not perimeter or z < .039 or opening:
            removed.append(face)
    bmesh.ops.delete(mesh, geom=removed, context='FACES')
    orphan = [v for v in mesh.verts if not v.link_faces]
    if orphan:
        bmesh.ops.delete(mesh, geom=orphan, context='VERTS')
    for vertex in mesh.verts:
        x, y = vertex.co.x, vertex.co.y
        vertex.co.x = math.copysign(14.8 + (abs(x) - .335) * (.9 / (.9033576846 * .5 - .335)), x) if abs(x) > .335 else x * (14.8 / .335)
        vertex.co.y = 19.0 + (y - .385) * (.6 / (.9785512090 * .5 - .385)) if y > .385 else -19.6 + (y + .9785512090 * .5) * (38.6 / (.385 + .9785512090 * .5))
        vertex.co.z = (vertex.co.z - .04) * 42.0
    mesh.to_mesh(obj.data)
    mesh.free()
    obj.data.update()
    if not obj.data.polygons:
        bpy.data.objects.remove(obj, do_unlink=True)
        continue
    obj.data.calc_loop_triangles()
    triangles += len(obj.data.loop_triangles)
    retained.append(obj)

old_report = json.loads((KIT / 'architecture-derivative/derivative.json').read_text(encoding='utf-8'))
assert triangles == old_report['retained_triangles'], (triangles, old_report['retained_triangles'])
assert retained
bpy.ops.object.select_all(action='DESELECT')
for obj in retained:
    obj.select_set(True)
bpy.context.view_layer.objects.active = retained[0]
bpy.ops.object.join()
shell = bpy.context.object
shell.name = 'ClinicalPerimeterShell'
shell.data.name = 'MeasuredPackedClinicalPerimeter'
assert len(shell.data.materials) == 1, len(shell.data.materials)
for obj in list(bpy.context.scene.objects):
    if obj != shell:
        bpy.data.objects.remove(obj, do_unlink=True)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT / 'clinical-perimeter-packed.blend'))
target = OUT / 'clinical_perimeter_packed.glb'
bpy.ops.export_scene.gltf(filepath=str(target), export_format='GLB', use_selection=True,
                        export_animations=False, export_yup=True, export_normals=True, export_texcoords=True)
record = {
    'source': str(SOURCE), 'source_sha256': hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
    'raw_geometry_triangles': original_geometry[0], 'raw_geometry_fingerprint_1um': original_geometry[1],
    'packed_geometry_fingerprint_1um': packed_geometry[1], 'maximum_source_triangle_position_error': maximum_source_error,
    'export_origin_correction_blender': list(origin_correction),
    'raw_geometry_match': True, 'retained_triangles': triangles, 'material_count': len(shell.data.materials),
    'derivative': str(target), 'derivative_sha256': hashlib.sha256(target.read_bytes()).hexdigest(),
    'images': [{'name': image.name, 'size': list(image.size)} for image in
               {node.image for material in shell.data.materials if material.use_nodes
                for node in material.node_tree.nodes if node.type == 'TEX_IMAGE' and node.image}],
    'scope': 'Same measured perimeter mask/fit and retained triangle count; packed UV/PBR source. Native art, residency and route acceptance remain required.'
}
(OUT / 'derivative.json').write_text(json.dumps(record, indent=2) + '\n', encoding='utf-8')
print('PACKED_PERIMETER_BUILT', json.dumps(record))

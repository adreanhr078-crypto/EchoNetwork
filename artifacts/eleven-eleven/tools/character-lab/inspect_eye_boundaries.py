"""Inspect welded skin boundaries next to visually reviewed eye components.

Diagnostic curves only. No facial vertices, weights, UVs or shape keys change.
"""
from collections import Counter, defaultdict
import hashlib
import json
from pathlib import Path

import bpy
from mathutils import Vector

APP = Path(__file__).resolve().parents[2]
production = APP/'art/production/echo-school-rebuild-20261029'
out = production/'face/intake-20261102'
intake = json.loads((out/'topology.json').read_text())
source = production/'source/echo-school-rig-metric.glb'
assert hashlib.sha256(source.read_bytes()).hexdigest() == intake['source_sha256']
bpy.ops.wm.open_mainfile(filepath=str(out/'head-topology-diagnostic.blend'))
mesh = next(obj for obj in bpy.context.scene.objects if obj.type == 'MESH')
mesh.modifiers['DiagnosticWireOnly'].show_render = False
components = json.loads((out/'component-vertices.json').read_text())
points = [mesh.matrix_world @ vertex.co for vertex in mesh.data.vertices]
position_ids, unique, vertex_ids = {}, [], []
for point in points:
    key = tuple(round(value, 6) for value in point)
    if key not in position_ids:
        position_ids[key] = len(unique)
        unique.append(point)
    vertex_ids.append(position_ids[key])
skin = set(components[0])
edges = Counter()
for polygon in mesh.data.polygons:
    if not all(index in skin for index in polygon.vertices): continue
    vertices = [vertex_ids[index] for index in polygon.vertices]
    for first, second in zip(vertices, vertices[1:]+vertices[:1]):
        if first != second: edges[tuple(sorted((first, second)))] += 1
boundary = [edge for edge, count in edges.items() if count == 1]
adjacent = defaultdict(set)
for first, second in boundary:
    adjacent[first].add(second)
    adjacent[second].add(first)
remaining = set(adjacent)
loops = []
while remaining:
    todo, group = [min(remaining)], set()
    while todo:
        index = todo.pop()
        if index in group: continue
        group.add(index)
        todo.extend(adjacent[index]-group)
    remaining.difference_update(group)
    loops.append(sorted(group))
eyes = {str(index): sum((points[vertex] for vertex in components[index]), Vector())/len(components[index]) for index in [30, 31]}
rows = []
for index, loop in enumerate(loops):
    rows.append({'id': index, 'vertices': len(loop), 'closed_degree2': all(len(adjacent[v]) == 2 for v in loop),
                 'center': list(sum((unique[v] for v in loop),Vector())/len(loop)),
                 'low': [min(unique[v][axis] for v in loop) for axis in range(3)],
                 'high': [max(unique[v][axis] for v in loop) for axis in range(3)],
                 'eye_distance_m': {eye: min((unique[v]-center).length for v in loop) for eye, center in eyes.items()}})
nearest = {eye: sorted(rows,key=lambda row: row['eye_distance_m'][eye])[:4] for eye in eyes}
for eye, candidates in nearest.items():
    print('EYE_BOUNDARIES',eye,json.dumps(candidates))
selected = sorted({row['id'] for rows in nearest.values() for row in rows[:2]})
for index in selected:
    group = set(loops[index])
    curve = bpy.data.curves.new('BoundaryCandidate%03d'%index, 'CURVE')
    curve.dimensions = '3D'
    curve.bevel_depth = .00035
    for first, second in boundary:
        if first not in group: continue
        spline = curve.splines.new('POLY')
        spline.points.add(1)
        for point, vertex in zip(spline.points, [first,second]): point.co = (*unique[vertex],1)
    obj = bpy.data.objects.new(curve.name,curve)
    bpy.context.scene.collection.objects.link(obj)
    mat = bpy.data.materials.new(curve.name)
    mat.diffuse_color = ((.05,.85,.8,1) if index == selected[0] else (.95,.3,.08,1))
    curve.materials.append(mat)
scene = bpy.context.scene
scene.display.shading.color_type = 'MATERIAL'
camera = scene.camera
center = sum(eyes.values(),Vector())/2
camera.data.ortho_scale = .17
for view, offset in [('front',(0,-3,0)),('threequarter',(1.5,-3,0))]:
    camera.location = center+Vector(offset)
    camera.rotation_euler = (center-camera.location).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath = str(out/f'eye-boundaries-{view}.png')
    bpy.ops.render.render(write_still=True)
report = {'status':'BOUNDARY_CANDIDATES_NOT_A_BLINK_MASK', 'source_sha256':intake['source_sha256'],
          'eye_component_ids':[30,31], 'eye_component_review':'Detached visible white eye surfaces reviewed in colored and textured head views; anatomical side assignment pending',
          'main_skin_boundary_components':len(loops),'nearest_to_each_eye':nearest,'selected_for_diagnostic_curves':selected,
          'nonmanifold_skin_edges':sum(count>2 for count in edges.values()),'vertices_or_weights_changed':False}
(out/'eye-boundary-analysis.json').write_text(json.dumps(report,indent=2)+'\n')
(out/'boundary-welded-vertices.json').write_text(json.dumps({'loops':loops,'unique_positions':[list(point) for point in unique],'original_to_welded':vertex_ids})+'\n')
bpy.ops.wm.save_as_mainfile(filepath=str(out/'eye-boundary-diagnostic.blend'))

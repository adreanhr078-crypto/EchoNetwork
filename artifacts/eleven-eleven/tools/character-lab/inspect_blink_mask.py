"""Preview geodesic skin masks seeded from the actual separate eye silhouettes.

No vertex deformation, shape keys or weight changes. Review this exact mask first.
"""
from collections import defaultdict
import argparse
import hashlib
import heapq
import json
from pathlib import Path
import sys

import bpy
import numpy as np
from mathutils import Vector

APP = Path(__file__).resolve().parents[2]
production = APP/'art/production/echo-school-rebuild-20261029'
out = production/'face/intake-20261102'
parser = argparse.ArgumentParser()
parser.add_argument('--whole-eye',action='store_true',help='Include the actual iris extent and sample the complete silhouette;diagnostic only')
args = parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
tag = 'blink-whole-eye-mask' if args.whole_eye else 'blink-mask'
intake = json.loads((out/'topology.json').read_text())
assert hashlib.sha256((production/'source/echo-school-rig-metric.glb').read_bytes()).hexdigest() == intake['source_sha256']
bpy.ops.wm.open_mainfile(filepath=str(out/'head-topology-diagnostic.blend'))
mesh = next(obj for obj in bpy.context.scene.objects if obj.type == 'MESH')
mesh.modifiers['DiagnosticWireOnly'].show_render = False
components = json.loads((out/'component-vertices.json').read_text())
points = [mesh.matrix_world @ vertex.co for vertex in mesh.data.vertices]
positions, unique, vertex_ids = {}, [], []
for point in points:
    key = tuple(round(value, 6) for value in point)
    if key not in positions:
        positions[key] = len(unique)
        unique.append(point)
    vertex_ids.append(positions[key])
skin_indices = sorted({vertex_ids[index] for index in components[0]})
if args.whole_eye:
    ocular = json.loads((out/'ocular-regions.json').read_text())
    # Texture-classified ocular surfaces cannot be relabeled as eyelid skin.
    # This is a diagnostic eligibility constraint, never a deformation mask.
    warm = set()
    for row in ocular['nearby_polygons']:
        if row['component'] == 0 and row['rgb'][0]-row['rgb'][2] >= .035:
            warm.update(vertex_ids[index] for index in mesh.data.polygons[row['polygon']].vertices)
    skin_indices = sorted(warm)
skin_points = np.asarray([list(unique[index]) for index in skin_indices])
skin_set = set(components[0])
graph = defaultdict(dict)
for polygon in mesh.data.polygons:
    if not all(index in skin_set for index in polygon.vertices): continue
    indices = [vertex_ids[index] for index in polygon.vertices]
    for first,second in zip(indices,indices[1:]+indices[:1]):
        if first == second: continue
        distance = (unique[first]-unique[second]).length
        graph[first][second] = distance
        graph[second][first] = distance

def cross(first,second,third):
    return (second[0]-first[0])*(third[1]-first[1])-(second[1]-first[1])*(third[0]-first[0])

def hull(points2):
    points2 = sorted(set(points2))
    lower,upper = [],[]
    for point in points2:
        while len(lower)>1 and cross(lower[-2],lower[-1],point)<=0: lower.pop()
        lower.append(point)
    for point in reversed(points2):
        while len(upper)>1 and cross(upper[-2],upper[-1],point)<=0: upper.pop()
        upper.append(point)
    return lower, list(reversed(upper))

def interpolate(curve,x):
    for first,second in zip(curve,curve[1:]):
        if first[0]<=x<=second[0] and second[0]-first[0]>1e-8:
            return first[1]+(second[1]-first[1])*(x-first[0])/(second[0]-first[0])
    return min(curve,key=lambda point:abs(point[0]-x))[1]

records = {}
colors = {}
for cid,side in [(31,'left'),(30,'right')]:
    eye_components = [cid,cid-4] if args.whole_eye else [cid]
    eye_points = [points[index] for component in eye_components for index in components[component]]
    lower,upper = hull([(float(point.x),float(point.z)) for point in eye_points])
    width = max(point.x for point in eye_points)-min(point.x for point in eye_points)
    height = max(point.z for point in eye_points)-min(point.z for point in eye_points)
    radius = height
    rows = {}
    for label,curve,color in [('upper',upper,(.05,.9,.85)),('lower',lower,(1,.35,.05))]:
        seeds = set()
        pairs = []
        samples = curve
        if args.whole_eye:
            samples = [(float(x),interpolate(curve,float(x))) for x in np.linspace(min(p[0] for p in curve),max(p[0] for p in curve),37)]
        for x,z in samples:
            candidates = sorted(eye_points,key=lambda point:(point.x-x)**2+(point.z-z)**2)[:1]
            anchor = Vector((x,candidates[0].y,z))
            distances = np.sum((skin_points-np.asarray(list(anchor)))**2,axis=1)
            if args.whole_eye:
                # Existing warm skin on the exterior side of the measured eye
                # outline, rather than the textured ocular surface itself.
                valid = skin_points[:,2] >= z-.0005 if label == 'upper' else skin_points[:,2] <= z+.0005
                distances[~valid] = np.inf
            slot = int(np.argmin(distances))
            distance = float(np.sqrt(distances[slot]))
            if distance > width*.2: continue
            index = skin_indices[slot]
            seeds.add(index)
            pairs.append({'eye_point':list(anchor),'skin_welded_vertex':index,'skin_point':list(unique[index]),'distance_m':distance})
        distance_map = {index:0.0 for index in seeds}
        queue = [(0.0,index) for index in seeds]
        heapq.heapify(queue)
        while queue:
            distance,index = heapq.heappop(queue)
            if distance != distance_map[index]: continue
            for neighbor,length in graph[index].items():
                next_distance = distance+length
                if next_distance <= radius and next_distance < distance_map.get(neighbor,float('inf')):
                    distance_map[neighbor] = next_distance
                    heapq.heappush(queue,(next_distance,neighbor))
        weights = {}
        for index,distance in distance_map.items():
            t = max(0,1-distance/radius)
            weight = t*t*(3-2*t)
            weights[index] = weight
            old = colors.get(index,(0,(.48,.50,.54)))
            if weight > old[0]: colors[index] = (weight,color)
        rows[label] = {'pairs':pairs,'seeds':sorted(seeds),'welded_weights':weights}
    records[side] = {'eye_components':eye_components,'width_m':width,'height_m':height,'geodesic_radius_m':radius,
                     'lower_silhouette':lower,'upper_silhouette':upper,'masks':rows}
attribute = mesh.data.color_attributes.new(name='BlinkSemanticMaskDiagnostic',type='FLOAT_COLOR',domain='CORNER')
for loop in mesh.data.loops:
    weight,color = colors.get(vertex_ids[loop.vertex_index],(0,(.48,.50,.54)))
    base = (.48,.50,.54)
    attribute.data[loop.index].color = (*(base[axis]*(1-weight)+color[axis]*weight for axis in range(3)),1)
mesh.data.color_attributes.active_color = attribute
scene = bpy.context.scene
scene.display.shading.color_type = 'VERTEX'
camera = scene.camera
center = sum((sum((points[index] for index in components[cid]),Vector())/len(components[cid]) for cid in [30,31]),Vector())/2
camera.data.ortho_scale = .17
for view,offset in [('front',(0,-3,0)),('threequarter',(1.5,-3,0)),('reverse-threequarter',(-1.5,-3,0))]:
    camera.location = center+Vector(offset)
    camera.rotation_euler = (center-camera.location).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath = str(out/f'{tag}-{view}.png')
    bpy.ops.render.render(write_still=True)
data = {'status':'SEMANTIC_MASK_PREVIEW_NOT_APPROVED_FOR_DEFORMATION','source_sha256':intake['source_sha256'],
        'method':'Actual iris+sclera complete sampled silhouette -> exterior warm main-skin vertices -> weighted mesh geodesic neighborhood;diagnostic only,no bounding-box facial edit.' if args.whole_eye else 'Actual separate sclera silhouette -> nearest main-skin vertices -> weighted mesh geodesic neighborhood. No bounding-box facial edit.',
        'anatomical_sides':'Signed X of the actual Mixamo Left/Right shoulder/body roles:positiveX left,negativeX right',
        'eyes':records,'original_to_welded':vertex_ids,'deformation_authored':False,'shape_keys_created':False,
        'vertices_uv_weights_modified':False}
(out/f'{tag}-preview.json').write_text(json.dumps(data,indent=2)+'\n')
bpy.ops.wm.save_as_mainfile(filepath=str(out/f'{tag}-diagnostic.blend'))
print('BLINK_MASK_SEEDS',json.dumps({side:{key:len(value['seeds']) for key,value in row['masks'].items()} for side,row in records.items()}))

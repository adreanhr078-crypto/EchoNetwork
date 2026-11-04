"""Preserve the raw review scene and inspect the same four-view PBR source.

Run with Blender 5.2 in background, loading cassette-geometry-review-editable.blend.
This is asset geometry/material evidence; it does not accept Godot gameplay.
"""
import bpy
import hashlib
import json
import math
from pathlib import Path
from mathutils import Vector
from mathutils.kdtree import KDTree

A = Path(__file__).resolve().parents[2]
G = A / 'art/production/maintenance-refinement-20261025/maintenance-gantry-20261027'
OUT = Path(r'C:\Users\yasmo\Documents\Codex\2026-10-24\new-chat\outputs\quality-progress-20261025')
SOURCE = G / 'cassette-h31-fourview-pbr4k.glb'
EDITABLE = G / 'cassette-pbr-review-editable.blend'
assert not EDITABLE.exists(), 'Preserve existing editable review'
raw_scene = bpy.data.scenes['MAINTENANCE_CASSETTE_REVIEW_20261027']
raw = next(o for o in raw_scene.objects if o.type == 'MESH')
scene = bpy.data.scenes.new('MAINTENANCE_CASSETTE_PBR_REVIEW_20261027')
bpy.context.window.scene = scene
bpy.ops.import_scene.gltf(filepath=str(SOURCE))
visual = next(o for o in scene.objects if o.type == 'MESH')
visual.name = 'CassettePBRMesh'

def bounds(obj):
    points = [obj.matrix_world @ Vector(v) for v in obj.bound_box]
    lo = [min(p[i] for p in points) for i in range(3)]
    hi = [max(p[i] for p in points) for i in range(3)]
    return {'min': lo, 'max': hi, 'size': [hi[i] - lo[i] for i in range(3)]}

bpy.context.view_layer.update()
raw_bounds, pbr_bounds = bounds(raw), bounds(visual)
assert max(abs(a-b) for a,b in zip(raw_bounds['size'],pbr_bounds['size'])) < .0002, (raw_bounds,pbr_bounds)
distances = []
for target, probe in [(raw,visual),(visual,raw)]:
    tree = KDTree(len(target.data.vertices))
    for i,v in enumerate(target.data.vertices):
        tree.insert(target.matrix_world @ v.co, i)
    tree.balance()
    worst = squares = 0.
    for v in probe.data.vertices:
        distance = tree.find(probe.matrix_world @ v.co)[2]
        worst = max(worst,distance)
        squares += distance*distance
    distances.append({'target':target.name,'probe':probe.name,
                      'vertices':len(probe.data.vertices),
                      'max_source_units':worst,
                      'max_at_5m_width_m':worst*5/raw_bounds['size'][0],
                      'rms_source_units':math.sqrt(squares/len(probe.data.vertices))})
    del tree
assert all(d['max_at_5m_width_m'] < .0005 for d in distances), distances
counts = [sum(len(p.vertices)-2 for p in o.data.polygons) for o in [raw,visual]]
assert counts == [1943923,1943923], counts
images = [{'name':im.name,'size':list(im.size)} for im in bpy.data.images if im.size[0] > 1]
report = {'status':'GEOMETRY_PASS_MATERIAL_RENDER_REVIEW_PENDING',
          'scope':'Full bidirectional nearest-vertex comparison and equal triangle counts; not identical indices, native collision, or visual acceptance.',
          'source':SOURCE.name,'sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
          'raw_bounds_blender':raw_bounds,'pbr_bounds_blender':pbr_bounds,
          'triangles_each':counts[0],'distances':distances,'images':images,
          'raw_scene_preserved':raw_scene.name}
(G / 'cassette-pbr-geometry-audit.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
scene.render.engine = 'CYCLES'
scene.cycles.device = 'CPU'
scene.cycles.samples = 16
scene.render.resolution_x = scene.render.resolution_y = 640
scene.render.resolution_percentage = 100
scene.world = raw_scene.world.copy()
scene.view_settings.view_transform = 'AgX'
for old in raw_scene.objects:
    if old.type not in ['CAMERA','LIGHT']:
        continue
    obj = old.copy()
    obj.data = old.data.copy()
    scene.collection.objects.link(obj)
    if obj.type == 'CAMERA':
        scene.camera = obj
scene.view_layers[0].material_override = None
bpy.ops.wm.save_as_mainfile(filepath=str(EDITABLE))
center = Vector((0,0,.3347))
for name,position,scale in [('front',(0,2,.3347),1.18),
                            ('quarter',(1.5,2,1.05),1.22),
                            ('back',(0,-2,.3347),1.18)]:
    scene.camera.location = position
    scene.camera.rotation_euler = (center-scene.camera.location).to_track_quat('-Z','Y').to_euler()
    scene.camera.data.ortho_scale = scale
    scene.render.filepath = str(OUT / ('cassette-pbr-'+name+'-20261027.png'))
    assert not Path(scene.render.filepath).exists(), 'Preserve existing render'
    bpy.ops.render.render(write_still=True)
print('CASSETTE_GEOMETRY_AUDIT '+json.dumps(report))

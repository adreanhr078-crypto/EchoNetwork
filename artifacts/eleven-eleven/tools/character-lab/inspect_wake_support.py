"""Measure actual hand skin gaps in the untouched source and qualified target."""
import hashlib
import json
from pathlib import Path
import sys
import argparse

import bpy
import numpy as np

APP = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser()
parser.add_argument('--case',type=Path,default=APP/'art/production/echo-school-rebuild-20261029/motions/wake-studio-20261102')
args = parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
case = args.case.resolve(strict=True)
source_hash = hashlib.sha256((case/'source.glb').read_bytes()).hexdigest()
blend_hash = hashlib.sha256((case/'single-motion.blend').read_bytes()).hexdigest()
diagnosis = json.loads((case/'diagnosis.json').read_text())
reference = json.loads((case/'blender-reference.json').read_text())
bpy.ops.wm.open_mainfile(filepath=str(case/'single-motion.blend'))
scene = bpy.context.scene
rigs = {'source': bpy.data.objects[reference['source_rig']], 'target': bpy.data.objects[reference['target_rig']]}
meshes, hands = {}, {}
for name, rig in rigs.items():
    mesh = next(obj for obj in scene.objects if obj.type == 'MESH' and any(mod.type == 'ARMATURE' and mod.object == rig for mod in obj.modifiers))
    meshes[name] = mesh
    groups = {group.index: group.name for group in mesh.vertex_groups}
    hands[name] = {}
    for side in ['Left', 'Right']:
        eligible = {index for index, group in groups.items() if group.startswith('mixamorig:'+side+'Hand')}
        selected = [vertex.index for vertex in mesh.data.vertices if sum(weight.weight for weight in vertex.groups if weight.group in eligible) > .5]
        assert selected
        hands[name][side.lower()] = selected
rows = []
for index in range(len(reference['samples'])):
    scene.frame_set(index)
    bpy.context.view_layer.update()
    graph = bpy.context.evaluated_depsgraph_get()
    row = {'sample': index, 'time': index/24, 'phase': index/(len(reference['samples'])-1)}
    for name, mesh in meshes.items():
        evaluated = mesh.evaluated_get(graph)
        geometry = evaluated.to_mesh()
        local = np.empty((len(geometry.vertices),3),dtype=np.float32)
        geometry.vertices.foreach_get('co',local.ravel())
        matrix = np.asarray(mesh.matrix_world,dtype=np.float64)
        points = local @ matrix[:3,:3].T + matrix[:3,3]
        floor = float(np.min(points[:,2]))
        factor = diagnosis['leg_length_ratio'] if name == 'source' else 1
        row[name] = {side+'_hand_gap_m': (float(np.min(points[selected,2]))-floor)*factor for side, selected in hands[name].items()}
        row[name]['floor_before_alignment_m'] = floor
        row[name]['hand_vertices'] = {side: len(selected) for side, selected in hands[name].items()}
        evaluated.to_mesh_clear()
    rows.append(row)
report = {'status':'SUPPORT_PHASE_MEASUREMENT_PENDING_VISUAL_INTENT_REVIEW',
          'source_sha256':source_hash,'blend_sha256':blend_hash,'native_fps':24,
          'samples':rows,'selection':'Existing Hand and finger bone weights >0.5;lowest hand skin is a conservative palm-gap lower bound',
          'source_gap_scale':'Original source gaps scaled once by measured target/source leg ratio',
          'keys_or_geometry_changed':False,'warning':'A low gap alone does not establish support intent; align intervals with actual source poses and hand velocity.'}
(case/'support-phase-diagnosis.json').write_text(json.dumps(report,indent=2)+'\n')
assert hashlib.sha256((case/'single-motion.blend').read_bytes()).hexdigest() == blend_hash
assert hashlib.sha256((case/'source.glb').read_bytes()).hexdigest() == source_hash
for row in rows[::8]: print('SUPPORT',row['sample'],row['source'],row['target'])

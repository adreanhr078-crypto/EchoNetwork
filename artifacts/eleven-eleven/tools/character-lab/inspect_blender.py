"""Inspect a source .blend without saving or changing geometry, weights or keys."""
import argparse
import hashlib
import json
from pathlib import Path
import sys

import bpy


def digest(path):
    with path.open('rb') as handle:
        return hashlib.file_digest(handle, 'sha256').hexdigest()


parser = argparse.ArgumentParser()
parser.add_argument('--source', type=Path, required=True)
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:])
source, output = args.source.resolve(strict=True), args.output.resolve()
if source == output or source.suffix != '.blend' or output.suffix != '.json':
    raise ValueError('Expected source .blend and separate output .json')
before = digest(source)
bpy.ops.wm.open_mainfile(filepath=str(source), load_ui=False, use_scripts=False)
rigs, meshes = [], []
for obj in bpy.context.scene.objects:
    if obj.type == 'ARMATURE':
        bones = [bone.name for bone in obj.data.bones]
        rigs.append({'name': obj.name, 'bone_count': len(bones), 'bones': bones,
                     'possible_secondary_bones': [b for b in bones if any(
                         tag in b.lower() for tag in ('hair', 'coat', 'cape', 'skirt', 'tie'))]})
    elif obj.type == 'MESH':
        obj.data.calc_loop_triangles()
        meshes.append({'name': obj.name, 'vertices': len(obj.data.vertices),
                       'triangles': len(obj.data.loop_triangles),
                       'shape_keys': list(obj.data.shape_keys.key_blocks.keys()) if obj.data.shape_keys else [],
                       'vertex_groups': len(obj.vertex_groups),
                       'armature_modifiers': [m.object.name if m.object else None
                                              for m in obj.modifiers if m.type == 'ARMATURE']})
unchanged = digest(source) == before
report = {'status': 'PASS_READ_ONLY_INSPECTION' if unchanged else 'FAIL_SOURCE_CHANGED',
          'blender_version': bpy.app.version_string, 'source_sha256': before,
          'rigs': rigs, 'meshes': meshes, 'source_unchanged': unchanged,
          'actions': [action.name for action in bpy.data.actions],
          'visual_acceptance': 'UNVERIFIED', 'face_rig_authored': False}
output.parent.mkdir(parents=True, exist_ok=True)
output.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
if not unchanged:
    raise RuntimeError('Source changed during inspection')
print('CHARACTER_LAB_BLENDER_PASS ' + bpy.app.version_string)

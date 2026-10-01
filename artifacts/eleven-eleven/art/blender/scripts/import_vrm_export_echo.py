"""Import the owner-local VRM sample and export a neutral GLB proof."""
import argparse
import sys
from pathlib import Path
import bpy

parser = argparse.ArgumentParser()
parser.add_argument('--input', required=True)
parser.add_argument('--output', required=True)
args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:])
source = Path(args.input).resolve()
target = Path(args.output).resolve()
target.parent.mkdir(parents=True, exist_ok=True)
if not source.exists():
    raise FileNotFoundError(source)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(source))
meshes = [obj for obj in bpy.context.scene.objects if obj.type == 'MESH']
if not meshes:
    raise RuntimeError('VRM import produced no mesh objects')
for obj in meshes:
    obj.name = 'EchoVRoidPrototype_' + obj.name
    obj.hide_render = False
for obj in bpy.context.scene.objects:
    obj.select_set(obj.type in {'MESH', 'ARMATURE'})
bpy.ops.export_scene.gltf(filepath=str(target), export_format='GLB', export_cameras=False, export_lights=False, export_animations=True)
print('ECHO_VRM_IMPORTED', len(meshes))

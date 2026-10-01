"""Regression: batching must preserve transformed geometry and door identity."""
import math
import runpy
import sys
import tempfile
from pathlib import Path
import bpy

out = Path(tempfile.mkdtemp(prefix='echo-room-regression-'))
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.object.empty_add(location=(3,-2,4))
parent = bpy.context.object
parent.rotation_euler.z = 0.7
parent.scale = (2,1,1.3)
for name, pos in [('Wall',(1,2,0)),('Door',(0,0,1)),('Panel',(-1,0,2))]:
    bpy.ops.mesh.primitive_cube_add(location=pos)
    obj = bpy.context.object
    obj.name = name
    obj.parent = parent
bpy.ops.export_scene.gltf(filepath=str(out/'source.glb'),export_format='GLB')

def vertices():
    bpy.context.view_layer.update()
    return sorted(tuple(round(c,4) for c in o.matrix_world @ v.co)
                  for o in bpy.context.scene.objects if o.type=='MESH' for v in o.data.vertices)

# Compare the imported representation: glTF can split vertices at normals/UVs.
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(out/'source.glb'))
before = set(vertices())
sys.argv = ['blender','--','--input',str(out/'source.glb'),'--output',str(out/'result.glb')]
runpy.run_path(str(Path(__file__).with_name('sanitize_runtime_room.py')),run_name='__main__')
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(out/'result.glb'))
assert set(vertices()) == before, 'World-space geometry moved during sanitization'
assert any(o.name=='Door' for o in bpy.context.scene.objects), 'Door lost independent binding'
assert sum(o.type=='MESH' for o in bpy.context.scene.objects)==2
print('ROOM_TRANSFORM_AND_DOOR_REGRESSION_PASS')

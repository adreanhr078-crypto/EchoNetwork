"""Extract the authored console, merge static parts by material, retain key motion.

Run in portable Blender with -- source.blend output.raw.glb audit.json.
The original Jutsu scene remains untouched.
"""
import bpy
import bmesh
import json
import sys
from pathlib import Path

source, destination, audit_path = map(Path, sys.argv[sys.argv.index('--') + 1:])
bpy.ops.wm.open_mainfile(filepath=str(source.resolve()))
root = bpy.data.objects['EchoSignalConsole_Root']
root.location = (0, 0, 0)
key = bpy.data.objects['EchoSignalConsole_AcknowledgmentKey']
scene = bpy.context.scene
scene.frame_set(1)
groups = {}
for obj in list(bpy.data.objects):
    if obj.name.startswith('EchoSignalConsole_') and obj.type == 'MESH' and obj != key:
        groups.setdefault(obj.data.materials[0].name, []).append(obj)
for material, objects in groups.items():
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objects:
        bpy.context.view_layer.objects.active = obj
        for modifier in list(obj.modifiers):
            bpy.ops.object.modifier_apply(modifier=modifier.name)
        matrix = obj.matrix_world.copy()
        obj.parent = None
        obj.matrix_world = matrix
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    merged = bpy.context.object
    merged.name = 'EchoSignalConsole_Static_' + material.removeprefix('EchoSignalConsole_')
    matrix = merged.matrix_world.copy()
    merged.parent = root
    merged.matrix_world = matrix

bpy.ops.object.select_all(action='DESELECT')
selected = [root, key, key.parent] + [o for o in root.children if o.type == 'MESH']
for obj in selected:
    obj.select_set(True)
    if obj.type == 'MESH':
        bpy.context.view_layer.objects.active = obj
        for modifier in list(obj.modifiers):
            bpy.ops.object.modifier_apply(modifier=modifier.name)
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        bmesh.ops.dissolve_degenerate(bm, edges=list(bm.edges), dist=1e-7)
        bm.to_mesh(obj.data)
        bm.free()
        obj.data.update()
destination.parent.mkdir(parents=True, exist_ok=True)
bpy.ops.export_scene.gltf(filepath=str(destination.resolve()), export_format='GLB',
    export_apply=True, export_animations=True, export_animation_mode='ACTIONS',
    export_cameras=False, export_lights=False, use_selection=True)
dg = bpy.context.evaluated_depsgraph_get()
triangles = 0
for obj in selected:
    if obj.type != 'MESH':
        continue
    evaluated = obj.evaluated_get(dg)
    mesh = evaluated.to_mesh()
    mesh.calc_loop_triangles()
    triangles += len(mesh.loop_triangles)
    evaluated.to_mesh_clear()
poses = []
for frame in [1, 5, 12, 20, 24]:
    scene.frame_set(frame)
    poses.append({'frame': frame, 'local_position': list(key.location)})
assert abs(poses[0]['local_position'][1] - poses[-1]['local_position'][1]) < 1e-6
assert poses[1]['local_position'][1] > poses[0]['local_position'][1] + .005
audit = {'source': source.name, 'revision': 6, 'root_origin': list(root.location),
    'mesh_count': sum(o.type == 'MESH' for o in selected), 'triangles': triangles,
    'materials': list(groups), 'poses': poses, 'fps': scene.render.fps,
    'animation': key.animation_data.action.name, 'bytes': destination.stat().st_size,
    'note': 'Extraction metrics only; consult the execution report for runtime and device acceptance.'}
audit_path.write_text(json.dumps(audit, indent=2) + '\n', encoding='utf-8')
print(json.dumps(audit))

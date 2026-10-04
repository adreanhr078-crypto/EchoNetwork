"""Verify downloaded Jutsu source and export presentation-only prop.
Does not save or mutate the editable source .blend. No runtime integration.
"""
import bpy
import json
import math
from pathlib import Path

base = Path(bpy.data.filepath).parent
evidence = base.parents[2] / 'audits/evidence/character-shading-20261001/higgsfield'
evidence.mkdir(parents=True, exist_ok=True)
prop = bpy.data.collections['Conduit_Presentation']
depsgraph = bpy.context.evaluated_depsgraph_get()
points = []
triangles = 0
object_stats = []
for obj in prop.objects:
    evaluated = obj.evaluated_get(depsgraph)
    mesh = evaluated.to_mesh()
    mesh.calc_loop_triangles()
    points.extend(evaluated.matrix_world @ v.co for v in mesh.vertices)
    triangles += len(mesh.loop_triangles)
    object_stats.append({'name': obj.name, 'triangles': len(mesh.loop_triangles), 'material': obj.data.materials[0].name})
    evaluated.to_mesh_clear()
radius = max(math.hypot(v.x, v.y) for v in points)
zmin, zmax = min(v.z for v in points), max(v.z for v in points)
assert radius <= 0.45001, radius
assert abs(zmin) < 0.00001 and abs(zmax - 1.8) < 0.00001, (zmin, zmax)
assert not bpy.data.armatures and not bpy.data.actions
report = {'status': 'PASS', 'source': 'conduit-jutsu-r1.blend', 'footprint_radius_m': radius, 'bounds_z_m': [zmin, zmax], 'height_m': zmax - zmin, 'source_objects': object_stats, 'triangles_evaluated': triangles, 'armatures': 0, 'actions': 0, 'runtime_integrated': False}

# Read-only energized preview: no save and no keyframes, shell remains unchanged.
scene = bpy.context.scene
scene.render.resolution_x = 512
scene.render.resolution_y = 682
signal = bpy.data.materials['Signal_DormantAmber']
p = signal.node_tree.nodes['Principled BSDF']
for socket in ['Base Color', 'Emission Color']:
    p.inputs[socket].default_value = (0.012, 0.49, 0.60, 1)
p.inputs['Emission Strength'].default_value = 1.25
signal.diffuse_color = (0.012, 0.49, 0.60, 1)
scene.render.filepath = str(evidence / 'conduit-energized-review.png')
bpy.ops.render.render(write_still=True)
for socket in ['Base Color', 'Emission Color']:
    p.inputs[socket].default_value = (0.52, 0.16, 0.018, 1)
p.inputs['Emission Strength'].default_value = 0.65
signal.diffuse_color = (0.52, 0.16, 0.018, 1)

# Bake bevels to portable geometry, consolidate static material groups into five
# draw surfaces and retain two signal objects for explicit runtime binding.
bpy.ops.object.select_all(action='DESELECT')
for obj in prop.objects:
    obj.select_set(True)
bpy.context.view_layer.objects.active = prop.objects[0]
bpy.ops.object.convert(target='MESH')
roles = {'Shell_DeepBlueSteel': 'ShellMesh', 'Edge_BlueGraphite': 'HousingDetailMesh', 'Recess_Obsidian': 'RecessMesh', 'Service_CeramicIvory': 'CeramicDetailMesh', 'Fastener_BrushedSteel': 'FastenerMesh'}
for mat_name, name in roles.items():
    members = [o for o in prop.objects if o.type == 'MESH' and o.data.materials[0].name == mat_name]
    bpy.ops.object.select_all(action='DESELECT')
    for obj in members:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = members[0]
    if len(members) > 1:
        bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    obj.name = name
    obj['presentation_role'] = name
    obj['candidate_only'] = True
bpy.data.objects['Core_Lens'].name = 'CoreMesh'
bpy.data.objects['Status_Window'].name = 'StatusSignalMesh'
bpy.ops.object.select_all(action='DESELECT')
for obj in prop.objects:
    obj.select_set(True)
bpy.context.view_layer.objects.active = prop.objects[0]
output = base / 'sector11-conduit-v1.glb'
bpy.ops.export_scene.gltf(filepath=str(output), export_format='GLB', use_selection=True, export_apply=True, export_animations=False, export_cameras=False, export_lights=False, export_extras=True)
report['export'] = {'file': output.name, 'object_count': len(prop.objects), 'mesh_names': sorted(o.name for o in prop.objects), 'studio_excluded': True, 'signal_bindings': ['CoreMesh', 'StatusSignalMesh'], 'source_blend_saved': False}
(evidence / 'geometry-export-verification.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
print(json.dumps({'status':'PASS','radius':radius,'height':zmax-zmin,'triangles':triangles,'export_meshes':len(prop.objects),'file':output.name}))

"""Read-only, bone-semantic head topology intake before any facial deformation."""
import colorsys
import hashlib
import json
from pathlib import Path
import sys

import bpy
from mathutils import Vector

APP = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(APP/'tools/animation-library'))
from golden_reference import verify

verify()
production = APP/'art/production/echo-school-rebuild-20261029'
profile = json.loads((production/'target-profile.json').read_text())
source = Path(profile['target_file'])
digest = hashlib.sha256(source.read_bytes()).hexdigest()
assert digest == profile['target_sha256']
out = production/'face/intake-20261102'
out.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(source))
mesh = next(obj for obj in bpy.context.scene.objects if obj.type == 'MESH')
rig = next(obj for obj in bpy.context.scene.objects if obj.type == 'ARMATURE')
groups = {group.index: group.name for group in mesh.vertex_groups}
head_groups = {index for index, name in groups.items() if name in ['mixamorig:Head', 'mixamorig:HeadTop_End']}
assert head_groups
head = [vertex.index for vertex in mesh.data.vertices if sum(weight.weight for weight in vertex.groups if weight.group in head_groups) > .5]
assert len(head) > 100
points = [mesh.matrix_world @ vertex.co for vertex in mesh.data.vertices]
parent = list(range(len(points)))

def find(index):
    while parent[index] != index:
        parent[index] = parent[parent[index]]
        index = parent[index]
    return index

def union(first, second):
    first, second = find(first), find(second)
    if first != second:
        parent[second] = first

positions = {}
for index, point in enumerate(points):
    key = tuple(round(value, 6) for value in point)
    if key in positions:
        union(index, positions[key])
    else:
        positions[key] = index
for polygon in mesh.data.polygons:
    for index in polygon.vertices[1:]: union(polygon.vertices[0], index)
components = {}
for index in range(len(points)): components.setdefault(find(index), []).append(index)
components = sorted(components.values(), key=len, reverse=True)
ids = {vertex: index for index, component in enumerate(components) for vertex in component}
head_set = set(head)
rows = []
for index, component in enumerate(components):
    eligible = sorted(head_set.intersection(component))
    if not eligible: continue
    rows.append({'id': index, 'all_vertices': len(component), 'head_vertices': len(eligible),
                 'low': [min(points[i][axis] for i in eligible) for axis in range(3)],
                 'high': [max(points[i][axis] for i in eligible) for axis in range(3)]})
attribute = mesh.data.color_attributes.new(name='TopologyComponentDiagnostic', type='FLOAT_COLOR', domain='CORNER')
for loop in mesh.data.loops:
    rgb = colorsys.hsv_to_rgb((ids[loop.vertex_index]*.61803398875)%1, .72, .85)
    attribute.data[loop.index].color = (*rgb, 1)
mesh.data.color_attributes.active_color = attribute
low = Vector(tuple(min(points[i][axis] for i in head) for axis in range(3)))
high = Vector(tuple(max(points[i][axis] for i in head) for axis in range(3)))
center = (low+high)*.5
scene = bpy.context.scene
scene.render.engine = 'BLENDER_WORKBENCH'
scene.display.shading.light = 'STUDIO'
scene.display.shading.show_shadows = True
scene.display.shading.show_cavity = True
scene.world = bpy.data.worlds.new('ReadOnlyHeadIntake')
scene.world.color = (.045, .055, .075)
scene.render.resolution_x = 1100
scene.render.resolution_y = 1100
scene.render.resolution_percentage = 100
camera = bpy.data.objects.new('HeadDiagnosticCamera', bpy.data.cameras.new('HeadDiagnosticCamera'))
scene.collection.objects.link(camera)
scene.camera = camera
camera.data.type = 'ORTHO'
camera.data.ortho_scale = max(high.x-low.x, high.z-low.z)*1.15
captures = []
ink = bpy.data.materials.new('DiagnosticTopologyInk')
ink.diffuse_color = (.005, .008, .012, 1)
mesh.data.materials.append(ink)
wire = mesh.modifiers.new('DiagnosticWireOnly', 'WIREFRAME')
wire.thickness = .00015
wire.use_replace = False
wire.use_even_offset = False
wire.material_offset = len(mesh.data.materials)-1
wire.show_render = False
for mode in ['TEXTURE', 'MATERIAL', 'VERTEX', 'WIREFRAME']:
    scene.display.shading.color_type = 'MATERIAL' if mode == 'WIREFRAME' else mode
    wire.show_render = mode == 'WIREFRAME'
    for view, offset in [('front', (0, -3, 0)), ('threequarter', (1.5, -3, 0)), ('side', (3, 0, 0))]:
        camera.location = center+Vector(offset)
        camera.rotation_euler = (center-camera.location).to_track_quat('-Z', 'Y').to_euler()
        path = out/f'{mode.lower()}-{view}.png'
        scene.render.filepath = str(path)
        bpy.ops.render.render(write_still=True)
        captures.append({'path': path.name, 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()})
data = {'status': 'HEAD_TOPOLOGY_CAPTURE_PENDING_SEMANTIC_REVIEW', 'source_sha256': digest,
        'rig_bones': len(rig.data.bones), 'morphs': list(mesh.data.shape_keys.key_blocks.keys()) if mesh.data.shape_keys else [],
        'head_selection': 'Existing Head/HeadTop_End weights >0.5; intake only, no face feature selection/deformation',
        'head_vertices': len(head), 'whole_mesh_components_after_position_weld_analysis_only': len(components),
        'head_components': rows, 'captures': captures, 'source_geometry_or_weights_modified': False,
        'eyelid_mouth_semantics': 'UNREVIEWED; no Blink/viseme groups or shapes created'}
(out/'topology.json').write_text(json.dumps(data, indent=2)+'\n')
(out/'component-vertices.json').write_text(json.dumps(components)+'\n')
(out/'head-vertices.json').write_text(json.dumps(head)+'\n')
bpy.ops.wm.save_as_mainfile(filepath=str(out/'head-topology-diagnostic.blend'))
assert hashlib.sha256(source.read_bytes()).hexdigest() == digest
verify()
print('HEAD_TOPOLOGY', json.dumps({key: data[key] for key in ['head_vertices', 'whole_mesh_components_after_position_weld_analysis_only', 'head_components']}))

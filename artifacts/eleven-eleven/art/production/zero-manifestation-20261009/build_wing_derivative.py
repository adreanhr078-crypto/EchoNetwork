"""Editable finite feather rig from the immutable paid Tripo wing source.

Run with the pinned Blender executable. No source replacement, no paid requests.
"""
import hashlib
import json
import math
import shutil
from pathlib import Path
import bpy
from mathutils import Matrix, Vector

CASE = Path(__file__).resolve().parent
APP = CASE.parents[2]
SOURCE = APP / 'art/production/tripo-20261007/echo-shadow-wing-v1/tripo-out/echo-shadow-wing-v1-20261008-dc3f46f8/model.glb'
OUTPUT = APP / 'godot/assets/characters/echo_shadow_wing_feathers_v1.glb'
if OUTPUT.exists() and not (CASE/'wing-feathers-v1-4k.glb').exists():
    assert hashlib.sha256(OUTPUT.read_bytes()).hexdigest() == '404e01b00bf20be7e7e64672009c876bc2541fdbedb77c13c65667d3dd2002fb'
    shutil.copy2(OUTPUT, CASE/'wing-feathers-v1-4k.glb')
source_sha = hashlib.sha256(SOURCE.read_bytes()).hexdigest()
assert source_sha == '029d4a631c1244e552346912fc75c345782aae8cb6a25ece3069bdc4022cd4d8'
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(SOURCE))
meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
assert len(meshes) == 1
obj = meshes[0]
bpy.context.view_layer.objects.active = obj
obj.select_set(True)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
original_count = len(obj.data.vertices)
original_uv = [tuple(loop.uv) for loop in obj.data.uv_layers.active.data]

# Raw glTF has root at +Z=.44, Y=-.12 and its broad fan towards -Z.
# Blender imported glTF +Y as +Z. Rotate in Blender's XY plane, preserving
# winding/UVs, to yield Godot +X left-shoulder extension with +Y up.
for vertex in obj.data.vertices:
    x, y, z = vertex.co
    vertex.co = Vector(((y + .44) * .75, -x * .75, (z + .12) * .75))
obj.name = 'EchoShadowFeatherMesh'
obj.data.name = 'EchoShadowFeatherMesh'

armature_data = bpy.data.armatures.new('ZeroFeatherRig')
armature = bpy.data.objects.new('ZeroFeatherRig', armature_data)
bpy.context.collection.objects.link(armature)
obj.select_set(False)
armature.select_set(True)
bpy.context.view_layer.objects.active = armature
bpy.ops.object.mode_set(mode='EDIT')
root = armature.data.edit_bones.new('WingMount')
root.head = (0, 0, 0)
root.tail = (.06, 0, 0)
angles = [-23.0, -7.0, 10.0, 25.0, 39.0]
stations = [0.0, .18, .40, .69]
endpoints = []
for fan, degrees in enumerate(angles):
    angle = math.radians(degrees)
    direction = Vector((math.cos(angle), 0, math.sin(angle)))
    parent = root
    for segment in range(3):
        bone = armature.data.edit_bones.new(f'Feather_{fan}_{segment}')
        bone.head = direction * stations[segment]
        bone.tail = direction * stations[segment + 1]
        bone.parent = parent
        bone.use_connect = False
        parent = bone
    tip = direction * stations[-1]
    endpoints.append({'bone': f'Feather_{fan}_2', 'rest_tip': [tip.x, tip.z, -tip.y]})
bpy.ops.object.mode_set(mode='OBJECT')

groups = {'WingMount': obj.vertex_groups.new(name='WingMount')}
for fan in range(5):
    for segment in range(3):
        name = f'Feather_{fan}_{segment}'
        groups[name] = obj.vertex_groups.new(name=name)

def smooth(value):
    value = min(1., max(0., value))
    return value * value * (3. - 2. * value)

for vertex in obj.data.vertices:
    point = vertex.co
    distance = max(0., math.hypot(point.x, point.z))
    feather = smooth((distance - .035) / .15)
    if feather <= 0:
        groups['WingMount'].add([vertex.index], 1., 'REPLACE')
        continue
    degrees = math.degrees(math.atan2(point.z, max(.0001, point.x)))
    # Only neighbouring fans and longitudinal segments may influence a point.
    # Their support is continuous; no nearest-bone discontinuity or >4 weights.
    if degrees <= angles[0]: fa, fb, blend = 0, 0, 0.
    elif degrees >= angles[-1]: fa, fb, blend = 4, 4, 0.
    else:
        fa = next(i for i in range(4) if angles[i] <= degrees <= angles[i+1])
        fb = fa + 1
        blend = smooth((degrees - angles[fa]) / (angles[fb] - angles[fa]))
    segment_float = max(0., min(2., (distance - .09) / .235))
    sa = int(math.floor(segment_float))
    sb = min(sa+1, 2)
    segment_blend = smooth(segment_float-sa)
    weights = {}
    for fan, fan_weight in [(fa, 1.-blend), (fb, blend)]:
        for segment, segment_weight in [(sa, 1.-segment_blend), (sb, segment_blend)]:
            name = f'Feather_{fan}_{segment}'
            weights[name] = weights.get(name, 0.) + fan_weight*segment_weight
    # The short mount region is rigid; blending root with the first fin only
    # keeps four-or-fewer supports while the root cannot tear neighbouring fans.
    if feather < 1.:
        weights = {'WingMount': 1.-feather}
        for fan, value in [(fa, feather*(1.-blend)), (fb, feather*blend)]:
            name = f'Feather_{fan}_0'
            weights[name] = weights.get(name, 0.) + value
    for name, weight in weights.items():
        if weight > 1e-8: groups[name].add([vertex.index], weight, 'REPLACE')

modifier = obj.modifiers.new('Independent feather deformation', 'ARMATURE')
modifier.object = armature
# A root skinned mesh avoids glTF's ignored-parent-transform ambiguity.
# Its coordinates are already baked; the Armature modifier remains authoritative.
obj.parent = None
assert len(obj.data.vertices) == original_count
assert [tuple(loop.uv) for loop in obj.data.uv_layers.active.data] == original_uv
maximum_support = max(len([g for g in v.groups if g.weight > 1e-8]) for v in obj.data.vertices)
assert maximum_support <= 4
maximum_sum_error = max(abs(sum(g.weight for g in v.groups)-1.) for v in obj.data.vertices)
assert maximum_sum_error < 2e-7

# Keep the full-resolution paid source immutable; derive 2K runtime maps. The
# original 4K candidate is retained for pixel comparison, not overwritten.
texture_records = []
for image in bpy.data.images:
    if image.source != 'FILE' or image.size[0] == 0: continue
    original_size = list(image.size)
    if max(original_size) > 2048:
        ratio = 2048. / max(original_size)
        image.scale(round(original_size[0]*ratio), round(original_size[1]*ratio))
        image.pack()
    texture_records.append({'name':image.name,'source_size':original_size,'runtime_size':list(image.size),
                            'colour_space':image.colorspace_settings.name})
for material in obj.data.materials:
    material.name = 'ZeroObsidianFeatherPBR'
    if material.use_nodes:
        bsdf = next((n for n in material.node_tree.nodes if n.type == 'BSDF_PRINCIPLED'), None)
        if bsdf:
            bsdf.inputs['Roughness'].default_value = .49
            bsdf.inputs['Metallic'].default_value = .14

CASE.mkdir(parents=True, exist_ok=True)
OUTPUT.parent.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=str(CASE/'wing-feathers-v2.blend'))
obj.select_set(True)
armature.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(OUTPUT), export_format='GLB', use_selection=True,
                         export_animations=False, export_skins=True, export_def_bones=True,
                         export_yup=True, export_apply=False, export_all_influences=False,
                         export_tangents=True)
report = {'status':'EDITABLE_RIG_BUILT_VISUAL_REVIEW_REQUIRED', 'blender':bpy.app.version_string,
          'source_sha256':source_sha, 'source_task_id':'dc3f46f8-b751-49dc-ace0-ac498826561a',
          'output':str(OUTPUT), 'output_sha256':hashlib.sha256(OUTPUT.read_bytes()).hexdigest(),
          'blend_sha256':hashlib.sha256((CASE/'wing-feathers-v2.blend').read_bytes()).hexdigest(),
          'vertices':original_count, 'triangles':sum(len(p.vertices)-2 for p in obj.data.polygons),
          'bones':len(armature.data.bones), 'maximum_support':maximum_support,
          'maximum_weight_sum_error':maximum_sum_error, 'uv_preserved':True,
          'fin_endpoints':endpoints, 'runtime_textures':texture_records, 'canonical_extension':'anatomical-left, Godot +X',
          'rest_aabb':{'minimum':[min(v.co[i] for v in obj.data.vertices) for i in range(3)],
                       'maximum':[max(v.co[i] for v in obj.data.vertices) for i in range(3)]}}
(CASE/'wing-feathers-v2.json').write_text(json.dumps(report,indent=2), encoding='utf-8')
print(json.dumps({key:report[key] for key in ['status','vertices','triangles','bones','maximum_support','output_sha256']}))

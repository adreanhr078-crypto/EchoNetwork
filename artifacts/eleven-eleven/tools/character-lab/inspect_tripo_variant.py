"""Preserve a downloaded Tripo source and render a bounded geometry intake case."""
import argparse
import hashlib
import json
from pathlib import Path
import sys

import bpy
from mathutils import Vector

parser = argparse.ArgumentParser()
parser.add_argument('--source', type=Path, required=True)
parser.add_argument('--output', type=Path, required=True)
parser.add_argument('--textured', action='store_true')
args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:])
source, output = args.source.resolve(strict=True), args.output.resolve()
if output == source.parent or '/golden/' in output.as_posix().lower():
    raise ValueError('Use an isolated intake output')
output.mkdir(parents=True, exist_ok=True)
sha = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()
before = sha(source)
bpy.ops.wm.read_factory_settings(use_empty=True)
if source.suffix.lower() == '.fbx':
    bpy.ops.import_scene.fbx(filepath=str(source), use_anim=False)
elif source.suffix.lower() == '.glb':
    bpy.ops.import_scene.gltf(filepath=str(source))
else:
    raise ValueError('Expected FBX or GLB')
meshes = [obj for obj in bpy.context.scene.objects if obj.type == 'MESH']
if not meshes:
    raise ValueError('No source geometry')
points = [obj.matrix_world @ Vector(c) for obj in meshes for c in obj.bound_box]
low = Vector(tuple(min(p[i] for p in points) for i in range(3)))
high = Vector(tuple(max(p[i] for p in points) for i in range(3)))
center, size = (low + high) * .5, high - low
stats = []
for obj in meshes:
    obj.data.calc_loop_triangles()
    stats.append({'name': obj.name, 'vertices': len(obj.data.vertices),
                  'polygons': len(obj.data.polygons), 'triangles': len(obj.data.loop_triangles),
                  'quads': sum(len(p.vertices) == 4 for p in obj.data.polygons),
                  'uv_layers': list(obj.data.uv_layers.keys()),
                  'shape_keys': list(obj.data.shape_keys.key_blocks.keys()) if obj.data.shape_keys else []})
scene = bpy.context.scene
scene.render.engine = 'BLENDER_WORKBENCH'
scene.display.shading.light = 'STUDIO'
scene.display.shading.color_type = 'TEXTURE' if args.textured else 'MATERIAL'
scene.display.shading.show_cavity = True
scene.world = bpy.data.worlds.new('VariantIntake')
scene.world.color = (.055,.065,.085)
camera_data = bpy.data.cameras.new('IntakeCamera')
camera = bpy.data.objects.new('IntakeCamera', camera_data)
scene.collection.objects.link(camera)
scene.camera = camera
camera_data.type = 'ORTHO'
scene.render.resolution_x = 900
scene.render.resolution_y = 1000
scene.render.resolution_percentage = 100
camera_data.ortho_scale = max(size.z * 1.12, size.x * 1.25)
scene.render.image_settings.file_format = 'PNG'
captures = []
for label, offset in [('front', Vector((0,-4,0))), ('back', Vector((0,4,0))),
                      ('side', Vector((4,0,0))), ('three-quarter', Vector((3,-4,0)))]:
    camera.location = center + offset * max(size)
    camera.rotation_euler = (center-camera.location).to_track_quat('-Z','Y').to_euler()
    image = output / (label + '.png')
    scene.render.filepath = str(image)
    bpy.ops.render.render(write_still=True)
    captures.append({'view': label, 'file': str(image), 'sha256': sha(image)})
if args.textured:
    # Framing only; never selects or changes mesh vertices.
    face_center = Vector((0,center.y,low.z+size.z*.89))
    camera_data.ortho_scale = size.z*.25
    camera.location = face_center + Vector((0,-4,0))*max(size)
    camera.rotation_euler = (face_center-camera.location).to_track_quat('-Z','Y').to_euler()
    image = output/'face.png'
    scene.render.filepath = str(image)
    bpy.ops.render.render(write_still=True)
    captures.append({'view':'face','file':str(image),'sha256':sha(image)})
blend = output / 'intake-source.blend'
bpy.ops.wm.save_as_mainfile(filepath=str(blend))
report = {'status': 'CAPTURED_PENDING_VISUAL_REVIEW', 'source_sha256': before,
          'source_unchanged': sha(source) == before, 'meshes': stats,
          'bounds_min': list(low), 'bounds_max': list(high),
          'normalization_applied': False, 'bone_or_vertex_edits': False,
          'rigs': [obj.name for obj in scene.objects if obj.type == 'ARMATURE'],
          'blend_sha256': sha(blend), 'captures': captures,
          'runtime_accepted': False, 'scope': 'Original source geometry intake; no rig/motion/face acceptance'}
(output/'intake.json').write_text(json.dumps(report, indent=2)+'\n', encoding='utf-8')
if not report['source_unchanged']:
    raise RuntimeError('Source changed')
print('VARIANT_GEOMETRY_INTAKE', json.dumps(stats))

import argparse
import hashlib
import json
import sys
from pathlib import Path

import bpy
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
from golden_reference import guard_output, verify
from native_timing import read_native_fps

parser = argparse.ArgumentParser()
parser.add_argument('--source', type=Path, required=True)
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:])
source = args.source.resolve()
output = args.output.resolve()
guard_output(output)
verify()
source_hash = hashlib.sha256(source.read_bytes()).hexdigest()
output.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=str(source), use_anim=True)
rigs = [obj for obj in bpy.context.scene.objects if obj.type == 'ARMATURE']
assert len(rigs) == 1
rig = rigs[0]
action = rig.animation_data.action
first, last = action.frame_range
scene = bpy.context.scene
fps = scene.render.fps / scene.render.fps_base
native = read_native_fps(source)
assert fps == native['native_fps']
meshes = [obj for obj in scene.objects if obj.type == 'MESH']
assert meshes, 'Source mesh required for a rendered skin review'
samples = []
points = []
for frame in range(int(first), int(last) + 1):
    scene.frame_set(frame)
    bpy.context.view_layer.update()
    joints = {bone.name: list((rig.matrix_world @ bone.matrix).translation) for bone in rig.pose.bones}
    samples.append({'frame': frame, 'time': (frame - first) / fps, 'joints': joints})
    graph = bpy.context.evaluated_depsgraph_get()
    points.extend(obj.matrix_world @ Vector(corner) for obj in meshes for corner in obj.evaluated_get(graph).bound_box)
low = Vector(tuple(min(point[axis] for point in points) for axis in range(3)))
high = Vector(tuple(max(point[axis] for point in points) for axis in range(3)))
center = (low + high) * 0.5
scene.render.engine = 'BLENDER_WORKBENCH'
scene.display.shading.light = 'STUDIO'
scene.display.shading.color_type = 'TEXTURE'
scene.display.shading.show_shadows = True
scene.display.shading.show_cavity = True
scene.display.shading.background_type = 'WORLD'
scene.world = bpy.data.worlds.new('SourceReviewWorld')
scene.world.color = (0.045, 0.055, 0.075)
scene.render.resolution_x = 480
scene.render.resolution_y = 640
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = 'PNG'
camera_data = bpy.data.cameras.new('SourceReviewCamera')
camera = bpy.data.objects.new('SourceReviewCamera', camera_data)
scene.collection.objects.link(camera)
scene.camera = camera
camera_data.type = 'ORTHO'
camera_data.ortho_scale = max((high.z - low.z) * 1.2, (high.x - low.x) * 1.6, (high.y - low.y) * 1.6)
captures = []
frames = sorted({round(first + (last - first) * fraction / 5) for fraction in range(6)})
for frame in frames:
    scene.frame_set(frame)
    for view, offset in [('front', (0, -4, 0)), ('side', (4, 0, 0))]:
        camera.location = center + Vector(offset)
        camera.rotation_euler = (center - camera.location).to_track_quat('-Z', 'Y').to_euler()
        image_path = output / f'{frame:04d}-{view}.png'
        scene.render.filepath = str(image_path)
        bpy.ops.render.render(write_still=True)
        captures.append({'frame': frame, 'view': view, 'path': str(image_path), 'sha256': hashlib.sha256(image_path.read_bytes()).hexdigest()})
assert hashlib.sha256(source.read_bytes()).hexdigest() == source_hash
report = {'status': 'CAPTURED_PENDING_REVIEW', 'source': str(source), 'source_sha256': source_hash,
          'action': action.name, 'rig': rig.name, 'native_timing': native, 'fps': fps,
          'frame_range': [first, last], 'duration': (last - first) / fps,
          'samples': samples, 'captures': captures, 'source_keys_changed': False}
(output / 'source-render.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
verify()
print('SOURCE_RENDER_CAPTURED', len(captures), source_hash, flush=True)

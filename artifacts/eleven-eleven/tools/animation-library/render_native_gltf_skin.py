"""Review original glTF skin at its measured native times, without source writes.

Requires inspect_native_gltf_motion.py's independent raw joint samples. The
Blender importer must match those samples before any source skin is rendered.
"""
import argparse
import hashlib
import json
from pathlib import Path
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
from golden_reference import verify, guard_output

p = argparse.ArgumentParser()
p.add_argument('--reference', type=Path, required=True)
p.add_argument('--output', type=Path, required=True)
a = p.parse_args(sys.argv[sys.argv.index('--') + 1:])
a.output = a.output.resolve()
reference = json.loads(a.reference.read_text(encoding='utf-8'))
source = Path(reference['source'])
digest = hashlib.sha256(source.read_bytes()).hexdigest()
assert digest == reference['source_sha256']
guard_output(a.output)
verify()
a.output.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.render.fps = reference['fps']
bpy.ops.import_scene.gltf(filepath=str(source))
rigs = [o for o in scene.objects if o.type == 'ARMATURE']
assert len(rigs) == 1, 'Ambiguous source rig'
rig = rigs[0]
action = rig.animation_data.action
assert action, 'No imported authored action'
meshes = [o for o in scene.objects if o.type == 'MESH']
assert meshes, 'Source skin is required'
maximum = 0.0
comparisons = 0
bounds = []
for sample in reference['frames']:
    clock = sample['time'] * reference['fps']
    whole = int(clock + 1e-5)
    scene.frame_set(whole, subframe=max(0.0, clock - whole))
    bpy.context.view_layer.update()
    for name, point in sample['points'].items():
        if name not in rig.pose.bones:
            continue
        expected = Vector((point[0], -point[2], point[1]))
        actual = (rig.matrix_world @ rig.pose.bones[name].matrix).translation
        maximum = max(maximum, (actual - expected).length)
        comparisons += 1
    graph = bpy.context.evaluated_depsgraph_get()
    bounds.extend(o.matrix_world @ Vector(c) for o in meshes for c in o.evaluated_get(graph).bound_box)
assert comparisons >= len(reference['frames']) * 20
assert maximum < .0001, f'Imported source differs from raw native joints: {maximum}'
low = Vector(tuple(min(v[i] for v in bounds) for i in range(3)))
high = Vector(tuple(max(v[i] for v in bounds) for i in range(3)))
center = (low + high) * .5
scene.render.engine = 'BLENDER_WORKBENCH'
scene.display.shading.light = 'STUDIO'
scene.display.shading.color_type = 'TEXTURE'
scene.display.shading.show_shadows = True
scene.display.shading.show_cavity = True
scene.world = bpy.data.worlds.new('OriginalMotionReview')
scene.world.color = (.045, .055, .075)
scene.render.resolution_x = 480
scene.render.resolution_y = 640
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = 'PNG'
data = bpy.data.cameras.new('SourceReviewCamera')
camera = bpy.data.objects.new('SourceReviewCamera', data)
scene.collection.objects.link(camera)
scene.camera = camera
data.type = 'ORTHO'
data.ortho_scale = max((high.z-low.z)*1.2, (high.x-low.x)*1.6, (high.y-low.y)*1.6)
captures = []
for index in sorted({round((len(reference['frames'])-1)*i/6) for i in range(7)}):
    clock = reference['frames'][index]['time'] * reference['fps']
    whole = int(clock + 1e-5)
    scene.frame_set(whole, subframe=max(0.0, clock-whole))
    for view, offset in [('front', (0, -4, 0)), ('side', (4, 0, 0))]:
        camera.location = center + Vector(offset)
        camera.rotation_euler = (center-camera.location).to_track_quat('-Z', 'Y').to_euler()
        path = a.output / f'{index:04d}-{view}.png'
        scene.render.filepath = str(path)
        bpy.ops.render.render(write_still=True)
        captures.append({'sample': index, 'time': reference['frames'][index]['time'], 'view': view, 'path': str(path), 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()})
blend = a.output / 'original-source.blend'
bpy.ops.wm.save_as_mainfile(filepath=str(blend))
result = {'status': 'CAPTURED_PENDING_VISUAL_REVIEW', 'source_sha256': digest,
          'native_joint_comparisons': comparisons, 'maximum_import_error_m': maximum,
          'fps': reference['fps'], 'sample_count': len(reference['frames']),
          'source_keys_changed': False, 'blend_sha256': hashlib.sha256(blend.read_bytes()).hexdigest(),
          'captures': captures}
(a.output/'source-skin-review.json').write_text(json.dumps(result, indent=2)+'\n', encoding='utf-8')
assert hashlib.sha256(source.read_bytes()).hexdigest() == digest
verify()
print('ORIGINAL_GLTF_SKIN_CAPTURED', comparisons, maximum, flush=True)

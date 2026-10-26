"""Isolated native-pose geometry/texture review; never saves or changes input keys."""
import argparse
import hashlib
import json
import sys
from pathlib import Path
import bpy
from mathutils import Vector

APP = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(APP / 'tools/animation-library'))
from golden_reference import verify, guard_output

parser = argparse.ArgumentParser()
parser.add_argument('--case', type=Path, required=True)
parser.add_argument('--include-endpoint', action='store_true')
args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:])
case = args.case.resolve()
guard_output(case)
verify()
sha = lambda path: hashlib.sha256(Path(path).read_bytes()).hexdigest()
report = json.loads((case / 'blender-reference.json').read_text(encoding='utf-8'))
assert report['status'] == 'PASS'
for path, digest in report['hashes'].items():
    assert sha(path) == digest
source = case / 'single-motion.blend'
source_sha = sha(source)
bpy.ops.wm.open_mainfile(filepath=str(source))
target = bpy.data.objects[report['target_rig']]
meshes = [ob for ob in bpy.context.scene.objects if ob.type == 'MESH' and any(mod.type == 'ARMATURE' and mod.object == target for mod in ob.modifiers)]
assert meshes
for ob in bpy.context.scene.objects:
    if ob.type == 'MESH':
        ob.hide_render = ob not in meshes
        ob.hide_viewport = ob not in meshes
for ob in meshes:
    assert all(mod.type != 'ARMATURE' or mod.object == target for mod in ob.modifiers)
scene = bpy.context.scene
scene.render.engine = 'BLENDER_WORKBENCH'
scene.display.shading.light = 'STUDIO'
scene.display.shading.color_type = 'TEXTURE'
scene.display.shading.show_shadows = True
scene.display.shading.show_cavity = True
scene.display.shading.background_type = 'WORLD'
if scene.world is None:
    scene.world = bpy.data.worlds.new('IsolatedReviewWorld')
scene.world.color = (.045, .055, .075)
scene.render.resolution_x = 640
scene.render.resolution_y = 800
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = 'PNG'
camera_data = bpy.data.cameras.new('IsolatedReviewCamera')
camera = bpy.data.objects.new('IsolatedReviewCamera', camera_data)
scene.collection.objects.link(camera)
scene.camera = camera
camera_data.type = 'ORTHO'
out = case / 'blender-captures'
out.mkdir(exist_ok=True)
count = len(report['samples'])
frames = sorted(set([0, round((count-1)*.25), round((count-1)*.5), round((count-1)*.75)]))
if args.include_endpoint:
    frames = sorted(set(frames + [count - 1]))
captures = []
for frame in frames:
    scene.frame_set(frame)
    bpy.context.view_layer.update()
    graph = bpy.context.evaluated_depsgraph_get()
    points = [ob.matrix_world @ Vector(corner) for ob in meshes for corner in ob.evaluated_get(graph).bound_box]
    low = Vector(tuple(min(point[axis] for point in points) for axis in range(3)))
    high = Vector(tuple(max(point[axis] for point in points) for axis in range(3)))
    center = (low + high) * .5
    camera_data.ortho_scale = max((high.z-low.z)*1.18, (high.x-low.x)*1.5, (high.y-low.y)*1.5)
    for view, offset in [('front',(0,-3,0)), ('side',(3,0,0)), ('rear',(0,3,0))]:
        camera.location = center + Vector(offset)
        camera.rotation_euler = (center-camera.location).to_track_quat('-Z','Y').to_euler()
        path = out / f'{frame:04d}-{view}.png'
        scene.render.filepath = str(path)
        bpy.ops.render.render(write_still=True)
        captures.append({'frame':frame, 'source_frame':frame+1, 'view':view, 'path':str(path), 'sha256':sha(path)})
assert sha(source) == source_sha
manifest = {'status':'CAPTURED_PENDING_VISUAL_REVIEW', 'blend_sha256':source_sha, 'take_id':report['take_id'], 'captures':captures, 'scope':'Workbench texture/geometry inspection; shared Godot renderer and actual movement require their own review.', 'source_keys_changed':False}
(out / 'capture-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
verify()
print('V31_LOCOMOTION_CAPTURED', len(captures), source_sha, flush=True)

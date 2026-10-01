"""Render imported character evidence without modifying the delivered asset."""
import argparse
import json
import sys
from pathlib import Path
import bpy
from mathutils import Vector

p = argparse.ArgumentParser()
p.add_argument('--input', required=True)
p.add_argument('--output', required=True)
p.add_argument('--clip')
p.add_argument('--verify-only', action='store_true')
a = p.parse_args(sys.argv[sys.argv.index('--') + 1:])
out = Path(a.output).resolve()
out.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(Path(a.input).resolve()))
arm = next(o for o in bpy.context.scene.objects if o.type == 'ARMATURE')
arm.animation_data_clear()
for pb in arm.pose.bones:
    pb.matrix_basis.identity()
bpy.context.view_layer.update()
if a.clip:
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    from validate_character_glb import validate_animated_pose
    action = next(action for action in bpy.data.actions if action.name.upper().split('|')[-1] == a.clip.upper())
    validate_animated_pose(arm, action)
    bpy.context.scene.frame_set(1)
    bpy.context.view_layer.update()
    print('ANIMATION_SEMANTIC_PASS=' + a.clip)
if a.verify_only:
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    from validate_character_glb import validate_animated_pose
    for action in bpy.data.actions:
        validate_animated_pose(arm, action)
        print('ANIMATION_SEMANTIC_PASS=' + action.name)
    raise SystemExit(0)
meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
coords = []
for obj in meshes:
    evaluated = obj.evaluated_get(bpy.context.evaluated_depsgraph_get())
    mesh = evaluated.to_mesh()
    coords.extend(evaluated.matrix_world @ v.co for v in mesh.vertices)
    evaluated.to_mesh_clear()
lo = Vector([min(v[i] for v in coords) for i in range(3)])
hi = Vector([max(v[i] for v in coords) for i in range(3)])
center = (lo + hi) / 2
scene = bpy.context.scene
scene.world = bpy.data.worlds.new('ReviewWorld')
scene.world.use_nodes = True
scene.world.node_tree.nodes['Background'].inputs['Color'].default_value = (0.15,0.15,0.15,1)
scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value = 0.6
for pos, power in [((2,-3,4),500),((-2,-1,2),300),((0,2,3),400)]:
    bpy.ops.object.light_add(type='AREA', location=pos)
    light = bpy.context.object
    light.data.energy = power
    light.data.shape='DISK'
    light.data.size=3
    light.rotation_euler=(center-light.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add()
cam=bpy.context.object
scene.camera=cam
cam.data.type='ORTHO'
cam.data.ortho_scale=max(hi.z-lo.z,hi.x-lo.x)*1.2
scene.render.engine='CYCLES'
scene.cycles.samples=8
scene.cycles.use_denoising=True
scene.render.resolution_x=600
scene.render.resolution_y=700
scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'
views = [('front',(0,-5,0)),('back',(0,5,0))]
if a.clip:
    views = [('pose-'+str(f),(2,-5,0)) for f in (1,8,16,24,31)]
for label, offset in views:
    if a.clip:
        bpy.context.scene.frame_set(int(label.split('-')[1]))
    cam.location=center+Vector(offset)
    cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath=str(out/(label+'.png'))
    bpy.ops.render.render(write_still=True)
print('REVIEW_BOUNDS',list(lo),list(hi))
print('REVIEW_BONES',json.dumps({b.name:{'head':list(arm.matrix_world @ b.head_local),'matrix':[list(r) for r in b.matrix_local]} for b in arm.data.bones if b.name in ['neck','thigh.L','upper_arm.L','shin.L']}))

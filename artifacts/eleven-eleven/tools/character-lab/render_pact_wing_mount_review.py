"""Actual full-body and mounting close-ups of the bounded wing candidate."""
from pathlib import Path
import bpy,sys,json,math,hashlib
from mathutils import Vector,Quaternion
case=Path(sys.argv[sys.argv.index('--')+1]).resolve();out=case/'wing-mount-review';out.mkdir(exist_ok=True)
ref=json.loads((case/'blender-reference.json').read_text());bpy.ops.wm.open_mainfile(filepath=str(case/'single-motion.blend'))
rig=bpy.data.objects[ref['target_rig']];root=rig.pose.bones['WingRootLeft'];source=bpy.data.objects[ref['source_rig']]
meshes=[o for o in bpy.context.scene.objects if o.type=='MESH' and any(m.type=='ARMATURE' and m.object==rig for m in o.modifiers)]
for o in bpy.context.scene.objects:
 if o.type=='MESH':o.hide_render=o not in meshes
scene=bpy.context.scene;scene.world=bpy.data.worlds.new('DiagnosticWorld');scene.render.engine='BLENDER_WORKBENCH';scene.display.shading.light='STUDIO';scene.display.shading.color_type='MATERIAL';scene.display.shading.show_shadows=True;scene.display.shading.show_cavity=True;scene.display.shading.background_type='WORLD';scene.world.color=(.045,.055,.07)
scene.render.resolution_x=960;scene.render.resolution_y=720;scene.render.resolution_percentage=100;scene.render.image_settings.file_format='PNG'
bpy.ops.object.camera_add();camera=bpy.context.object;camera.data.type='ORTHO';scene.camera=camera
basis=(rig.matrix_world@root.bone.matrix_local).to_quaternion().inverted();rows=[]
for f in [28,34,36,40]:
 scene.frame_set(f);root.rotation_mode='QUATERNION';root.rotation_quaternion=Quaternion(basis@Vector((0,0,1)),math.radians(45))@Quaternion(basis@Vector((1,0,0)),math.radians(45));bpy.context.view_layer.update()
 center=rig.matrix_world@root.matrix.translation
 for name,direction in [('front',Vector((0,-1,.12))),('back',Vector((0,1,.12))),('side',Vector((1,0,.12)))]:
  camera.data.ortho_scale=.64;camera.location=center+direction*2;camera.rotation_euler=(center-camera.location).to_track_quat('-Z','Y').to_euler();scene.render.filepath=str(out/f'{f:03}-{name}.png');bpy.ops.render.render(write_still=True);rows.append(scene.render.filepath)
 if f in [34,40]:
  points=[]
  for m in meshes:
   e=m.evaluated_get(bpy.context.evaluated_depsgraph_get());points.extend(e.matrix_world@Vector(c) for c in e.bound_box)
  low=Vector(tuple(min(p[a] for p in points) for a in range(3)));high=Vector(tuple(max(p[a] for p in points) for a in range(3)));center=(low+high)/2
  camera.data.ortho_scale=max(high.z-low.z+.3,high.x-low.x+.3)*1.4;camera.location=center+Vector((0,-5,0));camera.rotation_euler=(center-camera.location).to_track_quat('-Z','Y').to_euler();scene.render.filepath=str(out/f'{f:03}-whole.png');bpy.ops.render.render(write_still=True);rows.append(scene.render.filepath)
(out/'capture-manifest.json').write_text(json.dumps({'status':'CAPTURED_PENDING_ACTUAL_REVIEW','source_blend_sha256':hashlib.sha256((case/'single-motion.blend').read_bytes()).hexdigest(),'candidate':'WingRoot local rotation:character-world Z45 thenX45;body/source keys unchanged','captures':{p:hashlib.sha256(Path(p).read_bytes()).hexdigest() for p in rows}},indent=2)+'\n')

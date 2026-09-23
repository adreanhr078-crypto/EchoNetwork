import bpy,math
from pathlib import Path
from mathutils import Matrix,Vector,Quaternion
root=Path(r'C:\Users\yasmo\EchoNetwork\artifacts\eleven-eleven')
bpy.ops.wm.open_mainfile(filepath=str(root/'art/production/echo-opening-uniform-reference/echo-opening-uniform-v6.blend'))
scene=bpy.context.scene;rig=bpy.data.objects['EchoOpeningUniformRig']
for t in rig.animation_data.nla_tracks:t.mute=True
action=bpy.data.actions['preset:walk'];rig.animation_data.action=action
if action.slots:rig.animation_data.action_slot=action.slots[0]
legs=[f'tripo::1_{side}_Limb_{i}' for side in ['Left','Right'] for i in range(4)]
for layer in action.layers:
 for strip in layer.strips:
  for bag in strip.channelbags:
   for fc in list(bag.fcurves):
    if any(f'pose.bones["{name}"]' in fc.data_path for name in legs):bag.fcurves.remove(fc)
for fr in range(1,58):
 scene.frame_set(fr)
 phase=2*math.pi*(fr-1)/28
 swing=math.sin(phase)
 for side,sign in [('Left',1.0),('Right',-1.0)]:
  for index in range(4):
   name=f'tripo::1_{side}_Limb_{index}';bone=rig.pose.bones[name]
   bone.rotation_mode='QUATERNION';bone.matrix_basis=Matrix.Identity(4)
   bone.keyframe_insert(data_path='location',frame=fr,group=name)
   bone.keyframe_insert(data_path='rotation_quaternion',frame=fr,group=name)
   bone.keyframe_insert(data_path='scale',frame=fr,group=name)
  hip=rig.pose.bones[f'tripo::1_{side}_Limb_0']
  knee=rig.pose.bones[f'tripo::1_{side}_Limb_1']
  foot=rig.pose.bones[f'tripo::1_{side}_Limb_2']
  local_swing=swing*sign
  hip.rotation_quaternion=Quaternion((1,0,0),0.38*local_swing)
  hip.keyframe_insert(data_path='rotation_quaternion',frame=fr,group=hip.name)
  knee.rotation_quaternion=Quaternion((1,0,0),0.42*max(0.0,local_swing))
  knee.keyframe_insert(data_path='rotation_quaternion',frame=fr,group=knee.name)
  foot.rotation_quaternion=Quaternion((1,0,0),-0.12*local_swing-0.12*max(0.0,local_swing))
  foot.keyframe_insert(data_path='rotation_quaternion',frame=fr,group=foot.name)
for layer in action.layers:
 for strip in layer.strips:
  for bag in strip.channelbags:
   for fc in bag.fcurves:
    if any(f'pose.bones["{name}"]' in fc.data_path for name in legs):
     for kp in fc.keyframe_points:kp.interpolation='BEZIER'
     fc.update()
rig.animation_data.action=None
for t in rig.animation_data.nla_tracks:t.mute=False
for obj in scene.objects:obj.select_set(False)
rig.select_set(True);body=bpy.data.objects['EchoOpeningUniformBody'];body.select_set(True);bpy.context.view_layer.objects.active=rig
blend=root/'art/production/echo-opening-uniform-reference/echo-opening-uniform-v7.blend'
out=root/'godot/assets/characters/echo_opening_uniform_v7.glb'
bpy.ops.wm.save_as_mainfile(filepath=str(blend))
bpy.ops.export_scene.gltf(filepath=str(out),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='NLA_TRACKS',export_skins=True,export_image_format='JPEG',export_keep_originals=False,export_materials='EXPORT',export_apply=False)
print('OUTPUT',out,'WALK_FRAMES',action.frame_range)

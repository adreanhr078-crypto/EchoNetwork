import bpy
from pathlib import Path
from mathutils import Matrix,Quaternion
root=Path(r'C:\Users\yasmo\EchoNetwork\artifacts\eleven-eleven')
bpy.ops.wm.open_mainfile(filepath=str(root/'art/production/echo-opening-uniform-reference/echo-opening-uniform-v4.blend'))
scene=bpy.context.scene;rig=bpy.data.objects['EchoOpeningUniformRig']
for t in rig.animation_data.nla_tracks:t.mute=True
action=bpy.data.actions['preset:idle'];rig.animation_data.action=action
if action.slots:rig.animation_data.action_slot=action.slots[0]
leg_names=[f'tripo::1_{side}_Limb_{i}' for side in ['Left','Right'] for i in range(4)]
for layer in action.layers:
 for strip in layer.strips:
  for bag in strip.channelbags:
   for fc in list(bag.fcurves):
    if any(f'pose.bones["{name}"]' in fc.data_path for name in leg_names):bag.fcurves.remove(fc)
frames=range(151,341)
for fr in frames:
 scene.frame_set(fr)
 for name in leg_names:
  bone=rig.pose.bones[name]
  bone.matrix_basis=Matrix.Identity(4)
  bone.keyframe_insert(data_path='location',frame=fr,group=name)
  bone.keyframe_insert(data_path='rotation_quaternion',frame=fr,group=name)
  bone.keyframe_insert(data_path='scale',frame=fr,group=name)
print('REST_LEG_KEYS',len(frames),leg_names)
rig.animation_data.action=None
for t in rig.animation_data.nla_tracks:t.mute=False
for obj in scene.objects:obj.select_set(False)
rig.select_set(True);body=bpy.data.objects['EchoOpeningUniformBody'];body.select_set(True);bpy.context.view_layer.objects.active=rig
blend=root/'art/production/echo-opening-uniform-reference/echo-opening-uniform-v6.blend'
out=root/'godot/assets/characters/echo_opening_uniform_v6.glb'
bpy.ops.wm.save_as_mainfile(filepath=str(blend))
bpy.ops.export_scene.gltf(filepath=str(out),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='NLA_TRACKS',export_skins=True,export_image_format='JPEG',export_keep_originals=False,export_materials='EXPORT',export_apply=False)
print('OUTPUT',out)

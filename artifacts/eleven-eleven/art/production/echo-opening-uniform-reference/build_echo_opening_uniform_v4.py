import bpy
from pathlib import Path
from mathutils import Matrix
root=Path(r'C:\Users\yasmo\EchoNetwork\artifacts\eleven-eleven')
bpy.ops.wm.open_mainfile(filepath=str(root/'art/production/echo-opening-uniform-reference/echo-opening-uniform-v3.blend'))
rig=bpy.data.objects['EchoOpeningUniformRig']
for track in rig.animation_data.nla_tracks: track.mute=True
names=['preset:idle','preset:walk','preset:run','preset:jump','preset:turn','preset:fall']
rot=Matrix.Rotation(3.141592653589793,4,'Z')
for name in names:
 action=bpy.data.actions[name]
 rig.animation_data.action=action
 if action.slots: rig.animation_data.action_slot=action.slots[0]
 start=int(action.frame_range[0]);end=int(action.frame_range[1])
 original={}
 for frame in range(start,end+1):
  bpy.context.scene.frame_set(frame)
  for side in ['Left','Right']:
   bone=rig.pose.bones[f'tripo::1_{side}_Limb_3']
   original[(frame,side)]=bone.matrix.copy()
 for frame in range(start,end+1):
  bpy.context.scene.frame_set(frame)
  for side in ['Left','Right']:
   bone=rig.pose.bones[f'tripo::1_{side}_Limb_3']
   mat=original[(frame,side)]
   pivot=Matrix.Translation(mat.translation)
   bone.matrix=pivot@rot@pivot.inverted()@mat
   bone.keyframe_insert(data_path='rotation_quaternion',frame=frame,group=bone.name)
 print('CORRECTED',name,start,end)
 rig.animation_data.action=None
for track in rig.animation_data.nla_tracks: track.mute=False
for obj in bpy.context.scene.objects: obj.select_set(False)
rig.select_set(True)
body=bpy.data.objects['EchoOpeningUniformBody'];body.select_set(True)
bpy.context.view_layer.objects.active=rig
blend=root/'art/production/echo-opening-uniform-reference/echo-opening-uniform-v4.blend'
out=root/'godot/assets/characters/echo_opening_uniform_v4.glb'
bpy.ops.wm.save_as_mainfile(filepath=str(blend))
bpy.ops.export_scene.gltf(filepath=str(out),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='NLA_TRACKS',export_skins=True,export_image_format='JPEG',export_keep_originals=False,export_materials='EXPORT',export_apply=False)
print('OUTPUT',out)

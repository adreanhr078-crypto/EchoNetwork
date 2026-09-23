import bpy
from pathlib import Path
root=Path(r'C:\Users\yasmo\EchoNetwork\artifacts\eleven-eleven')
bpy.ops.wm.open_mainfile(filepath=str(root/'art/production/echo-opening-uniform-reference/echo-opening-uniform-v2.blend'))
rig=bpy.data.objects['EchoOpeningUniformRig']
track=next(t for t in rig.animation_data.nla_tracks if t.name=='preset:idle')
strip=track.strips[0]
strip.action_frame_start=151
strip.action_frame_end=340
strip.frame_start=1
strip.frame_end=190
for obj in bpy.context.scene.objects: obj.select_set(False)
rig.select_set(True)
body=bpy.data.objects['EchoOpeningUniformBody']
body.select_set(True)
bpy.context.view_layer.objects.active=rig
blend=root/'art/production/echo-opening-uniform-reference/echo-opening-uniform-v3.blend'
out=root/'godot/assets/characters/echo_opening_uniform_v3.glb'
bpy.ops.wm.save_as_mainfile(filepath=str(blend))
bpy.ops.export_scene.gltf(filepath=str(out),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='NLA_TRACKS',export_skins=True,export_image_format='JPEG',export_keep_originals=False,export_materials='EXPORT',export_apply=False)
print('OUTPUT',out,'IDLE_RANGE',strip.action_frame_start,strip.action_frame_end)

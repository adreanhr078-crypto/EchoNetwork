import bpy
from pathlib import Path
root=Path(r'C:\Users\yasmo\EchoNetwork\artifacts\eleven-eleven')
bpy.ops.wm.open_mainfile(filepath=str(root/'art/production/echo-opening-uniform-reference/echo-opening-uniform-v1.blend'))
rig=bpy.data.objects['EchoOpeningUniformRig']
source=root/'art/production/tripo-out/echo-opening-uniform-phase1-moti-59a9fd4e/model.glb'
before=set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath=str(source))
imported=set(bpy.data.objects)-before
for name in ['preset:jump','preset:turn']:
    action=bpy.data.actions.get(name)
    if action is None: raise RuntimeError('Missing '+name)
    action.use_fake_user=True
    track=rig.animation_data.nla_tracks.new()
    track.name=name
    strip=track.strips.new(name,int(action.frame_range[0]),action)
    if hasattr(strip,'action_slot') and action.slots: strip.action_slot=action.slots[0]
for obj in imported:
    bpy.data.objects.remove(obj,do_unlink=True)
bpy.data.orphans_purge(do_recursive=True)
for obj in bpy.context.scene.objects: obj.select_set(False)
rig.select_set(True)
body=bpy.data.objects['EchoOpeningUniformBody']
body.select_set(True)
bpy.context.view_layer.objects.active=rig
blend=root/'art/production/echo-opening-uniform-reference/echo-opening-uniform-v2.blend'
out=root/'godot/assets/characters/echo_opening_uniform_v2.glb'
bpy.ops.wm.save_as_mainfile(filepath=str(blend))
bpy.ops.export_scene.gltf(filepath=str(out),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='NLA_TRACKS',export_skins=True,export_image_format='JPEG',export_keep_originals=False,export_materials='EXPORT',export_apply=False)
print('OUTPUT',out,'TRACKS',[t.name for t in rig.animation_data.nla_tracks])

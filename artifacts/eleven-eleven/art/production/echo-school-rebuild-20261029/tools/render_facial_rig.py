from pathlib import Path
import bpy,json
from mathutils import Vector
p=Path(__file__).resolve().parents[1];out=p/'facial';dest=out/'rig-review';dest.mkdir(exist_ok=True);bpy.ops.wm.open_mainfile(filepath=str(out/'echo-school-facial-rig.blend'))
scene=bpy.context.scene;scene.render.engine='BLENDER_WORKBENCH';scene.render.resolution_x=720;scene.render.resolution_y=900;scene.render.resolution_percentage=100;scene.display.shading.color_type='TEXTURE';scene.display.shading.show_cavity=False;scene.display.shading.show_shadows=False
if not scene.world:scene.world=bpy.data.worlds.new('FacialReviewWorld')
scene.world.color=(.04,.05,.065);data=bpy.data.cameras.new('FacialControlsReview');camera=bpy.data.objects.new('FacialControlsReview',data);scene.collection.objects.link(camera);scene.camera=camera;data.type='ORTHO';data.ortho_scale=.31;camera.location=(0,-3,1.589);camera.rotation_euler=(Vector((-.003,0,1.589))-camera.location).to_track_quat('-Z','Y').to_euler()
for f in [1,73,97,121,169,240]:
 scene.frame_set(f);scene.render.filepath=str(dest/f'capture-{f:03}.png');bpy.ops.render.render(write_still=True)
for obj in scene.objects:
 if obj.type=='MESH' and obj.data.shape_keys:obj.data.shape_keys.animation_data_clear()
for label,values in [('neutral',{}),('jaw-open',{'Jaw_Open':1}),('blink',{'Blink_L':1,'Blink_R':1}),('laugh-peak',{'Jaw_Open':.85,'Smile_L':.85,'Smile_R':.85,'Cheek_Raise_L':.3,'Cheek_Raise_R':.3,'Blink_L':.15,'Blink_R':.15}),('pupil-dilate',{'Pupil_Dilate_L':1,'Pupil_Dilate_R':1})]:
 scene.frame_set(1)
 for obj in scene.objects:
  if obj.type=='MESH' and obj.data.shape_keys:
   for key in obj.data.shape_keys.key_blocks:
    if key.name!='Basis':key.value=values.get(key.name,0)
 scene.render.filepath=str(dest/(label+'.png'));bpy.ops.render.render(write_still=True)
print('FACIAL_RIG_REVIEW_RENDERED')

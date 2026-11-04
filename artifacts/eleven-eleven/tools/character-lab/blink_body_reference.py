"""Read qualified body actions into the isolated blink;never rewrite their keys."""
import hashlib,json
from pathlib import Path
import bpy
from mathutils import Vector

APP=Path(__file__).resolve().parents[2];prod=APP/'art/production/echo-school-rebuild-20261029';case=prod/'face/blink-retopology-20261102'
sha=lambda path:hashlib.sha256(path.read_bytes()).hexdigest()
rest=json.loads((case/'blender-skin-reference.json').read_text());report=json.loads((case/'retopology-review.json').read_text())
assert sha(case/'connected-blink-research.blend')==rest['blend_sha256']==report['blend_sha256']
bpy.ops.wm.open_mainfile(filepath=str(case/'connected-blink-research.blend'))
obj=next(item for item in bpy.context.scene.objects if item.type=='MESH');rig=next(item for item in bpy.context.scene.objects if item.type=='ARMATURE')
blink=obj.data.shape_keys.key_blocks['blink'];selected=rest['sampled_original_vertex_indices'];scene=bpy.context.scene
rig.animation_data_create()
for track in rig.animation_data.nla_tracks:track.mute=True
def convert(point):return [float(point.x),float(point.z),float(-point.y)]
frames=[];motions={};captures=[]
camera=scene.camera;camera.data.ortho_scale=.17;face_center=Vector((-.003,-.05,1.597))
head=rig.data.bones['mixamorig:Head'];rest_head=rig.matrix_world@head.matrix_local
for slug in ['walk','jump','wake-studio-20261102']:
    motion=prod/'motions'/slug;body=json.loads((motion/'blender-reference.json').read_text());action_name=body['action']
    with bpy.data.libraries.load(str(motion/'single-motion.blend'),link=False) as (available,requested):
        assert action_name in available.actions;requested.actions=[action_name]
    action=requested.actions[0];rig.animation_data.action=action
    if action.is_action_layered:
        assert len(action.slots)==1;rig.animation_data.action_slot=action.slots[0]
    fps=float(body['fps']);count=len(body['samples']);scene.render.fps=round(fps)
    library='wake' if slug.startswith('wake-') else slug
    motions[slug]={'action':action_name,'source_blend':str(motion/'single-motion.blend'),'source_blend_sha256':sha(motion/'single-motion.blend'),
                   'library':str(APP/f'godot/assets/animations/school65/{library}_qualified.res'),
                   'library_sha256':sha(APP/f'godot/assets/animations/school65/{library}_qualified.res'),'fps':fps,'samples':count}
    for index in sorted({0,round((count-1)*.5),count-1}):
        scene.frame_set(index);bpy.context.view_layer.update()
        for value in [0,1]:
            blink.value=value;bpy.context.view_layer.update()
            evaluated=obj.evaluated_get(bpy.context.evaluated_depsgraph_get());mesh=evaluated.to_mesh()
            frames.append({'motion':slug,'action':action_name,'frame':index,'time':index/fps,'blink':value,
                           'positions':[convert(obj.matrix_world@mesh.vertices[vertex].co) for vertex in selected],
                           'bones':{bone.name.replace(':','_'):convert((rig.matrix_world@bone.matrix).translation) for bone in rig.pose.bones}})
            evaluated.to_mesh_clear()
            head_motion=(rig.matrix_world@rig.pose.bones['mixamorig:Head'].matrix)@rest_head.inverted()
            center=head_motion@face_center;camera.location=center+head_motion.to_3x3()@Vector((0,-3,0))
            camera.rotation_euler=(center-camera.location).to_track_quat('-Z','Y').to_euler()
            path=case/f'blender-body-{library}-{index:03d}-{value}.png';scene.render.filepath=str(path);bpy.ops.render.render(write_still=True)
            captures.append({'path':path.name,'sha256':sha(path)})
data={**{key:rest[key] for key in ['blend_sha256','export_glb_sha256','sampled_original_vertex_indices','moving_sample_count','static_sample_count','moving_flags','bones']},
      'status':'EVALUATED_BLENDER_BODY_PLUS_BLINK_REFERENCE','rest_positions':rest['frames'][0]['positions'],'frames':frames,'motions':motions,'captures':captures,
      'scope':'Qualified source actions read unchanged;manual native0/mid/last clocks;one blink0/1. No source key/rest/weight orruntime writes.'}
(case/'blender-body-reference.json').write_text(json.dumps(data,indent=2)+'\n');print('BLINK_BODY_REFERENCE',len(frames),len(selected),list(motions))

"""Author contact-based traversal clips on Echo's own skeleton, not guessed FBX maps.
Editable IK source is saved before baking; original character GLB is preserved.
"""
import bpy, math, json, sys
from pathlib import Path
from mathutils import Vector, Quaternion
source, blend, export, audit=map(Path,sys.argv[sys.argv.index('--')+1:])
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(source.resolve()))
rig=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
rig.animation_data_clear()
rig.animation_data_create()
for o in bpy.context.scene.objects:
    if o!=rig and o.animation_data: o.animation_data_clear()
scene=bpy.context.scene
scene.render.fps=24
scene.frame_start,scene.frame_end=1,25
targets={}
for label,bone_name,pole in [
 ('RightWrist','tripo::0_Right_Limb_1',(-.18,.3,.65)),
 ('LeftWrist','tripo::0_Left_Limb_0',(-.18,-.3,.65)),
 ('RightAnkle','tripo::1_Right_Limb_1',(.7,.065,.65)),
 ('LeftAnkle','tripo::1_Left_Limb_1',(.7,-.065,.65))]:
    target=bpy.data.objects.new(label+'_contact',None); scene.collection.objects.link(target)
    guide=bpy.data.objects.new(label+'_pole',None); scene.collection.objects.link(guide); guide.location=pole
    ik=rig.pose.bones[bone_name].constraints.new('IK')
    ik.name='AuthoredContact_'+label; ik.target=target; ik.chain_count=2; ik.use_stretch=False
    ik.pole_target=guide; ik.pole_angle=math.pi/2
    targets[label]=target
for label,bone in [('RightWrist','tripo::0_Right_Limb_2'),('LeftWrist','tripo::0_Left_Limb_1'),('RightAnkle','tripo::1_Right_Limb_2'),('LeftAnkle','tripo::1_Left_Limb_2')]:
    guide=bpy.data.objects.new(label+'_finger_contact',None); scene.collection.objects.link(guide)
    track=rig.pose.bones[bone].constraints.new('DAMPED_TRACK'); track.target=guide; track.track_axis='TRACK_Y'
    targets[label+('Toe' if 'Ankle' in label else 'Finger')]=guide
clips=[]
for clip in ['PARKOUR_HANG','PARKOUR_CLIMB','PARKOUR_MANTLE']:
    for target in targets.values(): target.animation_data_clear()
    for bone in rig.pose.bones:
        bone.matrix_basis.identity()
    rig.animation_data.action=None
    for frame in range(1,26):
        phase=2*math.pi*(frame-1)/24
        lean=math.radians(32)*math.sin(math.pi*(frame-1)/24) if clip=='PARKOUR_MANTLE' else math.radians(8)
        for bone_name,factor in [('tripo::Spine_0',.6),('tripo::Spine_1',.4)]:
            bone=rig.pose.bones[bone_name]; bone.rotation_mode='QUATERNION'
            bone.rotation_quaternion=Quaternion((0,1,0),lean*factor)
            bone.keyframe_insert(data_path='rotation_quaternion',frame=frame)
        for side,sign in [('Right',1),('Left',-1)]:
            hand_z=.80 if clip=='PARKOUR_HANG' else .85+.08*math.cos(phase+(0 if sign==1 else math.pi))
            contact_phase=((frame-1)/24+(0 if sign==1 else .5))%1
            # Stance lowers the contact at the motor's measured speed;
            # the shorter swing returns it to the next grip, with zero seam.
            stride=contact_phase/.7 if contact_phase<.7 else 1-((contact_phase-.7)/.3)**2*(3-2*((contact_phase-.7)/.3))
            if clip=='PARKOUR_CLIMB': hand_z=.9-.22*stride
            wrist=targets[side+'Wrist']; wrist.location=(.22,sign*.15,hand_z)
            finger=targets[side+'WristFinger']; finger.location=(.23,sign*.15,hand_z+.045)
            foot=targets[side+'Ankle']
            foot.location=(.09,sign*.065,.18 if clip=='PARKOUR_HANG' else .22+.08*math.cos(phase+(math.pi if sign==1 else 0)))
            if clip=='PARKOUR_CLIMB': foot.location.z=.30-.22*stride
            if clip=='PARKOUR_MANTLE':
                # Match the motor's measured 1.56m raise then .85m forward sweep.
                # Hands hold the lip during the push, then release to the rest pose.
                t=(frame-1)/24
                fold=.65*math.sin(math.pi*t)
                raised=(min(1,t/.65)*1.56-fold)/1.81
                forward=max(0,min(1,(t-.65)/.35))*.85/1.81
                release=max(0,min(1,(t-.80)/.20))
                contact=Vector((.22-forward,sign*.15,.83-raised))
                rest=Vector((.016,sign*.193,.518))
                wrist.location=contact.lerp(rest,release)
                finger.location=wrist.location+Vector((.04,0,-.03 if release>.5 else .045))
                # Ankle lift is separate from the body's offset: copying the
                # whole offset raised both ankles above the hips and splayed knees.
                foot.location=(.09*(1-t)-.04*math.sin(math.pi*t),sign*.065,.18*(1-t)+.18*math.sin(math.pi*t))
            toe=targets[side+'AnkleToe']; toe.location=foot.location+Vector((.12,0,0))
            for target in [wrist,finger,foot,toe]: target.keyframe_insert(data_path='location',frame=frame)
    for target in targets.values():
        if target.animation_data: target.animation_data.action.name=clip+'_'+target.name
    rig.animation_data.action.name='PoseDriver_'+clip
    scene.frame_set(1)
    # The original leg rest axes have different roll. A shared guessed pole
    # angle twists knees/feet; solve each chain against its anatomical plane.
    for side,sign,bone_name in [('Right',1,'tripo::1_Right_Limb_1'),('Left',-1,'tripo::1_Left_Limb_1')]:
        bone=rig.pose.bones[bone_name]
        constraint=next(c for c in bone.constraints if c.type=='IK')
        candidates=[]
        for i in range(72):
            angle=-math.pi+2*math.pi*i/72
            constraint.pole_angle=angle; bpy.context.view_layer.update()
            knee=rig.matrix_world @ bone.head
            # Favor a knee facing the wall, in the hip/ankle sagittal plane.
            score=8*(knee.y-sign*.065)**2+(knee.x-(.10 if clip=='PARKOUR_MANTLE' else .24))**2
            candidates.append((score,angle))
        constraint.pole_angle=min(candidates)[1]
    bpy.context.view_layer.objects.active=rig
    bpy.ops.object.select_all(action='DESELECT'); rig.select_set(True)
    bpy.ops.object.mode_set(mode='POSE')
    bpy.ops.nla.bake(frame_start=1,frame_end=25,step=1,only_selected=False,visual_keying=True,clear_constraints=False,clear_parents=False,use_current_action=False,bake_types={'POSE'})
    bpy.ops.object.mode_set(mode='OBJECT')
    action=rig.animation_data.action; action.name=clip
    clips.append(action)
    track=rig.animation_data.nla_tracks.new(); track.name=clip
    strip=track.strips.new(clip,1,action); track.mute=True
    rig.animation_data.action=None
    rig.animation_data.nla_tracks[-1].mute=True

# Save editable IK + targets and actions, then export a clean baked derivative.
blend.parent.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=str(blend.resolve()))
for b in rig.pose.bones:
    for constraint in list(b.constraints): b.constraints.remove(constraint)
for o in list(scene.objects):
    if o.type=='EMPTY' and ('_contact' in o.name or '_pole' in o.name): bpy.data.objects.remove(o,do_unlink=True)
for track in rig.animation_data.nla_tracks: track.mute=False
rig.animation_data.action=clips[0]
for action in list(bpy.data.actions):
    if action.name.startswith('PoseDriver_'): bpy.data.actions.remove(action)
scene.frame_set(1)
export.parent.mkdir(parents=True,exist_ok=True)
bpy.ops.export_scene.gltf(filepath=str(export.resolve()),export_format='GLB',export_animations=True,export_animation_mode='ACTIONS',export_cameras=False,export_lights=False)
metrics={'source':source.name,'rig':rig.name,'fps':24,'clips':[a.name for a in clips],'frames':[1,25],'method':'IK authored and visually baked on original rest rig; requires Godot contact/visual acceptance','bytes':export.stat().st_size,'originalSourceModified':False}
audit.write_text(json.dumps(metrics,indent=2)+'\n',encoding='utf-8')
print(json.dumps(metrics))

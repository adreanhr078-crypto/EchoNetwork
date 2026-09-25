import bpy, os, json
from mathutils import Vector
base=r'C:\Users\yasmo\EchoNetwork\artifacts\eleven-eleven\art\production\rokoko-idle-source\unpacked\EVERYDAY-IDLES-MOCAP'
files=[os.path.join(base,x) for x in sorted(os.listdir(base)) if x.lower().endswith('.fbx')]
jointnames=['Head','Neck','Spine','Spine1','Spine2','LeftShoulder','RightShoulder','LeftArm','RightArm','LeftForeArm','RightForeArm','LeftHand','RightHand','LeftUpLeg','RightUpLeg','LeftLeg','RightLeg','LeftFoot','RightFoot']
out=[]
for fp in files:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=fp,use_anim=True)
    arm=next(o for o in bpy.data.objects if o.type=='ARMATURE')
    act=arm.animation_data.action
    f0,f1=act.frame_range
    samples=[]
    for f in range(max(1,int(f0)),int(f1)+1,3):
        bpy.context.scene.frame_set(f)
        pose=[]
        for n in jointnames:
            pb=arm.pose.bones.get('mixamorig:'+n)
            if pb:
                v=arm.matrix_world@pb.head
                pose.extend([round(x,4) for x in v])
        samples.append({'f':f,'v':pose})
    out.append({'name':os.path.basename(fp),'n':len(samples),'names':jointnames,'samples':samples})
op=os.path.join(os.path.dirname(base),'idle_loop_scan.json')
with open(op,'w') as h:json.dump(out,h)
print('SAVED',op)

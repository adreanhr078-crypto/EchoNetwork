import bpy, json, os, math
from mathutils import Vector
base = r'C:\Users\yasmo\EchoNetwork\artifacts\eleven-eleven\art\production\rokoko-idle-source\unpacked\EVERYDAY-IDLES-MOCAP'
files = [os.path.join(base,x) for x in sorted(os.listdir(base)) if x.lower().endswith('.fbx')]
rows=[]
for fp in files:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=fp, use_anim=True)
    arms=[o for o in bpy.data.objects if o.type=='ARMATURE']
    acts=list(bpy.data.actions)
    scene=bpy.context.scene
    arm=arms[0] if arms else None
    act=arm.animation_data.action if arm and arm.animation_data else None
    if act is None and acts: act=acts[0]
    if act: arm.animation_data_create(); arm.animation_data.action=act
    bones=sorted([b.name for b in arm.data.bones]) if arm else []
    if act:
        f0,f1=act.frame_range
        fs=[int(f0),int((f0+f1)/2),int(f1)]
        snapshots=[]
        for f in fs:
            scene.frame_set(f)
            names=[x for x in bones if any(y in x.lower() for y in ('hips','spine','head','leftfoot','rightfoot','lefthand','righthand'))]
            P={}
            for n in names:
                pb=arm.pose.bones[n]
                h=arm.matrix_world@pb.head; t=arm.matrix_world@pb.tail
                P[n]={'head':[round(x,3) for x in h], 'tail':[round(x,3) for x in t], 'rot':[round(x,3) for x in pb.matrix.to_quaternion()]}
            snapshots.append(P)
        shared=set(snapshots[0]) & set(snapshots[-1]); deltas={n:round((Vector(snapshots[-1][n]['head'])-Vector(snapshots[0][n]['head'])).length,3) for n in shared}
    else: f0=f1=0; snapshots=[]; deltas={}
    rows.append({'file':os.path.basename(fp),'armature':arm.name if arm else None,'bone_count':len(bones),'bones':bones,'actions':[{'name':a.name,'range':list(a.frame_range)} for a in acts], 'frame_range':[f0,f1], 'fps':scene.render.fps/scene.render.fps_base,'object_scale':list(arm.scale) if arm else [],'head_loop_deltas':deltas,'samples':snapshots})
out=os.path.join(os.path.dirname(base),'idle_inspection.json')
with open(out,'w',encoding='utf-8') as h: json.dump(rows,h,indent=2)
print('INSPECTED',len(rows),'SAVED',out)

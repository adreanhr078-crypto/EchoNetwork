"""Owner-authorized, isolated v13 target diagnosis; never changes the avatar.

Geometric left/right is established from Z-up and measured toe-forward, not
Tripo's labels. Root is the existing translation controller at the floor; it
is explicitly NOT an anatomical pelvis. Only visual/contact gates can accept
a transfer that uses this controller. This profile is not canonical approval.
"""
import hashlib
import json
import sys
from pathlib import Path

import bpy
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
from golden_reference import APP, verify, guard_output

TARGET = APP / 'godot/assets/characters/echo_opening_uniform_v13.glb'
OUTPUT = APP / 'audits/evidence/quality-execution-20261006/current-target'
PROFILE = OUTPUT / 'profile.json'
ROLES = {
    'hips': 'tripo::Root',
    'spine': 'tripo::Spine_0', 'spine1': 'tripo::Spine_1', 'spine2': 'tripo::Spine_2',
    'neck': 'tripo::Head_0', 'head': 'tripo::Head_1',
    'leftshoulder': 'bone_6', 'leftarm': 'tripo::0_Right_Limb_0',
    'leftforearm': 'tripo::0_Right_Limb_1', 'lefthand': 'tripo::0_Right_Limb_2',
    'rightshoulder': 'tripo::Spine_3', 'rightarm': 'tripo::Spine_4',
    'rightforearm': 'tripo::0_Left_Limb_0', 'righthand': 'tripo::0_Left_Limb_1',
    'leftupleg': 'tripo::1_Right_Limb_0', 'leftleg': 'tripo::1_Right_Limb_1',
    'leftfoot': 'tripo::1_Right_Limb_2', 'lefttoebase': 'tripo::1_Right_Limb_3',
    'rightupleg': 'tripo::1_Left_Limb_0', 'rightleg': 'tripo::1_Left_Limb_1',
    'rightfoot': 'tripo::1_Left_Limb_2', 'righttoebase': 'tripo::1_Left_Limb_3',
}


def load_mapping(names):
    """Use the measured map only for the exact inspected target identity."""
    profile = json.loads(PROFILE.read_text(encoding='utf-8'))
    if profile['status'] != 'MEASURED_PROFILE_VISUAL_GATE_OPEN':
        raise ValueError('Current target measurement missing')
    if hashlib.sha256(TARGET.read_bytes()).hexdigest() != profile['target_sha256']:
        raise ValueError('Current target identity changed')
    if set(names) != set(profile['mapping'].values()):
        raise ValueError('Profile cannot be used on a different rig')
    return profile['mapping']


def main():
    verify()
    guard_output(OUTPUT)
    digest = hashlib.sha256(TARGET.read_bytes()).hexdigest()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(TARGET))
    rigs = [o for o in bpy.context.scene.objects if o.type == 'ARMATURE']
    if len(rigs) != 1:
        raise ValueError('Expected one current armature')
    rig = rigs[0]
    if set(rig.data.bones.keys()) != set(ROLES.values()):
        raise ValueError('Measured profile must account for all 22 bones')
    world = {k: rig.matrix_world @ rig.data.bones[n].matrix_local for k, n in ROLES.items()}
    forward = sum((world[s+'toebase'].translation-world[s+'foot'].translation for s in ['left','right']), Vector())
    forward.z = 0
    forward.normalize()
    left = Vector((0,0,1)).cross(forward).normalized()
    center = (world['leftupleg'].translation+world['rightupleg'].translation)*.5
    evidence = []
    for side, sign in [('left',1),('right',-1)]:
        for joint in ['shoulder','arm','forearm','hand','upleg','leg','foot','toebase']:
            role = side+joint
            lateral = (world[role].translation-center).dot(left)
            if sign*lateral < .015:
                raise ValueError('Measured anatomical side mismatch: '+role)
            evidence.append({'role':role,'bone':ROLES[role],'lateral_m':lateral})
        for a,b in [('upleg','leg'),('leg','foot'),('shoulder','arm'),('arm','forearm'),('forearm','hand')]:
            if world[side+a].translation.z <= world[side+b].translation.z:
                raise ValueError('Anatomical segment order mismatch')
        for chain in [('upleg','leg','foot','toebase'),('shoulder','arm','forearm','hand')]:
            for parent,child in zip(chain,chain[1:]):
                if rig.data.bones[ROLES[side+child]].parent.name != ROLES[side+parent]:
                    raise ValueError('Measured hierarchy mismatch')
    OUTPUT.mkdir(parents=True,exist_ok=True)
    data = {
        'status':'MEASURED_PROFILE_VISUAL_GATE_OPEN',
        'owner_scope':'2026-10-06 explicit isolated current-avatar profile; integrate only after numerical and visual gates',
        'target_file':str(TARGET),'target_sha256':digest,'mapping':ROLES,
        'front_blender':list(forward),'anatomical_left_blender':list(left),
        'side_evidence':evidence,
        'translation_anchor':{'bone':ROLES['hips'],'world_origin':list(world['hips'].translation),
            'anatomical_pelvis_origin':False,'measured_thigh_center':list(center),
            'risk':'Existing floor-root controller differs from source pelvic pivot. Preserve Golden math, reject anatomical/contact failure; no fitted offset or source correction.'},
        'bones':{role:{'name':name,'parent':rig.data.bones[name].parent.name if rig.data.bones[name].parent else None,
            'world_rest':[list(row) for row in world[role]],'length_m':rig.data.bones[name].length} for role,name in ROLES.items()},
        'source_keys_changed':False,'target_mesh_rest_changed':False,'golden_changed':False,'runtime_integrated':False,
    }
    PROFILE.write_text(json.dumps(data,indent=2)+'\n',encoding='utf-8')
    if hashlib.sha256(TARGET.read_bytes()).hexdigest()!=digest:
        raise ValueError('Original avatar changed during measurement')
    verify()
    print('CURRENT_TARGET_PROFILE '+json.dumps({'bones':len(ROLES),'side_checks':len(evidence),'status':data['status'],'floor_root_risk':True}))


if __name__=='__main__': main()

"""Read-only Blender diagnosis: current runtime and frozen Golden target identity."""
import bpy,hashlib,json,sys
from pathlib import Path
from mathutils import Vector
sys.path.insert(0,str(Path(__file__).resolve().parent))
from golden_reference import APP,verify
from retarget_contract import joint_map

verify()
records=[]
paths=[APP/'godot/assets/characters/echo_opening_uniform_v13.glb',APP/'art/production/echo-master-character/prepared-v1/echo-master-review-lod.glb']
for path in paths:
    before=hashlib.sha256(path.read_bytes()).hexdigest()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(path))
    rigs=[obj for obj in bpy.context.scene.objects if obj.type=='ARMATURE']
    if len(rigs)!=1:raise ValueError('Expected one original armature')
    rig=rigs[0]
    mapping=joint_map(rig.data.bones.keys())
    rest={bone.name:[[float(v) for v in row] for row in rig.matrix_world@bone.matrix_local] for bone in rig.data.bones}
    if 'leftfoot' in mapping and 'rightfoot' in mapping:
        feet=[(mapping[side+'foot'],mapping[side+'toebase']) for side in ['left','right']]
    else:
        feet=[('tripo__1_'+side+'_Limb_2','tripo__1_'+side+'_Limb_3') for side in ['Left','Right']]
    original_names={name.replace(':','_'):name for name in rig.data.bones.keys()}
    front=Vector()
    for foot,toe in feet:
        foot=original_names.get(foot,foot)
        toe=original_names.get(toe,toe)
        front+=(rig.matrix_world@rig.data.bones[toe].matrix_local).translation-(rig.matrix_world@rig.data.bones[foot].matrix_local).translation
    front.z=0
    front.normalize()
    godot_front=[front.x,front.z,-front.y]
    after=hashlib.sha256(path.read_bytes()).hexdigest()
    if before!=after:raise ValueError('Original asset changed during inspection')
    records.append({'file':str(path),'sha256':before,'bone_count':len(rig.data.bones),'semantic_mapping':mapping,'unmapped_primary_roles':sorted({'hips','leftupleg','rightupleg','leftfoot','rightfoot','head'}-mapping.keys()),'world_rest_matrices':rest,'front_blender':list(front),'front_godot':godot_front,'armature_world_matrix':[[float(v) for v in row] for row in rig.matrix_world]})
out=APP/'audits/evidence/quality-repair-20261006/avatar-facing/blender-rig-diagnosis.json'
out.write_text(json.dumps({'status':'DIAGNOSED_DISTINCT_TARGET_RIGS','source_keys_edited':False,'rebaked':False,'scene_saved':False,'runtime_replaced':False,'records':records},indent=2),encoding='utf-8')
verify()
print('RUNTIME_RIG_INSPECTION '+json.dumps([{k:r[k] for k in ['bone_count','unmapped_primary_roles','front_godot']} for r in records]))

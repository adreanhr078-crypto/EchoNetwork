"""Owner-authorized isolated reference-pose rig; originals remain frozen.

This authors a derivative bind/reference pose, never source motion keys. Run
inspect first. Golden transfer math remains unchanged in the motion adapter.
"""
import argparse
import hashlib
import json
import math
import sys
from array import array
from pathlib import Path

import bpy
from mathutils import Matrix, Quaternion, Vector

HERE = Path(__file__).resolve().parent
sys.path.insert(0,str(HERE))
from golden_reference import APP, verify, guard_output
from current_target_profile import ROLES as ORIGINAL_ROLES, TARGET as ORIGINAL

OUTPUT = APP/'audits/evidence/quality-execution-20261006/current-target/reference-pose-v1'
TARGET = OUTPUT/'echo-v13-measured-reference.glb'
PROFILE = OUTPUT/'profile.json'
ROLES = dict(ORIGINAL_ROLES,hips='EchoMeasuredPelvis')
EXPECTED = set(ROLES.values())|{'tripo::Root'}
CASE = OUTPUT.parent/'run-attempt-01'

def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()

def load_mapping(names):
    profile = json.loads(PROFILE.read_text(encoding='utf-8'))
    if set(names)!=EXPECTED or sha(TARGET)!=profile['target_sha256']:
        raise ValueError('Derived target identity changed')
    return ROLES.copy()

def write(path,data): path.write_text(json.dumps(data,indent=2)+'\n',encoding='utf-8')

def main():
    global OUTPUT,TARGET,PROFILE
    parser=argparse.ArgumentParser()
    parser.add_argument('--mode',choices=['inspect','build'],required=True)
    parser.add_argument('--revision',choices=['v1','v2'],default='v1')
    args=parser.parse_args(sys.argv[sys.argv.index('--')+1:])
    if args.revision=='v2':
        OUTPUT=OUTPUT.with_name('reference-pose-v2')
        TARGET=OUTPUT/'echo-v13-measured-reference.glb'
        PROFILE=OUTPUT/'profile.json'
    verify();guard_output(OUTPUT)
    OUTPUT.mkdir(parents=True,exist_ok=True)
    original_digest=sha(ORIGINAL)
    diagnosis=json.loads((CASE/'diagnosis.json').read_text(encoding='utf-8'))
    for path,digest in diagnosis['hashes'].items():
        if sha(Path(path))!=digest: raise ValueError('Inspected input changed')
    bpy.ops.wm.open_mainfile(filepath=str(CASE/'source-inspection.blend'))
    source=bpy.data.objects[diagnosis['source_rig']]
    target=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE' and o!=source)
    if set(target.data.bones.keys())!=set(ORIGINAL_ROLES.values()):
        raise ValueError('Unexpected original rig')
    target.animation_data_clear()
    for bone in target.pose.bones: bone.matrix_basis=Matrix.Identity(4)
    bpy.context.view_layer.update()
    source_hashes={str(Path(p)):digest for p,digest in diagnosis['hashes'].items()}
    mapping=diagnosis['mapping_and_local_axes']
    aligned=Quaternion((0,0,1),math.radians(diagnosis['alignment_yaw_degrees']))
    source_rest={k:source.matrix_world @ source.data.bones[v['source']].matrix_local for k,v in mapping.items()}
    old_rest={k:target.matrix_world @ target.data.bones[n].matrix_local for k,n in ORIGINAL_ROLES.items()}
    desired={n:target.matrix_world @ b.matrix_local for n,b in target.data.bones.items()}
    meshes=[o for o in bpy.context.scene.objects if o.type=='MESH' and any(m.type=='ARMATURE' and m.object==target for m in o.modifiers)]
    hand_evidence=[]
    segments=[]
    for side in ['left','right']:
        for parent,child in [('shoulder','arm'),('arm','forearm'),('forearm','hand')]:
            a,b=side+parent,side+child
            src=(aligned @ (source_rest[b].translation-source_rest[a].translation)).normalized()
            original=old_rest[b].translation-old_rest[a].translation
            delta=original.normalized().rotation_difference(src)
            parent_name,child_name=ORIGINAL_ROLES[a],ORIGINAL_ROLES[b]
            head=desired[parent_name].translation.copy()
            rotation=delta @ old_rest[a].to_quaternion()
            desired[parent_name]=Matrix.LocRotScale(head,rotation,Vector((1,1,1)))
            desired[child_name].translation=head+src*original.length
            segments.append({'role':a,'original_segment':list(original),'reference_direction':list(src),'correction_degrees':math.degrees(delta.angle),'preserved_length_m':original.length})
        role=side+'hand';name=ORIGINAL_ROLES[role]
        # Preserve the native palm roll while aligning its terminal bone axis
        # to the actual source reference; no finger bones or motion are invented.
        original_axis=old_rest[role].to_quaternion() @ Vector((0,1,0))
        reference_axis=aligned @ (source_rest[role].to_quaternion() @ Vector((0,1,0)))
        if args.revision=='v2':
            # The imported terminal Hand Y axis points vertically in the
            # source T pose. Its actual Middle1 joint points out of the palm.
            # Use that anatomical landmark and the untouched rigid hand skin,
            # rather than interpreting an arbitrary terminal bone stub as a
            # finger direction. Preserve native roll via the minimal rotation.
            source_name=mapping[role]['source']
            landmark=source.data.bones.get(source_name+'Middle1')
            if landmark is None: raise ValueError('Source middle knuckle unavailable')
            reference_axis=aligned @ ((source.matrix_world @ landmark.matrix_local).translation-source_rest[role].translation).normalized()
            candidates=[]
            for mesh in meshes:
                group=mesh.vertex_groups.get(name)
                if group is None: continue
                candidates.extend(mesh.matrix_world @ mesh.data.shape_keys.key_blocks['Basis'].data[v.index].co if mesh.data.shape_keys else mesh.matrix_world @ v.co
                                  for v in mesh.data.vertices if any(g.group==group.index and g.weight>.99 for g in v.groups))
            if len(candidates)<100: raise ValueError('Insufficient measured rigid hand skin')
            wrist=old_rest[role].translation
            original_axis=(max(candidates,key=lambda p:(p-wrist).length)-wrist).normalized()
            hand_evidence.append({'role':role,'source_landmark':landmark.name,'original_skin_direction':list(original_axis),'source_palm_direction':list(reference_axis),'rigid_hand_vertices':len(candidates),'rejected_terminal_axis_angle_degrees':math.degrees(reference_axis.angle(aligned @ (source_rest[role].to_quaternion() @ Vector((0,1,0))))),'source_keys_changed':False})
        delta=original_axis.rotation_difference(reference_axis)
        desired[name]=Matrix.LocRotScale(desired[name].translation,delta @ old_rest[role].to_quaternion(),Vector((1,1,1)))
    pelvis=(old_rest['leftupleg'].translation+old_rest['rightupleg'].translation)*.5
    for mesh in meshes:
        if any(m.type!='ARMATURE' for m in mesh.modifiers): raise ValueError('Unexpected mesh modifier needs diagnosis')
    evidence={'status':'MEASURED_DERIVATIVE_PLAN','owner_authorized':True,'source_hashes':source_hashes,'original_avatar_sha256':original_digest,'floor_controller':ORIGINAL_ROLES['hips'],'measured_pelvis_world':list(pelvis),'segments':segments,'meshes':[{'name':m.name,'vertices':len(m.data.vertices),'shape_keys':list(m.data.shape_keys.key_blocks.keys()) if m.data.shape_keys else [],'root_weighted_vertices':sum(any(g.group==m.vertex_groups[ORIGINAL_ROLES['hips']].index and g.weight>0 for g in v.groups) for v in m.data.vertices) if ORIGINAL_ROLES['hips'] in m.vertex_groups else 0} for m in meshes],'plan':'Measured arm-reference pose from source rest directions with native lengths and palm roll. Add anatomical pelvis at existing thigh midpoint, retain original floor controller unchanged, reparent existing spine/leg roots preserving world rest, rename only existing floor-root skin group to pelvis with exact weights. Bake neutral reference deformation for all existing shape keys through Blender evaluation. No source curve, Golden or runtime edit.'}
    if args.mode=='inspect':
        evidence['revision']=args.revision
        evidence['hand_landmarks']=hand_evidence
        write(OUTPUT/'diagnosis.json',evidence)
        verify()
        print('MEASURED_REFERENCE_DIAGNOSIS '+json.dumps(evidence))
        return
    evidence['revision']=args.revision
    evidence['hand_landmarks']=hand_evidence
    inspected=json.loads((OUTPUT/'diagnosis.json').read_text(encoding='utf-8'))
    if inspected!=evidence: raise ValueError('Exact derivative inspection must precede build')
    # Evaluate a static measured pose through the original Blender skinning.
    # No action, keyframe or source curve is authored or edited.
    inverse=target.matrix_world.inverted()
    def depth(bone):
        value=0
        while bone.parent: value+=1;bone=bone.parent
        return value
    order=sorted(target.pose.bones,key=depth)
    for bone in order:
        bone.matrix=inverse @ desired[bone.name]
        bpy.context.view_layer.update()
    snapshots={}
    def evaluated_coordinates(obj):
        evaluated=obj.evaluated_get(bpy.context.evaluated_depsgraph_get())
        result=evaluated.to_mesh()
        if len(result.vertices)!=len(obj.data.vertices):
            raise ValueError('Reference deformation changed topology')
        values=array('f',[0.0])*(len(result.vertices)*3)
        result.vertices.foreach_get('co',values)
        normals=[tuple(n.vector) for n in result.corner_normals]
        evaluated.to_mesh_clear()
        if not all(math.isfinite(v) for v in values): raise ValueError('Nonfinite reference skin')
        return values,normals
    for mesh in meshes:
        keys=mesh.data.shape_keys
        if keys and keys.animation_data: keys.animation_data_clear()
        saved_values={k.name:k.value for k in keys.key_blocks if k.name!='Basis'} if keys else {}
        # The untouched v13 GLB imports all four facial defaults at 1.0.
        # Evaluate each basis/morph independently, then restore those exact
        # defaults; changing the default expression is outside this rebind.
        if not all(math.isfinite(value) for value in saved_values.values()):
            raise ValueError('Nonfinite original morph defaults')
        blocks={}
        for name in ['Basis']+list(saved_values):
            if keys:
                for key in keys.key_blocks:
                    if key.name!='Basis': key.value=1.0 if key.name==name else 0.0
            bpy.context.view_layer.update()
            blocks[name],normals=evaluated_coordinates(mesh)
            if name=='Basis': base_normals=normals
        if keys:
            for name,value in saved_values.items(): keys.key_blocks[name].value=value
        snapshots[mesh.name]={'coordinates':blocks,'normals':base_normals,'values':saved_values,
            'weights':[(v.index,tuple((g.group,g.weight) for g in v.groups)) for v in mesh.data.vertices]}
    # Author a real pelvic pivot at the measured thigh midpoint. The original
    # floor controller keeps its exact rest transform and remains the parent.
    bpy.ops.object.select_all(action='DESELECT')
    target.select_set(True);bpy.context.view_layer.objects.active=target
    lengths={b.name:b.length for b in target.data.bones}
    original_floor=target.data.bones[ORIGINAL_ROLES['hips']].matrix_local.copy()
    bpy.ops.object.mode_set(mode='EDIT')
    for name,matrix in desired.items():
        bone=target.data.edit_bones[name]
        bone.matrix=inverse @ matrix
        bone.length=lengths[name]
    hips=target.data.edit_bones.new(ROLES['hips'])
    hips.matrix=inverse @ Matrix.LocRotScale(pelvis,aligned @ source_rest['hips'].to_quaternion(),Vector((1,1,1)))
    hips.length=(old_rest['spine'].translation-pelvis).length
    hips.parent=target.data.edit_bones[ORIGINAL_ROLES['hips']]
    hips.use_connect=False
    for name in [ORIGINAL_ROLES[k] for k in ['spine','leftupleg','rightupleg']]:
        bone=target.data.edit_bones[name]
        original_matrix=bone.matrix.copy();original_length=bone.length
        bone.parent=hips;bone.use_connect=False
        bone.matrix=original_matrix;bone.length=original_length
    bpy.ops.object.mode_set(mode='OBJECT')
    for bone in target.pose.bones: bone.matrix_basis=Matrix.Identity(4)
    for mesh in meshes:
        snapshot=snapshots[mesh.name]
        mesh.data.vertices.foreach_set('co',snapshot['coordinates']['Basis'])
        if mesh.data.shape_keys:
            for name,coordinates in snapshot['coordinates'].items():
                mesh.data.shape_keys.key_blocks[name].data.foreach_set('co',coordinates)
        mesh.data.normals_split_custom_set(snapshot['normals'])
        if ORIGINAL_ROLES['hips'] in mesh.vertex_groups:
            mesh.vertex_groups[ORIGINAL_ROLES['hips']].name=ROLES['hips']
        current_weights=[(v.index,tuple((g.group,g.weight) for g in v.groups)) for v in mesh.data.vertices]
        if current_weights!=snapshot['weights']: raise ValueError('Skin weight values changed')
        mesh.data.update()
    bpy.context.view_layer.update()
    max_error=0.0
    for mesh in meshes:
        snapshot=snapshots[mesh.name];keys=mesh.data.shape_keys
        for name,expected in snapshot['coordinates'].items():
            if keys:
                for key in keys.key_blocks:
                    if key.name!='Basis': key.value=1.0 if key.name==name else 0.0
            bpy.context.view_layer.update()
            actual,_=evaluated_coordinates(mesh)
            for i in range(0,len(actual),3):
                error=math.sqrt(sum((actual[i+j]-expected[i+j])**2 for j in range(3)))
                max_error=max(max_error,error)
        if keys:
            for name,value in snapshot['values'].items(): keys.key_blocks[name].value=value
    if max_error>1e-5: raise ValueError('Reference rebind differs from measured posed skin: '+str(max_error))
    if max(abs(target.data.bones[ORIGINAL_ROLES['hips']].matrix_local[r][c]-original_floor[r][c]) for r in range(4) for c in range(4))>1e-6:
        raise ValueError('Original floor controller rest changed')
    bpy.context.view_layer.update()
    bpy.ops.wm.save_as_mainfile(filepath=str(OUTPUT/'measured-reference.blend'))
    bpy.ops.object.select_all(action='DESELECT')
    target.select_set(True)
    for mesh in meshes: mesh.select_set(True)
    bpy.context.view_layer.objects.active=target
    bpy.ops.export_scene.gltf(filepath=str(TARGET),export_format='GLB',use_selection=True,
        export_animations=False,export_skins=True,export_yup=True,export_apply=False)
    profile={'status':'DERIVED_REFERENCE_NUMERICAL_PASS_VISUAL_OPEN','target_sha256':sha(TARGET),'target_file':str(TARGET),'mapping':ROLES,'expected_bones':sorted(EXPECTED),'source_hashes':source_hashes,'original_avatar_sha256':original_digest,'floor_controller_preserved':True,'anatomical_pelvis':list(pelvis),'max_reference_rebind_error_m':max_error,'shape_keys_preserved':True,'morph_defaults':{name:snapshot['values'] for name,snapshot in snapshots.items()},'skin_weight_values_preserved':True,'root_skin_group_renamed_to_pelvis':True,'source_keys_changed':False,'golden_changed':False,'runtime_integrated':False,'blend_sha256':sha(OUTPUT/'measured-reference.blend')}
    write(PROFILE,profile)
    for path,digest in source_hashes.items():
        if sha(Path(path))!=digest: raise ValueError('Original changed during derivative build')
    verify()
    print('MEASURED_REFERENCE_BUILD '+json.dumps(profile))

if __name__=='__main__': main()

"""Read-only School65/Pact72 body-rest compatibility for an earned swap."""
from pathlib import Path
import hashlib,json,math,sys
import bpy
APP=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(APP/'tools/animation-library'))
from retarget_contract import joint_map
out=APP/'art/production/echo-contract-rebuild-20261101/work/runtime-bridge-20261103';out.mkdir(exist_ok=True)
paths={'school':APP/'art/production/echo-school-rebuild-20261029/source/echo-school-rig-metric.glb',
       'pact':APP/'art/production/echo-contract-rebuild-20261101/work/wing-rig-v2/contract-wing-metric.glb'}
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
inputs={name:sha(path) for name,path in paths.items()};cache=out/'body-rest-comparison.json'
if cache.exists():
 old=json.loads(cache.read_text())
 if old['input_hashes']==inputs and old['inspector_sha256']==sha(Path(__file__)):
  print('PACT_BODY_REST_CACHE_HIT',json.dumps(old['summary']));raise SystemExit(0)
bpy.ops.wm.read_factory_settings(use_empty=True)
data={}
for label,path in paths.items():
 before=set(bpy.context.scene.objects);bpy.ops.import_scene.gltf(filepath=str(path))
 rig=next(obj for obj in bpy.context.scene.objects if obj not in before and obj.type=='ARMATURE')
 roles=joint_map(rig.data.bones.keys())
 data[label]={'rig':rig,'roles':roles,'rest':{role:rig.matrix_world@rig.data.bones[name].matrix_local for role,name in roles.items()}}
common=set(data['school']['rest'])&set(data['pact']['rest']);rows={}
for role in sorted(common):
 first=data['school']['rest'][role];second=data['pact']['rest'][role]
 angle=math.degrees(first.to_quaternion().rotation_difference(second.to_quaternion()).angle)
 rows[role]={'position_error_m':(first.translation-second.translation).length,'rest_rotation_error_degrees':min(angle,360-angle),
             'school_bone':data['school']['roles'][role],'pact_bone':data['pact']['roles'][role]}
summary={'school_bones':len(data['school']['rig'].data.bones),'pact_bones':len(data['pact']['rig'].data.bones),'common_roles':len(common),
         'max_position_difference_m':max(row['position_error_m'] for row in rows.values()),'max_rotation_difference_degrees':max(row['rest_rotation_error_degrees'] for row in rows.values()),
         'direct_library_reuse_allowed':False}
report={'status':'MEASURED_BODY_REST_ONLY','input_hashes':inputs,'inspector_sha256':sha(Path(__file__)),'summary':summary,'roles':rows,
        'decision':'Body-rest compatibility must be established before reusing School65 libraries. Numerical smallness alone doesnot accept skin/contact/visuals/runtime. No geometry,weights,maps,sourcekeys orproduction writes.'}
cache.write_text(json.dumps(report,indent=2)+'\n');print('PACT_BODY_REST',json.dumps(summary))

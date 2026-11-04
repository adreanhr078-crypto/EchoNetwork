"""Native-clock glTF intake adapter; frozen evaluated transfer/rest/export stay intact.

The original glTF is read only. Explicit measured source roles replace only source
name resolution. Its 24 Hz clock is retained, including the pre-first-key clamp.
"""
from pathlib import Path
import hashlib,json,sys

app=Path(__file__).resolve().parents[2]
drivers=app/'tools/animation-library'
sys.path.insert(0,str(drivers))
from golden_reference import verify,assert_transfer_equal

args=sys.argv[sys.argv.index('--')+1:]
record_path=Path(args[args.index('--source-record')+1]).resolve()
record=json.loads(record_path.read_text(encoding='utf-8'))
raw=json.loads(Path(record['raw_reference']).read_text(encoding='utf-8'))
source=app/record['entry']['working_copy']
assert hashlib.sha256(source.read_bytes()).hexdigest()==raw['source_sha256']==record['entry']['sha256']
assert raw['fps']==record['candidate']['fps']==24 and raw['sample_count']==73
assert abs(raw['first_time']-1/24)<1e-6 and abs(raw['last_time']-73/24)<1e-6
verify()
profile=json.loads((app/'art/production/echo-school-rebuild-20261029/target-profile.json').read_text())
code=(drivers/'v31_parkour_motion.py').read_text(encoding='utf-8')
def replace_once(old,new):
    global code
    if code.count(old)!=1: raise ValueError('Upstream identity/clock adapter point changed: '+old)
    code=code.replace(old,new)
replace_once("target_path = app/'godot/assets/characters/echo_v31_adopted_high.glb'",
             "target_path = app/'art/production/echo-school-rebuild-20261029/source/echo-school-rig-metric.glb'")
replace_once("'e88bcc7b50258c8af84c6bacbc7b9f94437853263715f3f3f44fe79c7ffd8810'",repr(profile['target_sha256']))
replace_once("choices=['Hang','Climb','Mantle','Stand','Attack']","choices=['Wake']")
replace_once('from retarget_contract import joint_map, planar_yaw',
    '''from retarget_contract import joint_map as _standard_map, planar_yaw
def joint_map(names):
    names=list(names)
    if 'tripo::Spine_0' in names:
        assert all(name in names for name in _native_roles.values())
        return dict(_native_roles)
    return _standard_map(names)''')
replace_once('from native_timing import read_native_fps, validate_timing',
    '''def read_native_fps(path):
    assert Path(path).suffix.lower()=='.glb'
    return dict(_native_clock)
def validate_timing(fps,candidate,first,last,native):
    assert fps==candidate['fps']==native['native_fps']==24
    assert abs(first-1)<1e-4 and abs(last-73)<1e-4
    return native''')
replace_once('bpy.ops.import_scene.fbx(filepath=str(source_path), use_anim=True)',
             "bpy.context.scene.render.fps = 24\n    bpy.ops.import_scene.gltf(filepath=str(source_path))")
replace_once('source.animation_data.action = action',
    '''for track in source.animation_data.nla_tracks: track.mute=True
    source.animation_data.action = action
    if action.is_action_layered:
        assert len(action.slots)==1
        source.animation_data.action_slot=action.slots[0]''')
replace_once('count = int(last-first)+1','count = int(last)+1  # include original glTF time-zero clamp')
replace_once('duration = (count-1)/30','duration = (count-1)/fps')
replace_once('for frame in range(1,count+1):','for frame in range(count):')
replace_once('    # Evaluate the completed action afresh, not just assigned matrices.',
    '''    # Clock transport is outside the unchanged evaluated transfer body.
    for sample_index,sample in enumerate(measurements): sample['time']=sample_index/fps
    # Evaluate the completed action afresh, not just assigned matrices.''')
replace_once('bpy.context.scene.render.fps = 30','bpy.context.scene.render.fps = int(fps)')
replace_once("'duration':duration,'fps':30,'samples':measurements","'duration':duration,'fps':fps,'samples':measurements")
replace_once("app = Path(__file__).resolve().parents[2]",'app = Path('+repr(str(app))+')')
generated=app/'.tmp/echo-character-lab/native-gltf-school-driver.py'
generated.write_text(code,encoding='utf-8')
assert_transfer_equal(generated)
clock={'native_fps':24,'authored_samples':73,'evaluated_samples':74,'first_authored_time':raw['first_time'],
       'last_authored_time':raw['last_time'],'source':'Original accessor timestamps;no key changes;time0 evaluated by source pre-key clamp'}
namespace={'__name__':'__main__','__file__':str(generated),'_native_roles':record['source_roles'],'_native_clock':clock}
exec(compile(code,str(generated),'exec'),namespace)
case=Path(args[args.index('--output')+1])
(case/'native-adapter-provenance.json').write_text(json.dumps({
    'status':'SOURCE_CLOCK_ADAPTER','native_fps':24,'original_samples':73,'evaluations_including_time_zero':74,
    'source_sha256':raw['source_sha256'],'source_keys_changed':False,'evaluated_transfer_rest_and_export_ast':'EXACT_GOLDEN_MATCH',
    'generated_driver_sha256':hashlib.sha256(generated.read_bytes()).hexdigest(),'source_roles_sha256':hashlib.sha256(record_path.read_bytes()).hexdigest()},indent=2)+'\n')

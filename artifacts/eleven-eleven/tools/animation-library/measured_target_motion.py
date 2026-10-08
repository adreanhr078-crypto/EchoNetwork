"""Golden transfer for the explicitly authorized isolated reference-pose rig."""
import hashlib
import json
import sys
from pathlib import Path

HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE))
from golden_reference import verify,assert_transfer_equal
from measured_target_reference import PROFILE,TARGET

verify()
profile=json.loads(PROFILE.read_text(encoding='utf-8'))
if hashlib.sha256(TARGET.read_bytes()).hexdigest()!=profile['target_sha256']:
    raise ValueError('Measured reference identity changed')
code=(HERE/'single_motion.py').read_text(encoding='utf-8')
old_import='from retarget_contract import joint_map, planar_yaw'
new_import='''from retarget_contract import joint_map as _source_joint_map, planar_yaw
from measured_target_reference import load_mapping, EXPECTED

def joint_map(names):
    names=list(names)
    return load_mapping(names) if set(names)==EXPECTED else _source_joint_map(names)'''
old_target="target_path = app/'art/production/echo-master-character/prepared-v1/echo-master-review-lod.glb'"
new_target="target_path = app/'audits/evidence/quality-execution-20261006/current-target/reference-pose-v1/echo-v13-measured-reference.glb'"
if code.count(old_import)!=1 or code.count(old_target)!=1:
    raise ValueError('Frozen entry points changed; inspect first')
code=code.replace(old_import,new_import).replace(old_target,new_target)
driver=HERE/'measured_target_single_motion.py'
driver.write_text(code,encoding='utf-8')
assert_transfer_equal(driver)
exec(compile(code,str(driver),'exec'),{'__name__':'__main__','__file__':str(driver)})

"""Scoped target-profile entry point; frozen transfer math stays byte-derived.

Produces a separately inspectable driver beside this file. Neither the original
single_motion pipeline nor the accepted Golden files are edited. The Golden AST
guard validates every transfer/rest/alignment/export expression in the driver.
"""
from pathlib import Path
import hashlib
import json
import sys

HERE = Path(__file__).resolve().parent
sys.path.insert(0,str(HERE))
from golden_reference import verify, assert_transfer_equal
from current_target_profile import PROFILE, TARGET

verify()
profile = json.loads(PROFILE.read_text(encoding='utf-8'))
if hashlib.sha256(TARGET.read_bytes()).hexdigest()!=profile['target_sha256']:
    raise ValueError('Current profile identity changed')
original = HERE/'single_motion.py'
code = original.read_text(encoding='utf-8')
old_import = 'from retarget_contract import joint_map, planar_yaw'
new_import = '''from retarget_contract import joint_map as _source_joint_map, planar_yaw
from current_target_profile import load_mapping, ROLES
def joint_map(names):
    names = list(names)
    return load_mapping(names) if set(names) == set(ROLES.values()) else _source_joint_map(names)'''
old_target = "target_path = app/'art/production/echo-master-character/prepared-v1/echo-master-review-lod.glb'"
new_target = "target_path = app/'godot/assets/characters/echo_opening_uniform_v13.glb'"
if code.count(old_import)!=1 or code.count(old_target)!=1:
    raise ValueError('Upstream entry points changed; inspect before adaptation')
code = code.replace(old_import,new_import).replace(old_target,new_target)
driver = HERE/'current_target_single_motion.py'
driver.write_text(code,encoding='utf-8')
assert_transfer_equal(driver)
exec(compile(code,str(driver),'exec'),{'__name__':'__main__','__file__':str(driver)})

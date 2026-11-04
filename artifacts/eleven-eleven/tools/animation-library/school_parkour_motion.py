"""Qualify existing native parkour takes on school65 using the frozen transfer.

Only measured target identity changes from the existing V31 parkour driver.
No source clock, source key, rest-space transfer or exporter change is made.
"""
from pathlib import Path
import hashlib
import json
import sys

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from golden_reference import verify, assert_transfer_equal

app = HERE.parents[1]
profile = json.loads((app/'art/production/echo-school-rebuild-20261029/target-profile.json').read_text(encoding='utf-8'))
target = Path(profile['target_file'])
verify()
if hashlib.sha256(target.read_bytes()).hexdigest() != profile['target_sha256']:
    raise ValueError('School source identity changed')
code = (HERE/'v31_parkour_motion.py').read_text(encoding='utf-8')
old_target = "target_path = app/'godot/assets/characters/echo_v31_adopted_high.glb'"
new_target = "target_path = app/'art/production/echo-school-rebuild-20261029/source/echo-school-rig-metric.glb'"
old_hash = "'e88bcc7b50258c8af84c6bacbc7b9f94437853263715f3f3f44fe79c7ffd8810'"
if code.count(old_target) != 1 or code.count(old_hash) != 1:
    raise ValueError('Existing parkour driver entry points changed; inspect first')
code = code.replace(old_target,new_target).replace(old_hash,repr(profile['target_sha256']))
old_choices = "choices=['Hang','Climb','Mantle','Stand','Attack']"
if code.count(old_choices) != 1:
    raise ValueError('Existing action identity options changed')
code = code.replace(old_choices,"choices=['Hang','Climb','Mantle','Stand','Attack','Roll','Wake']")
driver = HERE/'school_parkour_single_motion.py'
driver.write_text(code,encoding='utf-8')
assert_transfer_equal(driver)
exec(compile(code,str(driver),'exec'),{'__name__':'__main__','__file__':str(driver)})

"""Owner-authorized school target;frozen transfer unchanged. Native Walk label is permitted."""
from pathlib import Path
import hashlib,json,sys
HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE))
from golden_reference import verify,assert_transfer_equal
APP=HERE.parents[1]
PROFILE=APP/"art/production/echo-school-rebuild-20261029/target-profile.json"
profile=json.loads(PROFILE.read_text(encoding="utf-8"))
target=Path(profile["target_file"])
verify()
if profile["status"]!="MEASURED_SCHOOL_TARGET_READY_MOTION_GATES_OPEN" or hashlib.sha256(target.read_bytes()).hexdigest()!=profile["target_sha256"]:raise ValueError("School target identity changed")
source=HERE/"single_motion.py";code=source.read_text(encoding="utf-8")
old="target_path = app/'art/production/echo-master-character/prepared-v1/echo-master-review-lod.glb'"
new="target_path = app/'art/production/echo-school-rebuild-20261029/source/echo-school-rig-metric.glb'"
if code.count(old)!=1:raise ValueError("Frozen entry point changed")
code=code.replace(old,new)
choices="choices=['Run','Idle','Jump','Landing']"
if code.count(choices)!=1:raise ValueError('Expected motion-label list changed')
code=code.replace(choices,"choices=['Run','Idle','Jump','Landing','Walk']")
driver=HERE/"school_target_single_motion.py";driver.write_text(code,encoding="utf-8")
assert_transfer_equal(driver)
exec(compile(code,str(driver),"exec"),{"__name__":"__main__","__file__":str(driver)})

"""Measured Pact72 target adapter around the frozen Golden transfer.

The body rest,weights,source clocks andkeys are not edited. The seven wing
bones remain at rest during body-source qualification.
"""
from pathlib import Path
import hashlib,json,sys
APP=Path(__file__).resolve().parents[2];DRIVERS=APP/'tools/animation-library'
sys.path.insert(0,str(DRIVERS))
from golden_reference import verify,assert_transfer_equal
args=sys.argv[sys.argv.index('--')+1:]
family=args[args.index('--family')+1]
if family not in ['locomotion','parkour']:raise ValueError('Explicit existing source family required')
slot=sys.argv.index('--family');del sys.argv[slot:slot+2]
target=APP/'art/production/echo-contract-rebuild-20261101/work/wing-rig-v2/contract-wing-metric.glb'
expected='747dd0eb7182736d2fd6624829d07603926390128b984350475336a41fde08e8'
assert hashlib.sha256(target.read_bytes()).hexdigest()==expected
verify()
source=DRIVERS/('single_motion.py' if family=='locomotion' else 'v31_parkour_motion.py')
code=source.read_text(encoding='utf-8')
def replace(old,new):
 global code
 if code.count(old)!=1:raise ValueError('Frozen adapter anchor changed:'+old)
 code=code.replace(old,new)
old="target_path = app/"+("'art/production/echo-master-character/prepared-v1/echo-master-review-lod.glb'" if family=='locomotion' else "'godot/assets/characters/echo_v31_adopted_high.glb'")
replace(old,"target_path = app/'art/production/echo-contract-rebuild-20261101/work/wing-rig-v2/contract-wing-metric.glb'")
if family=='parkour':
 replace("'e88bcc7b50258c8af84c6bacbc7b9f94437853263715f3f3f44fe79c7ffd8810'",repr(expected))
 replace(' + actual current Echo V31 68-joint runtime target',' + actual isolated Pact72 target')
 replace("choices=['Hang','Climb','Mantle','Stand','Attack']","choices=['Hang','Climb','Mantle','Stand','Attack','Roll']")
else:
 replace("choices=['Run','Idle','Jump','Landing']","choices=['Run','Idle','Jump','Landing','Walk']")
replace('app = Path(__file__).resolve().parents[2]','app = Path('+repr(str(APP))+')')
generated=APP/'.tmp/echo-character-lab'/('pact-'+family+'-frozen-driver.py')
generated.write_text(code,encoding='utf-8');assert_transfer_equal(generated)
case=Path(args[args.index('--output')+1]);case.mkdir(parents=True,exist_ok=True)
provenance={'status':'FROZEN_TRANSFER_TARGET_ADAPTER_ONLY','target_sha256':expected,'target_bones':72,'source_keys_changed':False,
 'family':family,'upstream_driver_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'generated_driver_sha256':hashlib.sha256(generated.read_bytes()).hexdigest(),
 'adapter_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'wing_bones':'Seven unmapped wing bones stay at target rest;body/wing contact is separate.'}
(case/'pact-target-provenance.json').write_text(json.dumps(provenance,indent=2)+'\n')
exec(compile(code,str(generated),'exec'),{'__name__':'__main__','__file__':str(generated)})

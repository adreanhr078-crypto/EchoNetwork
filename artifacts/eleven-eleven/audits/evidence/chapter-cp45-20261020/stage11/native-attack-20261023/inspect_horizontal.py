from pathlib import Path
import hashlib,json,sys
app=Path.cwd();sys.path.insert(0,str(app/'tools/animation-library'))
from inspect_sources import inspect_file
case=app/'audits/evidence/chapter-cp45-20261020/stage11/native-attack-20261023/horizontal';case.mkdir(exist_ok=True);poses=case/'poses';poses.mkdir(exist_ok=True)
source=app/'art/production/echo-attack-cp45-20261023/Standing Melee Attack Horizontal.fbx';digest=hashlib.sha256(source.read_bytes()).hexdigest()
d=inspect_file(source,digest,case,poses)
(case/'inspection.json').write_text(json.dumps(d,indent=2))
assert len(d['takes'])==1
candidate=dict(d['takes'][0],file_sha256=digest,original_filename=source.name)
record={'candidate':candidate,'entry':{'sha256':digest,'working_copy':str(source.relative_to(app)).replace('\\','/')}}
(case/'source-record.json').write_text(json.dumps(record,indent=2))
print(json.dumps(record))

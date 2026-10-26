import sys,json,hashlib
from pathlib import Path
app=Path.cwd()
sys.path.insert(0,str(app/'tools/animation-library'))
from inspect_sources import inspect_file
p=app/'art/production/echo-attack-cp45-20261021/Great Sword Slash.fbx'
out=app/'audits/evidence/chapter-cp45-20261020/stage11/slash-inspection'
out.mkdir(parents=True,exist_ok=True)
h=hashlib.sha256(p.read_bytes()).hexdigest()
r=inspect_file(p,h,out/'inspection.json',out)
(out/'inspection.json').write_text(json.dumps(r,indent=2))
c=r['takes'][0]
c.update(file_sha256=h,original_filename=p.name)
record={'candidate':c,'entry':{'sha256':h,'working_copy':str(p.relative_to(app)).replace('\\','/')},'origin':'Adobe Mixamo original source downloaded in prior authorized session;30FPS,no key reduction; settings proof retained','source_keys_changed':False,'runtime_integrated':False}
(out/'source-record.json').write_text(json.dumps(record,indent=2))
print(json.dumps({k:c[k] for k in ['take_id','source_frame_range','fps','rig_hash','source_take']}))

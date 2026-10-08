"""Measure authored action skin in the approved runtime rig; never modify source keys."""
import json
from pathlib import Path
import numpy as np
base=Path(__file__).resolve().parents[2]
folder=base/'audits/evidence/quality-repair-20261006/action-support'
data=json.loads((folder/'samples.json').read_text(encoding='utf-8'))
v=np.asarray(data['vertices'],dtype=np.float64)
w=np.asarray(data['weights'],dtype=np.float64)
b=np.asarray(data['bones'],dtype=np.int32)
def skin_min(m):
 matrices=np.asarray(m,dtype=np.float64)
 # Exact weighted deformation of every source skin vertex, in rig space.
 y=np.einsum('vik,vk->vi',matrices[b,1,:],v)
 return float(np.sum(y*w,axis=1).min())
rest=skin_min(data['rest'])
curves={}
for name,samples in data['clips'].items():
 values=[]
 for sample in samples:
  minimum=skin_min(sample['matrices'])
  delta=rest-minimum+0.002
  if name not in ['DODGE_ROLL','HARD_LANDING']: delta=max(0,delta)
  values.append({'time':sample['time'],'delta_y':delta,'unadjusted_min_y':minimum})
 curves[name]=values
 print(name,'samples',len(values),'max support correction (rig meters)',round(max(x['delta_y'] for x in values),4))
(folder/'curves.json').write_text(json.dumps({'rest_min_y':rest,'vertex_count':len(v),'curves':curves},indent=2),encoding='utf-8')

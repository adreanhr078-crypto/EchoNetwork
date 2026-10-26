"""Read-only source sampling for a bounded actual-skin garment collision cage.

The generated data refers to the exact adopted source hash and original bind
coordinates. It changes no weights, topology, source curves or body joints.
"""
import argparse
import hashlib
import json
from pathlib import Path
import numpy as np

p=argparse.ArgumentParser()
p.add_argument('--evidence',type=Path,required=True)
p.add_argument('--output',type=Path,required=True)
a=p.parse_args()
folder=a.evidence.resolve()
data=json.loads((folder/'skin-poses.json').read_text(encoding='utf-8'))
samples=[]
directions=np.array([(1,0,0),(-1,0,0),(0,1,0),(0,-1,0),(0,0,1),(0,0,-1),(1,0,1),(-1,0,1)],dtype=np.float32)
for surface in data['surfaces']:
    prefix=folder/surface['prefix']
    vertices=np.fromfile(str(prefix)+'-vertices.bin',dtype='<f4').reshape(-1,3)
    vertices=np.c_[vertices,np.ones(len(vertices),dtype=np.float32)]
    joints=np.fromfile(str(prefix)+'-bones.bin',dtype='<i4').reshape(len(vertices),-1)
    weights=np.fromfile(str(prefix)+'-weights.bin',dtype='<f4').reshape(joints.shape)
    ids=np.array(surface['bind_ids'])
    names=[data['bone_names'][i] for i in ids]
    cape=np.array([name.startswith('Cape_') for name in names])
    cape_weights=weights*cape[joints]
    eligible=cape_weights.sum(axis=1)>.5
    dominant=joints[np.arange(len(vertices)),cape_weights.argmax(axis=1)]
    bind=np.array(surface['bind_poses'],dtype=np.float32)
    rest=np.array(surface['rest_matrices'],dtype=np.float32)
    points=np.zeros((len(vertices),3),dtype=np.float32)
    for slot in range(joints.shape[1]):
        points+=np.einsum('nij,nj->ni',rest[joints[:,slot]],vertices)*weights[:,slot,None]
    for bone,name in enumerate(names):
        if not cape[bone]:continue
        group=np.flatnonzero(eligible & (dominant==bone))
        if not len(group):continue
        chosen=set(group[np.argmax(points[group]@directions.T,axis=0)].tolist())
        # A true inner surface point catches contacts missed by joint endpoints.
        chosen.add(int(group[np.argmin(np.linalg.norm(points[group][:,[0,2]],axis=1))]))
        for vertex in sorted(chosen):
            skin=[]
            roots=[0.0]*5
            for index,w in zip(joints[vertex],weights[vertex]):
                if w<1e-6:continue
                skin.append({'bone':int(ids[index]),'point':(bind[index]@vertices[vertex]).tolist(),'weight':float(w)})
                if cape[index]:roots[int(names[index].split('_')[1])]+=float(w)
            samples.append({'source_surface':surface['prefix'],'source_vertex':int(vertex),'skin':skin,'roots':roots})
assert 30<=len(samples)<=135
result={'source_sha256':data['source_hashes']['assets/characters/echo_v31_adopted_high.glb'],'bone_names':data['bone_names'],
        'scope':'Original actual skin extrema and inner points, selected per dominant eligible Cape bone. Conservative runtime cage; full-triangle offline QA remains required.',
        'samples':samples}
a.output.parent.mkdir(parents=True,exist_ok=True)
a.output.write_text(json.dumps(result,separators=(',',':'))+'\n',encoding='utf-8')
print('CAPE_SKIN_CAGE',len(samples),'points',hashlib.sha256(a.output.read_bytes()).hexdigest())

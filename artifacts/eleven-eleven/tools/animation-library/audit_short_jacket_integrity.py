"""Independent binary audit of the short-jacket derivative against its source."""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import numpy as np

p=argparse.ArgumentParser()
p.add_argument('--source',type=Path,required=True)
p.add_argument('--variant',type=Path,required=True)
p.add_argument('--report',type=Path,required=True)
a=p.parse_args()
def load(path):
    raw=path.read_bytes();size=struct.unpack_from('<I',raw,12)[0]
    doc=json.loads(raw[20:20+size]);blob=raw[28+size:]
    def array(index):
        acc=doc['accessors'][index];view=doc['bufferViews'][acc['bufferView']]
        dtype={5126:'<f4',5123:'<u2',5125:'<u4',5121:'u1'}[acc['componentType']]
        count={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}[acc['type']]
        assert 'byteStride' not in view and 'sparse' not in acc
        return np.frombuffer(blob,dtype=dtype,offset=view.get('byteOffset',0)+acc.get('byteOffset',0),count=acc['count']*count).reshape(acc['count'],count)
    return raw,doc,array
source,s,sa=load(a.source)
variant,v,va=load(a.variant)
for key in ['nodes','skins','animations','materials','textures','images','samplers']:
    assert s.get(key)==v.get(key),'Protected structure changed: '+key
sp=s['meshes'][0]['primitives'][0];vp=v['meshes'][0]['primitives'][0]
for attribute,index in sp['attributes'].items():
    before=sa(index);after=va(vp['attributes'][attribute])
    assert np.array_equal(before,after[:len(before)]),'Original vertex attribute changed: '+attribute
source_joints=sa(sp['attributes']['JOINTS_0'])
source_weights=sa(sp['attributes']['WEIGHTS_0'])
cape=np.array([s['nodes'][i].get('name','').startswith('Cape_') for i in s['skins'][0]['joints']])
cw=(cape[source_joints]*source_weights).sum(axis=1)
sf=sa(sp['indices']).reshape(-1,3).astype('<u4')
vf=va(vp['indices']).reshape(-1,3).astype('<u4')
protected=sf[np.min(cw[sf],axis=1)<=.1]
rows=lambda x:np.ascontiguousarray(x).view(np.dtype((np.void,12))).ravel()
assert np.isin(rows(protected),rows(vf)).all(),'Removed a protected body or mixed seam triangle'
motion_accessors=set()
for animation in s.get('animations',[]):
    for sampler in animation['samplers']:
        motion_accessors.update([sampler['input'],sampler['output']])
for index in motion_accessors: assert np.array_equal(sa(index),va(index)),'Source motion keys changed'
for skin in s['skins']: assert np.array_equal(sa(skin['inverseBindMatrices']),va(skin['inverseBindMatrices']))
vertices=va(vp['attributes']['POSITION']);weights=va(vp['attributes']['WEIGHTS_0']);joints=va(vp['attributes']['JOINTS_0'])
assert np.isfinite(vertices).all() and np.isfinite(weights).all()
assert (weights>=0).all() and np.max(np.abs(weights.sum(axis=1)-1))<1e-5
assert vf.min()>=0 and vf.max()<len(vertices) and joints.max()<len(cape)
report={'status':'PASS_SOURCE_BODY_RIG_MOTION_BINARY_INTEGRITY','source_sha256':hashlib.sha256(source).hexdigest(),
    'variant_sha256':hashlib.sha256(variant).hexdigest(),'unchanged_original_vertices':len(source_joints),
    'unchanged_protected_body_or_mixed_seam_triangles':len(protected),'unchanged_native_animation_accessors':len(motion_accessors),
    'unchanged_joints_and_inverse_binds':len(cape),'new_boundary_vertices':len(vertices)-len(source_joints),
    'maximum_weight_normalization_error':float(np.max(np.abs(weights.sum(axis=1)-1))),
    'visual_boundary':'Binary integrity proves no added deformation in original body/face skin or source motion. Critical garment poses and runtime contacts still require visual inspection.'}
a.report.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(json.dumps(report))

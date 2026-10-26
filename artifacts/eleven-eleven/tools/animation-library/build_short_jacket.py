"""Clip only the adopted coat skirt in an isolated GLB derivative.

All source node, skin, animation, material and original binary bytes survive
unchanged. New mesh accessors append clipped triangles and a narrow folded hem.
No Blender round-trip, retargeting or source key regeneration is involved.
"""
import argparse
import copy
import hashlib
import json
from pathlib import Path
import struct

import numpy as np

p = argparse.ArgumentParser()
p.add_argument('--source', type=Path, required=True)
p.add_argument('--output', type=Path, required=True)
p.add_argument('--hem', type=float, default=.49)
a = p.parse_args()
assert a.source.resolve() != a.output.resolve()
raw = a.source.read_bytes()
size, kind = struct.unpack_from('<II', raw, 12)
assert kind == 0x4e4f534a
original = json.loads(raw[20:20+size])
binary_size, binary_kind = struct.unpack_from('<II', raw, 20+size)
assert binary_kind == 0x004e4942
binary = bytearray(raw[28+size:28+size+binary_size])
document = copy.deepcopy(original)
types = {5126:'<f4', 5123:'<u2', 5125:'<u4', 5121:'u1'}
widths = {'SCALAR':1, 'VEC2':2, 'VEC3':3, 'VEC4':4, 'MAT4':16}

def read(index):
    accessor = original['accessors'][index]
    view = original['bufferViews'][accessor['bufferView']]
    assert 'byteStride' not in view and 'sparse' not in accessor
    return np.frombuffer(binary, dtype=types[accessor['componentType']],
        offset=view.get('byteOffset',0)+accessor.get('byteOffset',0),
        count=accessor['count']*widths[accessor['type']]).reshape(accessor['count'],-1).copy()

assert len(document['meshes']) == 1 and len(document['meshes'][0]['primitives']) == 1
primitive = document['meshes'][0]['primitives'][0]
assert set(primitive['attributes']) == {'POSITION','NORMAL','TEXCOORD_0','JOINTS_0','WEIGHTS_0'}
assert primitive.get('mode',4) == 4 and 'targets' not in primitive
arrays = {name:read(index) for name,index in primitive['attributes'].items()}
triangles = read(primitive['indices']).reshape(-1,3)
joint_names = [original['nodes'][i].get('name','') for i in original['skins'][0]['joints']]
cape_joints = np.array([name.startswith('Cape_') for name in joint_names])
cape_weight = (cape_joints[arrays['JOINTS_0']]*arrays['WEIGHTS_0']).sum(axis=1)
cloth_faces = np.min(cape_weight[triangles],axis=1) > .1
positions = arrays['POSITION']
assert .46 <= a.hem <= .52 and np.sum(cloth_faces) > 10000
new = {name:[] for name in arrays}
edge_cache = {}
hem_edges = []
original_count = len(positions)

def vertex(index):
    if index < original_count:
        return {name:value[index] for name,value in arrays.items()}
    return {name:np.asarray(value[index-original_count]) for name,value in new.items()}

def append(value):
    index = original_count+len(new['POSITION'])
    for name in arrays: new[name].append(value[name])
    return index

def crossing(first, second):
    edge = tuple(sorted((first,second)))
    if edge in edge_cache: return edge_cache[edge]
    va, vb = vertex(first), vertex(second)
    t = (a.hem-va['POSITION'][1])/(vb['POSITION'][1]-va['POSITION'][1])
    result = {name:va[name]*(1-t)+vb[name]*t for name in ['POSITION','NORMAL','TEXCOORD_0']}
    result['POSITION'][1] = a.hem
    result['NORMAL'] /= max(np.linalg.norm(result['NORMAL']),1e-12)
    weights = {}
    for value, blend in [(va,1-t),(vb,t)]:
        for joint, weight in zip(value['JOINTS_0'],value['WEIGHTS_0']):
            weights[int(joint)] = weights.get(int(joint),0)+float(weight)*blend
    selected = sorted(weights.items(),key=lambda item:-item[1])[:4]
    while len(selected)<4: selected.append((0,0))
    result['JOINTS_0'] = np.array([item[0] for item in selected])
    result['WEIGHTS_0'] = np.array([item[1] for item in selected])
    result['WEIGHTS_0'] /= result['WEIGHTS_0'].sum()
    index = append(result)
    edge_cache[edge] = index
    return index

kept = []
removed = 0
cut = 0
for face, garment in zip(triangles,cloth_faces):
    if not garment or np.min(positions[face,1]) >= a.hem:
        kept.append(face.tolist())
        continue
    if np.max(positions[face,1]) < a.hem:
        removed += 1
        continue
    polygon = []
    boundary = []
    for first,second in zip(face,np.roll(face,-1)):
        first,second = int(first),int(second)
        above_first,above_second = positions[first,1] >= a.hem,positions[second,1] >= a.hem
        if above_first: polygon.append(first)
        if above_first != above_second:
            index = crossing(first,second)
            polygon.append(index)
            boundary.append(index)
    for index in range(1,len(polygon)-1): kept.append([polygon[0],polygon[index],polygon[index+1]])
    if len(boundary)==2: hem_edges.append(boundary)
    cut += 1

# A 2.7 mm world-scale folded edge gives the cut a deliberate sewn finish.
# It remains an open jacket, never a horizontal cap through the character.
for first,second in hem_edges:
    folded = []
    for index in [first,second]:
        value = {name:entry.copy() for name,entry in vertex(index).items()}
        value['POSITION'][1] -= .0015
        value['NORMAL'] = np.array([0.,-1.,0.])
        folded.append(append(value))
    kept.extend([[first,folded[0],second],[second,folded[0],folded[1]]])

merged = {name:np.concatenate([value,np.asarray(new[name],dtype=value.dtype)],axis=0) for name,value in arrays.items()}

def store(array, component, shape, target):
    while len(binary)%4: binary.append(0)
    offset = len(binary)
    data = np.ascontiguousarray(array,dtype=types[component])
    binary.extend(data.tobytes())
    view = len(document['bufferViews'])
    document['bufferViews'].append({'buffer':0,'byteOffset':offset,'byteLength':data.nbytes,'target':target})
    index = len(document['accessors'])
    accessor = {'bufferView':view,'componentType':component,'count':len(data),'type':shape}
    if shape == 'VEC3' and target==34962:
        accessor.update({'min':data.min(axis=0).tolist(),'max':data.max(axis=0).tolist()})
    document['accessors'].append(accessor)
    return index

for name,value in merged.items():
    old = original['accessors'][primitive['attributes'][name]]
    primitive['attributes'][name] = store(value,old['componentType'],old['type'],34962)
primitive['indices'] = store(np.asarray(kept,dtype='<u4').reshape(-1,1),5125,'SCALAR',34963)
while len(binary)%4: binary.append(0)
document['buffers'][0]['byteLength'] = len(binary)
encoded = json.dumps(document,separators=(',',':')).encode()
encoded += b' '*((-len(encoded))%4)
output = struct.pack('<III',0x46546c67,2,12+8+len(encoded)+8+len(binary))
output += struct.pack('<II',len(encoded),0x4e4f534a)+encoded+struct.pack('<II',len(binary),0x004e4942)+binary
a.output.parent.mkdir(parents=True,exist_ok=True)
a.output.write_bytes(output)
for key in ['nodes','skins','animations','materials','textures','images','samplers']:
    assert document.get(key) == original.get(key), 'Changed protected '+key
assert binary[:binary_size] == raw[28+size:28+size+binary_size]
report = {'status':'ISOLATED_SHORT_JACKET_REQUIRES_VISUAL_REVIEW','source':str(a.source.resolve()),
    'source_sha256':hashlib.sha256(raw).hexdigest(),'derivative_sha256':hashlib.sha256(output).hexdigest(),
    'hem_source_y':a.hem,'removed_garment_triangles':removed,'clipped_garment_triangles':cut,
    'folded_hem_segments':len(hem_edges),'source_triangles':len(triangles),'derivative_triangles':len(kept),
    'source_binary_preserved':True,'nodes_skins_animations_materials_unchanged':True,
    'source_vertices_preserved':True,'new_boundary_vertices':len(new['POSITION']),
    'remaining_below_hem_cloth_triangles':int(sum(np.all(merged['POSITION'][face,1]<a.hem-.0016) and np.min((cape_joints[merged['JOINTS_0'][face]]*merged['WEIGHTS_0'][face]).sum(axis=1))>.1 for face in kept))}
a.output.with_suffix('.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(json.dumps(report))

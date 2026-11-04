"""Fit the complete measured cassette without rewriting geometry or 4K images."""
from pathlib import Path
import hashlib
import json
import struct

A = Path(__file__).resolve().parents[2]
G = A / 'art/production/maintenance-refinement-20261025/maintenance-gantry-20261027'
source = G / 'cassette-h31-fourview-pbr4k.glb'
target = A / 'godot/assets/environments/maintenance_cp45/maintenance_primary_cassette_pbr4k.glb'
assert not target.exists(), 'Preserve the existing native derivative'
audit = json.loads((G / 'cassette-pbr-geometry-audit.json').read_text())
assert audit['triangles_each'] == 1943923
assert all(d['max_at_5m_width_m'] == 0 for d in audit['distances'])
data = source.read_bytes()
assert hashlib.sha256(data).hexdigest() == 'e62c4ab0b174b83433492592ab32211d5e17fe8821367b22e3c459059bdefce6'
length, kind = struct.unpack_from('<II', data, 12)
assert kind == 0x4e4f534a
document = json.loads(data[20:20+length])
tail = data[20+length:]
assert len(document['meshes']) == 1 and len(document['scenes']) == 1
assert len(document['nodes']) == 1
node = document['nodes'][0]
assert node.get('mesh') == 0 and not any(k in node for k in ['matrix','rotation','scale','translation'])
primitive = document['meshes'][0]['primitives'][0]
accessor = document['accessors'][primitive['attributes']['POSITION']]
lo, hi = accessor['min'], accessor['max']
size = [hi[i]-lo[i] for i in range(3)]
dimensions = [4.998, 3.398, .498]
scale = [dimensions[i]/size[i] for i in range(3)]
assert max(scale)/min(scale) < 1.025, 'Reject a materially distorted component fit'
translation = [-(hi[i]+lo[i])*.5*scale[i] for i in range(3)]
matrix = [scale[0],0,0,0, 0,scale[1],0,0, 0,0,scale[2],0, *translation,1]
document['nodes'] = [
    {'name':'MaintenancePrimaryCassette','children':[1],
     'extras':{'source_workspace':'bd6b234b-5a6b-44f5-bd19-fa5d6ff03fb8',
               'front_axis':'+Z',
               'front_evidence':'Actual PBR review: amber indicator face is Blender -Y / glTF +Z.',
               'native_body':'COLL_CLIMB_FirstWall',
               'scope':'Static visual architecture only; native cues and physics remain separate.'}},
    {'name':'CassetteStructuralMesh','mesh':0,'matrix':matrix},
]
document['scenes'] = [{'name':'MaintenancePrimaryCassettePBR','nodes':[0]}]
document['scene'] = 0
head = json.dumps(document,separators=(',',':'),ensure_ascii=False).encode()
head += b' '*((-len(head))%4)
result = (struct.pack('<III',0x46546c67,2,12+8+len(head)+len(tail))
          +struct.pack('<II',len(head),0x4e4f534a)+head+tail)
assert result[-len(tail):] == tail
assert len(result) < 100*1024*1024
target.write_bytes(result)
report = {'status':'PREPARED_NATIVE_REVIEW_PENDING',
          'source':source.name,'source_sha256':hashlib.sha256(data).hexdigest(),
          'asset':str(target.relative_to(A)).replace('\\','/'),
          'asset_sha256':hashlib.sha256(result).hexdigest(),'bytes':len(result),
          'buffer_and_embedded_images_byte_identical':True,
          'source_triangles':1943923,'mesh_count':1,'dimensions_m':dimensions,
          'component_fit_axis_scale':scale,'max_axis_scale_ratio':max(scale)/min(scale),
          'front_axis':'+Z','pivot':'center of original first-wall solid',
          'native_body':'COLL_CLIMB_FirstWall','native_position_m':[0,1.7,-6],
          'native_collision_size_m':[5,3.4,.5],
          'maps_actual_sizes':{'basecolor':[4096,4096],'normal':[4096,4096],'roughness_metallic':[4096,4096]},
          'geometry_review':'Raw and PBR have equal triangle counts and zero full bidirectional nearest-vertex distance; three PBR render views reviewed.',
          'scope':'Complete principal 5m cassette, with sub-2.5percent axis fitting within the unchanged solid. No new holds, rungs, collision, motion, or gameplay authority.'}
(G / 'native-cassette-contract.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
(target.parent / 'maintenance_primary_cassette_contract.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(json.dumps(report))

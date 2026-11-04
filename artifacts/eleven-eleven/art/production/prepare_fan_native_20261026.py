"""Restore measured metres and rigid pivots without rewriting Tripo geometry or images."""
from pathlib import Path
import json,struct,hashlib

A=Path(__file__).resolve().parents[2]
F=A/'art/production/maintenance-refinement-20261025/multiview-fan-20261026'
src=F/'fan-corrected-textured-pbr4k.glb'
dst=A/'godot/assets/environments/maintenance_cp45/maintenance_ventilation_fan_pbr.glb'
assert not dst.exists(),'Preserve an existing native derivative;review before replacement'
b=src.read_bytes();size,typ=struct.unpack_from('<II',b,12);assert typ==0x4e4f534a
j=json.loads(b[20:20+size]);tail=b[20+size:]
assert len(j['meshes'])==2 and len(j['scenes'])==1
old_nodes=j['nodes'];ids={n['name']:i for i,n in enumerate(old_nodes)}
assert {'Fan_FrameMesh','Fan_RotorMesh'}<=ids.keys()
frame=old_nodes[ids['Fan_FrameMesh']]['mesh'];rotor=old_nodes[ids['Fan_RotorMesh']]['mesh']
assert frame!=rotor
matrix=[1.2,0,0,0,0,1.2,0,0,0,0,1.2,0,0,-.5992413759231567,0,1]
j['nodes']=[
 {'name':'MaintenanceFan','rotation':[0,1,0,0],'children':[1,2],'extras':{'source_workspace':'f7405db2-e7fd-45cf-99be-9e17864d3a5d','front_axis':'+Z','normalization_restore':'Uniform1.2m;Y-.5992413759231567;rootYpi'}},
 {'name':'FanPBRStationaryFrame','children':[3]},
 {'name':'FanPBRRotorPivot','children':[4],'extras':{'mechanical_axis':'-Z','motion_owner':'existing room presentation time;no animation keys or gameplay authority'}},
 {'name':'FanPBRFrame','mesh':frame,'matrix':matrix},
 {'name':'FanPBRRotor','mesh':rotor,'matrix':matrix},
]
j['scenes']=[{'name':'MaintenanceFanRigidPBR','nodes':[0]}];j['scene']=0
head=json.dumps(j,separators=(',',':'),ensure_ascii=False).encode('utf-8');head+=b' '*((-len(head))%4)
result=struct.pack('<III',0x46546c67,2,12+8+len(head)+len(tail))+struct.pack('<II',len(head),0x4e4f534a)+head+tail
assert result[-len(tail):]==tail and len(result)<100*1024*1024
dst.write_bytes(result)
report={'status':'PREPARED_NATIVE_ACCEPTANCE_PENDING','source':src.name,'source_sha256':hashlib.sha256(b).hexdigest(),'asset':str(dst.relative_to(A)).replace('\\','/'),'asset_sha256':hashlib.sha256(result).hexdigest(),'bytes':len(result),'buffer_and_embedded_images_byte_identical':True,'retained_source_triangles':1775556,'rigid_meshes':2,'pivot':'FanPBRRotorPivot','axis_local':'-Z','front_axis':'+Z','dimensions_m':[1.2,1.19846,.42312],'frame_texture_actual_sizes':{'basecolor':4096,'normal':2048,'roughness_metallic':2048},'rotor_texture_actual_sizes':{'basecolor':2048,'normal':1024,'roughness_metallic':1024},'texture_note':'Studio4K choice allocates different per-part map sizes;not all maps4K.8K gated by paid upgrade;no purchase.','geometry_error_max_m':.0000427448,'collision_scope':'Earlier12 exact blade-stator sampled poses before texture,plus per-role full bidirectional vertex preservation <.043mm;native play/art/motion not yet accepted.'}
(F/'native-asset-contract.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(report,ensure_ascii=False))

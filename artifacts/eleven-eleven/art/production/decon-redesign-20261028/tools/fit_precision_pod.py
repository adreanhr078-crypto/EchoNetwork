import bpy,pathlib,json,struct,hashlib,math
from mathutils import Vector,Matrix,kdtree
A=pathlib.Path(r'C:\Users\yasmo\EchoNetwork\artifacts\eleven-eleven');P=A/'art/production/decon-redesign-20261028/tripo';src=P/'precision-pod-tripo-pbr-source.glb';dst=A/'godot/assets/environments/decon_clinical/decon_pod_precision_pbr.glb'
bpy.ops.wm.read_factory_settings(use_empty=True)
def import_points(path):
 before=set(bpy.data.objects);bpy.ops.import_scene.gltf(filepath=str(path));obs=[o for o in bpy.data.objects if o not in before and o.type=='MESH'];pts=[o.matrix_world@v.co for o in obs for v in o.data.vertices];lo=Vector(tuple(min(p[i] for p in pts) for i in range(3)));hi=Vector(tuple(max(p[i] for p in pts) for i in range(3)));return obs,pts,lo,hi
original,op,ol,oh=import_points(P/'precision-pod-authored-source.glb')
candidate,cp,cl,ch=import_points(src)
ratio=(oh-ol).z/(ch-cl).z
oc=(ol+oh)*.5;cc=(cl+ch)*.5
tree=kdtree.KDTree(len(op))
for i,p in enumerate(op):tree.insert(p,i)
tree.balance()
registrations=[]
for quarter in range(4):
 rotation=Matrix.Rotation(quarter*math.pi/2,3,'Z')
 errors=[tree.find(rotation@(p-cc)*ratio+oc)[2] for p in cp]
 registrations.append((max(errors),sum(errors)/len(errors),quarter,errors,rotation))
_,_,quarter,errors,rotation=min(registrations,key=lambda r:r[0])
print('REGISTRATION_CANDIDATES',[(r[0],r[1],r[2]) for r in registrations])
assert max(errors)<.0001,('Tripo altered rigid geometry',max(errors),ratio,list(oh-ol),list(ch-cl))
bpy.ops.object.select_all(action='DESELECT')
for o in candidate:
 world=o.matrix_world.copy();o.parent=None
 for v in o.data.vertices:v.co=rotation@(world@v.co-cc)*ratio+oc-Vector((0,0,ol.z))
 o.matrix_world.identity();o.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(dst),export_format='GLB',use_selection=True,export_apply=True)
raw=src.read_bytes();size=struct.unpack_from('<I',raw,12)[0];g=json.loads(raw[20:20+size]);tri=sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in candidate)
report={'scope':'Same authored geometry,Tripo texture/PBR only;floor origin corrected;no decimation','source_sha256':hashlib.sha256(raw).hexdigest(),'runtime_sha256':hashlib.sha256(dst.read_bytes()).hexdigest(),'source_triangles':35672,'candidate_triangles':tri,'uniform_scale':ratio,'quarter_turns_z':quarter,'max_registration_error_m':max(errors),'runtime_dimensions_m':list(oh-ol),'materials':len(g.get('materials',[])),'images':len(g.get('images',[])),'normal_mapped':sum('normalTexture' in m for m in g.get('materials',[])),'metallic_roughness_mapped':sum('metallicRoughnessTexture' in m.get('pbrMetallicRoughness',{}) for m in g.get('materials',[])),'runtime':str(dst)}
(P/'precision-pod-tripo-registration.json').write_text(json.dumps(report,indent=2));print('POD_REGISTRATION_PASS',report)

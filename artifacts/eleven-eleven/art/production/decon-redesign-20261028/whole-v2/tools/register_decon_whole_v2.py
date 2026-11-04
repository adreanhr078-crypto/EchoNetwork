import bpy,pathlib,json,struct,hashlib,itertools,collections
import numpy as np
from mathutils import Matrix,Quaternion,kdtree
P=pathlib.Path(r'C:\Users\yasmo\EchoNetwork\artifacts\eleven-eleven\art\production\decon-redesign-20261028\whole-v2')
def glb_points(path):
 raw=path.read_bytes();n=struct.unpack_from('<I',raw,12)[0];g=json.loads(raw[20:20+n]);buf=raw[28+n:];points=[];owners=[];names=[]
 def visit(idx,parent):
  node=g['nodes'][idx]
  if 'matrix' in node:m=np.array(node['matrix'],dtype=np.float64).reshape((4,4),order='F')
  else:
   q=node.get('rotation',[0,0,0,1]);r=np.asarray(Quaternion((q[3],*q[:3])).to_matrix());m=np.eye(4);m[:3,:3]=r@np.diag(node.get('scale',[1,1,1]));m[:3,3]=node.get('translation',[0,0,0])
  world=parent@m
  if 'mesh' in node:
   owner=len(names);names.append(node.get('name','source_%d'%idx))
   for p in g['meshes'][node['mesh']]['primitives']:
    a=g['accessors'][p['attributes']['POSITION']];v=g['bufferViews'][a['bufferView']];offset=v.get('byteOffset',0)+a.get('byteOffset',0);stride=v.get('byteStride',12)
    x=np.ndarray((a['count'],3),dtype='<f4',buffer=buf,offset=offset,strides=(stride,4)).astype(np.float64);x=x@world[:3,:3].T+world[:3,3];x=x[:,[0,2,1]];x[:,1]*=-1;points.append(x);owners.append(np.full(len(x),owner,dtype=np.int32))
  for child in node.get('children',[]):visit(child,world)
 for idx in g['scenes'][g.get('scene',0)]['nodes']:visit(idx,np.eye(4))
 return np.concatenate(points),np.concatenate(owners),names
source,owners,names=glb_points(P/'corrected-metric-source.glb');tree=kdtree.KDTree(len(source))
for i,p in enumerate(source):tree.insert(p,i)
tree.balance();print('SOURCE_TREE_READY',len(source),source.min(0),source.max(0),flush=True)
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(P/'corrected-tripo-pbr-source.glb'));objects=[o for o in bpy.data.objects if o.type=='MESH'];groups=[]
for o in objects:
 x=np.empty(len(o.data.vertices)*3,dtype=np.float32);o.data.vertices.foreach_get('co',x);x=x.reshape(-1,3).astype(np.float64);m=np.asarray(o.matrix_world);groups.append(x@m[:3,:3].T+m[:3,3])
candidate=np.concatenate(groups);rng=np.random.default_rng(20261028);sample=candidate[rng.choice(len(candidate),min(10000,len(candidate)),replace=False)]
def principal(x):
 mean=x.mean(0);w,v=np.linalg.eigh(np.cov(x.T));idx=np.argsort(w)[::-1];return mean,w[idx],v[:,idx]
sm,sw,sv=principal(source);cm,cw,cv=principal(candidate);initial_scale=np.sqrt(sw.sum()/cw.sum())
def similarity(x,y):
 xm=x.mean(0);ym=y.mean(0);xc=x-xm;yc=y-ym;u,d,vt=np.linalg.svd(xc.T@yc/len(x));r=vt.T@u.T
 if np.linalg.det(r)<0:vt[-1]*=-1;r=vt.T@u.T;d[-1]*=-1
 scale=d.sum()/np.mean(np.sum(xc*xc,axis=1));return scale,r,ym-scale*r@xm
def matches(x):
 rows=[tree.find(p) for p in x];return np.array([r[0] for r in rows]),np.array([r[2] for r in rows])
solutions=[]
for signs in itertools.product([-1,1],repeat=3):
 r=sv@np.diag(signs)@cv.T
 if np.linalg.det(r)<0:continue
 scale=initial_scale;t=sm-scale*r@cm
 for iteration in range(35):
  mapped=scale*sample@r.T+t;y,dist=matches(mapped);mask=dist<=np.quantile(dist,.9);scale,r,t=similarity(sample[mask],y[mask])
  if np.sqrt(np.mean(dist[mask]**2))<.00005:break
 mapped=scale*sample@r.T+t;_,dist=matches(mapped);rms=float(np.sqrt(np.mean(dist**2)));solutions.append((rms,scale,r,t));print('PCA_ICP',signs,iteration,rms,float(dist.max()),flush=True)
rms,scale,rotation,translation=min(solutions,key=lambda row:row[0]);registered=scale*candidate@rotation.T+translation
max_error=0.0;sum_squared=0.0
for start in range(0,len(registered),50000):
 _,dist=matches(registered[start:start+50000]);max_error=max(max_error,float(dist.max()));sum_squared+=float(np.sum(dist**2))
assert max_error<.005,('Rigid registration failed;do not integrate',rms,max_error)
transform=np.eye(4);transform[:3,:3]=rotation*scale;transform[:3,3]=translation;roles=[];offset=0
for o,x in zip(objects,groups):
 points=registered[offset:offset+len(x)];offset+=len(x);indices=np.linspace(0,len(points)-1,min(len(points),300),dtype=int);votes=collections.Counter(int(owners[tree.find(points[i])[1]]) for i in indices);owner,count=votes.most_common(1)[0];name=names[owner];o.name=name
 roles.append({'node':o.name,'source_node':name,'owner_match':count/len(indices),'materials':[m.name for m in o.data.materials if m]})
 o.matrix_world=Matrix(transform.tolist())@o.matrix_world
bpy.ops.object.select_all(action='DESELECT')
for o in objects:o.select_set(True)
bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
bpy.ops.export_scene.gltf(filepath=str(P/'textured-metric-source.glb'),export_format='GLB',use_selection=True,export_apply=True)
bpy.ops.wm.save_as_mainfile(filepath=str(P/'textured-metric-source.blend'))
report={'status':'REGISTRATION_PASS_NOT_NATIVE_ACCEPTANCE','scale':float(scale),'matrix':transform.tolist(),'source_vertices':len(source),'candidate_vertices':len(candidate),'all_candidate_vertices_verified':True,'max_registration_error_m':max_error,'rms_registration_error_m':float(np.sqrt(sum_squared/len(candidate))),'source_sha256':hashlib.sha256((P/'corrected-metric-source.glb').read_bytes()).hexdigest(),'pbr_sha256':hashlib.sha256((P/'corrected-tripo-pbr-source.glb').read_bytes()).hexdigest(),'roles':roles,'scope':'Rigid similarity registration after UI best angle0,0,-45;UV/PBR retained;no new geometry generation or authority changes'}
(P/'pbr-registration-report.json').write_text(json.dumps(report,indent=2));print('WHOLE_V2_METRIC_PBR_REGISTERED',max_error,len(objects),flush=True)

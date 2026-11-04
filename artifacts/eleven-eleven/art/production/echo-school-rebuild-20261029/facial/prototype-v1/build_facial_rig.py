"""Isolated facial derivative. Source, body skeleton/rest and Golden takes stay immutable."""
from pathlib import Path
import bpy,numpy as np,json,hashlib,sys,math
from mathutils import Vector
p=Path(__file__).resolve().parents[1];out=p/'facial';sys.path.insert(0,str(p.parents[2]/'tools/animation-library'))
from golden_reference import verify
verify();source=p/'source/echo-school-rig-metric.blend';source_sha=hashlib.sha256(source.read_bytes()).hexdigest();bpy.ops.wm.open_mainfile(filepath=str(source))
rig=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE');original=next(o for o in bpy.context.scene.objects if o.type=='MESH' and any(m.type=='ARMATURE' and m.object==rig for m in o.modifiers));m=original.data
rest=[(b.name,b.parent.name if b.parent else None,[list(r) for r in b.matrix_local]) for b in rig.data.bones];assert len(rest)==65
d=np.load(out/'component-assignments.npz');world=d['world_points'];components=d['vertex_component'];local=np.array([v.co[:] for v in m.vertices]);uv=m.uv_layers.active;normals=[n.vector[:] for n in m.corner_normals];C=-.00301
def smooth(a,b,x):
 t=np.clip((x-a)/(b-a),0,1);return t*t*(3-2*t)
def gauss(x,z,cx,cz,sx,sz):return np.exp(-.5*((x-cx)/sx)**2-.5*((z-cz)/sz)**2)
face_region=(np.abs(world[:,0]-C)<.081)&(world[:,2]>1.489)&(world[:,2]<1.637)&(world[:,1]<.027)
face_components={8,9,10,13,19,20,21};face_polys=[];body_polys=[]
for f in m.polygons:
 cid=int(components[f.vertices[0]])
 if cid==16:continue # Original undivided dental cylinder is retained only in untouched source.
 if cid in face_components or (cid==30 and any(face_region[i] for i in f.vertices)):face_polys.append(f)
 else:body_polys.append(f)
def subset(name,polys):
 indices=sorted({i for f in polys for i in f.vertices});remap={old:new for new,old in enumerate(indices)};mesh=bpy.data.meshes.new(name);mesh.from_pydata(local[indices].tolist(),[],[[remap[i] for i in f.vertices] for f in polys]);mesh.update()
 group_names=[g.name for g in original.vertex_groups];obj=original.copy();obj.data=mesh;obj.name=name;bpy.context.collection.objects.link(obj)
 obj.vertex_groups.clear()
 for group_name in group_names:obj.vertex_groups.new(name=group_name)
 for mat in m.materials:mesh.materials.append(mat)
 destuv=mesh.uv_layers.new(name=uv.name);custom=[]
 for f,src in zip(mesh.polygons,polys):
  f.material_index=src.material_index;f.use_smooth=src.use_smooth
  for di,si in zip(f.loop_indices,src.loop_indices):destuv.data[di].uv=uv.data[si].uv;custom.append(normals[si])
 mesh.normals_split_custom_set(custom)
 weights={}
 for ni,oi in enumerate(indices):
  for g in m.vertices[oi].groups:weights.setdefault((g.group,g.weight),[]).append(ni)
 for (gi,w),ids in weights.items():obj.vertex_groups[gi].add(ids,w,'REPLACE')
 return obj,np.array(indices)
static,static_ids=subset('EchoSchool_BodyPreserved',body_polys);face,ids=subset('EchoFace_Controls',face_polys);points=world[ids];comp=components[ids];x,y,z=points.T;fx=x-C;inv=np.array(original.matrix_world.inverted().to_3x3());face.shape_key_add(name='Basis')
def shape(obj,name,delta,base=None):
 key=obj.shape_key_add(name=name);key.slider_min=0;key.slider_max=1
 coords=(np.array([v.co[:] for v in obj.data.vertices]) if base is None else base)+delta
 key.data.foreach_set('co',coords.astype(np.float32).ravel());return key
def face_shape(name,delta):return shape(face,name,delta@inv.T)
skin=(comp==30);depth=smooth(-.105,-.079,y)*(1-smooth(.008,.03,y));width=1-smooth(.062,.08,np.abs(fx));chin=smooth(1.492,1.519,z);lower=1-smooth(1.5395,1.542,z);jaw_weight=depth*width*chin*lower*skin
delta=np.zeros_like(points);delta[:,2]=-.017*jaw_weight;delta[:,1]=.003*jaw_weight
# Tiny upper-lip lift opens the existing modeled oral slit;there is no painted mouth replacement.
upper=gauss(x,z,C,1.544,.017,.003)*skin*depth;delta[:,2]+=.0012*upper
tongue=(comp==13);delta[tongue,2]-=.012;delta[tongue,1]+=.002
face_shape('Jaw_Open',delta)
for side,sign,iris,brow,lash,cx in [('L',1,19,21,20,.029233),('R',-1,9,8,10,-.035251)]:
 smile=gauss(x,z,C+sign*.014,1.542,.013,.009)*depth*skin*smooth(-.002,.006,sign*fx)
 delta=np.zeros_like(points);delta[:,0]=sign*.0045*smile;delta[:,2]=.004*smile;delta[:,1]=-.001*smile;face_shape('Smile_'+side,delta)
 cheek=gauss(x,z,C+sign*.035,1.568,.018,.012)*depth*skin;delta=np.zeros_like(points);delta[:,2]=.0022*cheek;delta[:,1]=-.0014*cheek;face_shape('Cheek_Raise_'+side,delta)
 eye_width=1-smooth(.019,.027,np.abs(x-cx));eye_depth=smooth(-.083,-.069,y)*(1-smooth(-.008,.009,y));eye_vertical=smooth(1.580,1.588,z)*(1-smooth(1.607,1.617,z));eye_mask=eye_width*eye_depth*eye_vertical*skin
 eye_mask[(comp==iris)|(comp==lash)]=1;line=1.5921+.0015*((x-cx)/.023)**2
 delta=np.zeros_like(points);delta[:,2]=(line+(z-1.5965)*.035-z)*eye_mask;delta[comp==iris,1]=.0025;face_shape('Blink_'+side,delta);face_shape('Eye_Squint_'+side,delta*.42)
 brow_mask=(comp==brow).astype(float);inner=1-smooth(.012,.052,np.abs(fx));delta=np.zeros_like(points);delta[:,2]=-.003*inner*brow_mask;delta[:,0]=-sign*.0012*inner*brow_mask;face_shape('Brow_Frown_'+side,delta)
delta=np.zeros_like(points);bm=((comp==8)|(comp==21)).astype(float);delta[:,2]=.0028*(1-smooth(.012,.054,np.abs(fx)))*bm;face_shape('Brow_Inner_Up',delta)
delta=np.zeros_like(points);mouth=gauss(x,z,C,1.54,.023,.006)*depth*skin;delta[:,2]=.0015*mouth*(1-2*smooth(1.54,1.542,z));face_shape('Mouth_Grimace',delta)
original.hide_render=True;original.hide_set(True)
def solid(name,rgba,roughness=.5):
 mat=bpy.data.materials.new(name);mat.diffuse_color=rgba;mat.use_nodes=True;shader=mat.node_tree.nodes.get('Principled BSDF');shader.inputs['Base Color'].default_value=rgba;shader.inputs['Roughness'].default_value=roughness;return mat
tooth=solid('NaturalIvoryTeeth',(.72,.68,.59,1),.32);cavitymat=solid('OralCavity',(.018,.003,.005,1),.8);pupilmat=solid('NaturalDarkPupil',(.002,.003,.005,1),.16)
head_name=next(b.name for b in rig.data.bones if b.name.split(':')[-1]=='Head')
def head_mesh(name,verts,faces,material):
 mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update();obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj);mesh.materials.append(material)
 group=obj.vertex_groups.new(name=head_name);group.add(list(range(len(verts))),1,'REPLACE');mod=obj.modifiers.new('OriginalHead65','ARMATURE');mod.object=rig
 for poly in mesh.polygons:poly.use_smooth=True
 obj.shape_key_add(name='Basis');return obj
extras=[]
for lower_teeth in [False,True]:
 verts=[];faces=[]
 for i in range(8):
  cx=C+(i-3.5)*.0042;cy=-.054+.012*((i-3.5)/4)**2;cz=1.542 if not lower_teeth else 1.537
  # Individual restrained tooth blocks,rounded by bevel before facial key authoring.
  base=len(verts);w=.00408;h=.007 if not lower_teeth else .005;dep=.004
  verts.extend([(cx+sx*w*.5,cy+sy*dep*.5,cz+sz*h*.5) for sx,sy,sz in [(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),(-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]])
  faces.extend([[base+j for j in f] for f in [(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]])
 obj=head_mesh('LowerTeeth' if lower_teeth else 'UpperTeeth',verts,faces,tooth);co=np.array(verts);delta=np.zeros_like(co)
 if lower_teeth:delta[:,2]=-.016;delta[:,1]=.003
 shape(obj,'Jaw_Open',delta)
 for side,sign in [('L',1),('R',-1)]:
  w=smooth(-.002,.008,sign*(co[:,0]-C));dd=np.zeros_like(co);dd[:,0]=sign*.0015*w;shape(obj,'Smile_'+side,dd)
 extras.append(obj)
# Concave mouth chamber stays behind skin and teeth in the closed neutral pose.
verts=[];faces=[]
for j in range(5):
 for i in range(17):
  theta=math.pi*i/16;verts.append((C+.027*math.cos(theta),-.025+.013*math.sin(theta),1.554-.008*j))
for j in range(4):
 for i in range(16):a=j*17+i;faces.append((a,a+1,a+18,a+17))
oral=head_mesh('MouthInterior',verts,faces,cavitymat);co=np.array(verts);dd=np.zeros_like(co);dd[:,2]=-.01*(1-smooth(1.538,1.548,co[:,2]));shape(oral,'Jaw_Open',dd);extras.append(oral)
# Small curved pupil overlays preserve visible original iris rings;dilation is optional/default zero.
from mathutils.bvhtree import BVHTree
for side,cid in [('L',19),('R',9)]:
 vi=[i for i,c in enumerate(components) if int(c)==cid];remap={oi:ni for ni,oi in enumerate(vi)};polys=[[remap[i] for i in f.vertices] for f in m.polygons if int(components[f.vertices[0]])==cid];tree=BVHTree.FromPolygons([Vector(v) for v in world[vi]],polys);center=world[vi].mean(axis=0)
 def disc(scale):
  coords=[(0.,0.)]+[(math.cos(a)*.00235*scale,math.sin(a)*.00265*scale) for a in np.linspace(0,2*math.pi,33)[:-1]];result=[]
  for dx,dz in coords:
   xx=center[0]+dx;zz=center[2]+dz;hit=tree.ray_cast(Vector((xx,-.2,zz)),Vector((0,1,0)))[0];yy=(hit.y if hit else center[1])-.0001;result.append((xx,yy,zz))
  return np.array(result)
 co=disc(1);obj=head_mesh('Pupil_'+side,co.tolist(),[(0,i+1,(i+1)%32+1) for i in range(32)],pupilmat);shape(obj,'Pupil_Dilate_'+side,disc(1.5)-co);dd=np.zeros_like(co);dd[:,2]=1.5921+(co[:,2]-center[2])*.035-co[:,2];dd[:,1]=.003;shape(obj,'Blink_'+side,dd);shape(obj,'Eye_Squint_'+side,dd*.42);extras.append(obj)
objects=[static,face]+extras
scene=bpy.context.scene;scene.render.fps=24;scene.frame_start=1;scene.frame_end=240
# No armature keys are created;this is a facial-only library at the original reference rate.
capture=json.loads((out/'capture-base/face-capture.json').read_text());frames=capture['samples'];calibration={'jaw_gain':5.5,'smile_gain':.92,'blink_gain':1.65,'cheek_from_smile':.35,'notes':'Stylized reference estimates are calibrated controls,not ground-truth 3D reconstruction. No smoothing or body motion edits.'}
controls=[]
for f in frames:
 c=f['coefficients'];values={'Jaw_Open':float(np.clip((c['jawOpen']-.002)*5.5,0,1)),'Brow_Inner_Up':float(np.clip((c['browInnerUp']-.11)*1.5,0,.5)),'Mouth_Grimace':0.0}
 for side,label in [('L','Left'),('R','Right')]:
  values['Smile_'+side]=float(np.clip(c['mouthSmile'+label]*.92,0,1));values['Cheek_Raise_'+side]=values['Smile_'+side]*.35;values['Blink_'+side]=float(np.clip((c['eyeBlink'+label]-.015)*1.65,0,1));values['Eye_Squint_'+side]=float(np.clip((c['eyeSquint'+label]-.08)*.45,0,.18));values['Brow_Frown_'+side]=float(np.clip(c['browDown'+label]*2,0,.4));values['Pupil_Dilate_'+side]=0.0
 controls.append({'frame':f['frame'],'time_seconds':f['time_seconds'],'controls':values})
 for obj in objects:
  if not obj.data.shape_keys:continue
  for name,value in values.items():
   key=obj.data.shape_keys.key_blocks.get(name)
   if key:key.value=value;key.keyframe_insert(data_path='value',frame=f['frame']+1,group='FaceOnlyReference24Hz')
for obj in objects:
 keys=obj.data.shape_keys
 if keys and keys.animation_data and keys.animation_data.action:
  action=keys.animation_data.action;action.name='EchoFace_ApprovedLaugh24Hz'
  for slot in action.slots:
   for layer in action.layers:
    for strip in layer.strips:
     bag=strip.channelbag(slot)
     if bag:
      for curve in bag.fcurves:
       for key in curve.keyframe_points:key.interpolation='LINEAR'
assert rest==[(b.name,b.parent.name if b.parent else None,[list(r) for r in b.matrix_local]) for b in rig.data.bones]
assert hashlib.sha256(source.read_bytes()).hexdigest()==source_sha
scene.frame_set(1);blend=out/'echo-school-facial-rig.blend';bpy.ops.wm.save_as_mainfile(filepath=str(blend))
bpy.ops.object.select_all(action='DESELECT')
for obj in [rig]+objects:
 while obj:obj.select_set(True);obj=obj.parent
bpy.context.view_layer.objects.active=rig
bpy.ops.export_scene.gltf(filepath=str(out/'echo-school-facial-rig.glb'),export_format='GLB',use_selection=True,export_yup=True,export_skins=True,export_animations=True,export_animation_mode='SCENE',export_force_sampling=True,export_frame_range=True,export_morph=True)
report={'status':'FACIAL_RIG_AUTHORED_REVIEW_REQUIRED','source_sha256':source_sha,'body_rest65_unchanged':True,'source_motion_keys_changed':False,'reference_fps':24,'reference_samples':len(controls),'face_vertices':len(face.data.vertices),'static_vertices':len(static.data.vertices),'face_shapes':[k.name for k in face.data.shape_keys.key_blocks][1:],'extra_meshes':[o.name for o in extras],'calibration':calibration,'runtime_integrated':False,'tears':'OPEN_optional_control_not_in_original_master','first_video_is_master':True}
(out/'facial-rig-report.json').write_text(json.dumps(report,indent=2)+'\n');(out/'calibrated-controls24.json').write_text(json.dumps({'reference_sha256':'9d77073ea2d9e51d83ae2aa4887cd0a2bc474851a9358aa52b610b7f63f1c682','calibration':calibration,'frames':controls},separators=(',',':'))+'\n');verify();print('FACIAL_RIG_AUTHORED',json.dumps(report))

import bpy,bmesh,pathlib,json,math
from mathutils import Vector,Matrix
P=pathlib.Path(r'C:\Users\yasmo\EchoNetwork\artifacts\eleven-eleven\art\production\decon-redesign-20261028\whole-v2');bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(P/'source.glb'));source=[o for o in bpy.data.objects if o.type=='MESH'];records=[]
def material(name,color,metal=.2,rough=.55):
 m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True;s=m.node_tree.nodes['Principled BSDF'];s.inputs['Base Color'].default_value=(*color,1);s.inputs['Metallic'].default_value=metal;s.inputs['Roughness'].default_value=rough;return m
structure=material('Obsidian clinical structure',(.17,.19,.22),.35);ivory=material('Ivory pressure vessel castings',(.55,.59,.62),.3);floor_mat=material('Satin ceramic walk surface',(.31,.34,.37),.22);alloy=material('Satin graphite bridge alloy',(.15,.18,.21),.55);seal=material('Dark elastomer insets',(.025,.035,.045),.1)
def bounds(o):
 pts=[o.matrix_world@Vector(c) for c in o.bound_box];return Vector(tuple(min(v[i] for v in pts) for i in range(3))),Vector(tuple(max(v[i] for v in pts) for i in range(3)))
def bake(o,matrix):
 bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o;o.matrix_world=matrix;bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
def point(native):return Vector((native[0],-native[2],native[1]))
def fit(o,native,size):
 lo,hi=bounds(o);target=(size[0],size[2],size[1]);s=Vector(tuple(target[i]/(hi-lo)[i] for i in range(3)));origin=Vector(((lo.x+hi.x)*.5,(lo.y+hi.y)*.5,lo.z));bake(o,Matrix.Translation(point(native))@Matrix.Diagonal((*s,1))@Matrix.Translation(-origin)@o.matrix_world)
def replace_material(o,m):o.data.materials.clear();o.data.materials.append(m)
front=-.42947;back=.40943;floor_z=.012;SX=24/.6776;SY=32/(back-front);SZ=7.2/(.1501226425-floor_z)
perimeter_fit=Matrix.Translation((0,-front*SY,-floor_z*SZ))@Matrix.Diagonal((SX,SY,SZ,1));kept=[]
pods={4:(-6.5,0,-11),7:(-6.5,0,-16),8:(-6.5,0,-21),5:(6.5,0,-11),3:(6.5,0,-16),6:(6.5,0,-21)};arches={35:(0,0,-3.5),12:(0,0,-6.5)}
for o in source:
 idx=int(o.name.rsplit('_',1)[1]);before=len(o.data.polygons)
 if idx in pods:
  fit(o,pods[idx],(2.7,2.8,2.7));o.name='PressureVessel_%d'%idx;replace_material(o,ivory);kept.append(o);records.append({'source':idx,'role':'one of six pressure vessels','target_native':pods[idx]});continue
 if idx in arches:
  fit(o,arches[idx],(4,4.2,.45));o.name='SterilizationArch_%d'%idx;replace_material(o,alloy);kept.append(o);records.append({'source':idx,'role':'one of two retained arches','target_native':arches[idx]});continue
 if idx in [36,37]:bpy.data.objects.remove(o,do_unlink=True);records.append({'source':idx,'role':'duplicate arch removed'});continue
 # Keep the generated shell. The raw reconstruction invented four arches
 # and two stairs; discard all interior architecture before a measured rebuild.
 o.data.transform(o.matrix_world);o.matrix_world.identity();bm=bmesh.new();bm.from_mesh(o.data);bm.normal_update();remove=[]
 for f in bm.faces:
  c=f.calc_center_median();q=perimeter_fit@c
  if (abs(c.x)<.29 and -.395<c.y<.38) or (c.z<.018 and abs(f.normal.z)>.8) or (abs(q.x)<1.35 and q.z<3.2 and (q.y<.8 or q.y>31.2)):remove.append(f)
 bmesh.ops.delete(bm,geom=remove,context='FACES');bm.to_mesh(o.data);bm.free();o.data.update()
 if not o.data.polygons:bpy.data.objects.remove(o,do_unlink=True);continue
 bake(o,perimeter_fit);o.name='Perimeter_%02d'%idx;replace_material(o,structure);kept.append(o);records.append({'source':idx,'role':'generated perimeter retained','faces_before':before,'faces_after':len(o.data.polygons)})
new=[]
def box(name,native,size,mat=alloy,bevel=.025):
 bpy.ops.mesh.primitive_cube_add(size=1,location=point(native));o=bpy.context.object;o.name=name;o.dimensions=(size[0],size[2],size[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 if bevel:
  m=o.modifiers.new('Precise manufactured edge radii','BEVEL');m.width=bevel;m.segments=3;bpy.ops.object.modifier_apply(modifier=m.name)
 replace_material(o,mat)
 for p in o.data.polygons:p.use_smooth=True
 m=o.modifiers.new('Weighted planar normals','WEIGHTED_NORMAL');m.keep_sharp=True;bpy.ops.object.modifier_apply(modifier=m.name);new.append(o);return o
def beam(name,a,b,width,height,mat=alloy):
 va,vb=point(a),point(b);mid=(va+vb)*.5;v=vb-va;o=box(name,(mid.x,mid.z,-mid.y),(width,height,v.length),mat,.014);o.rotation_euler=v.to_track_quat('Y','Z').to_euler();return o
def join_group(label,items):
 bpy.ops.object.select_all(action='DESELECT')
 for o in items:o.select_set(True)
 bpy.context.view_layer.objects.active=items[0];bpy.ops.object.join();o=bpy.context.object;o.name=label;return o
# The walk plane, staircase and catwalk match the existing authoritative
# colliders exactly; generated source originals remain preserved separately.
start=len(new)
for x in range(12):
 for z in range(16):box('Floor cassette',(-11+2*x,-.035,-1-2*z),(1.984,.08,1.984),floor_mat,.012)
floor=join_group('MeasuredFloor',new[start:]);kept.append(floor)
start=len(new)
for side in [-1,1]:box('Continuous side backing',(side*12.05,3.6,-16),(.08,7.2,32.2),structure,.008)
for z,half,height in [(.10,1.3,3.2),(-32.10,1.025,2.8)]:
 for side in [-1,1]:box('End wall backing',(side*(12+half)/2,3.6,z),(12-half,7.2,.08),structure,.008)
 box('Actual portal header backing',(0,(height+7.2)/2,z),(half*2,7.2-height,.08),structure,.008)
backing=join_group('MeasuredHullBacking',new[start:]);kept.append(backing)
start=len(new)
box('Catwalk deck',(0,3.1,-16),(18,.2,2.4),alloy,.04)
for z in [-14.96,-17.04]:box('Catwalk structural stringer',(0,2.95,z),(18,.24,.16),alloy,.025)
for x in [-8.6,-4.3,4.3,8.6]:box('Catwalk underdeck cross tie',(x,2.96,-16),(.16,.18,2.2),alloy,.02)
for z,left,right in [(-17.15,-9,9),(-14.85,-7.7,9)]:
 for y in [3.65,4.12]:box('Continuous safe rail',((left+right)/2,y,z),(right-left,.065,.065),alloy,.018)
 count=math.ceil((right-left)/1.5)
 for i in range(count+1):box('Rail upright',(left+(right-left)*i/count,3.66,z),(.065,1.04,.065),alloy,.014)
bridge=join_group('MeasuredCatwalkAndRails',new[start:]);kept.append(bridge)
start=len(new)
for i in range(11):box('Stair tread',(-8.5,i*.29+.15,-9.25-i*.5),(1.6,.2,.5),alloy,.018)
for x in [-9.2,-7.8]:
 beam('Stair structural stringer',(x,.0,-9.0),(x,3.0,-14.1),.12,.18)
 beam('Stair handrail',(x,1.0,-9.0),(x,4.2,-14.1),.065,.065)
 for i in range(0,11,2):box('Stair handrail upright',(x,i*.29+.68,-9.25-i*.5),(.065,1.02,.065),alloy,.012)
box('Stair landing',(-8.5,3.1,-14.7),(1.6,.2,1.2),alloy,.024)
stairs=join_group('MeasuredWestStaircase',new[start:]);kept.append(stairs)
start=len(new)
for z in [-2,-7,-12,-17,-22,-27,-31]:box('Ceiling structural beam',(0,7.01,z),(23.5,.3,.2),alloy,.025)
for x in [-9.4,9.4]:box('Longitudinal overhead service spine',(x,6.93,-16),(.24,.28,32),alloy,.025)
for z in [-4.5,-11.5,-18.5,-25.5]:
 box('Ceiling extraction cassette',(0,7.10,z),(5.5,.12,3.0),structure,.025)
 for x in [-1.65,-.55,.55,1.65]:box('Extraction slot',(x,7.033,z),(.20,.018,2.55),seal,.006)
roof=join_group('MeasuredOpenCeilingRibs',new[start:]);kept.append(roof)
# The same source includes a separate leaf for the native moving gate and a
# bezel for the existing interactive console. Neither owns gameplay state.
start=len(new);box('Gate leaf',(0,1.4,-32),(2,2.8,.2),structure,.035);gate=join_group('NativeMovingGateVisual',new[start:]);kept.append(gate)
start=len(new);box('Console pedestal',(0,3.65,-16),(.62,.9,.55),alloy,.04)
pivot=point((0,3.95,-15.62));tilt=Matrix.Rotation(-.3,4,'X')
for loc,size in [((-.48,0,0),(.06,.68,.12)),((.48,0,0),(.06,.68,.12)),((0,.33,0),(.98,.06,.12)),((0,-.33,0),(.98,.06,.12)),((0,0,-.075),(.90,.60,.045))]:
 o=box('Native display machined bezel',loc,size,alloy,.01);o.matrix_world=Matrix.Translation(pivot)@tilt@o.matrix_world
console=join_group('NativeTerminalVisual',new[start:]);kept.append(console)
# One UV domain per final mesh. The source remains high resolution for texture
# generation; a measured runtime derivative follows after material inspection.
bpy.ops.object.select_all(action='DESELECT')
for o in kept:o.select_set(True)
bpy.context.view_layer.objects.active=kept[0]
for o in kept:
 if not o.data.uv_layers:
  bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o;bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.smart_project(angle_limit=math.radians(66),island_margin=.01);bpy.ops.object.mode_set(mode='OBJECT')
bpy.ops.object.select_all(action='DESELECT')
for o in kept:o.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(P/'corrected-metric-source.glb'),export_format='GLB',use_selection=True,export_apply=True)
bpy.ops.wm.save_as_mainfile(filepath=str(P/'corrected-metric-source.blend'))
report={'scope':'One complete multiview Tripo room corrected as an editable kit;native metred floor/stair/deck/ceiling geometry replaces duplicated generated interior. All original source preserved.','roles':records,'floor_source_datums':{'front':front,'back':back,'floor':floor_z},'perimeter_fit_xyz':[SX,SY,SZ],'objects':len(kept),'triangles':sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in kept),'native_landmarks':'6pods,2arches,one west staircase,one catwalk,one console,one dynamic exit leaf','portals':'Both door leaf regions removed;native aperture rendering guard remains required before integration','runtime_accepted':False}
(P/'correction-report.json').write_text(json.dumps(report,indent=2));print('CORRECTED_WHOLE_V2_EXPORTED',report['objects'],report['triangles'])
s=bpy.context.scene;s.render.engine='BLENDER_EEVEE';s.render.resolution_x=1280;s.render.resolution_y=960;s.render.resolution_percentage=100;s.eevee.taa_render_samples=32;s.world=bpy.data.worlds.new('Metric inspection');s.world.use_nodes=True;s.world.node_tree.nodes['Background'].inputs[0].default_value=(.12,.14,.17,1);s.world.node_tree.nodes['Background'].inputs[1].default_value=.7
grey=material('Geometry inspection neutral',(.5,.53,.56),.1,.6)
for o in kept:replace_material(o,grey)
center=Vector((0,16,3.6));diag=45
for offset,energy in [((1,-2,3),450),((-2,1,3),300)]:
 bpy.ops.object.light_add(type='AREA',location=center+Vector(offset)*diag);o=bpy.context.object;o.data.energy=energy*diag*diag;o.data.shape='DISK';o.data.size=diag*3;o.rotation_euler=(center-o.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(location=center+Vector((.9,-1.4,1.6))*diag);cam=bpy.context.object;cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=43;s.camera=cam;s.render.filepath=str(P/'corrected-geometry-inspection.png');bpy.ops.render.render(write_still=True)

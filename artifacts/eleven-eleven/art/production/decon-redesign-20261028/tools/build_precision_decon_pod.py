import bpy, math, pathlib, json
from mathutils import Vector
P=pathlib.Path(r'C:\Users\yasmo\EchoNetwork\artifacts\eleven-eleven\art\production\decon-redesign-20261028\tripo')
bpy.ops.wm.read_factory_settings(use_empty=True)
def mat(name,color,metal,rough):
 m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True
 s=m.node_tree.nodes.get('Principled BSDF');s.inputs['Base Color'].default_value=(*color,1);s.inputs['Metallic'].default_value=metal;s.inputs['Roughness'].default_value=rough
 return m
ceramic=mat('Pearl ceramic enamel',(.64,.70,.73),.18,.49)
alloy=mat('Satin machined titanium',(.23,.29,.33),.72,.42)
dark=mat('Recessed graphite seals',(.035,.052,.061),.18,.65)
blue=mat('Muted blue instrument polymer',(.035,.24,.30),.15,.46)
def finish(o,m,bevel=0):
 o.data.materials.append(m)
 if bevel:
  mod=o.modifiers.new('Manufactured edge radii','BEVEL');mod.width=bevel;mod.segments=3
  bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=mod.name)
 for p in o.data.polygons:p.use_smooth=True
 mod=o.modifiers.new('Area weighted planar normals','WEIGHTED_NORMAL');mod.keep_sharp=True;mod.weight=50
 bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=mod.name)
 return o
def lathe(name,profile,m):
 # Closed profile, no overlapping stacked cylinder faces. UVs follow the sweep.
 n=96;vs=[(r*math.cos(i*math.tau/n),r*math.sin(i*math.tau/n),z) for r,z in profile for i in range(n)];faces=[]
 for j in range(len(profile)):
  for i in range(n):faces.append((j*n+i,j*n+(i+1)%n,((j+1)%len(profile))*n+(i+1)%n,((j+1)%len(profile))*n+i))
 mesh=bpy.data.meshes.new(name);mesh.from_pydata(vs,[],faces);mesh.update();o=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(o)
 finish(o,m,.008);return o
def box(name,loc,scale,m,b=.02,angle=0):
 bpy.ops.mesh.primitive_cube_add(size=1,location=loc);o=bpy.context.object;o.name=name;o.dimensions=scale;o.rotation_euler.z=angle;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);finish(o,m,b);return o
lathe('Continuous lower pressure casting',[(.94,.10),(.94,.27),(1.05,.31),(1.26,.31),(1.34,.23),(1.34,.10),(1.26,.035),(1.02,.035)],ceramic)
lathe('Lower recessed circumferential seal',[(1.265,.118),(1.348,.118),(1.348,.154),(1.265,.154)],dark)
lathe('Upper annular pressure head',[(.96,2.51),(.96,2.70),(1.06,2.79),(1.24,2.79),(1.34,2.70),(1.34,2.56),(1.27,2.50),(1.05,2.50)],ceramic)
lathe('Upper head service seam',[(1.27,2.636),(1.348,2.636),(1.348,2.67),(1.27,2.67)],dark)
lathe('Upper inner compression lip',[(.955,2.49),(1.025,2.49),(1.025,2.54),(.955,2.54)],alloy)
lathe('Lower inner compression lip',[(.95,.27),(1.025,.27),(1.025,.33),(.95,.33)],alloy)
bpy.ops.mesh.primitive_cylinder_add(vertices=96,radius=.975,depth=.06,location=(0,0,.245));finish(bpy.context.object,alloy,.012);bpy.context.object.name='Interior removable sterilization deck'
lathe('Interior deck perimeter channel',[(.83,.279),(.87,.279),(.87,.289),(.83,.289)],dark)
for i in range(4):
 a=math.pi/4+i*math.pi/2;c,s=math.cos(a),math.sin(a)
 # A single tapered machined rib with a straight inner glass seat.
 profile=[(.93,.27),(1.20,.27),(1.23,.40),(1.12,.63),(1.12,2.27),(1.23,2.47),(1.20,2.55),(.93,2.55)]
 vs=[]
 for y in [-.083,.083]:
  for r,z in profile:vs.append((r*c-y*s,r*s+y*c,z))
 L=len(profile);faces=[tuple(range(L-1,-1,-1)),tuple(range(L,2*L))]+[(j,(j+1)%L,(j+1)%L+L,j+L) for j in range(L)]
 me=bpy.data.meshes.new('Rib');me.from_pydata(vs,[],faces);me.update();o=bpy.data.objects.new('Straight pressure rib %02d'%i,me);bpy.context.collection.objects.link(o);finish(o,ceramic,.022)
 box('Recessed rib service panel %02d'%i,(1.126*c,1.126*s,1.44),(.023,.108,1.35),dark,.009,a)
 for z in [.44,2.39]:
  bpy.ops.mesh.primitive_cylinder_add(vertices=16,radius=.036,depth=.014,location=(1.205*c,1.205*s,z),rotation=(0,math.pi/2,a));finish(bpy.context.object,alloy,.004);bpy.context.object.name='Captive rib fastener'
# Rear service spine is integrated behind the clear chamber, not a floating prop.
box('Rear filtration service spine',(0,.998,1.40),(.43,.29,2.12),alloy,.05)
box('Rear ceramic service access',(0,1.154,1.48),(.34,.075,1.66),ceramic,.025)
for z in [.72,.84,.96,1.08,1.20]:box('Recessed return-air slot',(0,1.197,z),(.24,.014,.035),dark,.012)
# One inset front fascia below the actual glass; does not invent an interaction.
box('Front instrument bezel',(0,-1.264,.205),(.45,.11,.16),alloy,.025)
box('Front passive instrument inset',(0,-1.323,.21),(.33,.016,.067),blue,.012)
for i in range(8):
 a=i*math.tau/8
 for z in [.32,2.495]:
  bpy.ops.mesh.primitive_uv_sphere_add(segments=12,ring_count=6,radius=.028,location=(1.16*math.cos(a),1.16*math.sin(a),z));o=bpy.context.object;o.name='Flush pressure-head captive screw';o.scale.z=.27;finish(o,alloy)
meshes=[o for o in bpy.data.objects if o.type=='MESH'];bpy.ops.object.select_all(action='DESELECT')
for o in meshes:o.select_set(True)
bpy.context.view_layer.objects.active=meshes[0];bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.smart_project(angle_limit=math.radians(66),island_margin=.012);bpy.ops.object.mode_set(mode='OBJECT')
tri=sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in meshes)
bpy.ops.export_scene.gltf(filepath=str(P/'precision-pod-authored-source.glb'),export_format='GLB',use_selection=True,export_apply=True)
bpy.ops.wm.save_as_mainfile(filepath=str(P/'precision-pod-authored-source.blend'))
(P/'precision-pod-authored-report.json').write_text(json.dumps({'scope':'Authored rigid pressure vessel;glass stays native;not a Tripo geometry regeneration','units':'metres','bounds_expected':[2.696,2.696,2.80],'mesh_objects':len(meshes),'triangles':tri,'closed_profile_castings':True,'uv':'Explicit smart projection;4 material zones','no_rig_or_gameplay_change':True},indent=2))
# Actual orthographic views of this same mesh, for coherent reference inspection.
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=16;scene.cycles.use_denoising=True;scene.render.resolution_x=768;scene.render.resolution_y=768;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('Neutral studio');scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.16,.18,.2,1);scene.world.node_tree.nodes['Background'].inputs[1].default_value=.5
for loc,energy,size in [((3,-4,6),700,5),((-4,-1,4),450,4),((1,4,5),650,3)]:
 bpy.ops.object.light_add(type='AREA',location=loc);o=bpy.context.object;o.data.energy=energy;o.data.shape='DISK';o.data.size=size;o.rotation_euler=(Vector((0,0,1.4))-o.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add();cam=bpy.context.object;scene.camera=cam;cam.data.type='ORTHO';cam.data.ortho_scale=3.6
for label,loc in [('front',(0,-7,3.0)),('left',(-7,0,3.0)),('right',(7,0,3.0)),('back',(0,7,3.0))]:
 cam.location=loc;cam.rotation_euler=(Vector((0,0,1.4))-cam.location).to_track_quat('-Z','Y').to_euler();scene.render.filepath=str(P/('precision-pod-'+label+'.png'));bpy.ops.render.render(write_still=True)
print('PRECISION_POD_EXPORTED',tri)

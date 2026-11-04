from pathlib import Path
import bpy,json,hashlib,sys
from mathutils import Vector
p=Path(__file__).resolve().parents[1];out=p/'facial';out.mkdir(exist_ok=True)
app=p.parents[2];sys.path.insert(0,str(app/'tools/animation-library'))
from golden_reference import verify
verify();source=p/'source/echo-school-rig-metric.blend';bpy.ops.wm.open_mainfile(filepath=str(source))
rig=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE');body=next(o for o in bpy.context.scene.objects if o.type=='MESH' and any(m.type=='ARMATURE' and m.object==rig for m in o.modifiers))
points=[body.matrix_world@v.co for v in body.data.vertices];head=[i for i,v in enumerate(points) if v.z>1.48]
report={'status':'INSPECTED_NO_FACE_CONTROLS_YET','source_blend_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'body':body.name,'vertices':len(points),'head_region_vertices':len(head),'head_region_bounds':{'min':[min(points[i][k] for i in head) for k in range(3)],'max':[max(points[i][k] for i in head) for k in range(3)]},'shape_names':[k.name for k in body.data.shape_keys.key_blocks] if body.data.shape_keys else [],'rig_bones':list(rig.data.bones.keys()),'original_source_unchanged':True,'runtime_replaced':False,'requirement':'Actual jaw/lip/mouth-cavity/cheek/brow/eyelid controls;body animation is not facial laughter.'}
(out/'topology-inspection.json').write_text(json.dumps(report,indent=2)+'\n')
for mat in body.data.materials:mat.diffuse_color=(.65,.68,.72,1)
import shutil
prior=out/'modifier-wire-diagnostic';prior.mkdir(exist_ok=True)
for name in ['front','three-quarter']:
 f=out/f'topology-{name}.png'
 if f.exists() and not (prior/f.name).exists():shutil.copy2(f,prior/f.name)
# Explicit world-space edge curves avoid wireframe miters on imported UV-split triangles.
curve=bpy.data.curves.new('InspectionHeadEdges','CURVE');curve.dimensions='3D';curve.resolution_u=1;curve.bevel_depth=.000025;curve.bevel_resolution=0
unique=set()
for edge in body.data.edges:
 a,b=(points[i] for i in edge.vertices)
 if min(a.z,b.z)<1.48 or (a-b).length>.018:continue
 key=tuple(sorted(tuple(round(x,6) for x in v) for v in [a,b]))
 if key in unique:continue
 unique.add(key);s=curve.splines.new('POLY');s.points.add(1);s.points[0].co=(*a,1);s.points[1].co=(*b,1)
wire=bpy.data.objects.new('TopologyEdges_InspectionOnly',curve);bpy.context.scene.collection.objects.link(wire);mat=bpy.data.materials.new('InspectionWire');mat.diffuse_color=(.018,.022,.029,1);curve.materials.append(mat)
scene=bpy.context.scene;scene.render.engine='BLENDER_WORKBENCH';scene.render.resolution_x=900;scene.render.resolution_y=1100;scene.render.resolution_percentage=100;scene.display.shading.color_type='MATERIAL';scene.display.shading.light='STUDIO';scene.display.shading.show_cavity=True
if scene.world is None:scene.world=bpy.data.worlds.new('InspectionWorld')
scene.world.color=(.055,.065,.08)
data=bpy.data.cameras.new('FaceTopologyReview');camera=bpy.data.objects.new('FaceTopologyReview',data);scene.collection.objects.link(camera);scene.camera=camera;data.type='ORTHO';data.ortho_scale=.30
for name,pos in [('front',(0,-3,1.635)),('three-quarter',(.95,-3,1.635))]:
 camera.location=pos;camera.rotation_euler=(Vector((.003,0,1.635))-camera.location).to_track_quat('-Z','Y').to_euler();scene.render.filepath=str(out/f'topology-{name}.png');bpy.ops.render.render(write_still=True)
bpy.ops.wm.save_as_mainfile(filepath=str(out/'topology-inspection.blend'));verify();print('FACE_TOPOLOGY_INSPECTED',len(head),'head-region vertices;zero expressions;source unchanged')

from pathlib import Path
import bpy,numpy as np,json
from mathutils import Vector
p=Path(__file__).resolve().parents[1];out=p/'facial';bpy.ops.wm.open_mainfile(filepath=str(p/'source/echo-school-rig-metric.blend'))
rig=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE');body=next(o for o in bpy.context.scene.objects if o.type=='MESH' and any(m.type=='ARMATURE' and m.object==rig for m in o.modifiers));mesh=body.data
data=np.load(out/'component-assignments.npz');comp=data['vertex_component'];points=data['world_points'];report=json.loads((out/'component-audit.json').read_text());ids=[r['component'] for r in report['head_components'] if r['component']!=30]
colors=[(.9,.2,.2,1),(.15,.7,.3,1),(.15,.4,1,1),(.9,.65,.1,1),(.7,.2,.85,1),(.1,.8,.8,1)]
mesh.materials.clear();base=bpy.data.materials.new('Main30');base.diffuse_color=(.55,.58,.63,1);mesh.materials.append(base);slots={30:0}
for i,cid in enumerate(ids):
 mat=bpy.data.materials.new(f'Component_{cid}');mat.diffuse_color=colors[i%len(colors)];slots[cid]=len(mesh.materials);mesh.materials.append(mat)
for poly in mesh.polygons:poly.material_index=slots.get(int(comp[poly.vertices[0]]),0)
scene=bpy.context.scene;scene.render.engine='BLENDER_WORKBENCH';scene.render.resolution_x=900;scene.render.resolution_y=1000;scene.render.resolution_percentage=100;scene.display.shading.color_type='MATERIAL';scene.display.shading.show_cavity=True
if not scene.world:scene.world=bpy.data.worlds.new('ComponentReviewWorld')
scene.world.color=(.045,.055,.07);camera_data=bpy.data.cameras.new('ComponentReview');camera=bpy.data.objects.new('ComponentReview',camera_data);scene.collection.objects.link(camera);scene.camera=camera;camera_data.type='ORTHO';camera_data.ortho_scale=.19;camera.location=(0,-3,1.582);camera.rotation_euler=(Vector((.003,0,1.582))-camera.location).to_track_quat('-Z','Y').to_euler()
scene.render.filepath=str(out/'components-front.png');bpy.ops.render.render(write_still=True)
# A separate static cutaway reveals existing mouth/eye islands without changing source topology.
body.hide_render=True;selected=set(ids);indices=[i for i,c in enumerate(comp) if int(c) in selected];mapping={i:j for j,i in enumerate(indices)};faces=[];face_ids=[]
for poly in mesh.polygons:
 if int(comp[poly.vertices[0]]) in selected:
  faces.append([mapping[i] for i in poly.vertices]);face_ids.append(int(comp[poly.vertices[0]]))
cut_mesh=bpy.data.meshes.new('CutawayParts');cut_mesh.from_pydata([points[i].tolist() for i in indices],[],faces);cut=bpy.data.objects.new('CutawayParts',cut_mesh);scene.collection.objects.link(cut)
for mat in mesh.materials:cut_mesh.materials.append(mat)
for poly,cid in zip(cut_mesh.polygons,face_ids):poly.material_index=slots[cid];poly.use_smooth=True
scene.render.filepath=str(out/'components-cutaway.png');bpy.ops.render.render(write_still=True)
(out/'component-color-key.json').write_text(json.dumps({str(cid):{'rgba':list(mesh.materials[slot].diffuse_color),'slot':slot} for cid,slot in slots.items()},indent=2)+'\n');print('FACIAL_COMPONENTS_RENDERED')

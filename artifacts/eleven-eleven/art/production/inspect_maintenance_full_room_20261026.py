import bpy,json,hashlib
from pathlib import Path
from mathutils import Vector
import numpy as np
A=Path(__file__).resolve().parents[2];P=A/'art/production/maintenance-refinement-20261025'
src=P/'full-room-h31-raw-2m.glb';assert src.exists(),'Wait for the actual completed source download'
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(src))
meshes=[o for o in bpy.context.scene.objects if o.type=='MESH'];bounds=[];vertex_count=0;triangles=0
for o in meshes:
 data=np.empty(len(o.data.vertices)*3,dtype=np.float32);o.data.vertices.foreach_get('co',data);data=data.reshape(-1,3)
 matrix=np.array(o.matrix_world,dtype=np.float64);world=data@matrix[:3,:3].T+matrix[:3,3]
 bounds.append((world.min(axis=0),world.max(axis=0)));vertex_count+=len(o.data.vertices)
 o.data.calc_loop_triangles();triangles+=len(o.data.loop_triangles)
lo=Vector(tuple(min(b[0][i] for b in bounds) for i in range(3)));hi=Vector(tuple(max(b[1][i] for b in bounds) for i in range(3)));extent=hi-lo;centre=(hi+lo)*.5
report={'source':src.name,'source_sha256':hashlib.sha256(src.read_bytes()).hexdigest(),'meshes':len(meshes),'triangles':triangles,'vertices':vertex_count,'blender_min':list(lo),'blender_max':list(hi),'blender_extent':list(extent),'native_target_width_depth_height':[10.2,15,10.6],'scope':'Actual untextured full-room shape only;the image and source normalized proportions are NOT native dimensional proof;measured derivative/player/art remain OPEN'}
assert triangles==1913491,'Unexpected raw topology'
scene=bpy.context.scene;scene.render.engine='BLENDER_WORKBENCH';scene.render.resolution_x=1024;scene.render.resolution_y=1024;scene.render.resolution_percentage=100
shade=scene.display.shading;shade.light='STUDIO';shade.color_type='SINGLE';shade.single_color=(.46,.51,.54);shade.show_cavity=True;shade.cavity_type='BOTH';shade.show_shadows=True
bpy.ops.object.camera_add();camera=bpy.context.object;camera.data.type='ORTHO';camera.data.ortho_scale=max(extent)*1.42;scene.camera=camera
for name,direction in [('front-left',Vector((-1.6,-2.0,1.6))),('front-right',Vector((1.6,-2.0,1.6))),('front',Vector((0,-3,.3))),('rear',Vector((0,3,.3))),('top',Vector((0,.001,3)))]:
 camera.location=centre+direction*max(extent);camera.rotation_euler=(centre-camera.location).to_track_quat('-Z','Y').to_euler();scene.render.filepath=str(P/('raw-'+name+'.png'));bpy.ops.render.render(write_still=True)
bpy.ops.wm.save_as_mainfile(filepath=str(P/'full-room-raw-inspection-editable.blend'))
(P/'raw-geometry-review.json').write_text(json.dumps(report,indent=2),encoding='utf-8');print('MAINTENANCE_RAW_GEOMETRY',json.dumps(report))

import bpy,json,hashlib
from pathlib import Path
from mathutils import Vector
A=Path(__file__).resolve().parents[2];P=A/'art/production/archive-refinement-20261025'
bpy.ops.wm.read_factory_settings(use_empty=True)
src=P/'core-h31-raw.glb';bpy.ops.import_scene.gltf(filepath=str(src))
meshes=[o for o in bpy.context.scene.objects if o.type=='MESH'];points=[o.matrix_world@v.co for o in meshes for v in o.data.vertices]
lo=Vector(tuple(min(v[i] for v in points) for i in range(3)));hi=Vector(tuple(max(v[i] for v in points) for i in range(3)));centre=(lo+hi)/2;extent=hi-lo
tri=0
for o in meshes:o.data.calc_loop_triangles();tri+=len(o.data.loop_triangles)
scene=bpy.context.scene;scene.render.engine='BLENDER_WORKBENCH';scene.render.resolution_x=768;scene.render.resolution_y=768;scene.render.resolution_percentage=100
scene.display.shading.light='STUDIO';scene.display.shading.color_type='SINGLE';scene.display.shading.single_color=(.43,.51,.58);scene.display.shading.show_cavity=True;scene.display.shading.cavity_type='BOTH';scene.display.shading.show_shadows=True
bpy.ops.object.camera_add();camera=bpy.context.object;camera.data.type='ORTHO';camera.data.ortho_scale=max(extent)*1.40;camera.location=centre+Vector((1.6,-2.0,1.6))*max(extent);camera.rotation_euler=(centre-camera.location).to_track_quat('-Z','Y').to_euler();scene.camera=camera
scene.render.filepath=str(P/'raw-geometry-review.png');bpy.ops.render.render(write_still=True)
report={'file':src.name,'sha256':hashlib.sha256(src.read_bytes()).hexdigest(),'meshes':len(meshes),'triangles':tri,'blender_extent':list(extent),'bottom':list(lo),'top':list(hi),'source_pivot':list(centre),'scope':'Raw untextured geometry silhouette review;dimensions will be fitted to native pedestal;not game art acceptance'}
(P/'raw-geometry-review.json').write_text(json.dumps(report,indent=2),encoding='utf8');print('RAW_ARCHIVE_BASE',json.dumps(report))

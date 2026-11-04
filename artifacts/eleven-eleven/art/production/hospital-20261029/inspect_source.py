import bpy,json,pathlib,math
from mathutils import Vector
P=pathlib.Path(r'C:\Users\yasmo\EchoNetwork\artifacts\eleven-eleven\art\production\hospital-20261029')
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(P/'source/headwall-p2-raw.glb'))
meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
points=[o.matrix_world@Vector(v) for o in meshes for v in o.bound_box]
low=Vector(tuple(min(p[i] for p in points) for i in range(3)));high=Vector(tuple(max(p[i] for p in points) for i in range(3)))
records=[]
for obj in meshes:
 obj.data.calc_loop_triangles();records.append({'name':obj.name,'vertices':len(obj.data.vertices),'faces':len(obj.data.polygons),'triangles':len(obj.data.loop_triangles),'materials':[m.name if m else None for m in obj.data.materials]})
(P/'source/raw-inspection.json').write_text(json.dumps({'bounds_min':list(low),'bounds_max':list(high),'dimensions_blender_xyz':list(high-low),'meshes':records},indent=2),encoding='utf-8')
scene=bpy.context.scene;scene.render.engine='BLENDER_WORKBENCH';scene.render.resolution_x=900;scene.render.resolution_y=1000;scene.render.resolution_percentage=100
scene.display.shading.light='STUDIO';scene.display.shading.color_type='SINGLE';scene.display.shading.single_color=(.42,.44,.48);scene.display.shading.show_shadows=True;scene.display.shading.show_cavity=True;scene.display.shading.cavity_type='BOTH'
bpy.ops.object.camera_add();camera=bpy.context.object;camera.data.type='ORTHO';camera.data.ortho_scale=max(high-low)*1.35;scene.camera=camera
center=(high+low)*.5;distance=max(high-low)*3.5
for name,vector in [('front',Vector((.14,-1,.12))),('back',Vector((-.14,1,.12)))]:
 camera.location=center+vector.normalized()*distance;camera.rotation_euler=(center-camera.location).to_track_quat('-Z','Y').to_euler();scene.render.filepath=str(P/'source'/f'{name}-geometry.png');bpy.ops.render.render(write_still=True)
print('SOURCE_INSPECTED',json.dumps(records))

import bpy,json,hashlib,math
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
A=Path(__file__).resolve().parents[2];P=A/'art/production/reactor-refinement-20261025'
bpy.ops.wm.read_factory_settings(use_empty=True)
src=P/'crown-h31-raw.glb';bpy.ops.import_scene.gltf(filepath=str(src))
meshes=[o for o in bpy.context.scene.objects if o.type=='MESH'];points=[];faces=[]
for o in meshes:
 offset=len(points);points.extend(o.matrix_world@v.co for v in o.data.vertices)
 o.data.calc_loop_triangles();faces.extend(tuple(offset+i for i in t.vertices) for t in o.data.loop_triangles)
lo=Vector(tuple(min(v[i] for v in points) for i in range(3)));hi=Vector(tuple(max(v[i] for v in points) for i in range(3)));centre=(lo+hi)/2;extent=hi-lo
radii=[math.hypot(v.x-centre.x,v.y-centre.y) for v in points]
tree=BVHTree.FromPolygons(points,faces,all_triangles=True)
hole_rays=[]
for x,y in [(0,0),(.10,0),(-.10,0),(0,.10),(0,-.10)]:
 origin=Vector((centre.x+x*max(radii),centre.y+y*max(radii),hi.z+1))
 hit=tree.ray_cast(origin,Vector((0,0,-1)),extent.z+2)[0]
 hole_rays.append({'fraction_xy':[x,y],'clear':hit is None})
report={'source':src.name,'sha256':hashlib.sha256(src.read_bytes()).hexdigest(),'meshes':len(meshes),'triangles':len(faces),'bounds_min':list(lo),'bounds_max':list(hi),'extent_blender':list(extent),'centre':list(centre),'radius_min':min(radii),'radius_max':max(radii),'central_axis_rays':hole_rays,'scope':'Actual raw shape and open annular centre only;not measured derivative or native art acceptance'}
(P/'raw-geometry-review.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
assert all(r['clear'] for r in hole_rays),'Generated crown has an unwanted centre closure'
assert min(radii)>.15*max(radii) and extent.z<max(extent.x,extent.y)*.30,'Not a shallow horizontal annulus'
scene=bpy.context.scene;scene.render.engine='BLENDER_WORKBENCH';scene.render.resolution_x=768;scene.render.resolution_y=768;scene.render.resolution_percentage=100
scene.display.shading.light='STUDIO';scene.display.shading.color_type='SINGLE';scene.display.shading.single_color=(.43,.51,.58);scene.display.shading.show_cavity=True;scene.display.shading.cavity_type='BOTH';scene.display.shading.show_shadows=True
bpy.ops.object.camera_add();camera=bpy.context.object;camera.data.type='ORTHO';camera.data.ortho_scale=max(extent)*1.38;scene.camera=camera
for name,direction in [('threequarter',Vector((1.6,-2.0,1.7))),('top',Vector((0,.001,3)))]:
 camera.location=centre+direction*max(extent);camera.rotation_euler=(centre-camera.location).to_track_quat('-Z','Y').to_euler();scene.render.filepath=str(P/('raw-'+name+'.png'));bpy.ops.render.render(write_still=True)
print('RAW_REACTOR_CROWN',json.dumps(report))

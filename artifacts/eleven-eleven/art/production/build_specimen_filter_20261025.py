"""Fit the accepted Tripo derivative to the original native cover volume."""
import bpy,json,hashlib
from pathlib import Path
from mathutils import Vector
APP=Path(__file__).resolve().parents[2]
P=APP/'art/production/specimen-refinement-20261025'
SOURCE=P/'filter-h31-pbr4k.glb'
OUT=APP/'godot/assets/environments/specimen_cp45/specimen_filter_h31_pbr4k.glb'
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(SOURCE))
meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
assert len(meshes)==1,'Reinspect unexpected mesh structure'
o=meshes[0]
bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o
bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
points=[v.co.copy() for v in o.data.vertices]
lo=Vector(tuple(min(p[i] for p in points) for i in range(3)));hi=Vector(tuple(max(p[i] for p in points) for i in range(3)))
extent=hi-lo;center=(lo+hi)*.5
assert .94<extent.x<1.03 and .6<extent.y<.72 and .72<extent.z<.82,'Provider changed reviewed raw orientation/proportions'
factor=Vector((2.2/extent.x,1.4/extent.y,1.8/extent.z))
for v in o.data.vertices:v.co=Vector(((v.co.x-center.x)*factor.x,(v.co.y-center.y)*factor.y,(v.co.z-lo.z)*factor.z))
o.name='SpecimenFilterH31Measured'
o.data.calc_loop_triangles();tri=len(o.data.loop_triangles)
assert tri==19635 and len(o.data.materials)==1
images=[]
bs=next(n for n in o.data.materials[0].node_tree.nodes if n.type=='BSDF_PRINCIPLED')
def image_upstream(socket):
 if not socket.is_linked:return None
 node=socket.links[0].from_node
 if node.type=='TEX_IMAGE':return node.image
 for inp in node.inputs:
  im=image_upstream(inp)
  if im:return im
 return None
for role,socket in [('basecolor','Base Color'),('normal','Normal'),('rm','Roughness')]:
 image=image_upstream(bs.inputs[socket]);assert image,'Missing mapped '+role
 images.append({'source_name':image.name,'role':role,'width':image.size[0],'height':image.size[1]})
 image.name='specimen_filter_'+role+'_'+str(image.size[0])
assert len(images)==3
assert all(i['width']==4096 and i['height']==4096 for i in images if i['role']!='normal'),'Expected original4K base/RM maps'
assert images[1]['width']==2048 and images[1]['height']==2048,'Reinspect changed provider normal-map output'
o.data.materials[0].name='SpecimenFilterCleanPBR'
bpy.ops.wm.save_as_mainfile(filepath=str(P/'specimen-filter-measured.blend'))
bpy.ops.export_scene.gltf(filepath=str(OUT),export_format='GLB',use_selection=True,export_animations=False,export_yup=True)
report={'source':SOURCE.name,'source_sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),'output':str(OUT.relative_to(APP)).replace('\\','/'),'output_sha256':hashlib.sha256(OUT.read_bytes()).hexdigest(),'triangles':tri,'surfaces':1,'target_native_m':[2.2,1.8,1.4],'pivot':'bottom centre; native+Z service doors','source_blender_extent':list(extent),'blender_scale':list(factor),'images':images,'scope':'Visual-only measured fitting; raw source retained. No physics,interaction,scanner or story changes. Native visual review pending.'}
(P/'filter-derivative-build.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print('SPECIMEN_FILTER_BUILT',json.dumps(report))

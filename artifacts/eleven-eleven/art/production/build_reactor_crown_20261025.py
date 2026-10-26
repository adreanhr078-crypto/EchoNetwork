"""Measured annular derivative of the retained full-detail Tripo crown.
Radial remap fits the core while explicitly transforming custom normals with
the inverse-transpose Jacobian. Original source,topology,UVs/maps are retained.
"""
import bpy,json,hashlib,math
from pathlib import Path
from mathutils import Vector
A=Path(__file__).resolve().parents[2];P=A/'art/production/reactor-refinement-20261025'
src=P/'crown-h31-pbr4k.glb';out=A/'godot/assets/environments/reactor_cp45/reactor_crown_pbr4k.glb';out.parent.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.scene.unit_settings.system='METRIC'
bpy.ops.import_scene.gltf(filepath=str(src));objects=[o for o in bpy.context.scene.objects if o.type=='MESH']
assert len(objects)==1,'Changed provider geometry structure needs review'
o=objects[0];bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o
bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
points=[v.co.copy() for v in o.data.vertices]
lo=Vector(tuple(min(v[i] for v in points) for i in range(3)));hi=Vector(tuple(max(v[i] for v in points) for i in range(3)));centre=(lo+hi)/2;extent=hi-lo
assert .94<extent.x<1.03 and .94<extent.y<1.03 and .07<extent.z<.14,'Source axes or shape changed'
radii=[math.hypot(v.x-centre.x,v.y-centre.y) for v in points];rmin=min(radii);rmax=max(radii)
assert .20<rmin<.30 and .47<rmax<.52,'Source annulus needs fresh geometry inspection'
radial_scale=(4.75-4.125)/(rmax-rmin);radial_offset=4.125-radial_scale*rmin;vertical_scale=.60/extent.z
old_normals=[n.vector.copy() for n in o.data.corner_normals];mapped_normals=[]
for loop,normal in zip(o.data.loops,old_normals):
 p=points[loop.vertex_index];r=radii[loop.vertex_index];u=Vector(((p.x-centre.x)/r,(p.y-centre.y)/r,0))
 nr=u*normal.dot(u);nz=Vector((0,0,normal.z));nt=normal-nr-nz
 tangent_scale=radial_scale+radial_offset/r
 mapped_normals.append((nr/radial_scale+nt/tangent_scale+nz/vertical_scale).normalized())
for vertex,p,r in zip(o.data.vertices,points,radii):
 scale=(radial_scale*r+radial_offset)/r
 vertex.co=Vector(((p.x-centre.x)*scale,(p.y-centre.y)*scale,(p.z-lo.z)*vertical_scale))
o.data.update();o.data.normals_split_custom_set(mapped_normals)
o.data.calc_loop_triangles();triangles=len(o.data.loop_triangles)
assert triangles==196054 and len(o.data.materials)==1
actual_r=[math.hypot(v.co.x,v.co.y) for v in o.data.vertices]
assert min(actual_r)>=4.12499 and max(actual_r)<=4.75001
assert min(v.co.z for v in o.data.vertices)>=-.00001 and max(v.co.z for v in o.data.vertices)<=.60001
o.name='ReactorCrownMeasuredFullDetail';o.data.materials[0].name='ReactorCrownPBR4K'
bs=next(n for n in o.data.materials[0].node_tree.nodes if n.type=='BSDF_PRINCIPLED')
def upstream(socket):
 if not socket.is_linked:return None
 node=socket.links[0].from_node
 if node.type=='TEX_IMAGE':return node.image
 for inp in node.inputs:
  image=upstream(inp)
  if image:return image
 return None
images=[]
for role,key in [('basecolor','Base Color'),('normal','Normal'),('rm','Roughness')]:
 image=upstream(bs.inputs[key]);assert image,'Missing actual PBR map:'+role
 images.append({'role':role,'size':list(image.size)});image.name='reactor_crown_'+role+'_'+str(image.size[0])
assert all(im['size']==[4096,4096] for im in images),'Preserve actual map dimensions;do not claim4K until allverified'
bpy.ops.wm.save_as_mainfile(filepath=str(P/'reactor-crown-measured-editable.blend'))
bpy.ops.export_scene.gltf(filepath=str(out),export_format='GLB',use_selection=True,export_animations=False,export_yup=True,export_tangents=True)
report={'source':src.name,'source_sha256':hashlib.sha256(src.read_bytes()).hexdigest(),'output':str(out.relative_to(A)).replace('\\','/'),'output_sha256':hashlib.sha256(out.read_bytes()).hexdigest(),'triangles':triangles,'surfaces':1,'measured_metres':{'outer_diameter':9.5,'inner_clear_diameter':8.25,'height':.6},'actual_radius_min_max':[min(actual_r),max(actual_r)],'source_extent':list(extent),'source_radius_min_max':[rmin,rmax],'radial_scale':radial_scale,'radial_offset':radial_offset,'height_scale':vertical_scale,'normal_transform':'Explicit inverse-transpose radial Jacobian;loop normals/UV topology preserved;new tangent basis exported','pivot':'Bottom centre;GodotYup','images':images,'scope':'Measured visual annulus inside original4.8m collider,no newphysics;radialcompression changes fastener proportions,not exact image reconstruction. Actual native art/LOD/play acceptance separate.'}
(P/'crown-derivative-build.json').write_text(json.dumps(report,indent=2),encoding='utf-8');print('REACTOR_CROWN_BUILT',json.dumps(report))

"""Fit the retained full-detail Tripo source to the original archive base."""
import bpy,json,hashlib,math
from pathlib import Path
from mathutils import Vector
A=Path(__file__).resolve().parents[2];P=A/'art/production/archive-refinement-20261025'
src=P/'core-h31-pbr4k.glb';out=A/'godot/assets/environments/archive_cp45/archive_core_base_pbr4k.glb';out.parent.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.scene.unit_settings.system='METRIC';bpy.ops.import_scene.gltf(filepath=str(src))
objects=[o for o in bpy.context.scene.objects if o.type=='MESH'];assert len(objects)==1,'Inspect changed provider object structure'
o=objects[0];bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o;bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
points=[v.co.copy() for v in o.data.vertices];lo=Vector(tuple(min(v[i] for v in points) for i in range(3)));hi=Vector(tuple(max(v[i] for v in points) for i in range(3)));extent=hi-lo;centre=(lo+hi)*.5
assert .94<extent.x<1.03 and .94<extent.y<1.03 and .20<extent.z<.32,'Source axes/silhouette changed;review before fitting'
radius=max(math.hypot(v.x-centre.x,v.y-centre.y) for v in points);sx=2.8/radius;sz=1.0/extent.z
# Apply a genuine object transform so imported custom normals receive its
# inverse transpose. Uniform XY preserves the manufactured radial symmetry.
o.scale=Vector((sx,sx,sz));o.location=Vector((-centre.x*sx,-centre.y*sx,-lo.z*sz));bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
o.name='ArchiveCoreFullDetailMeasured';o.data.calc_loop_triangles();tri=len(o.data.loop_triangles);assert tri==195893 and len(o.data.materials)==1
max_radius=max(math.hypot(v.co.x,v.co.y) for v in o.data.vertices);top_radius=max(math.hypot(v.co.x,v.co.y) for v in o.data.vertices if v.co.z>.94)
assert max_radius<=2.80001 and .995<=max(v.co.z for v in o.data.vertices)<=1.00001
assert top_radius<=2.65,'Top shoulder needs explicit review against native2.5m top radius'
bs=next(n for n in o.data.materials[0].node_tree.nodes if n.type=='BSDF_PRINCIPLED')
def upstream(socket):
 if not socket.is_linked:return None
 node=socket.links[0].from_node
 if node.type=='TEX_IMAGE':return node.image
 for inp in node.inputs:
  im=upstream(inp)
  if im:return im
 return None
images=[]
for role,key in [('basecolor','Base Color'),('normal','Normal'),('rm','Roughness')]:
 im=upstream(bs.inputs[key]);assert im,'Missing actual PBR map:'+role
 images.append({'role':role,'original_name':im.name,'width':im.size[0],'height':im.size[1]});im.name='archive_core_'+role+'_'+str(im.size[0])
assert all(x['width']==4096 and x['height']==4096 for x in images if x['role']!='normal')
assert next(x for x in images if x['role']=='normal')['width']>=2048
o.data.materials[0].name='ArchiveCoreFullDetailPBR';bpy.ops.wm.save_as_mainfile(filepath=str(P/'archive-core-measured-editable.blend'))
bpy.ops.export_scene.gltf(filepath=str(out),export_format='GLB',use_selection=True,export_animations=False,export_yup=True)
report={'source':src.name,'source_sha256':hashlib.sha256(src.read_bytes()).hexdigest(),'output':str(out.relative_to(A)).replace('\\','/'),'output_sha256':hashlib.sha256(out.read_bytes()).hexdigest(),'triangles':tri,'surfaces':1,'native_collider':{'radius':2.8,'height':1.0,'unchanged':True},'source_blender_extent':list(extent),'uniform_xy_scale':sx,'height_scale':sz,'actual_max_radius':max_radius,'actual_top_band_radius':top_radius,'native_visual_top_radius':2.5,'pivot':'bottom centre;Godot Y up','images':images,'lod':'Request native Godot generated mesh LODs;actual imported LODs not yet verified','scope':'Measured full-detail visual derivative;uniform radial fit with independent native height. Original195893 triangles andUV/source maps retained. Not exact reconstruction of the image or native art/player acceptance.'}
(P/'core-derivative-build.json').write_text(json.dumps(report,indent=2),encoding='utf8');print('ARCHIVE_CORE_BUILT',json.dumps(report))

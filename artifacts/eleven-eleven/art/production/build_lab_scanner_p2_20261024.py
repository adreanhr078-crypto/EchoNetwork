import bpy,json,math,hashlib
from pathlib import Path
from mathutils import Vector
APP=Path(__file__).resolve().parents[2]
P=APP/'art/production/lab-modular-refinement-20261024'
SOURCE=P/'clinical_scanner_p2_pbr_4k.glb'
OUT=APP/'godot/assets/environments/lab_clinical_cp45/clinical_scanner_p2_4k.glb'
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(SOURCE))
meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
assert len(meshes)==1
obj=meshes[0]
bpy.ops.object.select_all(action='DESELECT');obj.select_set(True);bpy.context.view_layer.objects.active=obj
bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
points=[v.co.copy() for v in obj.data.vertices]
lo=Vector(tuple(min(p[i] for p in points) for i in range(3)))
hi=Vector(tuple(max(p[i] for p in points) for i in range(3)))
assert .98<hi.x-lo.x<1.02 and .98<hi.y-lo.y<1.02,'Provider changed measured raw normalization'
scale=5.2/(hi.x-lo.x)
# The horizontal ring's measured dominant height is BlenderZ.42. Preserve
# its semantic nativeY7m datum; do not centre the AABB including boom ends.
datum=.42
supports=[]
for sx in [-1,1]:
    for sy in [-1,1]:
        top=[p for p in points if p.z>hi.z-.0001 and p.x*sx>0 and p.y*sy>0]
        assert len(top)>3,'Missing measured upper suspension'
        centre=Vector(tuple((min(p[i] for p in top)+max(p[i] for p in top))*.5 for i in range(3)))
        supports.append({'blender_xy':[centre.x*scale,centre.y*scale],'top_local_y':(max(p.z for p in top)-datum)*scale})
for v in obj.data.vertices:
    v.co=Vector((v.co.x*scale,v.co.y*scale,(v.co.z-datum)*scale))
obj.name='ClinicalScannerP2Measured'
obj.data.calc_loop_triangles()
triangles=len(obj.data.loop_triangles)
assert triangles<8500 and len(obj.data.materials)==1
for mat in obj.data.materials:
    bs=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    mat.name='ClinicalScannerP2CleanPBR'
images=[{'name':i.name,'width':i.size[0],'height':i.size[1]} for i in bpy.data.images if i.type=='IMAGE']
assert len(images)==3 and all(i['width']==4096 and i['height']==4096 for i in images)
for image in bpy.data.images:
    if image.type!='IMAGE':continue
    role='normal' if 'tripo_normal' in image.name else ('rm' if 'tripo_rgb' in image.name else 'basecolor')
    image.name='scanner_'+role+'_4k'
bpy.ops.wm.save_as_mainfile(filepath=str(P/'clinical-scanner-p2-measured.blend'))
bpy.ops.export_scene.gltf(filepath=str(OUT),export_format='GLB',use_selection=True,export_animations=False,export_yup=True)
report={'source':str(SOURCE.relative_to(APP)).replace('\\','/'),'source_sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),'output':str(OUT.relative_to(APP)).replace('\\','/'),'output_sha256':hashlib.sha256(OUT.read_bytes()).hexdigest(),'triangles':triangles,'surfaces':1,'uniform_scale':scale,'ring_blender_datum':datum,'native_ring_y':7.0,'ring_diameter_m':5.2,'supports':supports,'images':images,'scope':'Static measured presentation only; original source and native room colliders/story retained. Native visual/performance review pending.'}
(P/'scanner-derivative-build.json').write_text(json.dumps(report,indent=2)+'\n')
print('SCANNER_P2_BUILT',json.dumps(report))

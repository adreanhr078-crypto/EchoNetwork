"""Inspect the isolated bind-pose export and render neutral geometry only."""
import json
import math
import sys
from pathlib import Path
import bpy
from mathutils import Vector
from mathutils.kdtree import KDTree

HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE))
from measured_target_reference import OUTPUT,TARGET,ROLES,EXPECTED,sha
from golden_reference import verify

if '--revision' in sys.argv and sys.argv[sys.argv.index('--revision')+1]=='v2':
    OUTPUT=OUTPUT.with_name('reference-pose-v2')
    TARGET=OUTPUT/'echo-v13-measured-reference.glb'

verify()
profile=json.loads((OUTPUT/'profile.json').read_text())
assert sha(TARGET)==profile['target_sha256']
bpy.ops.wm.open_mainfile(filepath=str(OUTPUT/'measured-reference.blend'))
rig=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE' and set(o.data.bones.keys())==EXPECTED)

def owned_meshes(r):
    return [o for o in bpy.context.scene.objects if o.type=='MESH' and any(m.type=='ARMATURE' and m.object==r for m in o.modifiers)]

def points(obj,key):
    if obj.data.shape_keys:
        for k in obj.data.shape_keys.key_blocks:
            if k.name!='Basis': k.value=1.0 if k.name==key else 0.0
    bpy.context.view_layer.update()
    evaluated=obj.evaluated_get(bpy.context.evaluated_depsgraph_get())
    mesh=evaluated.to_mesh()
    result=[evaluated.matrix_world @ v.co for v in mesh.vertices]
    triangles=sum(len(p.vertices)-2 for p in mesh.polygons)
    evaluated.to_mesh_clear()
    assert all(math.isfinite(v) for p in result for v in p)
    return result,triangles

original={}
for m in owned_meshes(rig):
    original[m.name]={k:points(m,k) for k in ['Basis']+list(profile['morph_defaults'][m.name])}
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(TARGET))
rig=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
assert set(rig.data.bones.keys())==EXPECTED
meshes=owned_meshes(rig)
assert len(meshes)==len(original)
max_error=0.0
for m in meshes:
    saved=original[m.name]
    assert set(m.data.shape_keys.key_blocks.keys())==set(saved)
    for k,expected in profile['morph_defaults'][m.name].items():
        assert abs(m.data.shape_keys.key_blocks[k].value-expected)<1e-6
    for key,(before,triangles) in saved.items():
        after,count=points(m,key)
        assert count==triangles
        for a,b in [(before,after),(after,before)]:
            tree=KDTree(len(a))
            for i,p in enumerate(a):tree.insert(p,i)
            tree.balance()
            max_error=max(max_error,max(tree.find(p)[2] for p in b))
assert max_error<1e-5,max_error
for m in meshes:points(m,'Basis')
scene=bpy.context.scene
scene.render.engine='BLENDER_EEVEE'
scene.render.resolution_x=720
scene.render.resolution_y=720
scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('MeasuredReferenceWorld')
scene.world.color=(.06,.06,.06)
scene.view_settings.view_transform='Standard'
all_points=[p for m in meshes for p in points(m,'Basis')[0]]
low=Vector(tuple(min(p[i] for p in all_points) for i in range(3)))
high=Vector(tuple(max(p[i] for p in all_points) for i in range(3)))
center=(low+high)*.5
for name,location,energy,size in [('key',(3,-4,5),550,4),('fill',(-3,2,3),350,3)]:
    bpy.ops.object.light_add(type='AREA',location=location)
    light=bpy.context.object;light.name=name;light.data.energy=energy;light.data.shape='DISK';light.data.size=size
    light.rotation_euler=(center-light.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add()
camera=bpy.context.object;camera.data.type='ORTHO';camera.data.ortho_scale=max(high[i]-low[i] for i in range(3))*1.3
scene.camera=camera
images=[]
for name,offset in [('front',(4,0,0)),('side',(0,-4,0)),('three-quarter',(3,-3,.6))]:
    camera.location=center+Vector(offset)
    camera.rotation_euler=(center-camera.location).to_track_quat('-Z','Y').to_euler()
    path=OUTPUT/(name+'.png');scene.render.filepath=str(path)
    bpy.ops.render.render(write_still=True);images.append(str(path))
report={'status':'EXPORT_GEOMETRY_PASS_VISUAL_OPEN','max_export_geometry_error_m':max_error,'original_and_exported_triangles_equal':True,'morph_defaults_preserved':True,'all_morph_geometry_checked':True,'images':images,'target_sha256':sha(TARGET),'runtime_integrated':False}
(OUTPUT/'export-geometry-review.json').write_text(json.dumps(report,indent=2)+'\n')
verify()
print('REFERENCE_EXPORT_REVIEW '+json.dumps(report))

"""Preserve the whole Tripo source; correct its single obstructive bridge.

Run in background Blender with --factory-startup. Original PBR objects remain
in their own scene. The bridge is intersected with a solid cutting volume so
its retained end is capped, rather than deleting faces by coordinate selection.
"""
import bpy
import hashlib
import json
from pathlib import Path
from mathutils import Matrix, Vector

A=Path(__file__).resolve().parents[2]
G=A/'art/production/maintenance-parkour-rebuild-20261027'
OUT=Path(r'C:\Users\yasmo\Documents\Codex\2026-10-24\new-chat\outputs\quality-progress-20261025')
SOURCE=G/'whole-room-h31-multiview-pbr4k.glb'
EDITABLE=G/'whole-room-derived-editable.blend'
UPLOAD=G/'whole-room-corrected-single-mesh-source.glb'
COLLISION=G/'whole-room-collision-source.glb'
assert not any(p.exists() for p in [EDITABLE,UPLOAD,COLLISION]), 'Preserve prior derivatives'
scale=18/.98175048828125

def meshes(scene):
    return [o for o in scene.objects if o.type=='MESH']

def bounds(obj):
    points=[obj.matrix_world@Vector(v) for v in obj.bound_box]
    lo=Vector([min(p[i] for p in points) for i in range(3)])
    hi=Vector([max(p[i] for p in points) for i in range(3)])
    return lo,hi

def triangles(obj):
    return sum(len(p.vertices)-2 for p in obj.data.polygons)

def activate(scene,objects):
    bpy.context.window.scene=scene
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objects:obj.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]

def export(scene,objects,path):
    activate(scene,objects)
    bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,
                              export_animations=False,export_cameras=False,export_lights=False)

original=bpy.data.scenes.new('STORMWORKS_ORIGINAL_PBR_20261027')
bpy.context.window.scene=original
bpy.ops.import_scene.gltf(filepath=str(SOURCE))
bpy.context.view_layer.update()
assert len(meshes(original))==27
assert sum(triangles(o) for o in meshes(original))==1854657
derived=bpy.data.scenes.new('STORMWORKS_CORRECTED_ASSEMBLY_20261027')
parts={}
for obj in meshes(original):
    clone=obj.copy();clone.data=obj.data.copy();derived.collection.objects.link(clone)
    clone.name='Stormworks_'+obj.name
    parts[obj.name]=clone
bpy.context.window.scene=derived
bpy.context.view_layer.update()

# Argon's bounded geometry finding: the long central slab obstructed the
# parkour camera/airspace. Retain a 2m end section and place it at the rear.
bridge=parts['tripo_part_4']
before_bridge=triangles(bridge)
bpy.ops.mesh.primitive_cube_add(size=2,location=(0,2/scale,6/scale))
cutter=bpy.context.object;cutter.name='BridgeEndSectionTrimVolume'
cutter.scale=(20/scale,1/scale,12/scale)
bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
cap=bpy.data.materials.new('ExposedBridgeEndSteel');cap.use_nodes=True
bs=cap.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(.16,.19,.19,1)
bs.inputs['Metallic'].default_value=.55;bs.inputs['Roughness'].default_value=.55
cutter.data.materials.append(cap)
activate(derived,[bridge])
modifier=bridge.modifiers.new('CappedBridgeEndSection','BOOLEAN')
modifier.operation='INTERSECT';modifier.solver='EXACT';modifier.object=cutter
if hasattr(modifier,'material_mode'):modifier.material_mode='TRANSFER'
bpy.ops.object.modifier_apply(modifier=modifier.name)
assert triangles(bridge)>1000
bpy.data.objects.remove(cutter,do_unlink=True)
bridge.matrix_world.translation+=Vector((0,5.3/scale,0))
bpy.context.view_layer.update()
lo,hi=bounds(bridge)
assert 1.95<(hi.y-lo.y)*scale<2.05,(list(lo),list(hi))

# Make the existing source vault block physically compatible with the
# existing motor's 1.8m landing search; keep its centre and height unchanged.
vault=parts['tripo_part_23'];lo,hi=bounds(vault);pivot=(lo+hi)*.5
vault.matrix_world=(Matrix.Translation(pivot)@Matrix.Diagonal((.65,1,1,1))
                    @Matrix.Translation(-pivot)@vault.matrix_world)
bpy.context.view_layer.update()
report={'status':'DERIVATIVE_PREPARED_NATIVE_REVIEW_PENDING',
        'source':SOURCE.name,'source_sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
        'original_scene_preserved':original.name,'uniform_native_scale':scale,
        'native_ground_shift_y':-1.05,'native_front_setback_m':1,
        'bridge':{'part':'tripo_part_4','triangles_before':before_bridge,
                  'triangles_after':triangles(bridge),'retained_depth_m':(hi.y-lo.y)*scale,
                  'end_section_source_y_m':[1,3],'rigid_translation_blender_y_m':5.3},
        'vault':{'part':'tripo_part_23','scale_about_center':[.65,1,1],
                 'reason':'Fits native vault landing clearance;no whole-room distortion'},
        'scope':'Complete Tripo environment with two scoped assembly corrections. No collision/player/art acceptance yet.'}

# Collider-only derivatives simplify the original static shapes. They carry
# no render material and never replace the highest-detail visual source.
collision_scene=bpy.data.scenes.new('STORMWORKS_COLLISION_DERIVATIVE_20261027')
collision_parts=[]
for source in meshes(derived):
    obj=source.copy();obj.data=source.data.copy();obj.name=source.name+'_Collision'
    collision_scene.collection.objects.link(obj);activate(collision_scene,[obj])
    count=triangles(obj)
    if count>15000:
        modifier=obj.modifiers.new('StaticCollisionSimplification','DECIMATE')
        modifier.ratio=.12 if count<50000 else .07
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    obj.data.materials.clear();collision_parts.append(obj)
export(collision_scene,collision_parts,COLLISION)
report['collision_triangles']=sum(triangles(o) for o in collision_parts)

# A single material source avoids the provider allocating tiny per-part
# maps. The preserved 27-part PBR source remains available for comparison.
upload_scene=bpy.data.scenes.new('STORMWORKS_SINGLE_MESH_UV_SOURCE_20261027')
upload_parts=[]
for source in meshes(derived):
    obj=source.copy();obj.data=source.data.copy();upload_scene.collection.objects.link(obj);upload_parts.append(obj)
activate(upload_scene,upload_parts);bpy.ops.object.join()
joined=bpy.context.object;joined.name='StormworksCompleteRoom'
joined.data.materials.clear()
neutral=bpy.data.materials.new('StormworksNeutralSource');neutral.diffuse_color=(.55,.57,.56,1)
joined.data.materials.append(neutral)
for polygon in joined.data.polygons:polygon.material_index=0
export(upload_scene,[joined],UPLOAD)
report['corrected_visual_triangles']=triangles(joined)
report['single_mesh_source_sha256']=hashlib.sha256(UPLOAD.read_bytes()).hexdigest()
report['collision_source_sha256']=hashlib.sha256(COLLISION.read_bytes()).hexdigest()
(G/'corrected-room-contract.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')

bpy.context.window.scene=derived
derived.render.engine='CYCLES';derived.cycles.device='CPU';derived.cycles.samples=12
derived.render.resolution_x=1280;derived.render.resolution_y=800;derived.render.resolution_percentage=100
derived.world=bpy.data.worlds.new('StormworksPBRReviewWorld');derived.world.use_nodes=True
derived.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.45
derived.view_settings.view_transform='AgX'
center=Vector((0,0,.23))
for name,pos,power in [('Key',(-1,-1.5,2),160),('Fill',(1,1,1.4),110),('Top',(0,0,2),90)]:
    data=bpy.data.lights.new('StormworksPBR'+name,'AREA');data.energy=power;data.shape='DISK';data.size=2
    obj=bpy.data.objects.new(data.name,data);derived.collection.objects.link(obj);obj.location=pos
    obj.rotation_euler=(center-obj.location).to_track_quat('-Z','Y').to_euler()
data=bpy.data.cameras.new('StormworksPBRCamera');camera=bpy.data.objects.new(data.name,data)
derived.collection.objects.link(camera);derived.camera=camera;data.type='ORTHO';data.ortho_scale=1.5
bpy.ops.wm.save_as_mainfile(filepath=str(EDITABLE))
for name,pos in [('whole',(1.3,-1.8,1.1)),('interior',(-1.6,-1.5,1.0))]:
    camera.location=pos;camera.rotation_euler=(center-camera.location).to_track_quat('-Z','Y').to_euler()
    derived.render.filepath=str(OUT/('new-room-pbr-derived-'+name+'-20261027.png'))
    assert not Path(derived.render.filepath).exists()
    bpy.ops.render.render(write_still=True)
print('STORMWORKS_DERIVATIVE '+json.dumps(report))

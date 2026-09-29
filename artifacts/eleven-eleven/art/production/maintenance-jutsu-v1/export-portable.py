"""Compact Jutsu room for Godot; preserve an explicit collision sidecar."""
import bpy, bmesh, json, sys
from pathlib import Path
from mathutils import Vector
source, output, collisions, audit = map(Path,sys.argv[sys.argv.index('--')+1:])
bpy.ops.wm.open_mainfile(filepath=str(source.resolve()))
bpy.context.scene.frame_set(1)
rows=[]
for o in bpy.context.scene.objects:
    if o.type=='MESH' and o.name.startswith('COLL_'):
        c=o.matrix_world.translation
        d=o.dimensions
        rows.append({'name':o.name,'position':[c.x,c.z,-c.y],'size':[d.x,d.z,d.y],'climbable':o.name.startswith('COLL_CLIMB_')})
        # Separate overlapping visual caps by 6mm after recording exact physics.
        # The rest deck and wall otherwise have coplanar tops that shimmer.
        if o.name in ['COLL_UpperRest','COLL_GapLanding','COLL_FinalRest']:
            o.location.z += .006
groups={}
def is_dynamic(obj):
    while obj:
        if obj.get('runtime_dynamic',False): return True
        obj=obj.parent
    return False
for o in list(bpy.context.scene.objects):
    if o.type=='MESH' and not o.animation_data and not is_dynamic(o):
        groups.setdefault(o.data.materials[0].name,[]).append(o)
for name,objects in groups.items():
    bpy.ops.object.select_all(action='DESELECT')
    for o in objects:
        bpy.context.view_layer.objects.active=o
        for modifier in list(o.modifiers): bpy.ops.object.modifier_apply(modifier=modifier.name)
        o.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]
    if len(objects)>1: bpy.ops.object.join()
    bpy.context.object.name='Maintenance_Static_'+name.replace(' ','_')
bpy.ops.object.select_all(action='DESELECT')
triangles=0
meshes=[]
for o in bpy.context.scene.objects:
    if o.type!='MESH': continue
    bpy.context.view_layer.objects.active=o
    for modifier in list(o.modifiers): bpy.ops.object.modifier_apply(modifier=modifier.name)
    bm=bmesh.new(); bm.from_mesh(o.data)
    bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=1e-7)
    # bmesh round-tripping can drop a BYTE_COLOR layer used by the catalog
    # material. Keep its authored vertex colors and clean only uncolored meshes.
    if not o.data.color_attributes: bm.to_mesh(o.data)
    bm.free()
    o.data.calc_loop_triangles()
    triangles+=len(o.data.loop_triangles)
    meshes.append(o.name)
    o.select_set(True)
for o in bpy.context.scene.objects:
    if o.get('runtime_dynamic',False): o.select_set(True)
output.parent.mkdir(parents=True,exist_ok=True)
bpy.ops.export_scene.gltf(filepath=str(output.resolve()),export_format='GLB',use_selection=True,export_apply=True,export_animations=True,export_animation_mode='ACTIONS',export_cameras=False,export_lights=False)
collisions.write_text(json.dumps({'schema':'echo-maintenance-collision-v1','bodies':rows},indent=2)+'\n',encoding='utf-8')
metrics={'source':source.name,'cloudRevision':int(source.stem.split('-r')[-1]),'triangles':triangles,'meshes':meshes,'collisionBodies':len(rows),'bytes':output.stat().st_size,'animation':'Maintenance_Signal_Cycle','characterAnimation':False,'dynamicRoots':[o.name for o in bpy.context.scene.objects if o.get('runtime_dynamic',False)]}
audit.write_text(json.dumps(metrics,indent=2)+'\n',encoding='utf-8')
print(json.dumps(metrics))

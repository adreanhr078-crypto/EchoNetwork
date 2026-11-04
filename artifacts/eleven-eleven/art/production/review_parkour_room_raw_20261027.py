"""Inspect the complete new Tripo room before textures or gameplay acceptance.

Run Blender in background with --factory-startup. Preserve the source objects
and factory scene; this file only creates an inspection scene and neutral views.
"""
import bpy
import hashlib
import json
from pathlib import Path
from mathutils import Vector

A=Path(__file__).resolve().parents[2]
G=A/'art/production/maintenance-parkour-rebuild-20261027'
SOURCE=G/'whole-room-h31-multiview-raw.glb'
EDITABLE=G/'whole-room-raw-inspection-editable.blend'
OUT=Path(r'C:\Users\yasmo\Documents\Codex\2026-10-24\new-chat\outputs\quality-progress-20261025')
assert SOURCE.exists() and not EDITABLE.exists(), 'Preserve source and previous review'
scene=bpy.data.scenes.new('NEW_STORMWORKS_ROOM_RAW_REVIEW_20261027')
bpy.context.window.scene=scene
bpy.ops.import_scene.gltf(filepath=str(SOURCE))
bpy.context.view_layer.update()
meshes=[o for o in scene.objects if o.type=='MESH']
records=[]
for obj in meshes:
    corners=[obj.matrix_world@Vector(v) for v in obj.bound_box]
    lo=[min(v[i] for v in corners) for i in range(3)]
    hi=[max(v[i] for v in corners) for i in range(3)]
    records.append({'name':obj.name,'triangles':sum(len(p.vertices)-2 for p in obj.data.polygons),
                    'vertices':len(obj.data.vertices),'min_blender':lo,'max_blender':hi,
                    'size_blender':[hi[i]-lo[i] for i in range(3)],
                    'materials':[m.name if m else None for m in obj.data.materials]})
lo=Vector([min(r['min_blender'][i] for r in records) for i in range(3)])
hi=Vector([max(r['max_blender'][i] for r in records) for i in range(3)])
center=(lo+hi)*.5
size=hi-lo
width_scale=18/size.x
report={'status':'RAW_GEOMETRY_IMPORTED_VISUAL_REVIEW_PENDING','provider_workspace':'5902b46f-a4ad-4b06-a5d2-3cf4a772bd5a',
        'source':SOURCE.name,'source_sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
        'mesh_count':len(meshes),'triangles':sum(r['triangles'] for r in records),
        'min_blender':list(lo),'max_blender':list(hi),'size_blender':list(size),
        'provisional_size_at_18m_width_blender':[v*width_scale for v in size],
        'parts':records,'native_acceptance':'PENDING;no texture,collision or actual player review yet'}
(G/'raw-room-geometry-report.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
scene.render.engine='CYCLES';scene.cycles.device='CPU';scene.cycles.samples=12
scene.render.resolution_x=960;scene.render.resolution_y=800;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('StormworksNeutralReviewWorld');scene.world.use_nodes=True
bg=scene.world.node_tree.nodes['Background'];bg.inputs['Color'].default_value=(.15,.17,.20,1);bg.inputs['Strength'].default_value=.5
mat=bpy.data.materials.new('RawRoomReviewNeutralOverride');mat.use_nodes=True
bs=mat.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(.43,.46,.48,1);bs.inputs['Roughness'].default_value=.6
scene.view_layers[0].material_override=mat
cam_data=bpy.data.cameras.new('StormworksReviewCamera');cam=bpy.data.objects.new(cam_data.name,cam_data);scene.collection.objects.link(cam);scene.camera=cam
cam_data.type='ORTHO';cam_data.ortho_scale=max(size)*1.43
for name,offset,power in [('Key',(-1.3,-1.5,2),180),('Fill',(1.5,1.5,1.5),120),('Top',(0,0,2.5),100)]:
    data=bpy.data.lights.new('StormworksReview'+name,'AREA');data.energy=power;data.shape='DISK';data.size=2
    obj=bpy.data.objects.new(data.name,data);scene.collection.objects.link(obj);obj.location=center+Vector(offset)
    obj.rotation_euler=(center-obj.location).to_track_quat('-Z','Y').to_euler()
scene.view_settings.view_transform='AgX'
bpy.ops.wm.save_as_mainfile(filepath=str(EDITABLE))
views=[('front',(0,-2.2,1)),('left',(-2,0,1)),('right',(2,0,1)),('back',(0,2.2,1)),('overhead',(0,-.001,3))]
for name,offset in views:
    cam.location=center+Vector(offset)
    cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath=str(OUT/('new-whole-room-raw-'+name+'-20261027.png'))
    assert not Path(scene.render.filepath).exists(), 'Preserve existing render'
    bpy.ops.render.render(write_still=True)
print('NEW_ROOM_RAW_REVIEW '+json.dumps({k:v for k,v in report.items() if k!='parts'}))

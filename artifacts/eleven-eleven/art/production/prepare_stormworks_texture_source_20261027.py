"""One verified room mesh for an atlas texture pass; geometry is unchanged."""
import bpy,json,hashlib
from pathlib import Path
A=Path(r'C:/Users/yasmo/EchoNetwork/artifacts/eleven-eleven')
G=A/'art/production/maintenance-parkour-rebuild-20261027'
source=A/'godot/assets/environments/maintenance_stormworks/stormworks_visual_portal_v5.glb'
target=G/'stormworks_whole_room_4k_source_v5.glb'
assert not target.exists()
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(source))
scene=bpy.context.scene
parts=[o for o in scene.objects if o.type=='MESH']
assert len(parts)==27
before=sum(len(p.vertices)-2 for o in parts for p in o.data.polygons)
for o in parts:
    matrix=o.matrix_world.copy();o.parent=None;o.matrix_world=matrix
bpy.ops.object.select_all(action='DESELECT')
for o in parts:o.select_set(True)
bpy.context.view_layer.objects.active=parts[0]
bpy.ops.object.join()
joined=bpy.context.object;joined.name='StormworksCompleteRoomV5'
joined.data.materials.clear()
mat=bpy.data.materials.new('NeutralRoomTextureSource')
mat.diffuse_color=(.55,.57,.56,1);joined.data.materials.append(mat)
for p in joined.data.polygons:p.material_index=0
bpy.ops.export_scene.gltf(filepath=str(target),export_format='GLB',use_selection=True,
                         use_active_scene=True,export_animations=False,export_cameras=False,export_lights=False)
b=target.read_bytes();j=json.loads(b[20:20+int.from_bytes(b[12:16],'little')])
after=sum(j['accessors'][p['indices']]['count']//3 for m in j['meshes'] for p in m['primitives'])
assert before==after and len(j['scenes'])==1 and len(j['meshes'])==1 and len(j['materials'])==1 and not j.get('images')
(G/'texture-source-v5-contract.json').write_text(json.dumps({
    'status':'ATLAS_SOURCE_VERIFIED_NOT_TEXTURE_ACCEPTED',
    'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),
    'sha256':hashlib.sha256(b).hexdigest(),'bytes':len(b),'triangles':after,
    'scenes':1,'meshes':1,'materials':1,'images':0,
    'reason':'Provider multipart4K choice allocated32..2048 maps;one atlas pass is justified for improved room texel density.'},indent=2)+'\n')
print('TEXTURE_SOURCE_VERIFIED '+str(after)+' '+str(len(b)))

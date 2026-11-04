"""Export only the geometry-qualified isolated blink for cross-tool diagnosis.

This is not artistic or runtime acceptance. Never writes a production avatar.
"""
import hashlib,json,struct
from pathlib import Path
import bpy

APP=Path(__file__).resolve().parents[2]
case=APP/'art/production/echo-school-rebuild-20261029/face/blink-retopology-20261102'
sha=lambda path:hashlib.sha256(path.read_bytes()).hexdigest()
qualification=json.loads((case/'geometry-qualification.json').read_text())
assert qualification['status']=='PASS_SCOPED_GEOMETRY_ONLY' and all(qualification['checks'].values())
assert sha(case/'connected-blink-research.blend')==qualification['candidate_blend_sha256']
bpy.ops.wm.open_mainfile(filepath=str(case/'connected-blink-research.blend'))
obj=next(item for item in bpy.context.scene.objects if item.type=='MESH')
rig=next(item for item in bpy.context.scene.objects if item.type=='ARMATURE')
assert len(rig.data.bones)==65
assert list(obj.data.shape_keys.key_blocks.keys())==['Basis','blink']
obj.data.shape_keys.key_blocks['blink'].value=0
# Diagnostic-only secondUV channel provides unambiguous Blender vertex identity
# through glTF material/normal splits. OriginalUV0 andall PBR pixels stay exact.
assert len(obj.data.vertices)<131072
labels=obj.data.uv_layers.new(name='LAB_SOURCE_VERTEX_ID')
for loop in obj.data.loops:
    index=loop.vertex_index
    labels.data[loop.index].uv=(float(index%256)/255.0,float(index//256)/511.0)
obj.data.uv_layers.active_index=0;obj.data.uv_layers[0].active_render=True
bpy.ops.object.select_all(action='DESELECT');obj.select_set(True);rig.select_set(True)
bpy.context.view_layer.objects.active=rig
options={'filepath':str(case/'diagnostic-blink.glb'),'export_format':'GLB','use_selection':True,
         'export_animations':False,'export_skins':True,'export_yup':True,'export_morph':True,
         'export_morph_normal':True,'export_normals':True,'export_tangents':True}
properties=bpy.ops.export_scene.gltf.get_rna_type().properties.keys()
print('BLINK_EXPORT_UV_OPTIONS',[key for key in properties if 'texcoord' in key])
if 'export_unused_texcoords' in properties:options['export_unused_texcoords']=True
assert all(key in properties for key in options),'Inspect this installed exporter before changing its options'
bpy.ops.export_scene.gltf(**options)
payload=(case/'diagnostic-blink.glb').read_bytes();length=struct.unpack_from('<I',payload,12)[0]
doc=json.loads(payload[20:20+length])
assert not doc.get('animations')
assert len(doc['skins'])==1 and len(doc['skins'][0]['joints'])==65
assert all(mesh.get('extras',{}).get('targetNames')==['blink'] for mesh in doc['meshes'])
assert all(len(primitive['targets'])==1 for mesh in doc['meshes'] for primitive in mesh['primitives'])
assert all('TEXCOORD_1' in primitive['attributes'] for mesh in doc['meshes'] for primitive in mesh['primitives']),'SourceID UV2 must survive the diagnostic export'
report={'status':'ISOLATED_DIAGNOSTIC_EXPORT_NOT_RUNTIME_OR_ART_ACCEPTANCE',
        'source_blend_sha256':qualification['candidate_blend_sha256'],'geometry_qualification_sha256':sha(case/'geometry-qualification.json'),
        'glb_sha256':sha(case/'diagnostic-blink.glb'),'bones':65,'morphs':['blink'],'animations':0,
        'image_count':len(doc.get('images',[])),'morph_normals':True,
        'diagnostic_uv2':'LAB_SOURCE_VERTEX_ID:low8bits/255,high9bits/511;referenceidentity only,notlightmap. OriginalUV0 unchanged.',
        'limits':'NativeGodot import/deformation and bodymotion stillunverified. Upperlidfaceting/skinart notaccepted. DefaultV31 andproductionSchool65 untouched.'}
(case/'diagnostic-export.json').write_text(json.dumps(report,indent=2)+'\n')
print('BLINK_LAB_EXPORT',json.dumps(report))

import bpy, pathlib, json, hashlib

P=pathlib.Path(r'C:\Users\yasmo\EchoNetwork\artifacts\eleven-eleven\art\production\decon-redesign-20261028\whole-v2')
roles={'MeasuredCatwalkAndRails','MeasuredFloor','MeasuredHullBacking','MeasuredOpenCeilingRibs','MeasuredWestStaircase','NativeMovingGateVisual','NativeTerminalVisual'}
assert (P/'authored-repaired-metric-pbr.glb').exists()
assert not (P/'textured-metric-combined.glb').exists(),'Preserve prior combined output before a new merge'
bpy.ops.wm.open_mainfile(filepath=str(P/'textured-metric-source.blend'))
old=[o for o in bpy.data.objects if o.type=='MESH']
assert len(old)==85
replace=[o for o in old if o.name in roles]
assert len(replace)==7,[(o.name) for o in old]
keep=[o for o in old if o not in replace]
assert len(keep)==78

def fingerprint(o):
    h=hashlib.sha256()
    h.update(str(tuple(tuple(row) for row in o.matrix_world)).encode())
    for v in o.data.vertices:h.update(str(tuple(v.co)).encode())
    for poly in o.data.polygons:h.update(str((tuple(poly.vertices),poly.material_index)).encode())
    for uv in o.data.uv_layers:
        for item in uv.data:h.update(str(tuple(item.uv)).encode())
    return {'sha256':h.hexdigest(),'materials':[m.name for m in o.data.materials if m]}

before={o.name:fingerprint(o) for o in keep}
for o in replace:bpy.data.objects.remove(o,do_unlink=True)
prior=set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath=str(P/'authored-repaired-metric-pbr.glb'))
added=[o for o in bpy.data.objects if o not in prior and o.type=='MESH']
assert len(added)==7
assert {o.name for o in added}==roles,[(o.name) for o in added]
after={o.name:fingerprint(o) for o in keep}
assert before==after,'Original 78 generated groups changed'
all_meshes=keep+added
for o in all_meshes:
    assert o.data.uv_layers.active is not None
    assert len(o.data.materials)>0
    for m in o.data.materials:
        assert m and m.use_nodes
        images=[n.image for n in m.node_tree.nodes if n.type=='TEX_IMAGE' and n.image]
        assert images,('Missing material textures',o.name,m.name)
bpy.ops.object.select_all(action='DESELECT')
for o in all_meshes:o.select_set(True)
bpy.context.view_layer.objects.active=all_meshes[0]
bpy.ops.export_scene.gltf(filepath=str(P/'textured-metric-combined.glb'),export_format='GLB',use_selection=True,export_apply=True)
bpy.ops.wm.save_as_mainfile(filepath=str(P/'textured-metric-combined.blend'))
report={'status':'MERGED_SOURCE_NOT_NATIVE_ACCEPTANCE','generated_groups_preserved':78,'authored_groups_replaced':7,'retained_fingerprints':after,'authored_roles':sorted(roles),'combined_sha256':hashlib.sha256((P/'textured-metric-combined.glb').read_bytes()).hexdigest(),'triangles':sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in all_meshes),'objects':len(all_meshes),'source_geometry_generation_repeated':False}
(P/'retexture-20261029/merge-report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print('MERGE_PASS',report['objects'],report['triangles'],report['combined_sha256'],flush=True)

import bpy,bmesh,json,struct
from pathlib import Path
scene=bpy.data.scenes['Room01PersonalTraceCraft'];bpy.context.window.scene=scene
collection=bpy.data.collections['Room01TraceAsset']
frame=collection.objects['PhotoFrameHero']
mat=frame.data.materials[0]
vertices=[(x,y,z) for z in [.022,.025] for x,y in [(-.326,-.226),(.326,-.226),(.326,.226),(-.326,.226)]]
faces=[(3,2,1,0),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]
mesh=bpy.data.meshes.new('PaperBackingMesh');mesh.from_pydata(vertices,[],faces);mesh.materials.append(mat)
backing=bpy.data.objects.new('PaperBacking',mesh);collection.objects.link(backing)
checks={}
for item in collection.objects:
    bm=bmesh.new();bm.from_mesh(item.data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    checks[item.name]=sum(not edge.is_manifold for edge in bm.edges)
    bm.to_mesh(item.data);bm.free()
assert not any(checks.values()),checks
bpy.ops.object.select_all(action='DESELECT')
for item in collection.objects:item.select_set(True)
bpy.context.view_layer.objects.active=frame
bpy.ops.object.join()
dest=Path(r'C:\Users\yasmo\EchoNetwork\artifacts\eleven-eleven\art\production\room01-hero-clock-20261014')
path=dest/'room01-trace-frame.glb'
bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,
    use_active_scene=True,export_apply=True,export_animations=False,export_cameras=False,export_lights=False)
raw=path.read_bytes();size=struct.unpack_from('<I',raw,12)[0];doc=json.loads(raw[20:20+size])
assert [n.get('name') for n in doc['nodes']]==['PhotoFrameHero']
result={'path':str(path),'bytes':len(raw),'textures':len(doc.get('images',[])),
        'triangles':sum(len(p.vertices)-2 for p in frame.data.polygons),'material_slots':len(frame.data.materials),
        'non_manifold_edges_before_join':checks,
        'camera_read':'frame-candidate viewed: bevels, quiet brass inset and genuine recess; added backing below retained paper to prevent a see-through gap'}
(dest/'frame-export-report.json').write_text(json.dumps(result,indent=2))

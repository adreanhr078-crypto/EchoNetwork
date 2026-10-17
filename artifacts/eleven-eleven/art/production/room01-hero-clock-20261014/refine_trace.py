"""Original irregular archival paper and two physical corner clips; no new image."""
import bpy,bmesh,json,struct
from pathlib import Path
scene=bpy.data.scenes['Room01PersonalTraceCraft'];bpy.context.window.scene=scene
collection=bpy.data.collections['Room01TraceAsset']
brass=next(m for m in collection.objects['PhotoFrameHero'].data.materials if m.name.startswith('Trace_AgedInnerBrass'))
mat=bpy.data.materials.new('Trace_RuntimePaper');mat.diffuse_color=(.8,.76,.68,1);mat.use_nodes=True
shader=mat.node_tree.nodes.get('Principled BSDF');shader.inputs['Base Color'].default_value=(.8,.76,.68,1);shader.inputs['Roughness'].default_value=.92
# Four gently worn edges; explicit contour preserves a quiet reading surface.
contour=[(-.309,-.215),(-.201,-.216),(-.087,-.214),(.034,-.216),(.178,-.215),(.310,-.213),
         (.316,-.205),(.315,-.109),(.316,.024),(.313,.148),(.311,.212),
         (.207,.216),(.080,.214),(-.033,.216),(-.179,.214),(-.310,.212),
         (-.315,.205),(-.314,.095),(-.316,-.028),(-.313,-.156)]
vertices=[(0,0,.00015)]+[(x,y,[-.0002,.0003,.0001,-.00015][i%4]) for i,(x,y) in enumerate(contour)]
faces=[(0,i+1,(i+1)%len(contour)+1) for i in range(len(contour))]
mesh=bpy.data.meshes.new('TracePaperMesh');mesh.from_pydata(vertices,[],faces);mesh.update();mesh.materials.append(mat)
uv=mesh.uv_layers.new(name='UVMap')
for polygon in mesh.polygons:
    for loop_index in polygon.loop_indices:
        vertex=mesh.vertices[mesh.loops[loop_index].vertex_index].co
        uv.data[loop_index].uv=(vertex.x/.64+.5,vertex.y/.44+.5)
paper=bpy.data.objects.new('TracePaper',mesh);collection.objects.link(paper)

vertices=[];faces=[]
for sign in [-1,1]:
    x=sign*.305;y=-sign*.208
    contour=[(x-.017,y-.003),(x+.005,y-.003),(x+.005,y+.017),(x+.001,y+.017),(x+.001,y+.001),(x-.017,y+.001)]
    start=len(vertices);n=len(contour)
    vertices.extend([(px,py,z) for z in [.0295,.0335] for px,py in contour])
    faces.extend([tuple(start+i for i in range(n-1,-1,-1)),tuple(start+n+i for i in range(n))])
    faces.extend([(start+i,start+(i+1)%n,start+(i+1)%n+n,start+i+n) for i in range(n)])
mesh=bpy.data.meshes.new('ArchivalClipsMesh');mesh.from_pydata(vertices,[],faces);mesh.materials.append(brass)
bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));assert all(e.is_manifold for e in bm.edges);bm.to_mesh(mesh);bm.free()
clips=bpy.data.objects.new('ArchivalClips',mesh);collection.objects.link(clips)

bpy.ops.object.select_all(action='DESELECT')
for item in collection.objects:item.select_set(True)
dest=Path(r'C:\Users\yasmo\EchoNetwork\artifacts\eleven-eleven\art\production\room01-hero-clock-20261014')
path=dest/'room01-trace-frame.glb'
bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,use_active_scene=True,
    export_apply=True,export_animations=False,export_cameras=False,export_lights=False)
raw=path.read_bytes();size=struct.unpack_from('<I',raw,12)[0];doc=json.loads(raw[20:20+size])
assert set(n.get('name') for n in doc['nodes'])=={'PhotoFrameHero','TracePaper','ArchivalClips'}
result={'bytes':len(raw),'nodes':[n.get('name') for n in doc['nodes']],
        'triangles':sum(sum(len(p.vertices)-2 for p in item.data.polygons) for item in collection.objects),
        'textures':len(doc.get('images',[])),
        'paper':'20face original slight irregularity; runtime retains the exact existing emulsion texture and normal transform',
        'backing':'Below paper; clips lie over the two corners intentionally',
        'canonical_image_replaced':False}
(dest/'frame-refined-export-report.json').write_text(json.dumps(result,indent=2))

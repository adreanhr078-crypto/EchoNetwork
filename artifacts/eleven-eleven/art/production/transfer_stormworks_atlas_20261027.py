"""Register the provider atlas and transfer UVs without replacing room geometry."""
import bpy,json,hashlib,math
import numpy as np
from pathlib import Path
from mathutils import Vector,Matrix
from mathutils.kdtree import KDTree

A=Path(r'C:/Users/yasmo/EchoNetwork/artifacts/eleven-eleven')
G=A/'art/production/maintenance-parkour-rebuild-20261027'
ASSETS=A/'godot/assets/environments/maintenance_stormworks'
SOURCE=ASSETS/'stormworks_visual_portal_v5.glb'
DONOR=G/'whole-room-atlas4k-pbr-v5.glb'
OUTPUT=G/'stormworks_atlas4k_visual_v5.glb'
assert not OUTPUT.exists()
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(SOURCE))
parts=[o for o in bpy.context.scene.objects if o.type=='MESH']
assert len(parts)==27
for o in parts:
    matrix=o.matrix_world.copy();o.parent=None;o.matrix_world=matrix
bpy.context.view_layer.update()

def points(obj):return [obj.matrix_world@v.co for v in obj.data.vertices]
def geometry_hash(obj):
    h=hashlib.sha256()
    h.update(np.asarray([list(v.co) for v in obj.data.vertices],dtype='<f4').tobytes())
    h.update(np.asarray([l.vertex_index for l in obj.data.loops],dtype='<i4').tobytes())
    return h.hexdigest()

source_points=[p for o in parts for p in points(o)]
before={o.name:geometry_hash(o) for o in parts}
known=set(bpy.context.scene.objects)
bpy.ops.import_scene.gltf(filepath=str(DONOR))
donors=[o for o in bpy.context.scene.objects if o not in known and o.type=='MESH']
assert len(donors)==1
donor=donors[0]
matrix=donor.matrix_world.copy();donor.parent=None;donor.matrix_world=matrix
donor_points=points(donor)

def box(values):
    lo=Vector([min(p[i] for p in values) for i in range(3)])
    hi=Vector([max(p[i] for p in values) for i in range(3)])
    return lo,hi

lo,hi=box(source_points);center=(lo+hi)*.5
dlo,dhi=box(donor_points);dcenter=(dlo+dhi)*.5
# The provider rotates X/Z ninety degrees and normalizes the longest span.
# Test both rigid orientations; use one uniform scale, never deform geometry.
scale=(hi.x-lo.x)/(dhi.y-dlo.y)
sample=source_points[::max(1,len(source_points)//7000)]
registrations=[]
for degrees in [-90,90]:
    rotation=Matrix.Rotation(math.radians(degrees),4,'Z')
    transform=Matrix.Translation(center)@rotation@Matrix.Scale(scale,4)@Matrix.Translation(-dcenter)
    kd=KDTree(len(donor_points))
    for i,p in enumerate(donor_points):kd.insert(transform@p,i)
    kd.balance()
    errors=[kd.find(p)[2] for p in sample]
    registrations.append((float(np.mean(errors)),degrees,transform,kd))
best=min(registrations,key=lambda row:row[0])
assert best[0]<5e-5,[(r[0],r[1]) for r in registrations]
donor.matrix_world=best[2]@donor.matrix_world
bpy.context.view_layer.update()
errors=np.empty(len(source_points),dtype=np.float64)
nearest_vertices=np.empty(len(source_points),dtype=np.int32)
for i,p in enumerate(source_points):
    hit=best[3].find(p);nearest_vertices[i]=hit[1];errors[i]=hit[2]
diagnostic={'chosen_degrees':best[1],'scale':scale,'count':len(errors),
            'max':float(np.max(errors)),'p99':float(np.quantile(errors,.99)),
            'p999':float(np.quantile(errors,.999)),'parts':[]}
cursor=0
for o in parts:
    values=errors[cursor:cursor+len(o.data.vertices)];cursor+=len(o.data.vertices)
    diagnostic['parts'].append({'name':o.name,'max':float(np.max(values)),
                                'over_1e4':int(np.sum(values>1e-4)),
                                'vertices':len(values)})
(G/'atlas-registration-diagnostic.json').write_text(json.dumps(diagnostic,indent=2)+'\n')
assert np.quantile(errors,.999)<1e-4 and np.max(errors)<.005
material=donor.data.materials[0]
images=sorted({n.image for n in material.node_tree.nodes if n.type=='TEX_IMAGE' and n.image},key=lambda im:im.name)
image_sizes=[{'name':im.name,'width':im.size[0],'height':im.size[1]} for im in images]
assert len(images)==3 and all(im.size[0]==4096 and im.size[1]==4096 for im in images),image_sizes
donor.data.uv_layers.active_index=0
donor_xyz=np.asarray([list(p) for p in points(donor)],dtype=np.float64)
_,geometry_ids=np.unique(donor_xyz,axis=0,return_inverse=True)
donor_loops=np.empty(len(donor.data.loops),dtype=np.int32)
donor.data.loops.foreach_get('vertex_index',donor_loops)
assert len(donor_loops)==len(donor.data.polygons)*3
donor_triangles=donor_loops.reshape(-1,3)
donor_geometry=geometry_ids[donor_triangles].astype(np.uint32)
donor_uv=np.empty(len(donor_loops)*2,dtype=np.float32)
donor.data.uv_layers.active.data.foreach_get('uv',donor_uv)
donor_uv=donor_uv.reshape(-1,3,2)

def triangle_keys(ids):
    return np.ascontiguousarray(np.sort(ids.astype('<u4'),axis=1)).view('V12').ravel()

keys=triangle_keys(donor_geometry)
order=np.argsort(keys,kind='stable');sorted_keys=keys[order]
flat=donor_geometry.ravel()
adj_order=np.argsort(flat,kind='stable')
adj_faces=np.repeat(np.arange(len(donor_triangles),dtype=np.int32),3)[adj_order]
adj_starts=np.concatenate(([0],np.cumsum(np.bincount(flat,minlength=int(np.max(flat))+1))))
cursor=0;part_correspondence=[]
for o in parts:
    # One global face correspondence preserves UV seams and avoids rebuilding
    # a 1.7M-face Data Transfer search structure for each of the27parts.
    loops=np.empty(len(o.data.loops),dtype=np.int32)
    o.data.loops.foreach_get('vertex_index',loops)
    assert len(loops)==len(o.data.polygons)*3
    triangles=loops.reshape(-1,3)
    count=len(o.data.vertices)
    xyz=np.asarray([list(p) for p in source_points[cursor:cursor+count]],dtype=np.float64)
    mapped=geometry_ids[nearest_vertices[cursor:cursor+count]]
    cursor+=count
    source_ids=mapped[triangles].astype(np.uint32)
    query=triangle_keys(source_ids)
    left=np.searchsorted(sorted_keys,query)
    right=np.searchsorted(sorted_keys,query,side='right')
    exact=(left<len(sorted_keys)) & (sorted_keys[np.minimum(left,len(sorted_keys)-1)]==query)
    face_ids=order[np.minimum(left,len(sorted_keys)-1)].copy()
    for row in np.flatnonzero(~exact):
        candidates=np.unique(np.concatenate([adj_faces[adj_starts[int(v)]:adj_starts[int(v)+1]] for v in source_ids[row]]))
        assert len(candidates),o.name
        values=donor_xyz[donor_triangles[candidates]]
        distance=((xyz[triangles[row]][None,:,None,:]-values[:,None,:,:])**2).sum(axis=3)
        face_ids[row]=candidates[np.argmin(distance.min(axis=2).sum(axis=1))]
    for row in np.flatnonzero(exact & ((right-left)>1)):
        candidates=order[left[row]:right[row]]
        source_triangle=xyz[triangles[row]]
        source_normal=np.cross(source_triangle[1]-source_triangle[0],source_triangle[2]-source_triangle[0])
        values=donor_xyz[donor_triangles[candidates]]
        normals=np.cross(values[:,1]-values[:,0],values[:,2]-values[:,0])
        face_ids[row]=candidates[np.argmax(normals@source_normal)]
    uv=np.empty((len(triangles),3,2),dtype=np.float32)
    max_corner=0.0
    for start in range(0,len(triangles),50000):
        end=min(start+50000,len(triangles))
        values=donor_xyz[donor_triangles[face_ids[start:end]]]
        distance=((xyz[triangles[start:end]][:,:,None,:]-values[:,None,:,:])**2).sum(axis=3)
        corners=np.argmin(distance,axis=2)
        max_corner=max(max_corner,float(np.sqrt(np.max(np.min(distance,axis=2)))))
        uv[start:end]=donor_uv[face_ids[start:end]][np.arange(end-start)[:,None],corners]
    if not o.data.uv_layers:o.data.uv_layers.new(name='AtlasUV')
    o.data.uv_layers.active_index=0
    o.data.uv_layers.active.name=donor.data.uv_layers.active.name
    o.data.uv_layers.active.active_render=True
    o.data.uv_layers.active.data.foreach_set('uv',uv.ravel())
    assert geometry_hash(o)==before[o.name],o.name
    o.data.materials.clear();o.data.materials.append(material)
    for polygon in o.data.polygons:polygon.material_index=0
    row={'part':o.name,'triangles':len(triangles),'exact_face_matches':int(np.sum(exact)),
         'adjacent_face_fallbacks':int(np.sum(~exact)),'max_uv_corner_distance':max_corner}
    part_correspondence.append(row)
    print('ATLAS_PART '+json.dumps(row),flush=True)
bpy.ops.object.select_all(action='DESELECT')
for o in parts:o.select_set(True)
bpy.context.view_layer.objects.active=parts[0]
bpy.ops.export_scene.gltf(filepath=str(OUTPUT),export_format='GLB',use_selection=True,
                         use_active_scene=True,export_animations=False,export_cameras=False,export_lights=False)
blob=OUTPUT.read_bytes();gltf=json.loads(blob[20:20+int.from_bytes(blob[12:16],'little')])
assert len(gltf['scenes'])==1 and len(gltf['meshes'])==27 and len(gltf['materials'])==1 and len(gltf['images'])==3
report={'status':'UV_TRANSFER_VERIFIED_NATIVE_ART_PENDING',
        'source_sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
        'donor_sha256':hashlib.sha256(DONOR.read_bytes()).hexdigest(),
        'output_sha256':hashlib.sha256(blob).hexdigest(),'bytes':len(blob),
        'rigid_yaw_blender_z_degrees':best[1],'uniform_registration_scale':scale,
        'registration_candidates':[{'degrees':r[1],'mean_error':r[0]} for r in registrations],
        'all_source_vertices_checked':len(errors),'max_distance':float(np.max(errors)),
        'p999_distance':float(np.quantile(errors,.999)),
        'geometry_hashes_unchanged':before,'images':image_sizes,
        'face_correspondence':part_correspondence,
        'native_vault_transform':'Room applies the same rigid transform to visual part23 and collision part23',
        'limitations':'UV/geometry contract only;requires current native captures and public traversal.'}
(G/'atlas-transfer-contract.json').write_text(json.dumps(report,indent=2)+'\n')
print('ATLAS_TRANSFER_VERIFIED '+json.dumps({k:v for k,v in report.items() if k not in ['geometry_hashes_unchanged']}))

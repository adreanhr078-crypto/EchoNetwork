"""Export preserved corrected Tripo room and measure candidate native geometry."""
import bpy, bmesh, json, hashlib
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree

A=Path(r'C:/Users/yasmo/EchoNetwork/artifacts/eleven-eleven')
G=A/'art/production/maintenance-parkour-rebuild-20261027'
DEST=A/'godot/assets/environments/maintenance_stormworks'
DEST.mkdir(exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(G/'whole-room-derived-editable.blend'))
scene=bpy.data.scenes['STORMWORKS_CORRECTED_ASSEMBLY_20261027']
bpy.context.window.scene=scene
bpy.ops.object.select_all(action='DESELECT')
parts=[o for o in scene.objects if o.type=='MESH']
for o in parts:
    # Copies retained parents from the preserved source scene. Detach while
    # preserving the measured world matrix: glTF must not traverse that scene.
    matrix=o.matrix_world.copy();o.parent=None;o.matrix_world=matrix
bpy.context.view_layer.update()
scale=18.334597451041343
# The original bridge is also an open shell. Keep its actual top faces by
# plane-splitting the preserved original, rather than a solid-volume Boolean.
bridge=next(o for o in parts if o.name=='Stormworks_tripo_part_4')
original_bridge=bpy.data.scenes['STORMWORKS_ORIGINAL_PBR_20261027'].objects['tripo_part_4']
bridge.data=original_bridge.data.copy()
bridge.matrix_world=original_bridge.matrix_world.copy()
bm=bmesh.new();bm.from_mesh(bridge.data);bm.transform(bridge.matrix_world)
for bound,inner,outer in [(-2/scale,True,False),(0,False,True)]:
    bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),
                          dist=1e-8,plane_co=Vector((0,bound,0)),plane_no=Vector((0,1,0)),
                          clear_inner=inner,clear_outer=outer)
bm.transform(bridge.matrix_world.inverted());bm.to_mesh(bridge.data);bm.free()
bridge.matrix_world.translation+=Vector((0,8.3/scale,0))
bridge.data.update();bpy.context.view_layer.update()
# The generated circular front opening starts above the entry floor.
# A doorway is required for the existing ground-level chapter entrance.
# Keep the source and first corrected assembly in their saved blend unchanged.
front_wall=next(o for o in parts if o.name=='Stormworks_tripo_part_2')
# Diagnosis: the generated front mesh has 21777 boundary edges. Solid Boolean
# assumes a closed volume and created a false cutter-face across the doorway.
# Split the open surface at all six exact box planes before discarding the
# fully enclosed pieces. BMesh interpolates the original loop UVs on each cut.
# Native jamb/header geometry covers the exposed wall thickness.
bm=bmesh.new();bm.from_mesh(front_wall.data)
bm.transform(front_wall.matrix_world)
low=Vector((-.95/scale,-9.5818091025/scale,.85/scale))
high=Vector((.95/scale,-4.8818091025/scale,3.55/scale))
for axis in range(3):
    normal=Vector((0,0,0));normal[axis]=1
    for bound in [low[axis],high[axis]]:
        point=Vector((0,0,0));point[axis]=bound
        bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),
                              dist=1e-8,plane_co=point,plane_no=normal)
inside=[]
for face in bm.faces:
    p=face.calc_center_median()
    if all(low[i]+1e-8<p[i]<high[i]-1e-8 for i in range(3)):inside.append(face)
bmesh.ops.delete(bm,geom=inside,context='FACES')
bm.transform(front_wall.matrix_world.inverted());bm.to_mesh(front_wall.data);bm.free()
front_wall.data.update();bpy.context.view_layer.update()
for o in parts:o.select_set(True)
bpy.context.view_layer.objects.active=parts[0]
target=DEST/'stormworks_visual_portal_v5.glb'
assert not target.exists(),str(target)
bpy.ops.export_scene.gltf(filepath=str(target),export_format='GLB',use_selection=True,
                         use_active_scene=True,export_yup=True,export_animations=False,
                         export_cameras=False,export_lights=False)
payload=target.read_bytes()
gltf=json.loads(payload[20:20+int.from_bytes(payload[12:16],'little')])
assert len(gltf['scenes'])==1 and len(gltf['meshes'])==27
exported_triangles=sum(gltf['accessors'][p['indices']]['count']//3
                       for m in gltf['meshes'] for p in m['primitives'])
assert 1700000<exported_triangles<1800000,exported_triangles
offset=Vector((0,-1.05,-9.8818091025))
vertices=[];polygons=[];bounds=[]
for o in parts:
    points=[o.matrix_world@v.co for v in o.data.vertices]
    native=[Vector((p.x,p.z,-p.y))*scale+offset for p in points]
    start=len(vertices);vertices.extend(native)
    polygons.extend([tuple(start+i for i in p.vertices) for p in o.data.polygons])
    lo=[min(v[i] for v in native) for i in range(3)]
    hi=[max(v[i] for v in native) for i in range(3)]
    bounds.append({'name':o.name,'min':lo,'max':hi})
bvh=BVHTree.FromPolygons(vertices,polygons,all_triangles=False)
front=[]
for x in [-6,-4,-2,-1,0,1,2,4,6]:
    row={'x':x,'samples':[]}
    for y in [.15,.5,1,1.5,2]:
        hit,normal,index,distance=bvh.ray_cast(Vector((x,y,0)),Vector((0,0,-1)),5)
        row['samples'].append({'y':y,'distance':distance,'point':list(hit) if hit else None})
    front.append(row)
rear=[]
for x in [-6,-5,-4.5,-4,-3.5,-3,-2,-1,0,1,2,3,4,5,6]:
    row={'x':x,'samples':[]}
    for y in [4.2,4.8,5.4,6]:
        hit,normal,index,distance=bvh.ray_cast(Vector((x,y,-16.5)),Vector((0,0,-1)),4)
        row['samples'].append({'y':y,'distance':distance,'point':list(hit) if hit else None})
    rear.append(row)
bridge=next(o for o in parts if o.name=='Stormworks_tripo_part_4')
bridge_points=[bridge.matrix_world@v.co for v in bridge.data.vertices]
contract=json.loads((G/'corrected-room-contract.json').read_text())
contract['bridge']['retained_depth_m']=(max(p.y for p in bridge_points)-min(p.y for p in bridge_points))*scale
contract['bridge']['depth_measurement']='Measured vertices after exact open-shell clipping;solid Boolean derivative rejected'
contract['bridge']['method']='Vertical ray grid found the continuous source floor atY-2..0m;preserve that complete section and translateY+8.3m'
contract['bridge']['end_section_source_y_m']=[-2,0]
contract['bridge']['rigid_translation_blender_y_m']=8.3
contract['bridge']['triangles_after']=sum(len(p.vertices)-2 for p in bridge.data.polygons)
(G/'corrected-room-contract.json').write_text(json.dumps(contract,indent=2)+'\n')
report={'status':'NATIVE_CANDIDATE_GEOMETRY_ONLY','scale':scale,'translation':list(offset),
        'visual_sha256':hashlib.sha256(target.read_bytes()).hexdigest(),
        'parts':bounds,'front_probe':front,'rear_probe':rear,
        'limitations':'Point rays do not prove capsule clearance or player traversal.'}
(G/'native-portal-scope.json').write_text(json.dumps({
    'source_preserved':'whole-room-derived-editable.blend',
    'part':'Stormworks_tripo_part_2','operation':'six-plane exact open-surface difference;UV interpolation retained',
    'diagnosis':'21777 boundary edges;solid Boolean produced false closure and was rejected',
    'native_door_width':1.9,'reason':'Generated circular aperture starts above ground entry',
    'status':'Capsule and player acceptance pending'},indent=2)+'\n')
# Export a fresh collision derivative from the exact portal-corrected assembly.
for o in parts:
    if len(o.data.polygons)>7500:
        bpy.context.view_layer.objects.active=o
        dec=o.modifiers.new('NativeStaticCollision','DECIMATE');dec.ratio=.08
        bpy.ops.object.modifier_apply(modifier=dec.name)
    o.data.materials.clear()
bpy.ops.export_scene.gltf(filepath=str(DEST/'stormworks_collision_portal_v5.glb'),
                         export_format='GLB',use_selection=True,use_active_scene=True,
                         export_yup=True,export_animations=False,export_cameras=False,export_lights=False)
(G/'native-geometry-measurements.json').write_text(json.dumps(report,indent=2)+'\n')
print('NATIVE_EXPORT_COMPLETE '+str(target)+' '+report['visual_sha256'])

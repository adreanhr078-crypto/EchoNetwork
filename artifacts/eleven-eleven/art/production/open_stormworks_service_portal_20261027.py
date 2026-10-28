"""Match the measured rear service opening to Echo's full physical capsule."""
import bpy,bmesh,json,hashlib
from pathlib import Path
from mathutils import Vector
A=Path(r'C:/Users/yasmo/EchoNetwork/artifacts/eleven-eleven')
G=A/'art/production/maintenance-parkour-rebuild-20261027'
ASSETS=A/'godot/assets/environments/maintenance_stormworks'
SCALE=18.334597451041343
low=Vector((-1/SCALE,6.6181908975/SCALE,6.45/SCALE))
high=Vector((1/SCALE,9.1181908975/SCALE,8.85/SCALE))
outputs=[]
for source,target in [
    ('stormworks_atlas4k_visual_v5.glb','stormworks_atlas4k_visual_v7.glb'),
    ('stormworks_collision_portal_v5.glb','stormworks_collision_portal_v7.glb')]:
    assert not (ASSETS/target).exists()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(G/source))
    parts=[o for o in bpy.context.scene.objects if o.type=='MESH']
    assert len(parts)==27
    for o in parts:
        matrix=o.matrix_world.copy();o.parent=None;o.matrix_world=matrix
    bpy.context.view_layer.update()
    wall=next(o for o in parts if o.name=='Stormworks_tripo_part_0')
    before=sum(len(p.vertices)-2 for p in wall.data.polygons)
    bm=bmesh.new();bm.from_mesh(wall.data);bm.transform(wall.matrix_world)
    # The closed/open sweep proved central headroom blocked. A second
    # standing-overlap probe also proved the wheel bay occupied bypart0.
    # Form a four-metre-wide front recess leading to the two-metre door.
    recess_low=Vector((-2/SCALE,6.6181908975/SCALE,6.45/SCALE))
    recess_high=Vector((2/SCALE,8.1681908975/SCALE,8.85/SCALE))
    for lower,upper in [(low,high),(recess_low,recess_high)]:
        for axis in range(3):
            normal=Vector((0,0,0));normal[axis]=1
            for bound in [lower[axis],upper[axis]]:
                point=Vector((0,0,0));point[axis]=bound
                bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),
                                      dist=1e-8,plane_co=point,plane_no=normal)
        removed=[f for f in bm.faces if all(lower[i]+1e-8<f.calc_center_median()[i]<upper[i]-1e-8 for i in range(3))]
        assert removed
        bmesh.ops.delete(bm,geom=removed,context='FACES')
    bm.transform(wall.matrix_world.inverted());bm.to_mesh(wall.data);bm.free()
    wall.data.update();bpy.context.view_layer.update()
    bpy.ops.object.select_all(action='DESELECT')
    for o in parts:o.select_set(True)
    bpy.context.view_layer.objects.active=wall
    bpy.ops.export_scene.gltf(filepath=str(ASSETS/target),export_format='GLB',use_selection=True,
                             use_active_scene=True,export_animations=False,export_cameras=False,export_lights=False)
    blob=(ASSETS/target).read_bytes();gltf=json.loads(blob[20:20+int.from_bytes(blob[12:16],'little')])
    assert len(gltf['scenes'])==1 and len(gltf['meshes'])==27
    outputs.append({'file':target,'source':source,'sha256':hashlib.sha256(blob).hexdigest(),
                    'bytes':len(blob),'wall_triangles_before':before,
                    'wall_triangles_after':sum(len(p.vertices)-2 for p in wall.data.polygons)})
    print('SERVICE_PORTAL_EXPORTED '+target,flush=True)
(G/'service-portal-contract.json').write_text(json.dumps({
    'status':'MESH_CORRECTION_READY_CAPSULE_REVIEW_PENDING',
    'cause':'Actual Echo capsule remained blocked bypart0 after opening the gate;old aperture had insufficient headroom.',
    'native_window':{'min':[-1,5.4,-19],'max':[1,7.8,-16.5]},
    'native_front_recess':{'min':[-2,5.4,-18.05],'max':[2,7.8,-16.5]},
    'method':'Six-plane surface difference onpart0 only;interpolated atlas UVs retained;native steel frame closes cut edges.',
    'originals_preserved':True,'outputs':outputs},indent=2)+'\n')

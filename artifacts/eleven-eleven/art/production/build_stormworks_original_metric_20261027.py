"""Preserve the coherent original UV/PBR and bake native metres before LOD import.

The single-atlas variant remains preserved: controlled Godot comparisons showed
triangular colour patches even with its normal map disabled and standard PBR.
"""
import bpy,bmesh,json,hashlib
import numpy as np
from pathlib import Path
from mathutils import Vector,Matrix
A=Path(r'C:/Users/yasmo/EchoNetwork/artifacts/eleven-eleven')
G=A/'art/production/maintenance-parkour-rebuild-20261027'
ASSETS=A/'godot/assets/environments/maintenance_stormworks'
SOURCE=ASSETS/'stormworks_visual_portal_v5.glb'
OUTPUT=ASSETS/'stormworks_original_pbr_metric_v8.glb'
assert not OUTPUT.exists()
S=18.334597451041343
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(SOURCE))
parts=[o for o in bpy.context.scene.objects if o.type=='MESH']
assert len(parts)==27
for o in parts:
    matrix=o.matrix_world.copy();o.parent=None;o.matrix_world=matrix
bpy.context.view_layer.update()
wall=next(o for o in parts if o.name=='Stormworks_tripo_part_0')
bm=bmesh.new();bm.from_mesh(wall.data);bm.transform(wall.matrix_world)
for low,high in [
    (Vector((-1/S,6.6181908975/S,6.45/S)),Vector((1/S,9.1181908975/S,8.85/S))),
    (Vector((-2/S,6.6181908975/S,6.45/S)),Vector((2/S,8.1681908975/S,8.85/S)))]:
    for axis in range(3):
        normal=Vector((0,0,0));normal[axis]=1
        for bound in [low[axis],high[axis]]:
            point=Vector((0,0,0));point[axis]=bound
            bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),
                                  dist=1e-8,plane_co=point,plane_no=normal)
    removed=[f for f in bm.faces if all(low[i]+1e-8<f.calc_center_median()[i]<high[i]-1e-8 for i in range(3))]
    assert removed
    bmesh.ops.delete(bm,geom=removed,context='FACES')
bm.transform(wall.matrix_world.inverted());bm.to_mesh(wall.data);bm.free()
wall.data.update();bpy.context.view_layer.update()
metric=Matrix.Translation((0,9.8818091025,-1.05))@Matrix.Scale(S,4)
maximum_error=0.0
for o in parts:
    expected=np.asarray([list(metric@o.matrix_world@v.co) for v in o.data.vertices],dtype=np.float64)
    uv_before=np.empty(len(o.data.uv_layers.active.data)*2,dtype=np.float32)
    o.data.uv_layers.active.data.foreach_get('uv',uv_before)
    o.matrix_world=metric@o.matrix_world
    bpy.ops.object.select_all(action='DESELECT');o.select_set(True)
    bpy.context.view_layer.objects.active=o
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    actual=np.asarray([list(o.matrix_world@v.co) for v in o.data.vertices],dtype=np.float64)
    maximum_error=max(maximum_error,float(np.max(np.linalg.norm(expected-actual,axis=1))))
    uv_after=np.empty_like(uv_before);o.data.uv_layers.active.data.foreach_get('uv',uv_after)
    assert np.array_equal(uv_before,uv_after),o.name
assert maximum_error<1e-5,maximum_error
bpy.ops.object.select_all(action='DESELECT')
for o in parts:o.select_set(True)
bpy.context.view_layer.objects.active=parts[0]
bpy.ops.export_scene.gltf(filepath=str(OUTPUT),export_format='GLB',use_selection=True,
                         use_active_scene=True,export_animations=False,export_cameras=False,export_lights=False)
blob=OUTPUT.read_bytes();gltf=json.loads(blob[20:20+int.from_bytes(blob[12:16],'little')])
assert len(gltf['scenes'])==1 and len(gltf['meshes'])==27
images={}
for material in bpy.data.materials:
    if material.use_nodes:
        for n in material.node_tree.nodes:
            if n.type=='TEX_IMAGE' and n.image:images[n.image.name]=list(n.image.size)
histogram={}
for size in images.values():
    key='%dx%d'%tuple(size);histogram[key]=histogram.get(key,0)+1
report={'status':'METRIC_ORIGINAL_UV_PBR_READY_NATIVE_ART_PENDING',
        'source_sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
        'sha256':hashlib.sha256(blob).hexdigest(),'bytes':len(blob),
        'mesh_roles':27,'materials':len(gltf['materials']),'images':len(gltf['images']),
        'original_image_size_histogram':histogram,'uv_arrays_unchanged':True,
        'native_world_position_bake_max_error_m':maximum_error,
        'native_visual_root_scale':1,'native_visual_root_translation':[0,0,0],
        'collision':'Existingv7proxy remains unchanged;already baked by the room into native metres',
        'art_choice':'Original per-part UV/PBR visibly outperformed the preserved single-atlas variant in controlled current Godot captures.',
        'limits':'Original maps are adaptive32..2048px,not all4K. Current art/full route must be reviewed again.'}
(G/'original-metric-v8-contract.json').write_text(json.dumps(report,indent=2)+'\n')
print('ORIGINAL_METRIC_VERIFIED '+json.dumps(report),flush=True)

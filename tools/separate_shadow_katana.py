import bpy

glb = r'artifacts/eleven-eleven/art/production/tripo-20261007/shadow-katana/tripo-out/shadow-katana-20261007-c9cae674/model.glb'
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=glb)
obj = bpy.context.scene.objects[0]
bpy.context.view_layer.objects.active = obj
obj.select_set(True)
bpy.ops.object.mode_set(mode='EDIT')
bpy.ops.mesh.separate(type='LOOSE')
bpy.ops.object.mode_set(mode='OBJECT')

parts = [o for o in bpy.context.scene.objects if o.type == 'MESH']
print(f"Separated parts count: {len(parts)}")
for i, p in enumerate(parts):
    min_z = min(c[2] for c in p.bound_box)
    max_z = max(c[2] for c in p.bound_box)
    dim = p.dimensions
    print(f"Part {i}: {p.name}, verts={len(p.data.vertices)}, faces={len(p.data.polygons)}, dims=({dim.x:.3f}, {dim.y:.3f}, {dim.z:.3f}), Z-range=[{min_z:.3f}, {max_z:.3f}]")

# Let's inspect the geometry details of each part (e.g. blade edge vs hollow/tubular sheath)
for i, p in enumerate(parts):
    # Check bounding box in Y (length)
    mesh = p.data
    # Look at cross section along the blade body (e.g. Y from 0.0 to 0.3)
    mid_verts = [v for v in mesh.vertices if 0.0 < v.co.y < 0.3]
    if mid_verts:
        xs = [v.co.x for v in mid_verts]
        zs = [v.co.z for v in mid_verts]
        print(f"Part {i} mid-section: X span = {max(xs)-min(xs):.4f}, Z span = {max(zs)-min(zs):.4f}")

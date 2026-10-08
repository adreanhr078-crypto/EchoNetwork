import bpy
import glob
from pathlib import Path

props_dir = Path("artifacts/eleven-eleven/godot/assets/props")
pattern = str(props_dir / "*_tripo_20261008.glb")
files = glob.glob(pattern)
print(f"Found {len(files)} tripo glb files in props:")

for f in sorted(files):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=f)
    objs = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    total_v = sum(len(o.data.vertices) for o in objs)
    total_p = sum(len(o.data.polygons) for o in objs)
    max_dims = [0.0, 0.0, 0.0]
    for o in objs:
        for i in range(3):
            max_dims[i] = max(max_dims[i], o.dimensions[i])
    print(f"File: {Path(f).name} | meshes: {len(objs)} | verts: {total_v} | polys: {total_p} | dims: ({max_dims[0]:.3f}, {max_dims[1]:.3f}, {max_dims[2]:.3f})")

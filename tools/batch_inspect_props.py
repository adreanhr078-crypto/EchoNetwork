import bpy
from mathutils import Vector
import numpy as np

def inspect_prop(path, name):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=path)
    obj = bpy.context.scene.objects[0]
    coords = np.array([v.co for v in obj.data.vertices])
    min_c = coords.min(axis=0)
    max_c = coords.max(axis=0)
    dims = max_c - min_c
    print(f"\n================ {name} ================")
    print(f"Vertices: {len(coords)}, Polygons: {len(obj.data.polygons)}")
    print(f"BBox Min: {min_c}")
    print(f"BBox Max: {max_c}")
    print(f"Dimensions: {dims} (X={dims[0]:.3f}, Y={dims[1]:.3f}, Z={dims[2]:.3f})")

props = [
    (r"C:\Users\yasmo\EchoNetwork\artifacts\eleven-eleven\art\production\tripo-20261007\standard-katana\tripo-out\standard-katana-20261007-f43b4b42\model.glb", "standard-katana"),
    (r"C:\Users\yasmo\EchoNetwork\artifacts\eleven-eleven\art\production\tripo-20261007\shadow-katana\tripo-out\shadow-katana-20261007-c9cae674\model.glb", "shadow-katana"),
    (r"C:\Users\yasmo\EchoNetwork\artifacts\eleven-eleven\art\production\tripo-20261007\diagnostic-cart\tripo-out\diagnostic-cart-20261007-787ef5a5\model.glb", "diagnostic-cart"),
    (r"C:\Users\yasmo\EchoNetwork\artifacts\eleven-eleven\art\production\tripo-20261007\security-terminal\tripo-out\security-terminal-20261007-df7cbe72\model.glb", "security-terminal"),
    (r"C:\Users\yasmo\EchoNetwork\artifacts\eleven-eleven\art\production\tripo-20261007\observation-server\tripo-out\observation-server-20261007-4cdb4008\model.glb", "observation-server"),
    (r"C:\Users\yasmo\EchoNetwork\artifacts\eleven-eleven\art\production\tripo-20261007\medical-wall-unit\tripo-out\medical-wall-unit-20261007-5affa583\model.glb", "medical-wall-unit")
]

for path, name in props:
    inspect_prop(path, name)

bpy.ops.wm.quit_blender()

import bpy
import numpy as np

def inspect_orientation(glb_path, name):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=glb_path)
    obj = bpy.context.scene.objects[0]
    coords = np.array([v.co for v in obj.data.vertices])
    
    print(f"\n================ Orientation Analysis: {name} ================")
    print(f"BBox Min: {coords.min(axis=0)}")
    print(f"BBox Max: {coords.max(axis=0)}")
    
    # Check extremes
    # Top vertices (max Z)
    top_verts = coords[coords[:, 2] > (coords[:, 2].max() - 0.05)]
    # Bottom vertices (min Z)
    bot_verts = coords[coords[:, 2] < (coords[:, 2].min() + 0.05)]
    print(f"Top verts Z > {coords[:, 2].max() - 0.05:.3f}: count={len(top_verts)}, center={top_verts.mean(axis=0)}")
    print(f"Bot verts Z < {coords[:, 2].min() + 0.05:.3f}: count={len(bot_verts)}, center={bot_verts.mean(axis=0)}")
    
    # Check Y extremes (front vs back)
    y_min_verts = coords[coords[:, 1] < (coords[:, 1].min() + 0.05)]
    y_max_verts = coords[coords[:, 1] > (coords[:, 1].max() - 0.05)]
    print(f"Y min verts: count={len(y_min_verts)}, center={y_min_verts.mean(axis=0)}")
    print(f"Y max verts: count={len(y_max_verts)}, center={y_max_verts.mean(axis=0)}")
    
    # Check X extremes (left vs right)
    x_min_verts = coords[coords[:, 0] < (coords[:, 0].min() + 0.05)]
    x_max_verts = coords[coords[:, 0] > (coords[:, 0].max() - 0.05)]
    print(f"X min verts: count={len(x_min_verts)}, center={x_min_verts.mean(axis=0)}")
    print(f"X max verts: count={len(x_max_verts)}, center={x_max_verts.mean(axis=0)}")

props = [
    (r"C:\Users\yasmo\EchoNetwork\artifacts\eleven-eleven\art\production\tripo-20261007\diagnostic-cart\tripo-out\diagnostic-cart-20261007-787ef5a5\model.glb", "diagnostic-cart"),
    (r"C:\Users\yasmo\EchoNetwork\artifacts\eleven-eleven\art\production\tripo-20261007\security-terminal\tripo-out\security-terminal-20261007-df7cbe72\model.glb", "security-terminal"),
    (r"C:\Users\yasmo\EchoNetwork\artifacts\eleven-eleven\art\production\tripo-20261007\observation-server\tripo-out\observation-server-20261007-4cdb4008\model.glb", "observation-server"),
    (r"C:\Users\yasmo\EchoNetwork\artifacts\eleven-eleven\art\production\tripo-20261007\medical-wall-unit\tripo-out\medical-wall-unit-20261007-5affa583\model.glb", "medical-wall-unit")
]

for p, n in props:
    inspect_orientation(p, n)

bpy.ops.wm.quit_blender()

import bpy
import bmesh
import numpy as np

bpy.ops.wm.read_factory_settings(use_empty=True)
glb_path = r"C:\Users\yasmo\EchoNetwork\artifacts\eleven-eleven\art\production\tripo-20261007\shadow-katana\tripo-out\shadow-katana-20261007-c9cae674\model.glb"
bpy.ops.import_scene.gltf(filepath=glb_path)
obj = bpy.context.scene.objects[0]
bm = bmesh.new()
bm.from_mesh(obj.data)

visited = set()
islands = []
for v in bm.verts:
    if v in visited:
        continue
    queue = [v]
    visited.add(v)
    island = []
    while queue:
        curr = queue.pop()
        island.append(curr)
        for e in curr.link_edges:
            o = e.other_vert(curr)
            if o not in visited:
                visited.add(o)
                queue.append(o)
    islands.append(island)

islands.sort(key=lambda x: len(x), reverse=True)
print(f"Top 10 islands by vertex count:")
for i in range(min(10, len(islands))):
    coords = np.array([v.co for v in islands[i]])
    print(f"Rank {i+1}: count={len(islands[i])}, min={coords.min(axis=0)}, max={coords.max(axis=0)}, mean={coords.mean(axis=0)}")

bm.free()
bpy.ops.wm.quit_blender()

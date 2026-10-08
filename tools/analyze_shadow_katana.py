import bpy
import bmesh
from mathutils import Vector
import numpy as np

bpy.ops.wm.read_factory_settings(use_empty=True)
glb_path = r"C:\Users\yasmo\EchoNetwork\artifacts\eleven-eleven\art\production\tripo-20261007\shadow-katana\tripo-out\shadow-katana-20261007-c9cae674\model.glb"
bpy.ops.import_scene.gltf(filepath=glb_path)

mesh_objs = [obj for obj in bpy.context.scene.objects if obj.type == 'MESH']
assert len(mesh_objs) == 1
obj = mesh_objs[0]

# Convert to bmesh to analyze connected components (loose parts)
bm = bmesh.new()
bm.from_mesh(obj.data)

# Find connected components (islands)
visited_verts = set()
islands = []

for v in bm.verts:
    if v in visited_verts:
        continue
    island_verts = []
    queue = [v]
    visited_verts.add(v)
    while queue:
        curr = queue.pop()
        island_verts.append(curr)
        for edge in curr.link_edges:
            other = edge.other_vert(curr)
            if other not in visited_verts:
                visited_verts.add(other)
                queue.append(other)
    islands.append(island_verts)

print(f"Total connected components (islands): {len(islands)}")
for idx, island in enumerate(islands):
    coords = np.array([v.co for v in island])
    min_c = coords.min(axis=0)
    max_c = coords.max(axis=0)
    dims = max_c - min_c
    print(f"Island {idx}: {len(island)} verts, bbox min={min_c}, max={max_c}, dims={dims}")

bm.free()
bpy.ops.wm.quit_blender()

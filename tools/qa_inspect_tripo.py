import sys
import json
import bpy
from mathutils import Vector

def inspect_glb(glb_path):
    # Clear existing data
    bpy.ops.wm.read_factory_settings(use_empty=True)

    # Import GLB
    bpy.ops.import_scene.gltf(filepath=glb_path)

    objects = [obj for obj in bpy.context.scene.objects if obj.type == 'MESH']
    
    total_vertices = 0
    total_polygons = 0
    total_triangles = 0
    
    min_coord = Vector((float('inf'), float('inf'), float('inf')))
    max_coord = Vector((float('-inf'), float('-inf'), float('-inf')))

    for obj in objects:
        mesh = obj.data
        total_vertices += len(mesh.vertices)
        total_polygons += len(mesh.polygons)
        
        # Calculate triangles
        mesh.calc_loop_triangles()
        total_triangles += len(mesh.loop_triangles)

        # Bounding box in world coordinates
        for corner in obj.bound_box:
            world_corner = obj.matrix_world @ Vector(corner)
            for i in range(3):
                min_coord[i] = min(min_coord[i], world_corner[i])
                max_coord[i] = max(max_coord[i], world_corner[i])

    dimensions = max_coord - min_coord
    
    materials_info = []
    for mat in bpy.data.materials:
        mat_data = {
            "name": mat.name,
            "use_nodes": mat.use_nodes,
            "textures": []
        }
        if mat.use_nodes and mat.node_tree:
            for node in mat.node_tree.nodes:
                if node.type == 'TEX_IMAGE' and node.image:
                    mat_data["textures"].append({
                        "name": node.image.name,
                        "filepath": node.image.filepath,
                        "size": list(node.image.size)
                    })
        materials_info.append(mat_data)

    images_info = []
    for img in bpy.data.images:
        images_info.append({
            "name": img.name,
            "size": list(img.size),
            "channels": img.channels,
            "filepath": img.filepath
        })

    result = {
        "glb_path": glb_path,
        "mesh_objects_count": len(objects),
        "mesh_names": [obj.name for obj in objects],
        "total_vertices": total_vertices,
        "total_faces": total_polygons,
        "total_triangles": total_triangles,
        "bounds_min": [min_coord.x, min_coord.y, min_coord.z],
        "bounds_max": [max_coord.x, max_coord.y, max_coord.z],
        "dimensions": [dimensions.x, dimensions.y, dimensions.z],
        "materials": materials_info,
        "images": images_info
    }
    return result

if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if not args:
        print("Usage: blender --background --python qa_inspect_tripo.py -- <path_to_glb>")
        sys.exit(1)
        
    glb_path = args[0]
    info = inspect_glb(glb_path)
    print("=== INSPECTION RESULT ===")
    print(json.dumps(info, indent=2))

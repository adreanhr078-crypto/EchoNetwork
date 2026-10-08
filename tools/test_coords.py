import bpy
from mathutils import Vector

bpy.ops.wm.read_factory_settings(use_empty=True)

# Create a test cube at (0, 0, 0.5) with size 1 -> z ranges from 0 to 1
bpy.ops.mesh.primitive_cube_add(location=(0, 0, 0.5))
cube = bpy.context.active_object
cube.scale = (0.5, 0.5, 0.5) # cube size 1x1x1, z from 0 to 1
bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)

# Export to temp glb
temp_glb = r"C:\Users\yasmo\EchoNetwork\tools\test_coords.glb"
bpy.ops.export_scene.gltf(filepath=temp_glb, export_format='GLB')

# Re-read raw glTF JSON chunks
import json
with open(temp_glb, 'rb') as f:
    header = f.read(12)
    # chunk 0 is JSON
    chunk_len = int.from_bytes(f.read(4), 'little')
    chunk_type = f.read(4)
    chunk_data = f.read(chunk_len).decode('utf-8')
    gltf_json = json.loads(chunk_data)
    print("glTF Accessors (min/max):")
    for acc in gltf_json.get('accessors', []):
        if 'min' in acc and 'max' in acc:
            print(f"  Type: {acc.get('type')}, Min: {acc['min']}, Max: {acc['max']}")

bpy.ops.wm.quit_blender()

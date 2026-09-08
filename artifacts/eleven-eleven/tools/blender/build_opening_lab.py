import bpy
import os
import math

def create_material(name, color, metallic=0.0, roughness=0.5, emission_color=None, emission_strength=0.0):
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    
    bsdf.inputs['Base Color'].default_value = color
    if 'Metallic' in bsdf.inputs:
        bsdf.inputs['Metallic'].default_value = metallic
    if 'Roughness' in bsdf.inputs:
        bsdf.inputs['Roughness'].default_value = roughness
        
    if emission_color and emission_strength > 0:
        if 'Emission Color' in bsdf.inputs:
             bsdf.inputs['Emission Color'].default_value = emission_color
        elif 'Emission' in bsdf.inputs: 
             bsdf.inputs['Emission'].default_value = emission_color
             
        if 'Emission Strength' in bsdf.inputs:
            bsdf.inputs['Emission Strength'].default_value = emission_strength
            
    return mat

def clear_scene():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    for block in bpy.data.materials:
        if not block.users:
            bpy.data.materials.remove(block)

def build_room():
    obsidian_floor = create_material("Mat_ObsidianFloor", (0.02, 0.02, 0.02, 1.0), metallic=0.8, roughness=0.2)
    obsidian_wall = create_material("Mat_ObsidianWall", (0.03, 0.04, 0.05, 1.0), metallic=0.5, roughness=0.6)
    crimson_glow = create_material("Mat_CrimsonGlow", (1.0, 0.0, 0.1, 1.0), emission_color=(1.0, 0.0, 0.1, 1.0), emission_strength=5.0)
    pod_metal = create_material("Mat_PodMetal", (0.1, 0.1, 0.1, 1.0), metallic=0.9, roughness=0.3)
    desk_metal = create_material("Mat_DeskMetal", (0.05, 0.08, 0.1, 1.0), metallic=0.7, roughness=0.4)
    
    width, depth, height = 8.8, 6.8, 3.6
    
    # Floor
    bpy.ops.mesh.primitive_plane_add(size=1, location=(0, 0, 0))
    floor = bpy.context.active_object
    floor.name = "Floor"
    floor.scale = (width, depth, 1)
    floor.data.materials.append(obsidian_floor)
    
    # Walls
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, depth/2, height/2))
    wall_n = bpy.context.active_object
    wall_n.name = "Wall_North"
    wall_n.scale = (width, 0.2, height)
    wall_n.data.materials.append(obsidian_wall)
    
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, -depth/2, height/2))
    wall_s = bpy.context.active_object
    wall_s.name = "Wall_South"
    wall_s.scale = (width, 0.2, height)
    wall_s.data.materials.append(obsidian_wall)
    
    bpy.ops.mesh.primitive_cube_add(size=1, location=(width/2, 0, height/2))
    wall_e = bpy.context.active_object
    wall_e.name = "Wall_East"
    wall_e.scale = (0.2, depth, height)
    wall_e.data.materials.append(obsidian_wall)
    
    bpy.ops.mesh.primitive_cube_add(size=1, location=(-width/2, 0, height/2))
    wall_w = bpy.context.active_object
    wall_w.name = "Wall_West"
    wall_w.scale = (0.2, depth, height)
    wall_w.data.materials.append(obsidian_wall)
    
    # Pod Base
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0.15, -1.82, 0.38))
    pod_base = bpy.context.active_object
    pod_base.name = "Pod_Base"
    pod_base.scale = (1.5, 2.2, 0.76)
    pod_base.data.materials.append(pod_metal)
    
    # Pod Glow
    bpy.ops.mesh.primitive_plane_add(size=1, location=(0.15, -1.82, 0.76 + 0.01))
    pod_glow = bpy.context.active_object
    pod_glow.name = "Pod_Glow"
    pod_glow.scale = (1.3, 2.0, 1)
    pod_glow.data.materials.append(crimson_glow)
    
    # Desk
    bpy.ops.mesh.primitive_cube_add(size=1, location=(-2.3, -3.32, 0.78))
    desk = bpy.context.active_object
    desk.name = "Desk"
    desk.scale = (1.8, 0.8, 1.56)
    desk.data.materials.append(desk_metal)
    
    # Terminal Screen
    bpy.ops.mesh.primitive_plane_add(size=1, location=(-2.3, -3.32 + 0.41, 1.2))
    screen = bpy.context.active_object
    screen.name = "Terminal_Screen"
    screen.rotation_euler = (math.radians(90), 0, 0)
    screen.scale = (1.0, 0.6, 1)
    screen.data.materials.append(crimson_glow)
    
def export_glb(filepath):
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.export_scene.gltf(
        filepath=filepath,
        export_format='GLB',
        use_selection=True,
        export_apply=True,
        export_yup=True
    )

if __name__ == "__main__":
    import sys
    argv = sys.argv
    try:
        index = argv.index("--") + 1
    except ValueError:
        index = len(argv)
    args = argv[index:]
    if not args:
        print("Usage: blender --background --python script.py -- <output_filepath>")
        sys.exit(1)
        
    output_filepath = args[0]
    os.makedirs(os.path.dirname(output_filepath), exist_ok=True)
    clear_scene()
    build_room()
    export_glb(output_filepath)
    print(f"Successfully exported to {output_filepath}")

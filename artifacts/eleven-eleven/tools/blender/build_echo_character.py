import bpy
import os
import math

def create_toon_material(name, color):
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs['Base Color'].default_value = color
    if 'Specular IOR Level' in bsdf.inputs:
        bsdf.inputs['Specular IOR Level'].default_value = 0.1
    if 'Roughness' in bsdf.inputs:
        bsdf.inputs['Roughness'].default_value = 0.9
    return mat

def create_humanoid():
    # Colors
    obsidian = create_toon_material("Mat_Echo_Obsidian", (0.05, 0.05, 0.06, 1.0))
    skin = create_toon_material("Mat_Echo_Skin", (0.9, 0.75, 0.65, 1.0))
    hair_color = create_toon_material("Mat_Echo_Hair", (0.1, 0.1, 0.15, 1.0))

    # Body parts
    bpy.ops.mesh.primitive_cube_add(size=1)
    torso = bpy.context.active_object
    torso.name = "Echo_Torso"
    torso.scale = (0.4, 0.25, 0.6)
    torso.location = (0, 0, 1.0)
    torso.data.materials.append(obsidian)
    
    bpy.ops.mesh.primitive_cube_add(size=1)
    head = bpy.context.active_object
    head.name = "Echo_Head"
    head.scale = (0.22, 0.22, 0.26)
    head.location = (0, 0, 1.55)
    head.data.materials.append(skin)

    # Simple hair block
    bpy.ops.mesh.primitive_cube_add(size=1)
    hair = bpy.context.active_object
    hair.name = "Echo_Hair"
    hair.scale = (0.24, 0.24, 0.1)
    hair.location = (0, 0, 1.68)
    hair.data.materials.append(hair_color)

    # Arm L
    bpy.ops.mesh.primitive_cube_add(size=1)
    arm_l = bpy.context.active_object
    arm_l.name = "Echo_Arm_L"
    arm_l.scale = (0.12, 0.12, 0.6)
    arm_l.location = (0.3, 0, 1.0)
    arm_l.data.materials.append(obsidian)

    # Arm R
    bpy.ops.mesh.primitive_cube_add(size=1)
    arm_r = bpy.context.active_object
    arm_r.name = "Echo_Arm_R"
    arm_r.scale = (0.12, 0.12, 0.6)
    arm_r.location = (-0.3, 0, 1.0)
    arm_r.data.materials.append(obsidian)

    # Leg L
    bpy.ops.mesh.primitive_cube_add(size=1)
    leg_l = bpy.context.active_object
    leg_l.name = "Echo_Leg_L"
    leg_l.scale = (0.15, 0.15, 0.7)
    leg_l.location = (0.12, 0, 0.35)
    leg_l.data.materials.append(obsidian)

    # Leg R
    bpy.ops.mesh.primitive_cube_add(size=1)
    leg_r = bpy.context.active_object
    leg_r.name = "Echo_Leg_R"
    leg_r.scale = (0.15, 0.15, 0.7)
    leg_r.location = (-0.12, 0, 0.35)
    leg_r.data.materials.append(obsidian)
    
    # Select all and join into one mesh for simplicity (or parent to Armature)
    bpy.ops.object.select_all(action='DESELECT')
    for obj in [torso, head, hair, arm_l, arm_r, leg_l, leg_r]:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = torso
    bpy.ops.object.join()
    torso.name = "Echo_Mesh"
    return torso

def build_echo():
    # Clear scene
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    
    mesh = create_humanoid()
    
    # Create simple rig/armature
    bpy.ops.object.armature_add(enter_editmode=True, align='WORLD', location=(0, 0, 0))
    armature = bpy.context.active_object
    armature.name = "Echo_Rig"
    
    # Parent mesh to armature
    bpy.ops.object.mode_set(mode='OBJECT')
    bpy.ops.object.select_all(action='DESELECT')
    mesh.select_set(True)
    armature.select_set(True)
    bpy.context.view_layer.objects.active = armature
    bpy.ops.object.parent_set(type='ARMATURE_AUTO')
    
    # Animate Idle
    armature.animation_data_create()
    action_idle = bpy.data.actions.new(name="idle")
    armature.animation_data.action = action_idle
    # Simple procedural bobbing for idle
    bone = armature.pose.bones["Bone"]
    bone.rotation_mode = 'XYZ'
    bone.keyframe_insert(data_path="location", frame=1)
    bone.location = (0, 0, -0.02)
    bone.keyframe_insert(data_path="location", frame=30)
    bone.location = (0, 0, 0)
    bone.keyframe_insert(data_path="location", frame=60)
    
    # Animate Walk (Dummy)
    action_walk = bpy.data.actions.new(name="walk")
    action_walk.use_fake_user = True
    
    # Animate Run (Dummy)
    action_run = bpy.data.actions.new(name="run")
    action_run.use_fake_user = True

def export_glb(filepath):
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.export_scene.gltf(
        filepath=filepath,
        export_format='GLB',
        use_selection=True,
        export_apply=True,
        export_animations=True
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
    build_echo()
    export_glb(output_filepath)
    print(f"Successfully exported to {output_filepath}")

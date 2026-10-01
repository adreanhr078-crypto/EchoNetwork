"""Prepare an owner-local VRoid export for a bounded G0 rig/clip proof."""
import argparse
import math
import sys
from pathlib import Path
import bpy
from mathutils import Vector, Quaternion

parser = argparse.ArgumentParser()
parser.add_argument('--input', required=True)
parser.add_argument('--output', required=True)
args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:])
source = Path(args.input).resolve()
target = Path(args.output).resolve()
target.parent.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(source))
armatures = [obj for obj in bpy.context.scene.objects if obj.type == 'ARMATURE']
if len(armatures) != 1:
    raise RuntimeError(f'Expected one armature, found {len(armatures)}')
arm = armatures[0]
arm.name = 'Echo_G0_Rig'
mapping = {
    'Root':'root', 'J_Bip_C_Hips':'hips', 'J_Bip_C_Spine':'spine_01',
    'J_Bip_C_Chest':'spine_02', 'J_Bip_C_Neck':'neck', 'J_Bip_C_Head':'head',
    'J_Bip_L_UpperArm':'upper_arm.L', 'J_Bip_L_LowerArm':'lower_arm.L',
    'J_Bip_L_Hand':'hand.L', 'J_Bip_R_UpperArm':'upper_arm.R',
    'J_Bip_R_LowerArm':'lower_arm.R', 'J_Bip_R_Hand':'hand.R',
    'J_Bip_L_UpperLeg':'thigh.L', 'J_Bip_L_LowerLeg':'shin.L',
    'J_Bip_L_Foot':'foot.L', 'J_Bip_L_ToeBase':'toe.L',
    'J_Bip_R_UpperLeg':'thigh.R', 'J_Bip_R_LowerLeg':'shin.R',
    'J_Bip_R_Foot':'foot.R', 'J_Bip_R_ToeBase':'toe.R',
}
for old, new in mapping.items():
    if old not in arm.data.bones:
        raise RuntimeError(f'Missing source bone: {old}')
    arm.data.bones[old].name = new

# Technical identifier glyphs. Placement must be reviewed against exposed skin;
# the source sample's high collar prevents final Canon approval.
neck = arm.data.bones['neck']
neck_world = arm.matrix_world @ neck.head_local
bpy.ops.object.text_add(location=neck_world + Vector((0.0, -0.065, 0.025)))
mark = bpy.context.object
mark.data.body = 'EX-011'
mark.data.align_x = 'CENTER'
mark.data.size = 0.018
mark.data.extrude = 0.0
mark.data.resolution_u = 4
mark.rotation_euler.x = math.pi / 2
bpy.ops.object.convert(target='MESH')
mark = bpy.context.object
mark.name = 'IdentifierPlacementStudy_EX011'
bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
mat = bpy.data.materials.new('SkinTattoo_EX011_Material')
mat.diffuse_color = (0.72, 0.01, 0.04, 1.0)
mat.use_nodes = True
bsdf = mat.node_tree.nodes.get('Principled BSDF')
bsdf.inputs['Base Color'].default_value = (0.72, 0.01, 0.04, 1.0)
bsdf.inputs['Emission Color'].default_value = (0.28, 0.0, 0.01, 1.0)
bsdf.inputs['Emission Strength'].default_value = 0.0
mark.data.materials.append(mat)
group = mark.vertex_groups.new(name='neck')
group.add(list(range(len(mark.data.vertices))), 1.0, 'REPLACE')
modifier = mark.modifiers.new('Neck deformation', 'ARMATURE')
modifier.object = arm

def pose_action(name, end_frame):
    action = bpy.data.actions.new(name)
    action.use_fake_user = True
    arm.animation_data_create()
    arm.animation_data.action = action
    for pb in arm.pose.bones:
        pb.matrix_basis.identity()
    controlled = ['upper_arm.L','upper_arm.R','lower_arm.L','lower_arm.R',
                  'thigh.L','thigh.R','shin.L','shin.R','foot.L','foot.R','spine_02']
    # Sample a complete periodic cycle. Both legs participate, with opposing
    # arm swing, flexing knees, and equal first/last poses for seamless playback.
    for frame in range(1, end_frame + 1):
        t = (frame - 1) / (end_frame - 1)
        phase = 2 * math.pi * t
        gait = name in {'WALK','RUN'}
        stride = 0.48 if name == 'RUN' else 0.30
        for bone_name in controlled:
            pb = arm.pose.bones[bone_name]
            side = 1 if bone_name.endswith('.L') else -1
            swing = math.sin(phase) * side
            rot = Quaternion((1,0,0,0))
            # Transform armature-space axes into each bone's rest frame.
            axes = arm.data.bones[bone_name].matrix_local.to_quaternion().inverted()
            if bone_name.startswith('upper_arm'):
                rot = Quaternion(axes @ Vector((0,1,0)), side * 1.15)
                if gait:
                    rot = Quaternion(axes @ Vector((1,0,0)), -stride*swing) @ rot
            elif bone_name.startswith('thigh') and gait:
                rot = Quaternion(axes @ Vector((1,0,0)), stride*swing)
            elif bone_name.startswith('shin') and gait:
                rot = Quaternion(axes @ Vector((1,0,0)), -max(0,swing)*(0.85 if name=='RUN' else 0.5))
            elif bone_name.startswith('lower_arm'):
                rot = Quaternion(axes @ Vector((1,0,0)), -0.65 if name=='RUN' else -0.15)
            elif bone_name == 'spine_02':
                rot = Quaternion(axes @ Vector((1,0,0)), 0.012*math.sin(phase))
            if name == 'INTERACT' and bone_name == 'upper_arm.R':
                rot = Quaternion(axes @ Vector((1,0,0)), -0.65*math.sin(math.pi*t)**2) @ rot
            pb.rotation_mode = 'QUATERNION'
            pb.rotation_quaternion = rot
            pb.keyframe_insert(data_path='rotation_quaternion', frame=frame, group=pb.name)
    arm.animation_data.action = None
    return action

bpy.context.scene.render.fps = 30
pose_action('IDLE', 61)
pose_action('WALK', 31)
pose_action('RUN', 21)
pose_action('INTERACT', 41)
for pb in arm.pose.bones:
    pb.matrix_basis.identity()

# Keep skinned mesh nodes at scene root so Godot and Khronos do not inherit
# an extra armature-object transform. The Armature modifiers still reference
# Echo_G0_Rig, so deformation and the renamed skeleton remain intact.
for obj in bpy.context.scene.objects:
    if obj.type == 'MESH' and obj != mark and obj.parent is not None:
        world_matrix = obj.matrix_world.copy()
        obj.parent = None
        obj.matrix_world = world_matrix

# Preserve original texture data and alpha. Blind JPEG conversion destroys
# transparency in eyelashes/hair cards and silently lowers visual quality.
# Keep source VRM untouched; the bounded proof uses at most 1024px textures.
for image in bpy.data.images:
    if image.type == 'IMAGE' and max(image.size) > 1024:
        factor = 1024 / max(image.size)
        image.scale(max(1, round(image.size[0]*factor)), max(1, round(image.size[1]*factor)))
        image.pack()

for obj in bpy.context.scene.objects:
    obj.select_set(obj.type in {'MESH', 'ARMATURE'})
bpy.context.view_layer.objects.active = arm
bpy.ops.export_scene.gltf(
    filepath=str(target), export_format='GLB', export_cameras=False,
    export_lights=False, export_animations=True, export_skins=True,
    export_try_sparse_sk=True,
)
print('ECHO_VISUAL_CANON_GATE=FAIL: sample collar and identity require original hero asset')
print('ECHO_G0_CANDIDATE_READY', len(arm.data.bones), len(bpy.data.actions))

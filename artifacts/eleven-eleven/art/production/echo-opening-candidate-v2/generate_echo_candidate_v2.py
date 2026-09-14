import bpy
import bmesh
import math
import os
import shutil
import subprocess

OUT_DIR = os.path.abspath("artifacts/eleven-eleven/art/production/echo-opening-candidate-v2")
os.makedirs(OUT_DIR, exist_ok=True)

# 1. Reset and Materials
bpy.ops.wm.read_factory_settings(use_empty=True)

def make_material(name, color, roughness=0.5, metallic=0.0):
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = color
        bsdf.inputs["Roughness"].default_value = roughness
        bsdf.inputs["Metallic"].default_value = metallic
    return mat

mat_skin = make_material("M_Echo_Skin", (0.94, 0.82, 0.74, 1.0), roughness=0.6)
mat_hair = make_material("M_Echo_Hair", (0.08, 0.08, 0.12, 1.0), roughness=0.35)
mat_eyes = make_material("M_Echo_Eyes", (0.10, 0.16, 0.26, 1.0), roughness=0.2)
mat_eye_white = make_material("M_Echo_EyeWhite", (0.92, 0.92, 0.94, 1.0), roughness=0.3)
mat_jacket = make_material("M_Echo_Jacket", (0.11, 0.12, 0.16, 1.0), roughness=0.7)
mat_shirt = make_material("M_Echo_Shirt", (0.84, 0.85, 0.88, 1.0), roughness=0.8)
mat_pants = make_material("M_Echo_Pants", (0.09, 0.10, 0.13, 1.0), roughness=0.7)
mat_shoes = make_material("M_Echo_Shoes", (0.07, 0.07, 0.09, 1.0), roughness=0.5)
mat_sole = make_material("M_Echo_ShoeSole", (0.75, 0.75, 0.78, 1.0), roughness=0.5)
mat_tattoo = make_material("M_Echo_Tattoo", (0.85, 0.08, 0.14, 1.0), roughness=0.4)

body_objs = []
hair_objs = []
clothing_objs = []
tattoo_obj = None

# Head & Face
bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=16, radius=0.13, location=(0, 0, 1.68))
head_mesh = bpy.context.active_object
head_mesh.name = "Echo_Head_Face"
head_mesh.scale = (0.92, 1.05, 1.15)
bpy.ops.object.transform_apply(scale=True)
head_mesh.data.materials.append(mat_skin)
body_objs.append(head_mesh)

bpy.ops.mesh.primitive_cone_add(vertices=16, radius1=0.08, radius2=0.02, depth=0.10, location=(0, -0.04, 1.57))
chin = bpy.context.active_object
chin.name = "Echo_Chin"
chin.rotation_euler = (math.radians(-15), 0, 0)
bpy.ops.object.transform_apply(rotation=True)
chin.data.materials.append(mat_skin)
body_objs.append(chin)

bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=0.012, radius2=0.002, depth=0.035, location=(0, -0.145, 1.66))
nose = bpy.context.active_object
nose.name = "Echo_Nose"
nose.rotation_euler = (math.radians(90), 0, 0)
bpy.ops.object.transform_apply(rotation=True)
nose.data.materials.append(mat_skin)
body_objs.append(nose)

for side, x in [("L", 0.045), ("R", -0.045)]:
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(x, -0.13, 1.72))
    brow = bpy.context.active_object
    brow.name = f"Echo_Eyebrow_{side}"
    brow.scale = (0.032, 0.006, 0.006)
    brow.rotation_euler = (0, math.radians(10 if side == "L" else -10), math.radians(-5 if side == "L" else 5))
    bpy.ops.object.transform_apply(scale=True, rotation=True)
    brow.data.materials.append(mat_hair)
    body_objs.append(brow)

for side, x in [("L", 0.046), ("R", -0.046)]:
    bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=8, radius=0.024, location=(x, -0.118, 1.68))
    eyeball = bpy.context.active_object
    eyeball.name = f"Echo_Eye_{side}"
    eyeball.scale = (1.0, 0.4, 0.8)
    bpy.ops.object.transform_apply(scale=True)
    eyeball.data.materials.append(mat_eye_white)
    body_objs.append(eyeball)

    bpy.ops.mesh.primitive_circle_add(vertices=12, radius=0.015, fill_type='NGON', location=(x, -0.128, 1.68))
    pupil = bpy.context.active_object
    pupil.name = f"Echo_Pupil_{side}"
    pupil.rotation_euler = (math.radians(90), 0, 0)
    pupil.scale = (0.8, 1.0, 1.0)
    bpy.ops.object.transform_apply(rotation=True, scale=True)
    pupil.data.materials.append(mat_eyes)
    body_objs.append(pupil)

    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(x, -0.125, 1.70))
    lid = bpy.context.active_object
    lid.name = f"Echo_Eyelid_{side}"
    lid.scale = (0.028, 0.008, 0.005)
    bpy.ops.object.transform_apply(scale=True)
    lid.data.materials.append(mat_skin)
    body_objs.append(lid)

for side, x in [("L", 0.125), ("R", -0.125)]:
    bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=0.022, depth=0.045, location=(x, 0.01, 1.67))
    ear = bpy.context.active_object
    ear.name = f"Echo_Ear_{side}"
    ear.rotation_euler = (math.radians(20), math.radians(15 if side == "L" else -15), 0)
    bpy.ops.object.transform_apply(rotation=True)
    ear.data.materials.append(mat_skin)
    body_objs.append(ear)

bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=0.058, depth=0.12, location=(0, -0.005, 1.53))
neck = bpy.context.active_object
neck.name = "Echo_Neck"
neck.data.materials.append(mat_skin)
body_objs.append(neck)

# Hair
bpy.ops.mesh.primitive_uv_sphere_add(segments=20, ring_count=12, radius=0.145, location=(0, 0.025, 1.71))
hair_cap = bpy.context.active_object
hair_cap.name = "Echo_Hair_Cap"
hair_cap.scale = (0.96, 1.08, 1.05)
bpy.ops.object.transform_apply(scale=True)
hair_cap.data.materials.append(mat_hair)
hair_objs.append(hair_cap)

hair_strands = [
    (0.00, -0.130, 1.77, 35, 0, 0, 0.024, 0.020, 0.08),
    (0.035, -0.128, 1.76, 32, 12, -8, 0.022, 0.018, 0.075),
    (-0.035, -0.128, 1.76, 32, -12, 8, 0.022, 0.018, 0.075),
    (0.075, -0.115, 1.73, 25, 20, -15, 0.025, 0.020, 0.09),
    (-0.075, -0.115, 1.73, 25, -20, 15, 0.025, 0.020, 0.09),
    (0.115, -0.05, 1.70, 10, 30, -10, 0.026, 0.022, 0.10),
    (-0.115, -0.05, 1.70, 10, -30, 10, 0.026, 0.022, 0.10),
    (0.00, 0.07, 1.84, -20, 0, 0, 0.030, 0.025, 0.07),
    (0.05, 0.05, 1.83, -15, 25, 0, 0.028, 0.022, 0.065),
    (-0.05, 0.05, 1.83, -15, -25, 0, 0.028, 0.022, 0.065),
    (0.00, 0.13, 1.68, -40, 0, 0, 0.035, 0.028, 0.11),
    (0.06, 0.11, 1.67, -35, 15, 0, 0.032, 0.026, 0.10),
    (-0.06, 0.11, 1.67, -35, -15, 0, 0.032, 0.026, 0.10),
]

for i, (hx, hy, hz, hrx, hry, hrz, hsx, hsy, hsz) in enumerate(hair_strands):
    bpy.ops.mesh.primitive_cone_add(vertices=8, radius1=1.0, radius2=0.05, depth=1.0, location=(hx, hy, hz))
    strand = bpy.context.active_object
    strand.name = f"Echo_HairClump_{i:02d}"
    strand.rotation_euler = (math.radians(hrx), math.radians(hry), math.radians(hrz))
    strand.scale = (hsx, hsy, hsz)
    bpy.ops.object.transform_apply(rotation=True, scale=True)
    strand.data.materials.append(mat_hair)
    hair_objs.append(strand)

# Tattoo (Separate mesh for direct-skin validation gate)
bpy.ops.mesh.primitive_plane_add(size=1.0, location=(0.058, -0.005, 1.53))
tattoo_obj = bpy.context.active_object
tattoo_obj.name = "SkinTattoo_EX011"
tattoo_obj.scale = (0.005, 0.022, 0.035)
tattoo_obj.rotation_euler = (0, math.radians(90), 0)
bpy.ops.object.transform_apply(scale=True, rotation=True)
tattoo_obj.data.materials.append(mat_tattoo)

# Clothing & Limbs
bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=0.10, depth=0.22, location=(0, 0, 1.40))
shirt = bpy.context.active_object
shirt.name = "Echo_Shirt"
shirt.scale = (1.20, 0.88, 1.0)
bpy.ops.object.transform_apply(scale=True)
shirt.data.materials.append(mat_shirt)
clothing_objs.append(shirt)

bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 1.34))
jacket = bpy.context.active_object
jacket.name = "Echo_Jacket"
jacket.scale = (0.28, 0.19, 0.28)
bpy.ops.object.transform_apply(scale=True)
jacket.data.materials.append(mat_jacket)
clothing_objs.append(jacket)

for side, x in [("L", 0.08), ("R", -0.08)]:
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(x, -0.10, 1.44))
    lapel = bpy.context.active_object
    lapel.name = f"Echo_Lapel_{side}"
    lapel.scale = (0.035, 0.015, 0.08)
    lapel.rotation_euler = (math.radians(-10), math.radians(-15 if side == "L" else 15), 0)
    bpy.ops.object.transform_apply(scale=True, rotation=True)
    lapel.data.materials.append(mat_jacket)
    clothing_objs.append(lapel)

bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=0.115, depth=0.20, location=(0, 0, 1.18))
waist = bpy.context.active_object
waist.name = "Echo_Waist"
waist.scale = (1.15, 0.85, 1.0)
bpy.ops.object.transform_apply(scale=True)
waist.data.materials.append(mat_jacket)
clothing_objs.append(waist)

bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 1.02))
pelvis = bpy.context.active_object
pelvis.name = "Echo_Hips_Mesh"
pelvis.scale = (0.27, 0.18, 0.14)
bpy.ops.object.transform_apply(scale=True)
pelvis.data.materials.append(mat_pants)
clothing_objs.append(pelvis)

for side, sign in [("L", 1), ("R", -1)]:
    bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=0.046, depth=0.28, location=(sign * 0.28, 0, 1.32))
    upper_arm = bpy.context.active_object
    upper_arm.name = f"Echo_UpperArm_{side}"
    upper_arm.rotation_euler = (0, math.radians(sign * 18), 0)
    bpy.ops.object.transform_apply(rotation=True)
    upper_arm.data.materials.append(mat_jacket)
    clothing_objs.append(upper_arm)

    bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=0.038, depth=0.26, location=(sign * 0.44, 0, 1.10))
    forearm = bpy.context.active_object
    forearm.name = f"Echo_Forearm_{side}"
    forearm.rotation_euler = (0, math.radians(sign * 14), 0)
    bpy.ops.object.transform_apply(rotation=True)
    forearm.data.materials.append(mat_shirt)
    clothing_objs.append(forearm)

    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(sign * 0.53, 0, 0.94))
    palm = bpy.context.active_object
    palm.name = f"Echo_Palm_{side}"
    palm.scale = (0.032, 0.055, 0.065)
    bpy.ops.object.transform_apply(scale=True)
    palm.data.materials.append(mat_skin)
    body_objs.append(palm)

    bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=0.009, depth=0.040, location=(sign * 0.52, -0.035, 0.93))
    thumb = bpy.context.active_object
    thumb.name = f"Echo_Thumb_{side}"
    thumb.rotation_euler = (math.radians(35), math.radians(sign * 25), 0)
    bpy.ops.object.transform_apply(rotation=True)
    thumb.data.materials.append(mat_skin)
    body_objs.append(thumb)

    finger_data = [
        ("Index", -0.018, 0.048),
        ("Middle", -0.006, 0.054),
        ("Ring", 0.008, 0.050),
        ("Pinky", 0.020, 0.040),
    ]
    for fname, fy, flen in finger_data:
        bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=0.008, depth=flen, location=(sign * 0.53, fy, 0.89 - flen * 0.4))
        finger = bpy.context.active_object
        finger.name = f"Echo_{fname}_{side}"
        finger.data.materials.append(mat_skin)
        body_objs.append(finger)

    bpy.ops.mesh.primitive_cylinder_add(vertices=14, radius=0.068, depth=0.42, location=(sign * 0.11, 0, 0.74))
    thigh = bpy.context.active_object
    thigh.name = f"Echo_Thigh_{side}"
    thigh.data.materials.append(mat_pants)
    clothing_objs.append(thigh)

    bpy.ops.mesh.primitive_cylinder_add(vertices=14, radius=0.054, depth=0.40, location=(sign * 0.11, 0, 0.32))
    shin = bpy.context.active_object
    shin.name = f"Echo_Shin_{side}"
    shin.data.materials.append(mat_pants)
    clothing_objs.append(shin)

    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(sign * 0.11, 0.04, 0.07))
    shoe = bpy.context.active_object
    shoe.name = f"Echo_Shoe_{side}"
    shoe.scale = (0.065, 0.14, 0.065)
    bpy.ops.object.transform_apply(scale=True)
    shoe.data.materials.append(mat_shoes)
    clothing_objs.append(shoe)

    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(sign * 0.11, 0.04, 0.015))
    sole = bpy.context.active_object
    sole.name = f"Echo_Sole_{side}"
    sole.scale = (0.068, 0.145, 0.02)
    bpy.ops.object.transform_apply(scale=True)
    sole.data.materials.append(mat_sole)
    clothing_objs.append(sole)

all_sub_objects = body_objs + hair_objs + clothing_objs + [tattoo_obj]
for obj in all_sub_objects:
    if obj.type == 'MESH':
        for poly in obj.data.polygons:
            poly.use_smooth = True

# Assign anatomical vertex groups to each sub-object BEFORE joining
for obj in all_sub_objects:
    target_bone = "hips"
    oname = obj.name.lower()
    if "tattoo" in oname:
        target_bone = "neck"
    elif "head" in oname or "chin" in oname or "nose" in oname or "eye" in oname or "ear" in oname or "hair" in oname:
        target_bone = "head"
    elif "neck" in oname:
        target_bone = "neck"
    elif "shirt" in oname or "lapel" in oname or "jacket" in oname:
        target_bone = "spine_02"
    elif "waist" in oname:
        target_bone = "spine_01"
    elif "hips" in oname:
        target_bone = "hips"
    elif "upperarm" in oname:
        target_bone = "upper_arm.L" if "_l" in oname else "upper_arm.R"
    elif "forearm" in oname:
        target_bone = "lower_arm.L" if "_l" in oname else "lower_arm.R"
    elif "palm" in oname or "thumb" in oname or "index" in oname or "middle" in oname or "ring" in oname or "pinky" in oname:
        target_bone = "hand.L" if "_l" in oname else "hand.R"
    elif "thigh" in oname:
        target_bone = "thigh.L" if "_l" in oname else "thigh.R"
    elif "shin" in oname:
        target_bone = "shin.L" if "_l" in oname else "shin.R"
    elif "shoe" in oname:
        target_bone = "foot.L" if "_l" in oname else "foot.R"
    elif "sole" in oname:
        target_bone = "toe.L" if "_l" in oname else "toe.R"
    
    vg = obj.vertex_groups.new(name=target_bone)
    v_indices = [v.index for v in obj.data.vertices]
    vg.add(v_indices, 1.0, 'REPLACE')

def join_objs(objs, target_name):
    if not objs:
        return None
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    res = bpy.context.active_object
    res.name = target_name
    return res

mesh_body = join_objs(body_objs, "Echo_Body")
mesh_hair = join_objs(hair_objs, "Echo_Hair")
mesh_clothing = join_objs(clothing_objs, "Echo_Clothing")

final_character_meshes = [mesh_body, mesh_hair, mesh_clothing, tattoo_obj]
print(f"Consolidated into {len(final_character_meshes)} production meshes.")

# 3. Create Connected 20-Bone Humanoid Armature
bpy.ops.object.armature_add(enter_editmode=True)
arm_obj = bpy.context.active_object
arm_obj.name = "Echo_Armature"
eb = arm_obj.data.edit_bones

root = eb[0]
root.name = "root"
root.head = (0, 0, 0)
root.tail = (0, 0, 0.20)

hips = eb.new("hips")
hips.head = (0, 0, 0.95)
hips.tail = (0, 0, 1.10)
hips.parent = root

spine_01 = eb.new("spine_01")
spine_01.head = (0, 0, 1.10)
spine_01.tail = (0, 0, 1.28)
spine_01.parent = hips

spine_02 = eb.new("spine_02")
spine_02.head = (0, 0, 1.28)
spine_02.tail = (0, 0, 1.48)
spine_02.parent = spine_01

neck_b = eb.new("neck")
neck_b.head = (0, 0, 1.48)
neck_b.tail = (0, 0, 1.58)
neck_b.parent = spine_02

head_b = eb.new("head")
head_b.head = (0, 0, 1.58)
head_b.tail = (0, 0, 1.82)
head_b.parent = neck_b

uarm_l = eb.new("upper_arm.L")
uarm_l.head = (0.18, 0, 1.42)
uarm_l.tail = (0.38, 0, 1.22)
uarm_l.parent = spine_02

larm_l = eb.new("lower_arm.L")
larm_l.head = (0.38, 0, 1.22)
larm_l.tail = (0.50, 0, 1.02)
larm_l.parent = uarm_l

hand_l = eb.new("hand.L")
hand_l.head = (0.50, 0, 1.02)
hand_l.tail = (0.56, 0, 0.88)
hand_l.parent = larm_l

uarm_r = eb.new("upper_arm.R")
uarm_r.head = (-0.18, 0, 1.42)
uarm_r.tail = (-0.38, 0, 1.22)
uarm_r.parent = spine_02

larm_r = eb.new("lower_arm.R")
larm_r.head = (-0.38, 0, 1.22)
larm_r.tail = (-0.50, 0, 1.02)
larm_r.parent = uarm_r

hand_r = eb.new("hand.R")
hand_r.head = (-0.50, 0, 1.02)
hand_r.tail = (-0.56, 0, 0.88)
hand_r.parent = larm_r

thigh_l = eb.new("thigh.L")
thigh_l.head = (0.11, 0, 0.95)
thigh_l.tail = (0.11, 0, 0.52)
thigh_l.parent = hips

shin_l = eb.new("shin.L")
shin_l.head = (0.11, 0, 0.52)
shin_l.tail = (0.11, 0, 0.12)
shin_l.parent = thigh_l

foot_l = eb.new("foot.L")
foot_l.head = (0.11, 0, 0.12)
foot_l.tail = (0.11, 0.10, 0.04)
foot_l.parent = shin_l

toe_l = eb.new("toe.L")
toe_l.head = (0.11, 0.10, 0.04)
toe_l.tail = (0.11, 0.18, 0.02)
toe_l.parent = foot_l

thigh_r = eb.new("thigh.R")
thigh_r.head = (-0.11, 0, 0.95)
thigh_r.tail = (-0.11, 0, 0.52)
thigh_r.parent = hips

shin_r = eb.new("shin.R")
shin_r.head = (-0.11, 0, 0.52)
shin_r.tail = (-0.11, 0, 0.12)
shin_r.parent = thigh_r

foot_r = eb.new("foot.R")
foot_r.head = (-0.11, 0, 0.12)
foot_r.tail = (-0.11, 0.10, 0.04)
foot_r.parent = shin_r

toe_r = eb.new("toe.R")
toe_r.head = (-0.11, 0.10, 0.04)
toe_r.tail = (-0.11, 0.18, 0.02)
toe_r.parent = foot_r

bpy.ops.object.mode_set(mode='OBJECT')

root_b = arm_obj.data.bones["root"]
for bname in arm_obj.data.bones.keys():
    if bname != "root":
        assert root_b in arm_obj.data.bones[bname].parent_recursive, f"Bone {bname} not connected to root!"

print("Armature hierarchy verified: All bones connect back to root.")

# 4. Skinning to Armature
for obj in final_character_meshes:
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    arm_obj.select_set(True)
    bpy.context.view_layer.objects.active = arm_obj
    bpy.ops.object.parent_set(type='ARMATURE')

# 5. Author 6 Real Animation Actions with Changing Relative Poses
arm_obj.animation_data_create()
pbones = arm_obj.pose.bones
for b in pbones:
    b.rotation_mode = 'XYZ'

def clear_pose():
    for b in pbones:
        b.location = (0, 0, 0)
        b.rotation_euler = (0, 0, 0)

# 1. IDLE (60 frames)
act_idle = bpy.data.actions.new(name="IDLE")
arm_obj.animation_data.action = act_idle
clear_pose()
for f in range(1, 61):
    t = (f - 1) / 60.0 * 2.0 * math.pi
    pbones["spine_01"].rotation_euler.x = math.sin(t) * 0.04
    pbones["spine_02"].rotation_euler.x = math.sin(t) * 0.035
    pbones["head"].rotation_euler.z = math.sin(t * 0.5) * 0.05
    pbones["head"].rotation_euler.x = math.cos(t * 0.5) * 0.025
    pbones["upper_arm.L"].rotation_euler.x = math.sin(t) * 0.02
    pbones["upper_arm.R"].rotation_euler.x = math.sin(t) * 0.02
    for bname in ["spine_01", "spine_02", "head", "upper_arm.L", "upper_arm.R"]:
        pbones[bname].keyframe_insert(data_path="rotation_euler", frame=f)
track = arm_obj.animation_data.nla_tracks.new()
track.name = "IDLE"
track.strips.new("IDLE", 1, act_idle)

# 2. WALK (32 frames)
act_walk = bpy.data.actions.new(name="WALK")
arm_obj.animation_data.action = act_walk
clear_pose()
for f in range(1, 33):
    t = (f - 1) / 32.0 * 2.0 * math.pi
    pbones["thigh.L"].rotation_euler.x = math.sin(t) * 0.45
    pbones["thigh.R"].rotation_euler.x = math.sin(t + math.pi) * 0.45
    pbones["shin.L"].rotation_euler.x = max(0.0, -math.sin(t)) * 0.55
    pbones["shin.R"].rotation_euler.x = max(0.0, -math.sin(t + math.pi)) * 0.55
    pbones["foot.L"].rotation_euler.x = math.cos(t) * 0.20
    pbones["foot.R"].rotation_euler.x = math.cos(t + math.pi) * 0.20
    pbones["upper_arm.L"].rotation_euler.x = math.sin(t + math.pi) * 0.35
    pbones["upper_arm.R"].rotation_euler.x = math.sin(t) * 0.35
    pbones["lower_arm.L"].rotation_euler.x = 0.20 + abs(math.sin(t + math.pi)) * 0.15
    pbones["lower_arm.R"].rotation_euler.x = 0.20 + abs(math.sin(t)) * 0.15
    pbones["spine_01"].rotation_euler.z = math.sin(t) * 0.06
    pbones["hips"].location.z = -abs(math.sin(2.0 * t)) * 0.035
    
    for bname in ["thigh.L", "thigh.R", "shin.L", "shin.R", "foot.L", "foot.R",
                  "upper_arm.L", "upper_arm.R", "lower_arm.L", "lower_arm.R", "spine_01"]:
        pbones[bname].keyframe_insert(data_path="rotation_euler", frame=f)
    pbones["hips"].keyframe_insert(data_path="location", frame=f)
track = arm_obj.animation_data.nla_tracks.new()
track.name = "WALK"
track.strips.new("WALK", 1, act_walk)

# 3. RUN (20 frames)
act_run = bpy.data.actions.new(name="RUN")
arm_obj.animation_data.action = act_run
clear_pose()
for f in range(1, 21):
    t = (f - 1) / 20.0 * 2.0 * math.pi
    pbones["spine_01"].rotation_euler.x = 0.18
    pbones["thigh.L"].rotation_euler.x = math.sin(t) * 0.80
    pbones["thigh.R"].rotation_euler.x = math.sin(t + math.pi) * 0.80
    pbones["shin.L"].rotation_euler.x = max(0.0, -math.sin(t)) * 1.05
    pbones["shin.R"].rotation_euler.x = max(0.0, -math.sin(t + math.pi)) * 1.05
    pbones["upper_arm.L"].rotation_euler.x = math.sin(t + math.pi) * 0.70
    pbones["upper_arm.R"].rotation_euler.x = math.sin(t) * 0.70
    pbones["lower_arm.L"].rotation_euler.x = 0.85 + math.sin(t + math.pi) * 0.25
    pbones["lower_arm.R"].rotation_euler.x = 0.85 + math.sin(t) * 0.25
    pbones["hips"].location.z = math.sin(2.0 * t) * 0.05
    
    for bname in ["thigh.L", "thigh.R", "shin.L", "shin.R", "upper_arm.L", "upper_arm.R",
                  "lower_arm.L", "lower_arm.R", "spine_01"]:
        pbones[bname].keyframe_insert(data_path="rotation_euler", frame=f)
    pbones["hips"].keyframe_insert(data_path="location", frame=f)
track = arm_obj.animation_data.nla_tracks.new()
track.name = "RUN"
track.strips.new("RUN", 1, act_run)

# 4. INTERACT (48 frames)
act_interact = bpy.data.actions.new(name="INTERACT")
arm_obj.animation_data.action = act_interact
clear_pose()
for f in range(1, 49):
    p = math.sin((f - 1) / 48.0 * math.pi)
    pbones["spine_01"].rotation_euler.y = p * 0.08
    pbones["spine_01"].rotation_euler.z = -p * 0.12
    pbones["head"].rotation_euler.x = p * 0.18
    pbones["upper_arm.R"].rotation_euler.x = -p * 1.15
    pbones["upper_arm.R"].rotation_euler.z = p * 0.25
    pbones["lower_arm.R"].rotation_euler.x = -p * 0.55
    pbones["hand.R"].rotation_euler.x = p * 0.35
    
    for bname in ["spine_01", "head", "upper_arm.R", "lower_arm.R", "hand.R"]:
        pbones[bname].keyframe_insert(data_path="rotation_euler", frame=f)
track = arm_obj.animation_data.nla_tracks.new()
track.name = "INTERACT"
track.strips.new("INTERACT", 1, act_interact)

# 5. WAKEUP (72 frames)
act_wakeup = bpy.data.actions.new(name="WAKEUP")
arm_obj.animation_data.action = act_wakeup
clear_pose()
for f in range(1, 73):
    progress = (f - 1) / 71.0
    recline = (1.0 - progress) * -0.65
    pbones["spine_01"].rotation_euler.x = recline
    pbones["neck"].rotation_euler.x = recline * 0.5
    pbones["head"].rotation_euler.z = math.sin(progress * 4.0 * math.pi) * (1.0 - progress) * 0.35
    pbones["upper_arm.L"].rotation_euler.x = (1.0 - progress) * 0.4 + math.sin(progress * 2.0 * math.pi) * 0.15
    pbones["upper_arm.R"].rotation_euler.x = (1.0 - progress) * 0.4 + math.cos(progress * 2.0 * math.pi) * 0.15
    pbones["lower_arm.L"].rotation_euler.x = (1.0 - progress) * 0.6
    pbones["lower_arm.R"].rotation_euler.x = (1.0 - progress) * 0.6
    
    for bname in ["spine_01", "neck", "head", "upper_arm.L", "upper_arm.R", "lower_arm.L", "lower_arm.R"]:
        pbones[bname].keyframe_insert(data_path="rotation_euler", frame=f)
track = arm_obj.animation_data.nla_tracks.new()
track.name = "WAKEUP"
track.strips.new("WAKEUP", 1, act_wakeup)

# 6. STANDUP (72 frames)
act_standup = bpy.data.actions.new(name="STANDUP")
arm_obj.animation_data.action = act_standup
clear_pose()
for f in range(1, 73):
    progress = (f - 1) / 71.0
    crouch = (1.0 - progress)
    pbones["hips"].location.z = -crouch * 0.45
    pbones["spine_01"].rotation_euler.x = crouch * 0.42
    pbones["thigh.L"].rotation_euler.x = crouch * 0.95
    pbones["thigh.R"].rotation_euler.x = crouch * 0.95
    pbones["shin.L"].rotation_euler.x = -crouch * 1.10
    pbones["shin.R"].rotation_euler.x = -crouch * 1.10
    pbones["foot.L"].rotation_euler.x = crouch * 0.30
    pbones["foot.R"].rotation_euler.x = crouch * 0.30
    pbones["upper_arm.L"].rotation_euler.x = crouch * -0.35
    pbones["upper_arm.R"].rotation_euler.x = crouch * -0.35
    pbones["lower_arm.L"].rotation_euler.x = crouch * 0.50
    pbones["lower_arm.R"].rotation_euler.x = crouch * 0.50
    
    pbones["hips"].keyframe_insert(data_path="location", frame=f)
    for bname in ["spine_01", "thigh.L", "thigh.R", "shin.L", "shin.R", "foot.L", "foot.R",
                  "upper_arm.L", "upper_arm.R", "lower_arm.L", "lower_arm.R"]:
        pbones[bname].keyframe_insert(data_path="rotation_euler", frame=f)
track = arm_obj.animation_data.nla_tracks.new()
track.name = "STANDUP"
track.strips.new("STANDUP", 1, act_standup)

clear_pose()
arm_obj.animation_data.action = act_idle
bpy.context.scene.frame_set(1)

print("All 6 actions authored and pushed to NLA tracks.")

# 6. Save Blend and Export GLB
blend_path = os.path.join(OUT_DIR, "echo-candidate.blend")
bpy.ops.wm.save_as_mainfile(filepath=blend_path)
print(f"Saved blend file to: {blend_path}")

glb_path = os.path.join(OUT_DIR, "echo-candidate.glb")
bpy.ops.export_scene.gltf(
    filepath=glb_path,
    export_format='GLB',
    use_selection=False,
    export_animations=True
)
print(f"Exported GLB candidate to: {glb_path}")

# 7. Lighting & Camera Setup for 4 Genuine Unique Renders
bpy.ops.object.light_add(type='SUN', location=(3, -4, 5))
sun = bpy.context.active_object
sun.name = "Key_Sun_Light"
sun.data.energy = 3.5

bpy.ops.object.light_add(type='AREA', location=(-3, -3, 3))
fill = bpy.context.active_object
fill.name = "Fill_Area_Light"
fill.data.energy = 80.0
fill.data.size = 2.0

bpy.ops.object.light_add(type='AREA', location=(0, 3, 3))
rim = bpy.context.active_object
rim.name = "Rim_Kicker_Light"
rim.data.energy = 150.0
rim.data.size = 2.5

scene = bpy.context.scene
scene.render.resolution_x = 900
scene.render.resolution_y = 900
scene.render.film_transparent = False

cameras_data = [
    ("Camera_Front", (0, -3.2, 0.95), (math.radians(90), 0, 0), "render_front.png"),
    ("Camera_Side", (3.2, 0, 0.95), (math.radians(90), 0, math.radians(90)), "render_side.png"),
    ("Camera_ThreeQuarter", (-2.2, -2.2, 1.25), (math.radians(76), 0, math.radians(-45)), "render_three_quarter.png"),
    ("Camera_Closeup", (0, -0.92, 1.62), (math.radians(90), 0, 0), "render_closeup.png"),
]

for cam_name, pos, rot, fname in cameras_data:
    bpy.ops.object.camera_add(location=pos, rotation=rot)
    cam = bpy.context.active_object
    cam.name = cam_name
    cam.data.lens = 50.0 if "Closeup" not in cam_name else 65.0
    scene.camera = cam
    scene.render.filepath = os.path.join(OUT_DIR, fname)
    bpy.ops.render.render(write_still=True)
    print(f"Rendered view: {fname}")

# 8. Render Real Animation Sequence & Encode MP4 Video
print("Rendering animation sequence for WALK cycle...")
cam_tq = bpy.data.objects["Camera_ThreeQuarter"]
scene.camera = cam_tq
arm_obj.animation_data.action = act_walk
scene.frame_start = 1
scene.frame_end = 32

temp_frames_dir = os.path.join(OUT_DIR, "temp_frames")
os.makedirs(temp_frames_dir, exist_ok=True)

for f in range(1, 33):
    scene.frame_set(f)
    frame_file = os.path.join(temp_frames_dir, f"walk_{f:04d}.png")
    scene.render.filepath = frame_file
    bpy.ops.render.render(write_still=True)

mp4_out = os.path.join(OUT_DIR, "animation_preview.mp4")
cmd = [
    "ffmpeg", "-y",
    "-framerate", "24",
    "-i", os.path.join(temp_frames_dir, "walk_%04d.png"),
    "-c:v", "libx264",
    "-pix_fmt", "yuv420p",
    "-vf", "scale=trunc(iw/2)*2:trunc(ih/2)*2",
    mp4_out
]
print("Running FFmpeg encoding:", " ".join(cmd))
res = subprocess.run(cmd, capture_output=True, text=True)
if res.returncode != 0:
    print("FFmpeg error:", res.stderr)
else:
    print(f"Successfully generated animation_preview.mp4 at {mp4_out}")

shutil.rmtree(temp_frames_dir, ignore_errors=True)
print("Candidate V2 generation finished successfully.")

"""Create a higher-fidelity, rigged Echo EX-011 hero foundation.

This remains a review candidate, not the approved final hero asset.  The script
prioritises silhouette, readable anime facial identity, layered hair, coat
construction and gameplay-safe proportions over asset count.
"""

import math
import os

import bpy
from mathutils import Vector


ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "production", "echo-hero-foundation-v3"))
BLEND = os.path.join(ROOT, "echo-hero-foundation-v3.blend")
GLB = os.path.join(ROOT, "echo-hero-foundation-v3.glb")
PREVIEW = os.path.join(ROOT, "echo-hero-foundation-v3-review.png")


def reset():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)


def mat(name, color, metallic=0.0, roughness=0.42, emission=None, strength=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    p = m.node_tree.nodes.get("Principled BSDF")
    p.inputs["Base Color"].default_value = color
    p.inputs["Metallic"].default_value = metallic
    p.inputs["Roughness"].default_value = roughness
    if emission and "Emission Color" in p.inputs:
        p.inputs["Emission Color"].default_value = emission
        p.inputs["Emission Strength"].default_value = strength
    return m


def finish(obj, material, bevel=0.0):
    if material:
        obj.data.materials.append(material)
    if bevel:
        mod = obj.modifiers.new("MicroBevel", "BEVEL")
        mod.width = bevel
        mod.segments = 3
    if hasattr(obj.data, "polygons"):
        for poly in obj.data.polygons:
            poly.use_smooth = True
    return obj


def ellipsoid(name, loc, scale, material, segments=48, rings=32):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, location=loc)
    o = bpy.context.object
    o.name = name
    o.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish(o, material)


def box(name, loc, scale, material, bevel=0.012, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(location=loc, rotation=rot)
    o = bpy.context.object
    o.name = name
    o.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish(o, material, bevel)


def segment(name, a, b, radius, material, vertices=32):
    av, bv = Vector(a), Vector(b)
    d = bv - av
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=d.length, location=(av + bv) * 0.5)
    o = bpy.context.object
    o.name = name
    o.rotation_mode = "QUATERNION"
    o.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(d.normalized())
    o.rotation_mode = "XYZ"
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish(o, material, radius * 0.12)


def wedge(name, verts, faces, material, bevel=0.008):
    mesh = bpy.data.meshes.new(name + "Mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    o = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(o)
    return finish(o, material, bevel)


def create_rig():
    data = bpy.data.armatures.new("Echo_EX011_RigData")
    rig = bpy.data.objects.new("Echo_EX011_Rig", data)
    bpy.context.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    rig.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    defs = {
        "root": ((0, 0, 0), (0, 0, .12), None),
        "hips": ((0, 0, .91), (0, 0, 1.06), "root"),
        "spine": ((0, 0, 1.06), (0, 0, 1.30), "hips"),
        "chest": ((0, 0, 1.30), (0, 0, 1.50), "spine"),
        "neck": ((0, 0, 1.50), (0, 0, 1.58), "chest"),
        "head": ((0, 0, 1.58), (0, 0, 1.79), "neck"),
    }
    for side, sign in (("L", 1), ("R", -1)):
        defs.update({
            f"upper_arm.{side}": ((.15*sign, 0, 1.45), (.43*sign, 0, 1.35), "chest"),
            f"forearm.{side}": ((.43*sign, 0, 1.35), (.69*sign, 0, 1.25), f"upper_arm.{side}"),
            f"hand.{side}": ((.69*sign, 0, 1.25), (.80*sign, 0, 1.21), f"forearm.{side}"),
            f"thigh.{side}": ((.105*sign, 0, .98), (.12*sign, 0, .56), "hips"),
            f"shin.{side}": ((.12*sign, 0, .56), (.12*sign, 0, .16), f"thigh.{side}"),
            f"foot.{side}": ((.12*sign, 0, .16), (.12*sign, -.22, .08), f"shin.{side}"),
        })
    for name, (head, tail, parent) in defs.items():
        bone = data.edit_bones.new(name)
        bone.head, bone.tail = head, tail
        if parent:
            bone.parent = data.edit_bones[parent]
    bpy.ops.object.mode_set(mode="OBJECT")
    rig.select_set(False)
    rig.show_in_front = True
    rig["asset_status"] = "hero-foundation-review-candidate"
    rig["character_id"] = "EX-011"
    return rig


def bind(obj, rig, bone):
    world = obj.matrix_world.copy()
    obj.parent = rig
    obj.parent_type = "BONE"
    obj.parent_bone = bone
    obj.matrix_world = world


def hair_tuft(name, base, tip, width, material, rig):
    base, tip = Vector(base), Vector(tip)
    d = tip - base
    bpy.ops.mesh.primitive_cone_add(vertices=18, radius1=width, radius2=.004, depth=d.length, location=(base+tip)*.5)
    o = bpy.context.object
    o.name = name
    o.rotation_mode = "QUATERNION"
    o.rotation_quaternion = Vector((0,0,1)).rotation_difference(d.normalized())
    o.rotation_mode = "XYZ"
    finish(o, material, .003)
    bind(o, rig, "head")


def build():
    os.makedirs(ROOT, exist_ok=True)
    reset()
    skin = mat("Echo_Skin", (.72, .50, .43, 1), roughness=.53)
    skin_shadow = mat("Echo_SkinShadow", (.38, .20, .18, 1), roughness=.58)
    hair = mat("Echo_Hair", (.006, .008, .014, 1), metallic=.08, roughness=.25)
    suit = mat("Echo_Undersuit", (.010, .013, .019, 1), metallic=.18, roughness=.37)
    coat = mat("Echo_Coat", (.016, .019, .027, 1), metallic=.12, roughness=.32)
    armor = mat("Echo_Armor", (.025, .030, .040, 1), metallic=.62, roughness=.22)
    red = mat("Echo_RedSignal", (.75, .004, .012, 1), metallic=.25, roughness=.18, emission=(1, .002, .006, 1), strength=3.2)
    cyan = mat("Echo_CyanSignal", (0, .32, .55, 1), metallic=.2, roughness=.16, emission=(0, .75, 1, 1), strength=3.0)
    white = mat("Echo_EyeWhite", (.82, .84, .86, 1), roughness=.12)
    black = mat("Echo_EyeLine", (.002, .002, .004, 1), roughness=.3)
    rig = create_rig()

    # Proportions and anatomy, intentionally slim heroic rather than chibi.
    parts = []
    parts += [(ellipsoid("Head", (0,-.006,1.68), (.142,.125,.183), skin, 64, 40), "head")]
    parts += [(ellipsoid("Jaw", (0,-.067,1.635), (.116,.084,.095), skin, 48, 32), "head")]
    parts += [(segment("Neck", (0,0,1.48),(0,0,1.59),.052,skin), "neck")]
    parts += [(ellipsoid("Torso", (0,.005,1.29), (.218,.125,.245), suit), "chest")]
    parts += [(ellipsoid("Pelvis", (0,.005,.99), (.173,.112,.15), suit), "hips")]
    for side, sign in (("L",1),("R",-1)):
        parts += [(segment(f"UpperArm_{side}",(.14*sign,0,1.44),(.43*sign,0,1.35),.061,coat),f"upper_arm.{side}")]
        parts += [(segment(f"Forearm_{side}",(.43*sign,0,1.35),(.69*sign,0,1.25),.051,suit),f"forearm.{side}")]
        parts += [(ellipsoid(f"Hand_{side}",(.75*sign,-.006,1.225),(.060,.031,.078),skin,36,24),f"hand.{side}")]
        parts += [(segment(f"Thigh_{side}",(.105*sign,0,.96),(.12*sign,0,.57),.078,suit),f"thigh.{side}")]
        parts += [(segment(f"Shin_{side}",(.12*sign,0,.55),(.12*sign,0,.18),.064,suit),f"shin.{side}")]
        boot = box(f"Boot_{side}",(.12*sign,-.075,.105),(.082,.145,.095),armor,.022)
        parts += [(boot,f"foot.{side}")]
        parts += [(box(f"KneeGuard_{side}",(.12*sign,-.061,.56),(.075,.028,.083),armor,.018),f"shin.{side}")]
        parts += [(box(f"ShoulderPlate_{side}",(.235*sign,-.015,1.43),(.115,.09,.052),armor,.018,rot=(0,math.radians(7*sign),math.radians(-18*sign))),f"upper_arm.{side}")]
        parts += [(box(f"ForearmGuard_{side}",(.58*sign,-.037,1.29),(.09,.047,.055),armor,.014,rot=(0,math.radians(8*sign),math.radians(-20*sign))),f"forearm.{side}")]
        parts += [(box(f"HipPouch_{side}",(.225*sign,-.09,.91),(.055,.035,.125),armor,.012),"hips")]
    for obj,bone in parts:
        bind(obj,rig,bone)

    # Facial planes: strong graphic anime read at gameplay distance.
    for side, x, iris_mat in (("L",-.048,red),("R",.048,cyan)):
        eye = ellipsoid(f"EyeWhite_{side}",(x,-.126,1.704),(.038,.009,.022),white,32,20); bind(eye,rig,"head")
        iris = ellipsoid(f"Iris_{side}",(x,-.135,1.704),(.015,.006,.015),iris_mat,24,16); bind(iris,rig,"head")
        pupil = ellipsoid(f"Pupil_{side}",(x,-.141,1.704),(.005,.003,.009),black,20,12); bind(pupil,rig,"head")
        brow = box(f"Brow_{side}",(x,-.132,1.748),(.045,.005,.006),hair,.003,rot=(0,math.radians(-8*sign if False else 0),math.radians(-7 if side=='L' else 7))); bind(brow,rig,"head")
    nose = wedge("Nose",[(0,-.144,1.69),(-.012,-.126,1.665),(.012,-.126,1.665)],[(0,1,2)],skin_shadow,0); bind(nose,rig,"head")
    mouth = box("Mouth",(0,-.126,1.625),(.032,.004,.004),skin_shadow,.002); bind(mouth,rig,"head")

    # Hair shell plus directional layered tufts.
    shell=ellipsoid("HairShell",(0,.006,1.746),(.157,.139,.175),hair,64,40); bind(shell,rig,"head")
    directions=[]
    for ring in range(3):
        count=14-ring*2
        z=1.78-ring*.052
        for i in range(count):
            a=math.tau*i/count + ring*.19
            base=(math.cos(a)*(.105+ring*.013),math.sin(a)*(.092+ring*.009),z)
            length=.12+(.035*((i+ring)%3))
            tip=(base[0]+math.cos(a)*length*.58,base[1]+math.sin(a)*length*.52,base[2]-length*(.28+ring*.12))
            directions.append((base,tip,.035+ring*.004))
    directions += [((-.10,-.09,1.77),(-.14,-.15,1.63),.04),((-.045,-.12,1.79),(-.075,-.15,1.65),.038),((.03,-.12,1.80),(.015,-.154,1.67),.036),((.095,-.09,1.77),(.14,-.14,1.66),.038),((0,.015,1.89),(.035,.02,1.99),.045)]
    for i,(a,b,w) in enumerate(directions): hair_tuft(f"HairTuft_{i:02d}",a,b,w,hair,rig)

    # Layered coat: fitted chest, raised collar, four independent tails.
    core=ellipsoid("CoatCore",(0,.008,1.30),(.235,.139,.255),coat,48,32); bind(core,rig,"chest")
    for side,sign in (("L",1),("R",-1)):
        collar=box(f"Collar_{side}",(.085*sign,-.015,1.52),(.087,.077,.063),coat,.014,rot=(0,math.radians(8*sign),math.radians(-5*sign))); bind(collar,rig,"chest")
        front=box(f"CoatFrontTail_{side}",(.12*sign,-.107,.68),(.105,.025,.39),coat,.016,rot=(0,math.radians(2*sign),math.radians(-3*sign))); bind(front,rig,"hips")
        back=box(f"CoatBackTail_{side}",(.12*sign,.105,.68),(.105,.026,.40),coat,.016,rot=(0,math.radians(-2*sign),math.radians(3*sign))); bind(back,rig,"hips")
        trim=segment(f"SignalTrim_{side}",(.19*sign,-.137,1.39),(.14*sign,-.137,.36),.006,red if side=='L' else cyan,12); bind(trim,rig,"hips")
    belt=box("Belt",(0,-.018,1.02),(.235,.128,.030),armor,.009); bind(belt,rig,"hips")
    buckle=box("BeltBuckle",(0,-.151,1.02),(.047,.012,.037),armor,.006); bind(buckle,rig,"hips")
    chestline=segment("ChestSignal",(0,-.137,1.46),(0,-.137,1.08),.006,red,12); bind(chestline,rig,"chest")
    node=ellipsoid("BackSignalNode",(0,.145,1.39),(.042,.018,.042),cyan,32,20); bind(node,rig,"chest")

    # A small idle action proves the deformation/animation path without hiding silhouette defects.
    rig.animation_data_create()
    action=bpy.data.actions.new("Echo_EX011_IDLE_BREATH")
    rig.animation_data.action=action
    for frame,z,angle in ((1,0,0),(36,.008,math.radians(1.2)),(72,0,0)):
        rig.pose.bones["hips"].location.z=z
        rig.pose.bones["hips"].keyframe_insert(data_path="location",frame=frame)
        rig.pose.bones["chest"].rotation_mode="XYZ"
        rig.pose.bones["chest"].rotation_euler.x=angle
        rig.pose.bones["chest"].keyframe_insert(data_path="rotation_euler",frame=frame)

    # Review stage.
    floor=box("ReviewFloor",(0,0,-.035),(3,3,.03),mat("Floor",(.012,.014,.02,1),metallic=.3,roughness=.27),.01)
    cam_data=bpy.data.cameras.new("ReviewCameraData")
    cam=bpy.data.objects.new("ReviewCamera",cam_data); bpy.context.collection.objects.link(cam)
    cam.location=(2.65,-4.8,1.65); cam_data.lens=72
    cam.rotation_euler=((Vector((0,0,1.05))-cam.location).to_track_quat("-Z","Y").to_euler())
    bpy.context.scene.camera=cam
    for name,loc,energy,color,size in (("Key",(-2.4,-3.0,4.0),1250,(1,.77,.68),2.4),("Fill",(2.8,-2.3,2.5),950,(.25,.65,1),2.1),("Rim",(0,2.4,3.3),1500,(1,.015,.035),1.8)):
        ld=bpy.data.lights.new(name,"AREA"); ld.energy=energy; ld.color=color; ld.shape="DISK"; ld.size=size
        lo=bpy.data.objects.new(name,ld); lo.location=loc; lo.rotation_euler=((Vector((0,0,1.1))-lo.location).to_track_quat("-Z","Y").to_euler()); bpy.context.collection.objects.link(lo)

    scene=bpy.context.scene
    scene.frame_start=1; scene.frame_end=72; scene.render.fps=24
    scene.render.engine="BLENDER_EEVEE_NEXT"
    scene.render.resolution_x=1200; scene.render.resolution_y=1600; scene.render.resolution_percentage=100
    scene.render.image_settings.file_format="PNG"; scene.render.filepath=PREVIEW
    scene.view_settings.look="AgX - Medium High Contrast"
    scene.world.use_nodes=True
    scene.world.node_tree.nodes["Background"].inputs["Color"].default_value=(.004,.006,.012,1)
    scene.world.node_tree.nodes["Background"].inputs["Strength"].default_value=.22
    bpy.ops.wm.save_as_mainfile(filepath=BLEND)
    bpy.ops.render.render(write_still=True)
    # Export only the hero hierarchy, not the review stage.
    bpy.ops.object.select_all(action="DESELECT")
    rig.select_set(True)
    for o in bpy.context.scene.objects:
        if o.parent == rig:
            o.select_set(True)
    bpy.context.view_layer.objects.active=rig
    bpy.ops.export_scene.gltf(filepath=GLB,export_format="GLB",use_selection=True,export_animations=True,export_apply=True)
    bpy.ops.wm.save_as_mainfile(filepath=BLEND)
    print("ECHO_HERO_FOUNDATION_V3_OK="+GLB)


if __name__ == "__main__":
    build()

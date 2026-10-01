"""Echo EX-011 facial identity and hair-silhouette quality gate.

This produces a focused bust study.  It is intentionally not a game export: the
face must pass close-up review before the body, coat and deformation stages are
allowed to inherit its proportions.
"""

import math
import os

import bpy
from mathutils import Vector


OUT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "production", "echo-face-sculpt-v1"))
BLEND = os.path.join(OUT, "echo-face-sculpt-v1.blend")
RENDER = os.path.join(OUT, "echo-face-sculpt-v1-closeup.png")


def material(name, color, metallic=0.0, roughness=0.45, emission=None, strength=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["IOR"].default_value = 1.42
    if emission and "Emission Color" in bsdf.inputs:
        bsdf.inputs["Emission Color"].default_value = emission
        bsdf.inputs["Emission Strength"].default_value = strength
    return m


def smooth(obj):
    for p in obj.data.polygons:
        p.use_smooth = True
    return obj


def bevel(obj, width, segments=3):
    m = obj.modifiers.new("EdgeSoftening", "BEVEL")
    m.width = width
    m.segments = segments
    return obj


def ellipsoid(name, location, scale, mat, segments=64, rings=48):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, location=location)
    o = bpy.context.object
    o.name = name
    o.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    smooth(o)
    o.data.materials.append(mat)
    return o


def curve_line(name, points, mat, radius=0.0035):
    c = bpy.data.curves.new(name + "Curve", "CURVE")
    c.dimensions = "3D"
    c.resolution_u = 4
    c.bevel_resolution = 4
    c.bevel_depth = radius
    spline = c.splines.new("BEZIER")
    spline.bezier_points.add(len(points) - 1)
    for bp, co in zip(spline.bezier_points, points):
        bp.co = co
        bp.handle_left_type = "AUTO"
        bp.handle_right_type = "AUTO"
    o = bpy.data.objects.new(name, c)
    bpy.context.collection.objects.link(o)
    o.data.materials.append(mat)
    return o


def head_mesh(mat):
    rings, sectors = 64, 96
    verts, faces = [], []
    center_z = 1.685
    for r in range(rings + 1):
        theta = math.pi * r / rings
        z_unit = math.cos(theta)
        radial = math.sin(theta)
        for s in range(sectors):
            phi = math.tau * s / sectors
            front = max(0.0, -math.sin(phi))
            z = center_z + .191 * z_unit
            # Narrow jaw and chin; preserve broader anime cranium/temples.
            jaw_t = max(0.0, min(1.0, (1.675 - z) / .17))
            temple_t = math.exp(-((z - 1.72) / .085) ** 2)
            width = .145 * (1.0 - .27 * jaw_t) * (1.0 + .035 * temple_t)
            chin_soft = 1.0 - .12 * max(0.0, (1.56 - z) / .07)
            x = width * radial * math.cos(phi) * chin_soft
            depth = .126 * radial
            # Flatten face plane subtly, retain cheek/nasolabial depth.
            face_flatten = .014 * front * max(0.0, 1.0 - abs(z - 1.69) / .16)
            cheek = .007 * front * math.exp(-((z - 1.67) / .055) ** 2)
            y = depth * math.sin(phi) + face_flatten - cheek
            verts.append((x, y, z))
    for r in range(rings):
        for s in range(sectors):
            a = r * sectors + s
            b = r * sectors + (s + 1) % sectors
            c = (r + 1) * sectors + (s + 1) % sectors
            d = (r + 1) * sectors + s
            faces.append((a, b, c, d))
    mesh = bpy.data.meshes.new("EchoFaceSculptMesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    o = bpy.data.objects.new("EchoFace_Sculpt", mesh)
    bpy.context.collection.objects.link(o)
    smooth(o)
    o.data.materials.append(mat)
    sub = o.modifiers.new("SculptSubdivision", "SUBSURF")
    sub.levels = 2
    sub.render_levels = 2
    return o


def hair_cap(mat):
    rings, sectors = 28, 72
    verts, faces = [], []
    for r in range(rings + 1):
        theta = (math.pi * .61) * r / rings
        for s in range(sectors):
            phi = math.tau * s / sectors
            x = .153 * math.sin(theta) * math.cos(phi)
            y = .137 * math.sin(theta) * math.sin(phi) + .008
            z = 1.706 + .184 * math.cos(theta)
            verts.append((x, y, z))
    for r in range(rings):
        for s in range(sectors):
            a = r*sectors+s; b=r*sectors+(s+1)%sectors
            c=(r+1)*sectors+(s+1)%sectors; d=(r+1)*sectors+s
            faces.append((a,b,c,d))
    me=bpy.data.meshes.new("HairCapMesh"); me.from_pydata(verts,[],faces); me.update()
    o=bpy.data.objects.new("HairCap",me); bpy.context.collection.objects.link(o)
    o.data.materials.append(mat); smooth(o)
    sub=o.modifiers.new("HairCapSubdivision","SUBSURF"); sub.levels=2; sub.render_levels=2
    return o


def hair_blade(name, path, widths, mat, thickness=.004):
    points=[Vector(p) for p in path]
    verts=[]
    for i,p in enumerate(points):
        if i==0: tangent=(points[1]-p).normalized()
        elif i==len(points)-1: tangent=(p-points[i-1]).normalized()
        else: tangent=(points[i+1]-points[i-1]).normalized()
        side=tangent.cross(Vector((0,1,0)))
        if side.length < .05: side=tangent.cross(Vector((0,0,1)))
        side.normalize()
        verts.extend([tuple(p-side*widths[i]),tuple(p+side*widths[i])])
    faces=[]
    for i in range(len(points)-1):
        faces.append((i*2,i*2+1,i*2+3,i*2+2))
    me=bpy.data.meshes.new(name+"Mesh"); me.from_pydata(verts,[],faces); me.update()
    o=bpy.data.objects.new(name,me); bpy.context.collection.objects.link(o); o.data.materials.append(mat)
    sol=o.modifiers.new("StrandThickness","SOLIDIFY"); sol.thickness=thickness; sol.offset=0
    bev=o.modifiers.new("StrandEdgeSoftening","BEVEL"); bev.width=.0035; bev.segments=3
    sub=o.modifiers.new("StrandSubdivision","SUBSURF"); sub.levels=2; sub.render_levels=2
    return o


def setup_references():
    ref_dir=os.path.abspath(os.path.join(os.path.dirname(__file__),"..","..","production","echo-higgsfield-turnaround"))
    specs=[
        ("REF_FRONT",os.path.join(ref_dir,"echo-front-apose-higgsfield-v2.png"),(0,.43,1.0),(math.radians(90),0,0)),
        ("REF_BACK",os.path.join(ref_dir,"echo-back-apose-higgsfield-v2.png"),(0,.47,1.0),(math.radians(90),0,math.pi)),
        ("REF_PROFILE",os.path.join(ref_dir,"echo-left-profile-higgsfield-v2.png"),(.44,0,1.0),(math.radians(90),0,math.radians(90))),
    ]
    for name,path,loc,rot in specs:
        if not os.path.exists(path): continue
        image=bpy.data.images.load(path,check_existing=True)
        o=bpy.data.objects.new(name,None)
        o.empty_display_type="IMAGE"; o.data=image; o.empty_display_size=1.78
        o.color[3]=.18; o.show_in_front=False; o.hide_render=True
        o.location=loc; o.rotation_euler=rot
        bpy.context.collection.objects.link(o)
        o["reference_only"]=True


def build():
    os.makedirs(OUT,exist_ok=True)
    bpy.ops.object.select_all(action="SELECT"); bpy.ops.object.delete(use_global=False)
    skin=material("Skin_PorcelainWarm",(.69,.46,.40,1),roughness=.5)
    skin_shadow=material("Skin_Shadow",(.35,.16,.15,1),roughness=.58)
    hair=material("Hair_BlackBlue",(.004,.006,.012,1),metallic=.12,roughness=.24)
    hair_edge=material("Hair_CoolEdge",(.015,.026,.052,1),metallic=.18,roughness=.2)
    sclera=material("Eye_Sclera",(.78,.82,.86,1),roughness=.12)
    dark=material("Eye_Line",(.001,.001,.003,1),roughness=.25)
    red=material("Iris_Left_Red",(.54,.002,.008,1),roughness=.1,emission=(1,.002,.004,1),strength=2.4)
    cyan=material("Iris_Right_Cyan",(0,.38,.62,1),roughness=.1,emission=(0,.72,1,1),strength=2.2)
    coat=material("Collar_MatteTech",(.012,.017,.026,1),metallic=.16,roughness=.34)
    metal=material("Collar_Hardware",(.035,.045,.06,1),metallic=.72,roughness=.2)
    head_mesh(skin)
    hair_cap(hair)
    ellipsoid("Ear_L",(-.143,.006,1.68),(.023,.014,.041),skin,40,28)
    ellipsoid("Ear_R",(.143,.006,1.68),(.023,.014,.041),skin,40,28)

    # Eye volumes and graphic eyelid contours.
    for side,x,iris_mat in (("L",-.049,red),("R",.049,cyan)):
        ellipsoid("Sclera_"+side,(x,-.1265,1.704),(.041,.010,.0215),sclera,48,28)
        ellipsoid("Iris_"+side,(x,-.1365,1.703),(.016,.005,.016),iris_mat,36,24)
        ellipsoid("Pupil_"+side,(x,-.141,1.703),(.005,.003,.010),dark,28,18)
        sign=-1 if side=="L" else 1
        curve_line("UpperLid_"+side,[(x-.040,-.139,1.703),(x-.016,-.143,1.724),(x+.018,-.143,1.722),(x+.041,-.138,1.706)],dark,.0042)
        curve_line("LowerLid_"+side,[(x-.037,-.137,1.700),(x,-.141,1.688),(x+.036,-.137,1.701)],skin_shadow,.0022)
        curve_line("Brow_"+side,[(x-.042,-.130,1.752),(x-.008,-.136,1.760),(x+.043,-.129,1.748+sign*.002)],hair,.005)
    # Nose and mouth are low relief to preserve the anime read.
    verts=[(0,-.149,1.704),(-.015,-.132,1.661),(.015,-.132,1.661),(0,-.153,1.655)]
    faces=[(0,1,3),(0,3,2),(1,2,3)]
    me=bpy.data.meshes.new("NosePlaneMesh"); me.from_pydata(verts,[],faces); me.update()
    no=bpy.data.objects.new("NosePlane",me); bpy.context.collection.objects.link(no); no.data.materials.append(skin_shadow)
    curve_line("MouthLine",[(-.036,-.131,1.619),(0,-.135,1.615),(.036,-.131,1.619)],skin_shadow,.0023)
    curve_line("LowerLipLight",[(-.020,-.130,1.609),(0,-.133,1.606),(.020,-.130,1.609)],skin,.0015)

    # Directional clumps: fewer, broad sculpted locks instead of cone spikes.
    locks=[]
    for i in range(18):
        a=math.tau*i/18 + .08
        root=(math.cos(a)*.055,math.sin(a)*.050+0.01,1.875)
        mid=(math.cos(a)*.135,math.sin(a)*.118+0.005,1.80)
        fall=.12+.035*(i%4)
        tip=(math.cos(a)*(.155+.012*(i%3)),math.sin(a)*(.135+.008*(i%2)),1.72-fall)
        locks.append((root,mid,tip,.033+.004*(i%3)))
    # Hero bangs and cheek-framing strands.
    locks += [
        ((-.06,-.02,1.87),(-.105,-.13,1.80),(-.105,-.153,1.655),.036),
        ((-.025,-.025,1.89),(-.055,-.14,1.80),(-.058,-.153,1.666),.034),
        ((.012,-.025,1.89),(.015,-.145,1.80),(.018,-.153,1.675),.032),
        ((.052,-.02,1.87),(.083,-.135,1.79),(.092,-.149,1.672),.035),
        ((-.13,.005,1.82),(-.158,-.07,1.74),(-.155,-.10,1.62),.031),
        ((.13,.005,1.82),(.158,-.07,1.74),(.155,-.10,1.63),.031),
        ((0,.025,1.89),(.025,.02,1.94),(.050,.015,1.99),.027),
    ]
    for i,(root,mid,tip,width) in enumerate(locks):
        hair_blade(f"HairLock_{i:02d}",[root,mid,tip],[width,width*.82,.002],hair_edge if i%5==0 else hair,.0045)

    # Neck and technical collar establish scale and costume identity in close-up.
    ellipsoid("Neck",(0,.015,1.49),(.060,.055,.13),skin,48,32)
    ellipsoid("ShoulderBust",(0,.045,1.34),(.31,.16,.18),coat,56,36)
    for side,sign in (("L",-1),("R",1)):
        bpy.ops.mesh.primitive_cube_add(location=(.092*sign,-.01,1.515),rotation=(math.radians(-6),math.radians(5*sign),math.radians(5*sign)))
        o=bpy.context.object; o.name="RaisedCollar_"+side; o.scale=(.097,.073,.068); bpy.ops.object.transform_apply(location=False,rotation=False,scale=True); o.data.materials.append(coat); bevel(o,.014)
        curve_line("CollarSignal_"+side,[(.035*sign,-.089,1.558),(.085*sign,-.091,1.552),(.142*sign,-.075,1.520)],red if side=="L" else cyan,.003)
    ellipsoid("NeuralClasp",(0,-.137,1.425),(.035,.012,.035),metal,36,24)
    ellipsoid("NeuralClaspCore",(0,-.149,1.425),(.016,.005,.016),cyan,28,18)

    setup_references()
    # Camera, portrait lighting and neutral background.
    cd=bpy.data.cameras.new("PortraitCameraData"); cam=bpy.data.objects.new("PortraitCamera",cd); bpy.context.collection.objects.link(cam)
    cam.location=(.34,-2.55,1.69); target=Vector((0,0,1.69)); cam.rotation_euler=(target-Vector(cam.location)).to_track_quat("-Z","Y").to_euler(); cd.lens=88
    bpy.context.scene.camera=cam
    for name,loc,energy,color,size in (("FaceKey",(-1.25,-1.8,2.55),1050,(1,.78,.70),1.7),("EyeFill",(1.35,-1.4,1.9),720,(.28,.67,1),1.3),("HairRim",(.2,.9,2.35),1250,(.68,.08,1),1.2)):
        ld=bpy.data.lights.new(name,"AREA"); ld.energy=energy; ld.color=color; ld.shape="DISK"; ld.size=size
        lo=bpy.data.objects.new(name,ld); lo.location=loc; lo.rotation_euler=(target-Vector(loc)).to_track_quat("-Z","Y").to_euler(); bpy.context.collection.objects.link(lo)
    scene=bpy.context.scene; scene.render.engine="BLENDER_EEVEE_NEXT"; scene.render.resolution_x=1400; scene.render.resolution_y=1800; scene.render.resolution_percentage=100
    scene.render.image_settings.file_format="PNG"; scene.render.filepath=RENDER; scene.render.film_transparent=False
    scene.render.image_settings.color_mode="RGBA"; scene.view_settings.look="AgX - Medium High Contrast"
    scene.world.use_nodes=True; bg=scene.world.node_tree.nodes.get("Background"); bg.inputs["Color"].default_value=(.012,.015,.024,1); bg.inputs["Strength"].default_value=.32
    scene["quality_gate"]="FACE_IDENTITY_REVIEW_REQUIRED"
    scene["canon_reference"]="Manhwa first; Higgsfield 4K orthographic reference set"
    bpy.ops.wm.save_as_mainfile(filepath=BLEND)
    bpy.ops.render.render(write_still=True)
    bpy.ops.wm.save_as_mainfile(filepath=BLEND)
    print("ECHO_FACE_SCULPT_V1_OK="+BLEND)


if __name__ == "__main__":
    build()

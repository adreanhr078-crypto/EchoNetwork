"""Find a two-foot seat-edge perch on the exact lab chair before baking a take."""
import hashlib
import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

source = Path(bpy.data.filepath)
args = sys.argv[sys.argv.index("--")+1:]
floor_rise = float(args[1]) if len(args) > 1 else 0.0
with source.open("rb") as stream:
    source_hash = hashlib.file_digest(stream, "sha256").hexdigest()
assert source_hash == "25e7e1bb15d162b457d463b7fd5f021a3ea1bb0f423acc46c9877224893e047d"
scene = bpy.context.scene
rig, = (o for o in scene.objects if o.type == "ARMATURE")
skin = next(o for o in bpy.context.selected_objects if o.type == "MESH")
chair = max((o for o in scene.objects if o.type == "MESH" and o != skin and not o.hide_render),
            key=lambda o: len(o.data.polygons))
bvh = BVHTree.FromPolygons([chair.matrix_world @ v.co for v in chair.data.vertices],
                           [tuple(p.vertices) for p in chair.data.polygons])
bones = {b.name.rsplit(":", 1)[-1]: b for b in rig.pose.bones}
world = rig.matrix_world
inverse = world.inverted()
names = ("Hips", "LeftUpLeg", "LeftLeg", "LeftFoot", "RightUpLeg", "RightLeg", "RightFoot")

def joint(name):
    return world @ bones[name].head

scene.frame_set(28)
floor_foot = {s: (world @ bones[s + "Foot"].matrix).to_quaternion() for s in ("Left", "Right")}
scene.frame_set(44)
rest = {name: bones[name].matrix_basis.copy() for name in names}
pelvis = world @ bones["Hips"].matrix
leg_reach = {}
leg_roots = {}
for side in ("Left", "Right"):
    hip, knee, foot = [joint(side + n) for n in ("UpLeg", "Leg", "Foot")]
    leg_reach[side] = ((knee - hip).length, (foot - knee).length)
    leg_roots[side] = hip - pelvis.translation

def ray(x, y):
    return bvh.ray_cast(Vector((x,y,1.7)),Vector((0,0,-1)),1.7)

def clear_floor(x, y):
    # Actor faces outboard. Allow full sole width and toe length.
    return all(ray(x+dx,y+dy)[0] is None
               for dx,dy in ((-.07,-.06),(-.07,.06),(.14,-.06),(.14,.06),(0,0)))

feet = [Vector((.44+.02*ix,-.86+.025*iy,.085+floor_rise))
        for ix in range(25) for iy in range(26)
        if clear_floor(.44+.02*ix,-.86+.025*iy)]
positions = []
for ix in range(15):
    for iy in range(18):
        x, y = .12+.02*ix,-.65+.022*iy
        hit, normal, _, _ = ray(x,y)
        if hit is None or not (.65 < hit.z < .95) or normal.z < .75:
            continue
        for offset in ((.155,.175,.195,.215,.235) if floor_rise else (.095,.115,.135)):
            pos = Vector((x,y,hit.z+offset))
            candidates = {}
            for side, sign in (("Left", 1), ("Right", -1)):
                hip = pos + leg_roots[side]
                a,b = leg_reach[side]
                candidates[side] = sorted((f for f in feet if .08 <= sign*(f.y-y) <= .28
                                           and .32 < (f-hip).length < a+b-.015),
                                          key=lambda f: (f-hip).length)
            if all(candidates.values()):
                feet_pair = {s: candidates[s][0] for s in candidates}
                positions.append((pos, feet_pair, offset))

def place(name, transform):
    bones[name].matrix = inverse @ transform
    bpy.context.view_layer.update()

def aim(name, child, target):
    start = joint(name)
    rotation = (joint(child)-start).rotation_difference(target-start)
    transform = rotation.to_matrix().to_4x4() @ world @ bones[name].matrix
    transform.translation = start
    place(name, transform)

def set_legs(stance):
    for side, target in stance.items():
        upper, lower, foot = (side+n for n in ("UpLeg","Leg","Foot"))
        hip = joint(upper)
        direction = (target-hip).normalized()
        a,b = leg_reach[side]
        d = (target-hip).length
        along = (a*a-b*b+d*d)/(2*d)
        forward = Vector((1,-.12,0))
        pole = (forward-direction*forward.dot(direction)).normalized()
        knee = hip + direction*along + pole*math.sqrt(max(0,a*a-along*along))
        aim(upper,lower,knee)
        aim(lower,foot,target)
        orientation = floor_foot[side].to_matrix().to_4x4()
        orientation.translation = joint(foot)
        place(foot,orientation)

hips = {g.index for g in skin.vertex_groups if g.name.rsplit(":",1)[-1] in {"Hips","LeftUpLeg","RightUpLeg"}}
hip_vertices = [v.index for v in skin.data.vertices if sum(g.weight for g in v.groups if g.group in hips)>.75]
screened = []
for pos, stance, offset in positions:
    for name, basis in rest.items():
        bones[name].matrix_basis = basis
    transform = pelvis.copy()
    transform.translation = pos
    place("Hips",transform)
    set_legs(stance)
    body = skin.evaluated_get(bpy.context.evaluated_depsgraph_get())
    mesh = body.to_mesh()
    try:
        vertices = [body.matrix_world @ v.co for v in mesh.vertices]
        body_bvh = BVHTree.FromPolygons(vertices, [tuple(p.vertices) for p in mesh.polygons])
        pairs = body_bvh.overlap(bvh)
        gaps = []
        for i in hip_vertices:
            p = vertices[i]
            if abs(p.z-pos.z)>.23 or (p.xy-pos.xy).length>.20:
                continue
            hit, normal, _, _ = bvh.ray_cast(p+Vector((0,0,.10)),Vector((0,0,-1)),.55)
            if hit is not None and normal.z>.55 and .60 < hit.z < pos.z-.035:
                gaps.append(p.z-hit.z)
        foot_error = max((joint(s+"Foot")-target).length for s,target in stance.items())
        screened.append(dict(pelvis=list(pos), feet={s:list(v) for s,v in stance.items()},
                             overlap_pairs=len(pairs), floor_min_m=min(v.z for v in vertices),
                             min_seat_gap_m=min(gaps) if gaps else None,
                             contact_samples=sum(-.004<=g<=.012 for g in gaps), foot_error_m=foot_error))
    finally:
        body.to_mesh_clear()

accepted = [r for r in screened if r["overlap_pairs"]==0 and r["floor_min_m"]>=floor_rise-.005
            and r["foot_error_m"]<=.002 and r["contact_samples"]>=6 and r["min_seat_gap_m"]>=-.004]
report = dict(source_sha256=source_hash, possible_floor_sites=len(feet),
              leg_reachable_poses=len(positions), static_candidates=len(accepted),
              required_support_surface_height_m=floor_rise,
              accepted=accepted, screened=screened,
              scope="Single side-facing pose and frame-44 torso configuration. Static geometric gate, no balance, no motion export.")
if len(args) > 2 and accepted:
    # Choose the closer seat fit with laterally aligned feet so one step can carry both.
    candidate = min(accepted,key=lambda r: (abs(r["feet"]["Left"][0]-r["feet"]["Right"][0]),r["min_seat_gap_m"]))
    stance = {s:Vector(p) for s,p in candidate["feet"].items()}
    xlo = min(p.x for p in stance.values())-.07
    xhi = max(p.x for p in stance.values())+.14
    ylo = min(p.y for p in stance.values())-.06
    yhi = max(p.y for p in stance.values())+.06
    # Reject any chair geometry under the proposed rectangular deck, including
    # gaps between the two sampled footprints.
    intersects = False
    for i in range(30):
        for j in range(50):
            x, y = xlo+(xhi-xlo)*i/29, ylo+(yhi-ylo)*j/49
            hit, _, _, _ = bvh.ray_cast(Vector((x,y,floor_rise)),Vector((0,0,-1)),floor_rise)
            intersects |= hit is not None
    report["step_screen"] = {"bounds_m":[xlo,xhi,ylo,yhi,0,floor_rise],"ray_intersection":intersects,"candidate":candidate}
    if not intersects:
        for name,basis in rest.items():
            bones[name].matrix_basis = basis
        transform = pelvis.copy()
        transform.translation = Vector(candidate["pelvis"])
        place("Hips",transform)
        set_legs(stance)
        bpy.ops.mesh.primitive_cube_add(size=1,location=((xlo+xhi)/2,(ylo+yhi)/2,floor_rise/2))
        step = bpy.context.object
        step.name = "Diagnostic Step Volume - Not Runtime"
        step.dimensions = (xhi-xlo,yhi-ylo,floor_rise)
        step.color = (0.08,0.40,0.48,1.0)
        scene.render.engine = "BLENDER_WORKBENCH"
        scene.render.resolution_x = 760
        scene.render.resolution_y = 480
        scene.render.resolution_percentage = 100
        scene.display.shading.light = "STUDIO"
        scene.display.shading.color_type = "OBJECT"
        scene.camera.location = (3.7,-3.25,2.75)
        scene.camera.rotation_euler = (Vector((.20,-.25,.88))-scene.camera.location).to_track_quat("-Z","Y").to_euler()
        scene.camera.data.type = "ORTHO"
        scene.camera.data.ortho_scale = 4.2
        scene.render.filepath = args[2]
        bpy.ops.render.render(write_still=True)
out = Path(args[0])
out.write_text(json.dumps(report,indent=2)+"\n",encoding="utf-8")
print("CHAIR_PERCH", len(feet),len(positions),len(accepted),flush=True)

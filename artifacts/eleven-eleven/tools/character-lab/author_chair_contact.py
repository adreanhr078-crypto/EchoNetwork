"""Author an isolated pre-contract restrained breath on the original School65 rig."""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path
import sys

import bpy
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

APP = Path(__file__).resolve().parents[2]
SCHOOL = APP / "art/production/echo-school-rebuild-20261029/source/echo-school-rig-metric.glb"
CHAIR = APP / "godot/assets/environments/lab_clinical_cp45/neural_chair_tripo_20k.glb"
CHAIR_SCALE = 2.6 / .9791260362
FPS = 30
LAST = 60
LEFT_RIGHT = (("Left", 1), ("Right", -1))


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def import_mesh(path):
    prior = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(path))
    return list(set(bpy.data.objects) - prior)


def capture(out):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "TEXTURE"
    scene.display.shading.show_cavity = True
    scene.display.shading.show_shadows = True
    scene.render.resolution_x, scene.render.resolution_y = 960, 600
    scene.render.resolution_percentage = 100
    camera = bpy.data.objects.new("Contact review camera", bpy.data.cameras.new("Contact review"))
    scene.collection.objects.link(camera)
    scene.camera = camera
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 3.72
    focus = Vector((0, -.02, .91))
    for name, location in (("three-quarter", (2.7, -2.6, 2.05)), ("side", (4.0, -.10, 1.55))):
        camera.location = location
        camera.rotation_euler = (focus - camera.location).to_track_quat("-Z", "Y").to_euler()
        scene.frame_set(30)
        scene.render.filepath = str(out / f"blender-{name}.png")
        bpy.ops.render.render(write_still=True)


def run(out, render, draft):
    out.mkdir(parents=True, exist_ok=True)
    hashes_before = {p.relative_to(APP).as_posix(): digest(p) for p in (SCHOOL, CHAIR)}
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.fps = FPS
    scene.frame_start, scene.frame_end = 0, LAST
    school_nodes = import_mesh(SCHOOL)
    rig = next(o for o in school_nodes if o.type == "ARMATURE")
    body = next(o for o in school_nodes if o.type == "MESH" and any(m.type == "ARMATURE" for m in o.modifiers))
    assert len(rig.data.bones) == 65
    assert not rig.animation_data or not rig.animation_data.action
    for obj in school_nodes:
        if obj.type == "MESH" and obj != body:
            obj.hide_render = True
    chair_nodes = import_mesh(CHAIR)
    chair = next(o for o in chair_nodes if o.type == "MESH")
    chair.matrix_world = Matrix.Rotation(-math.pi / 2, 4, "Z") @ Matrix.Scale(CHAIR_SCALE, 4) @ chair.matrix_world
    bpy.context.view_layer.update()
    bvh = BVHTree.FromPolygons([chair.matrix_world @ v.co for v in chair.data.vertices],
                               [tuple(p.vertices) for p in chair.data.polygons])
    to_world = rig.matrix_world.copy()
    from_world = to_world.inverted()
    bones = {bone.name.rsplit(":", 1)[-1]: bone for bone in rig.pose.bones}
    rest_world = {name: to_world @ bone.matrix.copy() for name, bone in bones.items()}
    joint_names = ["Hips", "Spine2", "Head", "LeftHand", "RightHand", "LeftFoot", "RightFoot"]
    touched = ["Hips", "Spine", "Spine1", "Spine2", "Neck", "Head"]
    touched += [side + joint for side, _ in LEFT_RIGHT for joint in
                ("Arm", "ForeArm", "Hand", "UpLeg", "Leg", "Foot")]
    for b in rig.pose.bones:
        b.rotation_mode = "QUATERNION"

    def update():
        bpy.context.view_layer.update()

    def joint(name):
        return to_world @ bones[name].head

    def set_world(name, matrix, pivot):
        matrix = matrix.copy()
        matrix.translation = pivot
        bones[name].matrix = from_world @ matrix
        update()

    def turn(name, axis, radians):
        transform = to_world @ bones[name].matrix
        set_world(name, Matrix.Rotation(radians, 4, axis) @ transform, transform.translation)

    def aim(name, child, target):
        start = joint(name)
        current = joint(child) - start
        rotation = current.rotation_difference(target - start)
        set_world(name, rotation.to_matrix().to_4x4() @ to_world @ bones[name].matrix, start)

    def solve(upper, lower, end, target, bend):
        start, middle, tip = [joint(n) for n in (upper, lower, end)]
        a, b = (middle - start).length, (tip - middle).length
        direction = (target - start).normalized()
        distance = min(max((target - start).length, abs(a - b) + .0001), a + b - .0001)
        elbow_projection = (a*a - b*b + distance*distance) / (2*distance)
        elbow_offset = math.sqrt(max(0, a*a - elbow_projection*elbow_projection))
        pole = (bend - direction * bend.dot(direction)).normalized()
        midpoint = start + direction * elbow_projection + pole * elbow_offset
        aim(upper, lower, midpoint)
        aim(lower, end, start + direction * distance)
        return (joint(end) - target).length

    def height(x, y):
        hit, normal, _, _ = bvh.ray_cast(Vector((x, y, 3)), Vector((0, 0, -1)))
        return hit.z if hit is not None and normal.z > .12 else None

    # Anchor from the same visible chair scaled in the current lab. The sample
    # centers Echo in chair-local coordinates and uses the actual support mesh.
    pelvis_xy = (0, -.010)
    pelvis_z = height(*pelvis_xy) + .119
    wrist = {}
    ankle = {}
    for side, sign in LEFT_RIGHT:
        x, y = .45 * sign, .125
        wrist[side] = Vector((x, y, height(x, y) + .027))
        x, y = .145 * sign, -.855
        ankle[side] = Vector((x, y, height(x, y) + .101))
    back_trim_deg = 0.0

    def pose(frame):
        for b in rig.pose.bones:
            b.matrix_basis = Matrix.Identity(4)
        update()
        effort = math.sin(math.pi * frame / LAST) ** 2
        # A small restrained breath and swallow; the seat, palms and ankles
        # are fixed throughout the take. There is no release or earned power.
        set_world("Hips", Matrix.Rotation(math.radians(-42), 4, "X") @ rest_world["Hips"],
                  Vector((*pelvis_xy, pelvis_z)))
        turn("Spine", "X", math.radians(-27 + back_trim_deg + .55 * effort))
        turn("Spine1", "X", math.radians(-4 + .15 * effort))
        turn("Spine2", "X", math.radians(-2))
        turn("Neck", "X", math.radians(18 + 4.0 * effort))
        turn("Head", "X", math.radians(10 - 1.2 * effort))
        errors = {}
        angles = {}
        for side, sign in LEFT_RIGHT:
            errors[side+"Wrist"] = solve(side+"Arm", side+"ForeArm", side+"Hand", wrist[side],
                                         Vector((sign*.7, .5, -.8)))
            set_world(side+"Hand", Matrix.Rotation(-sign*math.pi/2, 4, "Z") @ rest_world[side+"Hand"], joint(side+"Hand"))
            errors[side+"Ankle"] = solve(side+"UpLeg", side+"Leg", side+"Foot", ankle[side],
                                         Vector((sign*.22, 0, 1)))
            # Transport the foot with its shank before applying a small
            # relaxed plantar flexion. A world-space sole angle on a nearly
            # horizontal shank produces the visibly broken ankle.
            rest_shank = rest_world[side+"Foot"].translation - rest_world[side+"Leg"].translation
            posed_shank = joint(side+"Foot") - joint(side+"Leg")
            transport = rest_shank.rotation_difference(posed_shank).to_matrix().to_4x4()
            relax = Matrix.Rotation(math.radians(12), 4, "X")
            set_world(side+"Foot", transport @ relax @ rest_world[side+"Foot"], joint(side+"Foot"))
            rest_toe = rest_world[side+"ToeBase"].translation - rest_world[side+"Foot"].translation
            posed_toe = joint(side+"ToeBase") - joint(side+"Foot")
            angles[side] = math.degrees(abs((-posed_shank).angle(posed_toe) - (-rest_shank).angle(rest_toe)))
        return errors, angles

    def skin_support():
        depsgraph = bpy.context.evaluated_depsgraph_get()
        evaluated = body.evaluated_get(depsgraph)
        mesh = evaluated.to_mesh()
        buckets = {"seat": [], "back": [], "left_wrist": [], "right_wrist": [], "left_leg": [], "right_leg": []}
        try:
            for vertex in mesh.vertices:
                p = evaluated.matrix_world @ vertex.co
                side = "left" if p.x > 0 else "right"
                if abs(p.x) < .18 and .08 < p.y < .63 and 1.02 < p.z < 1.34:
                    hit, normal, _, _ = bvh.ray_cast(Vector((p.x, -.25, p.z)), Vector((0, 1, 0)))
                    if hit is not None and normal.y < -.20:
                        buckets["back"].append(hit.y - p.y)
                if abs(p.x) < .23 and -.25 < p.y < .085 and .69 < p.z < .99:
                    name = "seat"
                elif .385 < abs(p.x) < .53 and -.045 < p.y < .15 and 1.0 < p.z < 1.23:
                    name = side+"_wrist"
                elif .065 < abs(p.x) < .25 and -1.02 < p.y < -.58 and .65 < p.z < .97:
                    name = side+"_leg"
                else:
                    continue
                top = height(p.x, p.y)
                if top is not None:
                    buckets[name].append(p.z - top)
        finally:
            evaluated.to_mesh_clear()
        return {k: {"vertices":len(v), "minimum_m": min(v) if v else None,
                    "p05_m": sorted(v)[int(.05*(len(v)-1))] if v else None} for k,v in buckets.items()}

    # Correct the isolated anatomical anchors against evaluated shoe/palm and
    # seat skin, using one measured correction per local support pass.
    calibration = []
    for _ in range(2):
        pose(30)
        before = skin_support()
        calibration.append(before)
        pelvis_z += max(-.02, min(.03, .002 - before["seat"]["minimum_m"]))
        for side, _ in LEFT_RIGHT:
            wrist[side].z += max(-.035, min(.060, .003 - before[side.lower()+"_wrist"]["minimum_m"]))
            ankle[side].z += max(-.035, min(.065, .003 - before[side.lower()+"_leg"]["minimum_m"]))
    # Solve against the front of the back cushion instead of moving the
    # pelvis or changing limb lengths. An upright trim lifts the back away.
    lo, hi = 0.0, 10.0
    for _ in range(9):
        back_trim_deg = (lo + hi) / 2
        pose(0)
        clearance = skin_support()["back"]["minimum_m"]
        if clearance is None or clearance >= .004:
            hi = back_trim_deg
        else:
            lo = back_trim_deg
    back_trim_deg = hi
    sample_frames = [0, 15, 30, 45, LAST]
    errors, ankle_angles, samples, supports = [], [], [], {}
    frames = [30] if draft else range(LAST+1)
    for frame in frames:
        scene.frame_set(frame)
        error, angles = pose(frame)
        errors.append(error)
        ankle_angles.append(angles)
        samples.append({"frame":frame, "joints":{name:list(joint(name)) for name in joint_names}})
        if frame in sample_frames:
            supports[str(frame)] = skin_support()
        for name in touched:
            b = bones[name]
            b.keyframe_insert(data_path="rotation_quaternion", frame=frame, group=b.name)
        bones["Hips"].keyframe_insert(data_path="location", frame=frame, group=bones["Hips"].name)
    action = rig.animation_data.action
    action.name = "RestrainedBreath"
    if render:
        capture(out)
    max_anchor_error = max(max(e.values()) for e in errors)
    max_ankle_delta = max(max(a.values()) for a in ankle_angles)
    support_pass = all(value["vertices"] > 50 and value["minimum_m"] is not None
                       and -.006 <= value["minimum_m"] <= .025
                       for frame in supports.values() for key, value in frame.items() if key != "back")
    back_pass = all(frame["back"]["vertices"] > 50 and frame["back"]["minimum_m"] is not None
                    and -.004 <= frame["back"]["minimum_m"] <= .025 for frame in supports.values())
    if not draft:
        bpy.ops.object.select_all(action="DESELECT")
        rig.select_set(True)
        body.select_set(True)
        bpy.context.view_layer.objects.active = rig
        bpy.ops.wm.save_as_mainfile(filepath=str(out/"authored-contact.blend"), compress=True)
    assert hashes_before == {p.relative_to(APP).as_posix(): digest(p) for p in (SCHOOL, CHAIR)}
    result = {
        "scope":"Isolated original pose authoring. Geometry contact, render and animation import are separate gates.",
        "sources":hashes_before, "tool_sha256":digest(Path(__file__)), "fps":FPS,
        "chair_review_space":"Z-up; chair front -Y; scene-equivalent size without gameplay transform",
        "chair_scale":CHAIR_SCALE, "pelvis":list((*pelvis_xy,pelvis_z)),
        "wrist":{k:list(v) for k,v in wrist.items()}, "ankle":{k:list(v) for k,v in ankle.items()},
        "frames":samples, "skin_support":supports, "calibration":calibration,
        "max_joint_anchor_error_m":max_anchor_error,
        "max_ankle_angle_delta_from_rest_deg":max_ankle_delta,
        "ankle_angle_numeric_pass":max_ankle_delta <= 18,
        "back_trim_deg":back_trim_deg, "back_support_numeric_pass":back_pass,
        "anchor_numeric_pass":max_anchor_error < .002, "horizontal_support_numeric_pass":support_pass,
        "draft_only":draft, "no_source_key_edit":True,
    }
    if not draft:
        result["blend_sha256"] = digest(out/"authored-contact.blend")
    (out / "blender-contact.json").write_text(json.dumps(result,indent=2)+"\n",encoding="utf-8")
    print("CHAIR_CONTACT", json.dumps({k:result[k] for k in ("max_joint_anchor_error_m","skin_support","draft_only")}), flush=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--render", action="store_true")
    parser.add_argument("--draft", action="store_true")
    args = parser.parse_args(sys.argv[sys.argv.index("--")+1:])
    run(args.output, args.render, args.draft)

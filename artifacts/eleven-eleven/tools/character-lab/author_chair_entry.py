"""Author and screen one isolated stand-to-seat candidate on the exact chair blend."""

import argparse
import json
import math
from pathlib import Path
import sys

import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))

from author_chair_contact import APP, digest
from author_chair_cuffs import tree


PACKET = APP / "art/production/signature-slice-20261104/chair-contact-20261105"
SIDES = (("Left", 1), ("Right", -1))
FPS = 30
# Frame, pelvis, yaw, recline, left ankle, right ankle. Z-up, chair front -Y.
KEYS = (
    (0,  (.86, -.52, .957),  90, 0, (.84, -.36, .085), (.91, -.68, .085)),
    (12, (.79, -.52, .953),  90, 0, (.74, -.36, .085), (.91, -.68, .085)),
    (27, (.62, -.52, .945),  90, 2, (.74, -.36, .085), (.70, -.68, .085)),
    (44, (.34, -.51, 1.03),  83, 4, (.47, -.38, .270), (.70, -.68, .085)),
    (54, (.26, -.46, 1.025), 77, 9, (.49, -.46, .740), (.66, -.68, .360)),
    (63, (.20, -.41, 1.03),  65, 12, (.39, -.70, 1.05), (.66, -.69, .850)),
    (74, (.11, -.30, 1.026), 39, 21, (.24, -.84, 1.06), (.44, -.82, 1.10)),
    (83, (.03, -.13, 1.012), 13, 34, (.16, -.86, .99), (.03, -.88, 1.08)),
    (96, (0, -.01, .9634),   0, 42, (.145, -.855, .874), (-.145, -.855, .869)),
)


def smooth(value):
    return value * value * (3.0 - 2.0 * value)


def segment(frame):
    for start, end in zip(KEYS, KEYS[1:]):
        if frame <= end[0]:
            return start, end, smooth((frame - start[0]) / (end[0] - start[0]))
    raise ValueError(frame)


def between(start, end, amount, field):
    return Vector(start[field]).lerp(Vector(end[field]), amount)


def camera_stills(out):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.render.resolution_x, scene.render.resolution_y = 760, 480
    scene.render.resolution_percentage = 100
    shading = scene.display.shading
    shading.light, shading.color_type = "STUDIO", "MATERIAL"
    shading.show_shadows = True
    shading.show_cavity = True
    shading.background_type = "WORLD"
    camera = scene.camera
    camera.location = (3.7, -3.25, 2.75)
    camera.rotation_euler = (Vector((.20, -.25, .88)) - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 4.2
    for frame in (0, 27, 44, 63, 74, 96):
        scene.frame_set(frame)
        scene.render.filepath = str(out / f"entry-{frame:03d}.png")
        bpy.ops.render.render(write_still=True)


def run(blend, out, render):
    seated = json.loads((PACKET / "blender-contact.json").read_text(encoding="utf-8"))
    original = digest(blend)
    assert original == seated["blend_sha256"]
    for relative, expected in seated["sources"].items():
        assert digest(APP / relative) == expected
    out.mkdir(parents=True, exist_ok=True)
    target = out / "chair-entry-candidate.blend"
    assert not target.exists() and "golden" not in {part.lower() for part in target.resolve().parts}
    bpy.ops.wm.open_mainfile(filepath=str(blend))
    scene = bpy.context.scene
    scene.frame_set(0)
    rig = next(o for o in bpy.context.selected_objects if o.type == "ARMATURE")
    skin = next(o for o in bpy.context.selected_objects if o.type == "MESH")
    chair = max((o for o in scene.objects if o.type == "MESH" and o != skin and not o.hide_render),
                key=lambda obj: len(obj.data.polygons))
    chair_tree = tree(chair, chair.data)
    bones = {bone.name.rsplit(":", 1)[-1]: bone for bone in rig.pose.bones}
    assert len(bones) == 65 and rig.animation_data.action.name == "RestrainedBreath"
    world = rig.matrix_world.copy()
    inverse = world.inverted()
    rest = {name: world @ bone.bone.matrix_local for name, bone in bones.items()}
    finish = {name: bone.matrix_basis.copy() for name, bone in bones.items()}
    finish_world = {name: world @ bone.matrix.copy() for name, bone in bones.items()}
    rig.animation_data_clear()
    for bone in bones.values():
        bone.rotation_mode = "QUATERNION"
    names = ["Hips", "Spine", "Spine1", "Spine2", "Neck", "Head"]
    names += [side + part for side, _ in SIDES for part in
              ("Arm", "ForeArm", "Hand", "UpLeg", "Leg", "Foot")]
    scene.frame_start, scene.frame_end = 0, KEYS[-1][0]
    scene.render.fps = FPS

    def update():
        bpy.context.view_layer.update()

    def joint(name):
        return world @ bones[name].head

    def place(name, transform, at):
        matrix = transform.copy()
        matrix.translation = at
        bones[name].matrix = inverse @ matrix
        update()

    def aim(name, child, target):
        start = joint(name)
        rotation = (joint(child) - start).rotation_difference(target - start)
        place(name, rotation.to_matrix().to_4x4() @ world @ bones[name].matrix, start)

    def reach(upper, lower, end, target, bend):
        start, mid, tip = (joint(name) for name in (upper, lower, end))
        a, b = (mid - start).length, (tip - mid).length
        direction = (target - start).normalized()
        distance = min(max((target - start).length, abs(a - b) + .0001), a + b - .0001)
        projected = (a*a - b*b + distance*distance) / (2*distance)
        perpendicular = bend - direction * bend.dot(direction)
        offset = math.sqrt(max(0.0, a*a - projected*projected))
        aim(upper, lower, start + direction*projected + perpendicular.normalized()*offset)
        aim(lower, end, start + direction*distance)
        return (joint(end) - target).length

    def pose(frame):
        start, end, amount = segment(frame)
        hips = between(start, end, amount, 1)
        yaw = start[2] + (end[2] - start[2]) * amount
        recline = start[3] + (end[3] - start[3]) * amount
        turn = Matrix.Rotation(math.radians(yaw), 4, "Z")
        bend = Matrix.Rotation(math.radians(-recline), 4, "X")
        forward = turn.to_3x3() @ Vector((0, -1, 0))
        body_settle = smooth(max(0.0, min(1.0, (frame - 44) / 52)))
        knee_lift = smooth(max(0.0, min(1.0, (frame - 32) / 38)))
        exact_end = smooth(max(0.0, (frame - 88) / 8))
        for name, bone in bones.items():
            body_lean = name in ("Spine", "Spine1", "Spine2", "Neck", "Head")
            bone.matrix_basis = Matrix.Identity(4).lerp(finish[name], body_settle if body_lean else 0.0)
        update()
        place("Hips", turn @ bend @ rest["Hips"], hips)
        errors = {}
        for index, (side, sign) in enumerate(SIDES):
            foot = between(start, end, amount, 4 + index)
            # A foot in transfer clears the base before returning to the dais.
            if end[0] <= 27 and (Vector(start[4 + index]) - Vector(end[4 + index])).length > .015:
                foot.z += .075 * math.sin(math.pi * amount)
            if side == "Left" and end[0] == 44:
                foot.z += .15 * math.sin(math.pi * amount)
            pole = forward + Vector((0, 0, 1.9 * knee_lift))
            errors[side + "Foot"] = reach(side+"UpLeg", side+"Leg", side+"Foot", foot, pole)
            foot_rotation = (turn @ rest[side+"Foot"]).to_quaternion().slerp(
                finish_world[side+"Foot"].to_quaternion(), body_settle)
            place(side+"Foot", foot_rotation.to_matrix().to_4x4(), joint(side+"Foot"))
            shoulder = joint(side+"Arm")
            standing = shoulder + turn.to_3x3() @ Vector((.10*sign, -.07, -.39))
            elbow = turn.to_3x3() @ Vector((.70*sign, .25, -.25))
            support = Vector((.49, -.21, 1.25)) if side == "Left" else standing
            brace = smooth(max(0.0, min(1.0, (frame - 14) / 21)))
            land = smooth(max(0.0, min(1.0, (frame - 78) / 18)))
            wrist = finish_world[side+"Hand"].translation
            elevated = wrist + Vector((0, -.05, .16)) * (1.0 - land)
            hand = standing.lerp(support, brace).lerp(elevated, body_settle)
            errors[side+"Hand"] = reach(side+"Arm", side+"ForeArm", side+"Hand", hand, elbow)
            grip = max(body_settle, brace) if side == "Left" else body_settle
            place(side+"Hand", (turn @ rest[side+"Hand"]).lerp(finish_world[side+"Hand"], grip), joint(side+"Hand"))
        if exact_end > 0.0:
            for name in names:
                bones[name].matrix_basis = bones[name].matrix_basis.lerp(finish[name], exact_end)
            update()
        return errors

    def measure(frame, errors):
        evaluated = skin.evaluated_get(bpy.context.evaluated_depsgraph_get())
        mesh = evaluated.to_mesh()
        try:
            vertices = [evaluated.matrix_world @ vertex.co for vertex in mesh.vertices]
            pairs = tree(evaluated, mesh).overlap(chair_tree)
            touching = {skin_index for skin_index, _ in pairs}
            points = [vertices[i] for polygon in touching for i in mesh.polygons[polygon].vertices]
            minimum = min(point.z for point in vertices)
            return {
                "frame": frame,
                "overlap_pairs": len(pairs),
                "overlap_bounds": [[min(p[i] for p in points), max(p[i] for p in points)] for i in range(3)] if points else None,
                "floor_min_m": minimum,
                "max_ik_error_m": max(errors.values()),
                "ik_errors_m": errors,
                "joints": {name: list(joint(name)) for name in
                           ("Hips", "Spine2", "Head", "LeftHand", "RightHand", "LeftFoot", "RightFoot")},
            }
        finally:
            evaluated.to_mesh_clear()

    records = []
    for frame in range(scene.frame_end + 1):
        scene.frame_set(frame)
        errors = pose(frame)
        records.append(measure(frame, errors))
        for name in names:
            bones[name].keyframe_insert(data_path="rotation_quaternion", frame=frame, group=name)
        bones["Hips"].keyframe_insert(data_path="location", frame=frame, group="Hips")
    rig.animation_data.action.name = "ChairEntryCandidate"
    seated_delta = max((joint(name) - finish_world[name].translation).length for name in names)
    assert seated_delta < .0001
    bpy.ops.wm.save_as_mainfile(filepath=str(target), compress=True)
    assert digest(blend) == original
    result = {
        "status": "PASS_SAMPLED_GEOMETRY" if all(r["overlap_pairs"] == 0 and r["floor_min_m"] >= -.005 for r in records)
                  else "FAIL_SAMPLED_GEOMETRY",
        "scope": "Every 30 Hz frame, evaluated skin against original chair triangles; swept-volume and animation acceptance remain open.",
        "seated_source_sha256": original,
        "sources": seated["sources"],
        "tool_sha256": digest(Path(__file__)),
        "candidate_sha256": digest(target),
        "fps": FPS, "samples": len(records), "end_seat_delta_m": seated_delta, "frames": records,
    }
    (out / "entry-screen.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print("ENTRY", [(r["frame"], r["overlap_pairs"], round(r["floor_min_m"], 3), round(r["max_ik_error_m"], 3))
                    for r in records], flush=True)
    if render:
        camera_stills(out)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--blend", required=True, type=Path)
    parser.add_argument("--out", required=True, type=Path)
    parser.add_argument("--render", action="store_true")
    options = parser.parse_args(sys.argv[sys.argv.index("--") + 1:])
    run(options.blend.resolve(), options.out.resolve(), options.render)

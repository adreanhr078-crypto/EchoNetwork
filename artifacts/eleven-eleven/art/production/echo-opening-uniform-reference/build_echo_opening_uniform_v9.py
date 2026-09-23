import bpy
import math
from pathlib import Path
from mathutils import Matrix, Quaternion, Vector


ROOT = Path(r"C:\Users\yasmo\EchoNetwork\artifacts\eleven-eleven")
SOURCE = ROOT / "art/production/echo-opening-uniform-reference/echo-opening-uniform-v8.blend"
BLEND = ROOT / "art/production/echo-opening-uniform-reference/echo-opening-uniform-v9.blend"
GLB = ROOT / "godot/assets/characters/echo_opening_uniform_v9.glb"
MODEL_SCALE = 1.81
WALK_CYCLE = 24
RUN_CYCLE = 12

bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
scene = bpy.context.scene
scene.render.fps = 24
rig = bpy.data.objects["EchoOpeningUniformRig"]
armature = rig.data

for track in rig.animation_data.nla_tracks:
    track.mute = True


def select_rig(mode="OBJECT"):
    bpy.ops.object.mode_set(mode="OBJECT") if bpy.context.object and bpy.context.object.mode != "OBJECT" else None
    bpy.ops.object.select_all(action="DESELECT")
    rig.select_set(True)
    bpy.context.view_layer.objects.active = rig
    if mode != "OBJECT":
        bpy.ops.object.mode_set(mode=mode)


def create_helper_bones():
    names = {}
    for side in ("Left", "Right"):
        ankle_name = f"tripo::1_{side}_Limb_1"
        ankle = armature.bones[ankle_name].tail_local.copy()
        side_sign = -1.0 if side == "Left" else 1.0
        target_name = f"foot_ik_target_{side.lower()}"
        pole_name = f"foot_ik_pole_{side.lower()}"
        target = bpy.data.objects.new(target_name, None)
        pole = bpy.data.objects.new(pole_name, None)
        scene.collection.objects.link(target)
        scene.collection.objects.link(pole)
        for marker in (target, pole):
            marker.parent = rig
            marker.matrix_parent_inverse = Matrix.Identity(4)
            marker.empty_display_type = "SPHERE"
            marker.empty_display_size = 0.035
            marker.hide_render = True
        target.location = armature.bones[f"tripo::1_{side}_Limb_3"].tail_local.copy()
        pole.location = Vector((ankle.x + 0.38, ankle.y, -0.20))
        names[side] = {"target": target_name, "pole": pole_name, "ankle": ankle, "sign": side_sign}
        names[side]["target_object"] = target
        names[side]["pole_object"] = pole
    for side, values in names.items():
        effector = rig.pose.bones[f"tripo::1_{side}_Limb_3"]
        constraint = effector.constraints.new("IK")
        constraint.name = "FootContactIK"
        constraint.target = values["target_object"]
        constraint.pole_target = values["pole_object"]
        constraint.chain_count = 4
        constraint.use_tail = True
        constraint.use_stretch = False
        constraint.pole_angle = 0.0
        constraint.influence = 0.0
        values["constraint"] = constraint
    return names


helpers = create_helper_bones()
leg_bones = [f"tripo::1_{side}_Limb_{index}" for side in ("Left", "Right") for index in range(4)]


def activate_action(action):
    rig.animation_data.action = action
    if action.slots:
        rig.animation_data.action_slot = action.slots[0]


def begin_target_actions(action_name):
    for side in ("Left", "Right"):
        target = helpers[side]["target_object"]
        animation = target.animation_data_create()
        for track in animation.nla_tracks:
            track.mute = True
        action = bpy.data.actions.new(f"{action_name}_{side}_FootTarget")
        slot = action.slots.new(id_type="OBJECT", name=target.name)
        animation.action = action
        animation.action_slot = slot


def move_target_actions_to_nla(track_name):
    for side in ("Left", "Right"):
        target = helpers[side]["target_object"]
        animation = target.animation_data
        action = animation.action
        animation.action = None
        track = animation.nla_tracks.new()
        track.name = track_name
        start = int(round(action.frame_range[0]))
        strip = track.strips.new(track_name, start, action)
        if action.slots:
            strip.action_slot = action.slots[0]
        strip.blend_type = "REPLACE"
        track.mute = False


def remove_action_curves(action, fragments):
    for layer in action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for curve in list(bag.fcurves):
                    if any(fragment in curve.data_path for fragment in fragments):
                        bag.fcurves.remove(curve)


def animate_ik_influence(action, value, frames):
    activate_action(action)
    for side in ("Left", "Right"):
        constraint = helpers[side]["constraint"]
        path_fragment = f'constraints["{constraint.name}"]'
        remove_action_curves(action, [path_fragment])
        for frame in frames:
            constraint.influence = value
            constraint.keyframe_insert(data_path="influence", frame=frame, group=f"FootContactIK {side}")
    for layer in action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for curve in bag.fcurves:
                    if 'constraints["FootContactIK"].influence' in curve.data_path:
                        for point in curve.keyframe_points:
                            point.interpolation = "CONSTANT"
                        curve.update()


def set_target_pose(target_name, armature_position):
    target_object = next(data["target_object"] for data in helpers.values() if data["target"] == target_name)
    target_object.location = Vector(armature_position)
    return target_object


def solve_toe_contact(side, goal, seed):
    target_object = helpers[side]["target_object"]
    toe = rig.pose.bones[f"tripo::1_{side}_Limb_3"]
    position = Vector(seed)
    animation = target_object.animation_data
    saved_action = animation.action if animation else None
    saved_slot = animation.action_slot if animation else None
    saved_tracks = [(track, track.mute) for track in animation.nla_tracks] if animation else []
    if animation:
        animation.action = None
        for track, _ in saved_tracks:
            track.mute = True

    def sample(candidate):
        target_object.location = candidate.copy()
        bpy.context.view_layer.update()
        return toe.tail.copy()

    for iteration in range(24):
        actual = sample(position)
        error = goal - actual
        if error.length < 0.00075:
            break

        epsilon = 0.001
        columns = []
        for axis in range(3):
            offset = Vector((0.0, 0.0, 0.0))
            offset[axis] = epsilon
            columns.append((sample(position + offset) - actual) / epsilon)

        jacobian = Matrix((
            (columns[0].x, columns[1].x, columns[2].x),
            (columns[0].y, columns[1].y, columns[2].y),
            (columns[0].z, columns[1].z, columns[2].z),
        ))
        # Damped least squares stays stable near a straightened leg, where a
        # direct inverse becomes singular and sends the ankle target flying.
        jt = jacobian.transposed()
        normal = jt @ jacobian
        for axis in range(3):
            normal[axis][axis] += 0.0004
        try:
            step = normal.inverted() @ (jt @ error)
        except ValueError:
            break
        if step.length > 0.08:
            step *= 0.08 / step.length
        position += step * 0.65

    actual = sample(position)
    error = (goal - actual).length
    if animation:
        animation.action = saved_action
        if saved_action and saved_slot:
            animation.action_slot = saved_slot
        for track, was_muted in saved_tracks:
            track.mute = was_muted
    target_object.location = position
    bpy.context.view_layer.update()
    return position.copy(), error


def author_gait(action_name, cycle_frames, gait_speed, stance_ratio, lift_height, foot_pitch):
    action = bpy.data.actions[action_name]
    end_frame = cycle_frames * 2 + 1
    activate_action(action)
    begin_target_actions(action_name)
    clear_fragments = [f'pose.bones["{name}"]' for name in leg_bones]
    clear_fragments.extend(f'pose.bones["{helpers[side]["target"]}"]' for side in ("Left", "Right"))
    clear_fragments.append('constraints["FootContactIK"].influence')
    remove_action_curves(action, clear_fragments)

    fps = float(scene.render.fps)
    cycle_duration = cycle_frames / fps
    stance_distance = (gait_speed / MODEL_SCALE) * cycle_duration * stance_ratio
    half_stride = stance_distance * 0.5
    toe_contact_height = 0.052
    key_frames = range(1, end_frame + 1)
    expected_contacts = {}
    max_solve_error = 0.0

    for frame in key_frames:
        scene.frame_set(frame)
        for side in ("Left", "Right"):
            helpers[side]["constraint"].influence = 1.0
        cycle_phase = ((frame - 1) % cycle_frames) / float(cycle_frames)
        for side, side_offset in (("Left", 0.0), ("Right", 0.5)):
            data = helpers[side]
            phase = (cycle_phase + side_offset) % 1.0
            if phase < stance_ratio:
                local_phase = phase / stance_ratio
                stride_x = half_stride - stance_distance * local_phase
                swing_z = 0.0
                pitch = foot_pitch * math.sin(math.pi * local_phase) * 0.35
            else:
                local_phase = (phase - stance_ratio) / (1.0 - stance_ratio)
                eased = local_phase * local_phase * (3.0 - 2.0 * local_phase)
                stride_x = -half_stride + stance_distance * eased
                swing_z = lift_height * (math.sin(math.pi * local_phase) ** 1.35)
                pitch = -foot_pitch * math.sin(math.pi * local_phase)

            for index in range(4):
                name = f"tripo::1_{side}_Limb_{index}"
                pose_bone = rig.pose.bones[name]
                pose_bone.rotation_mode = "QUATERNION"
                pose_bone.matrix_basis = Matrix.Identity(4)
                pose_bone.keyframe_insert(data_path="location", frame=frame, group=name)
                pose_bone.keyframe_insert(data_path="rotation_quaternion", frame=frame, group=name)
                pose_bone.keyframe_insert(data_path="scale", frame=frame, group=name)

            foot = rig.pose.bones[f"tripo::1_{side}_Limb_2"]
            toe = rig.pose.bones[f"tripo::1_{side}_Limb_3"]
            foot.rotation_quaternion = Quaternion((1.0, 0.0, 0.0), 0.0)
            toe.rotation_quaternion = Quaternion((1.0, 0.0, 0.0), 0.0)
            foot.keyframe_insert(data_path="rotation_quaternion", frame=frame, group=foot.name)
            toe.keyframe_insert(data_path="rotation_quaternion", frame=frame, group=toe.name)

            toe_rest = armature.bones[f"tripo::1_{side}_Limb_3"].tail_local.copy()
            toe_goal = toe_rest + Vector((stride_x, 0.0, toe_contact_height + swing_z / MODEL_SCALE))
            solved_position, solve_error = solve_toe_contact(side, toe_goal, toe_goal)
            if solve_error > 0.02:
                raise RuntimeError(f"Could not plant {side} toe at frame {frame}: {solve_error:.4f}m")
            max_solve_error = max(max_solve_error, solve_error)
            expected_contacts[(frame, side)] = toe_goal.copy()
            target_bone = set_target_pose(data["target"], solved_position)
            target_bone.keyframe_insert(data_path="location", frame=frame, group=f"{action_name} {data['target']}")

            constraint = data["constraint"]
            constraint.influence = 1.0
            constraint.keyframe_insert(data_path="influence", frame=frame, group=f"FootContactIK {side}")

    for layer in action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for curve in bag.fcurves:
                    for point in curve.keyframe_points:
                        point.interpolation = "LINEAR" if curve.data_path.endswith(".location") and any(name in curve.data_path for name in ("foot_ik_target_left", "foot_ik_target_right")) else "BEZIER"
                    curve.update()
    for side in ("Left", "Right"):
        constraint = helpers[side]["constraint"]
        constraint.influence = 1.0
    move_target_actions_to_nla(action_name)
    return end_frame, expected_contacts, max_solve_error


def pose_matrix_in_local_space(pose_bone):
    kwargs = {}
    if pose_bone.parent:
        kwargs["parent_matrix"] = pose_bone.parent.matrix.copy()
        kwargs["parent_matrix_local"] = pose_bone.parent.bone.matrix_local.copy()
    return pose_bone.bone.convert_local_to_pose(
        pose_bone.matrix.copy(),
        pose_bone.bone.matrix_local.copy(),
        invert=True,
        **kwargs,
    )


def bake_gait_to_pose_keys(action_name, end_frame):
    action = bpy.data.actions[action_name]
    activate_action(action)
    for track in rig.animation_data.nla_tracks:
        track.mute = True
    for side in ("Left", "Right"):
        target = helpers[side]["target_object"]
        if target.animation_data:
            target.animation_data.action = None
            for track in target.animation_data.nla_tracks:
                track.mute = track.name != action_name

    sampled = {}
    for frame in range(1, end_frame + 1):
        scene.frame_set(frame)
        bpy.context.view_layer.update()
        sampled[frame] = {}
        for name in leg_bones:
            pose_bone = rig.pose.bones[name]
            sampled[frame][name] = pose_matrix_in_local_space(pose_bone).copy()

    remove_action_curves(action, [f'pose.bones["{name}"]' for name in leg_bones])
    remove_action_curves(action, ['constraints["FootContactIK"].influence'])
    activate_action(action)
    for frame, transforms in sampled.items():
        scene.frame_set(frame)
        for name, matrix in transforms.items():
            pose_bone = rig.pose.bones[name]
            location, rotation, scale = matrix.decompose()
            pose_bone.rotation_mode = "QUATERNION"
            pose_bone.location = location
            pose_bone.rotation_quaternion = rotation
            pose_bone.scale = scale
            pose_bone.keyframe_insert(data_path="location", frame=frame, group=name)
            pose_bone.keyframe_insert(data_path="rotation_quaternion", frame=frame, group=name)
            pose_bone.keyframe_insert(data_path="scale", frame=frame, group=name)

    for layer in action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for curve in bag.fcurves:
                    if any(f'pose.bones["{name}"]' in curve.data_path for name in leg_bones):
                        for point in curve.keyframe_points:
                            point.interpolation = "LINEAR"
                        curve.update()


def remove_ik_setup():
    for side in ("Left", "Right"):
        effector = rig.pose.bones[f"tripo::1_{side}_Limb_3"]
        for constraint in list(effector.constraints):
            if constraint.name == "FootContactIK":
                effector.constraints.remove(constraint)
        for key in ("target_object", "pole_object"):
            bpy.data.objects.remove(helpers[side][key], do_unlink=True)


# Keep IK disabled in every non-locomotion clip so jumps, turns, and recovery
# preserve their authored performance. Locomotion clips key it on explicitly.
for action in bpy.data.actions:
    if action.name in {"preset:walk", "preset:run"}:
        continue
    start, end = map(int, action.frame_range)
    animate_ik_influence(action, 0.0, [start, end])

walk_end, walk_contacts, walk_error = author_gait("preset:walk", WALK_CYCLE, 1.94, 0.52, 0.10, 0.16)
run_end, run_contacts, run_error = author_gait("preset:run", RUN_CYCLE, 6.4, 0.30, 0.16, 0.24)
bake_gait_to_pose_keys("preset:walk", walk_end)
bake_gait_to_pose_keys("preset:run", run_end)
remove_ik_setup()

def verify_baked_contacts(action_name, contacts):
    action = bpy.data.actions[action_name]
    activate_action(action)
    for track in rig.animation_data.nla_tracks:
        track.mute = True
    maximum = 0.0
    for (frame, side), goal in contacts.items():
        scene.frame_set(frame)
        bpy.context.view_layer.update()
        toe = rig.pose.bones[f"tripo::1_{side}_Limb_3"]
        error = (toe.tail - goal).length
        maximum = max(maximum, error)
    return maximum

walk_baked_error = verify_baked_contacts("preset:walk", walk_contacts)
run_baked_error = verify_baked_contacts("preset:run", run_contacts)
max_error = max(walk_error, run_error, walk_baked_error, run_baked_error)
print("FOOT_CONTACT_VALIDATION", "solver", round(max(walk_error, run_error), 5), "baked", round(max(walk_baked_error, run_baked_error), 5))
if max_error > 0.025:
    raise RuntimeError(f"Baked gait lost foot contact; maximum toe error {max_error:.4f}m")

rig.animation_data.action = None
for track in rig.animation_data.nla_tracks:
    track.mute = False
for obj in scene.objects:
    obj.select_set(False)
rig.select_set(True)
bpy.data.objects["EchoOpeningUniformBody"].select_set(True)
bpy.context.view_layer.objects.active = rig

bpy.ops.wm.save_as_mainfile(filepath=str(BLEND))
bpy.ops.export_scene.gltf(
    filepath=str(GLB),
    export_format="GLB",
    use_selection=True,
    export_animations=True,
    export_animation_mode="NLA_TRACKS",
    export_skins=True,
    export_image_format="JPEG",
    export_keep_originals=False,
    export_materials="EXPORT",
    export_apply=False,
)
print("OUTPUT", GLB, "WALK_FRAMES", walk_end, "RUN_FRAMES", run_end, "IK_ERROR", max_error)

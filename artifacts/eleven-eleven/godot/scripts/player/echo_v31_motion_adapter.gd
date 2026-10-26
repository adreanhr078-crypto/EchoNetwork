extends Node3D

## Owner-adopted V31. Existing CP17 keys stay immutable; runtime aliases are copies.
const SOURCE_LIBRARIES = [
	preload("res://assets/animations/v31/idle_cp17.res"),
	preload("res://assets/animations/v31/run_cp45.res"),
	preload("res://assets/animations/v31/jump_cp17.res"),
	preload("res://assets/animations/v31/hang_cp40.res"),
]
const SOURCE_NAMES = ["Idle_Source_Retarget", "Run_Source_Retarget", "Jump_Source_Retarget", "Hang_Source_Retarget"]
const ALIASES = ["IDLE", "RUN", "preset_jump", "PARKOUR_HANG"]
const CapeMotion = preload("res://engine_visuals/EchoCapeMotion.gd")
const WalkSource = preload("res://assets/animations/v31/walk_cp45.res")
const MantleSource = preload("res://assets/animations/v31/mantle_cp45.res")
const StandSource = preload("res://assets/animations/v31/stand_cp45.res")
const HorizontalAttackSource = preload("res://assets/animations/v31/attack_horizontal_cp45.res")
var _controlled_body: CharacterBody3D
var _skeleton: Skeleton3D
var _mixer: AnimationPlayer
var _hips := -1
var _base_position := Vector3.ZERO
var _left_hand := -1
var _right_hand := -1
var _hang_offset := Vector3.ZERO
var _native_return_remaining := 0.0
var _native_return_duration := 0.2
var _native_return_origin := Vector3.ZERO

func _ready() -> void:
	var skeleton := find_child("Skeleton3D",true,false) as Skeleton3D
	var player := find_child("AnimationPlayer",true,false) as AnimationPlayer
	var profile = preload("res://scripts/player/echo_rig_profile.gd").identify(skeleton)
	if profile.get("id") != preload("res://scripts/player/echo_rig_profile.gd").V31_ID or not player:
		push_error("Adopted Echo V31 rig identity unavailable; foreign animation injection refused")
		return
	var bodies = find_children("*", "MeshInstance3D", true, false)
	for body in bodies:
		if body.skin: body.name = "EchoV31BodyAndCoat"
	var library: AnimationLibrary = player.get_animation_library("")
	for i in SOURCE_LIBRARIES.size():
		var source: Animation = SOURCE_LIBRARIES[i].get_animation(SOURCE_NAMES[i])
		# Resolve every original track against the same imported rest hierarchy.
		var animation_root = player.get_node(player.root_node)
		for track in source.get_track_count():
			var target = animation_root.get_node_or_null(NodePath(source.track_get_path(track).get_concatenated_names()))
			if not target:
				push_error("V31 original motion path unresolved: " + str(source.track_get_path(track)))
				return
		if not library.has_animation(SOURCE_NAMES[i]): library.add_animation(SOURCE_NAMES[i], source)
		var alias: Animation = source.duplicate()
		alias.loop_mode = Animation.LOOP_LINEAR if i < 2 else Animation.LOOP_NONE
		if i == 3:
			# This is a wall-supported ledge: use its original braced support pose.
			# The later free-hang phase puts the torso under an overhead bar and
			# intersects a solid wall. All 29 source samples remain untouched.
			alias.set_meta("wall_support_pose_seconds", 0.0)
		library.add_animation(ALIASES[i], alias)
	# Separate native IPC Walk qualified on this exact target; immutable keys.
	var low_speed: Animation = WalkSource.get_animation("Walk_Source_Retarget").duplicate()
	low_speed.loop_mode = Animation.LOOP_LINEAR
	library.add_animation("WALK", low_speed)
	for entry in [[MantleSource, "Mantle_Source_Retarget", "PARKOUR_MANTLE"], [StandSource, "Stand_Source_Retarget", "PARKOUR_STAND"]]:
		var motion: Animation = entry[0].get_animation(entry[1]).duplicate()
		motion.loop_mode = Animation.LOOP_NONE
		library.add_animation(entry[2], motion)
	set_meta("owner_adopted_echo_v31", true)
	var attack:Animation=HorizontalAttackSource.get_animation("Attack_Source_Retarget").duplicate()
	attack.loop_mode=Animation.LOOP_NONE
	# Playback facts are instance metadata; all 4380 imported keys stay intact.
	# The actual built blade intersects the 1.8m target at native frame28.
	# The physics timer phase aligns damage with that observed intersection;
	# recovery may yield after the cut without trimming the source action.
	attack.set_meta("melee_contact_seconds",.95)
	attack.set_meta("melee_cancel_seconds",1.2)
	library.add_animation("MELEE_HORIZONTAL",attack)
	set_meta("motion_support", {"idle":"CP17", "run":"CP45 Standing Run Forward", "jump":"CP17", "walk":"CP45 MOB1_Walk_F_IPC", "attack":"CP45 native horizontal; distinct combo/iai acting open", "face":"open", "cape":"CP44 independent chains"})
	# In a controlled avatar, physics already owns displacement. Source motion
	# also translates Hips each cycle; leaving both active makes the
	# visible body leave its capsule then snap back. Resolve that presentation
	# origin after the mixer, preserving every source key and Root Motion setting.
	var owner_body := get_parent().get_parent() if get_parent() else null
	if owner_body is CharacterBody3D and owner_body.has_method("set_mobile_input_vector"):
		# Capsule movement and contact detection use the physics clock. Keep this
		# controlled avatar on that same clock so a slow render/capture cannot
		# advance a whole gait between physical foot-contact observations.
		player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS
		_controlled_body = owner_body
		_skeleton = skeleton
		_mixer = player
		_hips = skeleton.find_bone("Hips")
		_left_hand = skeleton.find_bone("LeftHand")
		_right_hand = skeleton.find_bone("RightHand")
		_base_position = position
		player.mixer_applied.connect(_sync_capsule_alignment)
		# The owner-approved short-jacket geometry keeps this exact rig and its
		# native motions. It has no long skirt requiring a secondary cloth solver.
		if not get_meta("short_jacket_variant", false):
			var cape := CapeMotion.new()
			cape.name = "EchoCapeMotion"
			skeleton.add_child(cape)
			if not cape.configure(_controlled_body):
				cape.queue_free()
				push_error("Explicit V31 garment chains unavailable; coat driver refused")

func _process(delta: float) -> void:
	if not is_instance_valid(_controlled_body): return
	if not _controlled_body.surface_motor.hanging and _native_return_remaining <= 0.0:
		# Return the presentation origin after release; capsule physics remains authoritative.
		_hang_offset = _hang_offset.move_toward(Vector3.ZERO, delta * 5.0)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(_controlled_body) or _native_return_remaining <= 0.0: return
	_native_return_remaining = maxf(0.0, _native_return_remaining - delta)
	_hang_offset = _native_return_origin * (_native_return_remaining / _native_return_duration)

func locomotion_reference_speed(clip: String, fallback: float) -> float:
	if not is_instance_valid(_mixer) or not is_instance_valid(_skeleton) or not _mixer.has_animation(clip): return fallback
	var animation: Animation = _mixer.get_animation(clip)
	var speed: Variant = animation.get_meta("source_ground_speed_mps", 0.0)
	if not (speed is float or speed is int) or not is_finite(float(speed)) or float(speed)<=0.01: return fallback
	# The native source stride is measured at the rig's authored scale. Only
	# playback rate follows world movement; source curves and root settings stay intact.
	var world_speed := float(speed) * _skeleton.global_basis.x.length()
	return world_speed if is_finite(world_speed) and world_speed>0.01 else fallback

func _sync_capsule_alignment() -> void:
	if not is_instance_valid(_controlled_body) or _hips < 0: return
	if _controlled_body.surface_motor.native_mantle_active:
		_controlled_body.surface_motor.sync_native_visual()
		return
	if _mixer.current_animation == "PARKOUR_HANG" and _controlled_body.surface_motor.hanging and _left_hand >= 0 and _right_hand >= 0:
		# Place the intact animated avatar against the measured edge after the mixer.
		# This changes only this presentation node, never bones, source keys or capsule.
		position = _base_position
		var grip := (_skeleton.to_global(_skeleton.get_bone_global_pose(_left_hand).origin) + _skeleton.to_global(_skeleton.get_bone_global_pose(_right_hand).origin)) * 0.5
		var destination:Vector3 = _controlled_body.surface_motor.hang_grip_world
		_hang_offset = get_parent().to_local(destination) - get_parent().to_local(grip)
		position = _base_position + _hang_offset
		return
	if _mixer.current_animation not in ["RUN", "WALK"]:
		position = _base_position + _hang_offset
		return
	var source_delta := _skeleton.get_bone_global_pose(_hips).origin - _skeleton.get_bone_global_rest(_hips).origin
	var parent_delta: Vector3 = get_parent().global_basis.inverse() * (_skeleton.global_basis * source_delta)
	# Keep the authored vertical gait and all joint rotations. Isolated source
	# replay without a controlled CharacterBody remains wholly unchanged.
	position = _base_position + _hang_offset - Vector3(parent_delta.x, 0.0, parent_delta.z)

func release_native_traversal() -> float:
	_hang_offset = position - _base_position
	_native_return_origin = _hang_offset
	_native_return_duration = maxf(0.2, _native_return_origin.length() / 2.0)
	_native_return_remaining = _native_return_duration
	return _native_return_duration

extends Node3D

## Owner-adopted V31. Existing CP17 keys stay immutable; runtime aliases are copies.
const SOURCE_LIBRARIES = [
	preload("res://assets/animations/v31/idle_cp17.res"),
	preload("res://assets/animations/v31/run_cp17.res"),
	preload("res://assets/animations/v31/jump_cp17.res"),
]
const SOURCE_NAMES = ["Idle_Source_Retarget", "Run_Source_Retarget", "Jump_Source_Retarget"]
const ALIASES = ["IDLE", "RUN", "preset_jump"]
var _controlled_body: CharacterBody3D
var _skeleton: Skeleton3D
var _mixer: AnimationPlayer
var _hips := -1
var _base_position := Vector3.ZERO

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
		library.add_animation(ALIASES[i], alias)
	# Low-speed movement keeps this rig's own run until a separate Walk gate closes.
	# This is an explicit temporary locomotion mapping, never a Walk acceptance claim.
	var low_speed: Animation = SOURCE_LIBRARIES[1].get_animation(SOURCE_NAMES[1]).duplicate()
	low_speed.loop_mode = Animation.LOOP_LINEAR
	library.add_animation("WALK", low_speed)
	set_meta("owner_adopted_echo_v31", true)
	set_meta("motion_support", {"idle":"CP17", "run":"CP17", "jump":"CP17", "walk":"temporary slowed native Run", "attack":"open", "face":"open", "cape":"owner temporary deferral"})
	# In a controlled avatar, physics already owns displacement. CP17's source
	# Run also translates Hips by 2.75m each cycle; leaving both active makes the
	# visible body leave its capsule then snap back. Resolve that presentation
	# origin after the mixer, preserving every source key and Root Motion setting.
	var owner_body := get_parent().get_parent() if get_parent() else null
	if owner_body is CharacterBody3D and owner_body.has_method("set_mobile_input_vector"):
		_controlled_body = owner_body
		_skeleton = skeleton
		_mixer = player
		_hips = skeleton.find_bone("Hips")
		_base_position = position
		player.mixer_applied.connect(_sync_capsule_alignment)

func _sync_capsule_alignment() -> void:
	if not is_instance_valid(_controlled_body) or _hips < 0: return
	if _mixer.current_animation not in ["RUN", "WALK"]:
		position = _base_position
		return
	var source_delta := _skeleton.get_bone_global_pose(_hips).origin - _skeleton.get_bone_global_rest(_hips).origin
	var parent_delta: Vector3 = get_parent().global_basis.inverse() * (_skeleton.global_basis * source_delta)
	# Keep the authored vertical gait and all joint rotations. Isolated source
	# replay without a controlled CharacterBody remains wholly unchanged.
	position = _base_position - Vector3(parent_delta.x, 0.0, parent_delta.z)

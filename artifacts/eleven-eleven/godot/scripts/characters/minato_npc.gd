class_name MinatoNPC
extends CharacterBody3D

signal spoke_with_player(npc_id: String, dialogue_line: String)

enum SchedulePhase {
	MORNING_SHIFT,
	AFTERNOON_STROLL,
	EVENING_COMMUTE,
	NIGHT_REST
}

enum FamiliarityTier {
	STRANGER,      # 0
	ACQUAINTANCE,  # 1-2
	REGULAR,       # 3-5
	FAMILIAR       # 6+
}

enum GestureType {
	NOD,
	WELCOMING_LEAN
}

@export var npc_id: String = "NPC_AOI_01"
@export var display_name: String = "Nurse Aoi Tanaka"
@export var role: String = "Hospital Outpatient Nurse"
@export var home_or_work_role: String = "Minato-Kasumi General Hospital"
@export var current_activity: String = "Finishing evening shift and heading home"
@export var schedule_phase: SchedulePhase = SchedulePhase.AFTERNOON_STROLL

@export var dialogue_lines: Array[String] = [
	"My shift at the clinic is finally over... You look pale, are you an outpatient?",
	"The coastal sea air always clears the mind after a double shift.",
	"Take care heading down the seawall, the wind picks up toward sundown."
]

@export_group("Procedural Animation")
@export var reduced_motion: bool = false
@export var breathing_enabled: bool = true
@export var look_at_tracking_enabled: bool = true
@export var look_at_distance: float = 3.5
@export var breath_speed: float = 2.0
@export var breath_y_amplitude: float = 0.014
@export var sway_speed: float = 0.95
@export var sway_z_amplitude: float = 0.022

const InteractableComponent = preload("res://scripts/interaction/interactable_component.gd")

var talk_count: int = 0
var familiarity_tier: FamiliarityTier = FamiliarityTier.STRANGER

# Node references
@onready var interactable = find_child("InteractableComponent", true, false)
@onready var body_mesh: MeshInstance3D = find_child("BodyMesh", true, false) as MeshInstance3D
@onready var head_mesh: MeshInstance3D = find_child("HeadMesh", true, false) as MeshInstance3D

# Internal animation state
var _idle_time: float = 0.0
var _body_base_pos: Vector3 = Vector3(0, 0.85, 0)
var _head_base_pos: Vector3 = Vector3(0, 1.55, 0)
var _body_base_rot: Vector3 = Vector3.ZERO
var _head_base_rot: Vector3 = Vector3.ZERO
var _initial_rotation_y: float = 0.0

# Look-at tracking state
var _cached_player: Node3D = null
var target_player: Node3D = null
var is_tracking_player: bool = false
var _head_current_yaw: float = 0.0
var _head_current_pitch: float = 0.0

# Interactive gesture state
var current_gesture: GestureType = GestureType.NOD
var gesture_timer: float = 0.0
var gesture_duration: float = 0.7
var is_gesturing: bool = false

func get_familiarity_name() -> String:
	match familiarity_tier:
		FamiliarityTier.STRANGER: return "Stranger"
		FamiliarityTier.ACQUAINTANCE: return "Acquaintance"
		FamiliarityTier.REGULAR: return "Regular"
		FamiliarityTier.FAMILIAR: return "Familiar"
	return "Stranger"

func _ready() -> void:
	if not interactable:
		interactable = find_child("InteractableComponent", true, false) as InteractableComponent
	if interactable:
		interactable.verb = InteractableComponent.InteractionVerb.TALK
		interactable.prompt_target_name = display_name

	if not body_mesh:
		body_mesh = find_child("BodyMesh", true, false) as MeshInstance3D
	if not head_mesh:
		head_mesh = find_child("HeadMesh", true, false) as MeshInstance3D

	if body_mesh:
		_body_base_pos = body_mesh.position
		_body_base_rot = body_mesh.rotation
	if head_mesh:
		_head_base_pos = head_mesh.position
		_head_base_rot = head_mesh.rotation

	_initial_rotation_y = rotation.y
	_idle_time = (npc_id.hash() % 1000) * 0.02

func _process(delta: float) -> void:
	_idle_time += delta
	var is_reduced: bool = is_reduced_motion()

	_update_look_at(delta, is_reduced)
	_update_gestures(delta, is_reduced)
	_apply_procedural_transforms(is_reduced)

func set_reduced_motion(enabled: bool) -> void:
	reduced_motion = enabled
	if enabled:
		gesture_timer = 0.0
		is_gesturing = false
		_head_current_yaw = 0.0
		_head_current_pitch = 0.0
		if body_mesh and is_instance_valid(body_mesh):
			body_mesh.position = _body_base_pos
			body_mesh.rotation = _body_base_rot
		if head_mesh and is_instance_valid(head_mesh):
			head_mesh.position = _head_base_pos
			head_mesh.rotation = _head_base_rot

func is_reduced_motion() -> bool:
	if reduced_motion:
		return true
	if is_inside_tree():
		var cur: Node = get_parent()
		while cur:
			if cur.get("reduced_motion") == true:
				return true
			cur = cur.get_parent()
	return false

func _get_active_player_target() -> Node3D:
	if is_instance_valid(target_player) and target_player.is_inside_tree():
		return target_player
	if interactable and is_instance_valid(interactable) and "current_interactor" in interactable:
		var cur = interactable.current_interactor
		if is_instance_valid(cur) and cur.is_inside_tree():
			return cur
	if is_instance_valid(_cached_player) and _cached_player.is_inside_tree():
		return _cached_player
	if is_inside_tree():
		var tree := get_tree()
		if tree:
			var players := tree.get_nodes_in_group("player")
			if not players.is_empty() and is_instance_valid(players[0]) and players[0] is Node3D:
				_cached_player = players[0] as Node3D
				return _cached_player
			var root: Node = tree.current_scene if tree.current_scene else tree.root
			if root:
				var echo := root.find_child("EchoPlayer", true, false) as Node3D
				if echo and is_instance_valid(echo):
					_cached_player = echo
					return _cached_player
				var p := root.find_child("Player", true, false) as Node3D
				if p and is_instance_valid(p):
					_cached_player = p
					return _cached_player
	return null

func _update_look_at(delta: float, is_reduced: bool) -> void:
	if not look_at_tracking_enabled:
		is_tracking_player = false
		return

	var echo: Node3D = _get_active_player_target()
	if echo and is_inside_tree() and echo.is_inside_tree():
		var my_pos: Vector3 = global_position
		var echo_pos: Vector3 = echo.global_position
		var dist: float = my_pos.distance_to(echo_pos)

		if dist <= look_at_distance and dist > 0.05:
			is_tracking_player = true
			var diff: Vector3 = echo_pos - my_pos
			diff.y = 0.0

			if diff.length_squared() > 0.001:
				var desired_body_yaw: float = atan2(diff.x, diff.z)
				if is_reduced:
					rotation.y = desired_body_yaw
				else:
					rotation.y = lerp_angle(rotation.y, desired_body_yaw, delta * 3.5)

			# Head tracking
			if head_mesh and not is_reduced:
				var head_gpos: Vector3 = head_mesh.global_position
				var gaze_world: Vector3 = (echo_pos + Vector3(0, 1.45, 0) - head_gpos).normalized()
				var gaze_local: Vector3 = global_transform.basis.inverse() * gaze_world
				var target_yaw: float = atan2(gaze_local.x, gaze_local.z)
				var dist_xz: float = sqrt(gaze_local.x * gaze_local.x + gaze_local.z * gaze_local.z)
				var target_pitch: float = -atan2(gaze_local.y, dist_xz)

				target_yaw = clampf(target_yaw, -deg_to_rad(55.0), deg_to_rad(55.0))
				target_pitch = clampf(target_pitch, -deg_to_rad(30.0), deg_to_rad(20.0))

				_head_current_yaw = lerp_angle(_head_current_yaw, target_yaw, delta * 5.5)
				_head_current_pitch = lerp_angle(_head_current_pitch, target_pitch, delta * 5.5)
			return

	# Return to neutral rest orientation when player is outside 3.5m
	is_tracking_player = false
	if is_inside_tree():
		if is_reduced:
			rotation.y = _initial_rotation_y
			_head_current_yaw = 0.0
			_head_current_pitch = 0.0
		else:
			rotation.y = lerp_angle(rotation.y, _initial_rotation_y, delta * 2.0)
			_head_current_yaw = lerp_angle(_head_current_yaw, 0.0, delta * 3.5)
			_head_current_pitch = lerp_angle(_head_current_pitch, 0.0, delta * 3.5)

func _update_gestures(delta: float, is_reduced: bool) -> void:
	if is_reduced or gesture_timer <= 0.0:
		is_gesturing = false
		gesture_timer = 0.0
		return

	gesture_timer = maxf(0.0, gesture_timer - delta)
	is_gesturing = (gesture_timer > 0.0)

func _apply_procedural_transforms(is_reduced: bool) -> void:
	var breath_y: float = 0.0
	var sway_z: float = 0.0
	var head_sway_z: float = 0.0

	if breathing_enabled and not is_reduced:
		# Subtle breathing bob (gentle vertical oscillation)
		breath_y = sin(_idle_time * breath_speed) * breath_y_amplitude
		# Weight shifting (gentle Z rotation oscillation)
		sway_z = sin(_idle_time * sway_speed) * sway_z_amplitude
		head_sway_z = -sway_z * 0.4

	# Gesture offsets
	var gest_body_pitch: float = 0.0
	var gest_body_y: float = 0.0
	var gest_head_pitch: float = 0.0
	var gest_head_y: float = 0.0

	if is_gesturing and gesture_duration > 0.0 and not is_reduced:
		var progress: float = 1.0 - (gesture_timer / gesture_duration)
		var curve: float = sin(progress * PI)

		if current_gesture == GestureType.NOD:
			# Polite nod: head pitches down smoothly, subtle upper body dip
			gest_head_pitch = curve * deg_to_rad(15.0)
			gest_head_y = -curve * 0.012
			gest_body_pitch = curve * deg_to_rad(3.0)
			gest_body_y = -curve * 0.008
		elif current_gesture == GestureType.WELCOMING_LEAN:
			# Welcoming lean / slight bow: torso leans forward and dips slightly
			gest_body_pitch = curve * deg_to_rad(8.0)
			gest_body_y = -curve * 0.024
			gest_head_pitch = curve * deg_to_rad(11.0)
			gest_head_y = -curve * 0.024

	# Apply to BodyMesh
	if body_mesh and is_instance_valid(body_mesh):
		body_mesh.position = _body_base_pos + Vector3(0.0, breath_y + gest_body_y, 0.0)
		body_mesh.rotation = Vector3(_body_base_rot.x + gest_body_pitch, _body_base_rot.y, _body_base_rot.z + sway_z)

	# Apply to HeadMesh
	if head_mesh and is_instance_valid(head_mesh):
		head_mesh.position = _head_base_pos + Vector3(0.0, breath_y * 1.1 + gest_head_y, 0.0)
		var final_head_pitch: float = _head_base_rot.x + _head_current_pitch + gest_head_pitch
		var final_head_yaw: float = _head_base_rot.y + _head_current_yaw
		var final_head_roll: float = _head_base_rot.z + head_sway_z
		head_mesh.rotation = Vector3(final_head_pitch, final_head_yaw, final_head_roll)

func play_interactive_gesture(type: int = -1) -> void:
	if is_reduced_motion():
		return

	if type == -1:
		var r_lower := role.to_lower()
		var n_lower := display_name.to_lower()
		if r_lower.contains("nurse") or r_lower.contains("clerk") or r_lower.contains("elderly") or r_lower.contains("gardener") or n_lower.contains("aoi") or n_lower.contains("haruko") or n_lower.contains("hana"):
			current_gesture = GestureType.WELCOMING_LEAN
			gesture_duration = 0.85
		else:
			current_gesture = GestureType.NOD
			gesture_duration = 0.65
	else:
		current_gesture = type as GestureType
		gesture_duration = 0.85 if current_gesture == GestureType.WELCOMING_LEAN else 0.65

	gesture_timer = gesture_duration
	is_gesturing = true

func play_nod() -> void:
	play_interactive_gesture(GestureType.NOD)

func play_welcoming_lean() -> void:
	play_interactive_gesture(GestureType.WELCOMING_LEAN)

func get_schedule_info() -> Dictionary:
	var phase_name = "Afternoon Stroll"
	match schedule_phase:
		SchedulePhase.MORNING_SHIFT: phase_name = "08:00-16:00 Hospital Shift"
		SchedulePhase.AFTERNOON_STROLL: phase_name = "16:00-18:30 Coastal Walk"
		SchedulePhase.EVENING_COMMUTE: phase_name = "18:30-20:00 Tram Commute"
		SchedulePhase.NIGHT_REST: phase_name = "20:00+ Home"

	var cur_pos = global_position if is_inside_tree() else position
	return {
		"npc_id": npc_id,
		"name": display_name,
		"role": role,
		"workplace": home_or_work_role,
		"activity": current_activity,
		"phase": phase_name,
		"familiarity": get_familiarity_name(),
		"location": cur_pos
	}

func on_interacted(interactor: Node3D, verb: int) -> Dictionary:
	return talk_to_player(interactor)

func talk_to_player(interactor: Node3D = null) -> Dictionary:
	if dialogue_lines.is_empty():
		return {"npc_id": npc_id, "name": display_name, "dialogue": "..."}

	var line_idx = talk_count % dialogue_lines.size()
	var spoken_line = dialogue_lines[line_idx]
	talk_count += 1

	# Update familiarity tier
	if talk_count >= 6:
		familiarity_tier = FamiliarityTier.FAMILIAR
	elif talk_count >= 3:
		familiarity_tier = FamiliarityTier.REGULAR
	elif talk_count >= 1:
		familiarity_tier = FamiliarityTier.ACQUAINTANCE

	# Check for player needs contextual observation
	var needs_comment: String = ""
	if interactor and "needs" in interactor and interactor.needs != null:
		var n = interactor.needs
		if n.is_exhausted():
			needs_comment = "(Noticing your exhaustion) You look pale and unsteady... please rest soon."
		elif n.is_hungry():
			needs_comment = "(Hearing your stomach rumble) Kasumi Mart down the road has hot bento and onigiri."
		elif n.is_thirsty():
			needs_comment = "(Noticing your chapped lips) There's cold water at the vending machine right there."

	# Turn to face interactor smoothly if provided
	if interactor:
		target_player = interactor
		var target_pos = interactor.global_position if interactor.is_inside_tree() else interactor.position
		var my_pos = global_position if is_inside_tree() else position
		var dir = (target_pos - my_pos).normalized()
		dir.y = 0.0
		if dir.length() > 0.01:
			rotation.y = atan2(dir.x, dir.z)

	# Trigger interactive gesture (nodding or welcoming lean)
	play_interactive_gesture()

	emit_signal("spoke_with_player", npc_id, spoken_line)

	return {
		"npc_id": npc_id,
		"name": display_name,
		"role": role,
		"dialogue": spoken_line,
		"needs_comment": needs_comment,
		"talk_count": talk_count,
		"familiarity_tier": int(familiarity_tier),
		"familiarity": get_familiarity_name()
	}



class_name PlayerTraversalController
extends Node

## 11.11 Genshin-Tier Player Traversal Controller
## Orchestrates Wall Climbing (Vertical Surface Latching, Climbing Kinematics, Ledge Mantle, Wall Jumps)
## and Surface Swimming (Water Immersion Clamping, Breaststroke & Sprint Paddle, Stamina Drain & Drown Recovery).

enum TraversalState {
	NORMAL,
	CLIMBING,
	SWIMMING
}

signal traversal_state_changed(old_state: int, new_state: int)
signal wall_latched(wall_normal: Vector3, contact_point: Vector3)
signal ledge_mantled()
signal water_entered(surface_y: float)
signal water_exited()
signal stamina_exhausted_fall()
signal drowned(respawn_pos: Vector3)

const ProceduralCinematicAudio = preload("res://scripts/audio/procedural_cinematic_audio.gd")

# Climbing Parameters (Genshin Benchmark)
const CLIMB_SPEED: float = 1.85
const CLIMB_SPRINT_SPEED: float = 3.2
const CLIMB_JUMP_IMPULSE: float = 5.2
const CLIMB_STAMINA_DRAIN_IDLE: float = 1.5
const CLIMB_STAMINA_DRAIN_MOVE: float = 10.0
const CLIMB_STAMINA_DRAIN_SPRINT: float = 24.0
const CLIMB_JUMP_STAMINA_COST: float = 20.0
const WALL_ALIGNMENT_SMOOTHING: float = 14.0

# Swimming Parameters (Genshin Benchmark)
const SWIM_SPEED: float = 2.4
const SWIM_SPRINT_SPEED: float = 4.8
const SWIM_STAMINA_DRAIN_IDLE: float = 1.0
const SWIM_STAMINA_DRAIN_MOVE: float = 4.5
const SWIM_STAMINA_DRAIN_SPRINT: float = 18.0
const WATER_IMMERSION_DEPTH: float = 0.42

var current_state: TraversalState = TraversalState.NORMAL
var wall_normal: Vector3 = Vector3.FORWARD
var wall_contact_point: Vector3 = Vector3.ZERO
var water_surface_y: float = 0.0
var last_dry_ground_pos: Vector3 = Vector3.ZERO

var audio_player: AudioStreamPlayer3D = null
var swim_stroke_timer: float = 0.0

func _ready() -> void:
	ensure_setup()

func ensure_setup() -> void:
	if not audio_player:
		audio_player = find_child("TraversalAudio", true, false) as AudioStreamPlayer3D
		if not audio_player:
			audio_player = AudioStreamPlayer3D.new()
			audio_player.name = "TraversalAudio"
			audio_player.unit_size = 5.0
			audio_player.max_distance = 20.0
			add_child(audio_player)

func is_climbing() -> bool:
	return current_state == TraversalState.CLIMBING

func is_swimming() -> bool:
	return current_state == TraversalState.SWIMMING

func get_state() -> TraversalState:
	return current_state

func play_audio(stream: AudioStream) -> void:
	if audio_player and is_inside_tree() and stream:
		audio_player.stream = stream
		audio_player.play()

# -------------------------------------------------------------
# CLIMBING LOGIC
# -------------------------------------------------------------

func can_start_climb(surface_normal: Vector3) -> bool:
	# Vertical wall test: normal.y must be between -0.35 and 0.35 (slope >= 70 degrees)
	return absf(surface_normal.y) <= 0.35 and surface_normal.length_squared() > 0.5

func start_climbing(surface_normal: Vector3, contact_point: Vector3) -> bool:
	if not can_start_climb(surface_normal):
		return false
	
	var old_state = current_state
	current_state = TraversalState.CLIMBING
	wall_normal = surface_normal.normalized()
	wall_contact_point = contact_point
	
	play_audio(ProceduralCinematicAudio.create_climb_grab_sfx())
	emit_signal("traversal_state_changed", old_state, current_state)
	emit_signal("wall_latched", wall_normal, wall_contact_point)
	return true

func stop_climbing() -> void:
	if current_state == TraversalState.CLIMBING:
		var old_state = current_state
		current_state = TraversalState.NORMAL
		emit_signal("traversal_state_changed", old_state, current_state)

func climb_jump(player_stamina: float) -> Dictionary:
	if current_state != TraversalState.CLIMBING:
		return {"success": false, "stamina_cost": 0.0, "impulse": Vector3.ZERO}
	
	if player_stamina < CLIMB_JUMP_STAMINA_COST:
		return {"success": false, "stamina_cost": 0.0, "impulse": Vector3.ZERO}
	
	# Wall hop upwards and slightly away from wall
	var jump_dir = (Vector3.UP * 0.85 + wall_normal * 0.25).normalized()
	var impulse = jump_dir * CLIMB_JUMP_IMPULSE
	
	play_audio(ProceduralCinematicAudio.create_climb_grab_sfx())
	return {
		"success": true,
		"stamina_cost": CLIMB_JUMP_STAMINA_COST,
		"impulse": impulse
	}

# -------------------------------------------------------------
# SWIMMING LOGIC
# -------------------------------------------------------------

func enter_water(surface_y: float, current_player_pos: Vector3 = Vector3.ZERO) -> void:
	if current_state == TraversalState.SWIMMING:
		return
	
	var old_state = current_state
	current_state = TraversalState.SWIMMING
	water_surface_y = surface_y
	if current_player_pos != Vector3.ZERO:
		last_dry_ground_pos = current_player_pos + Vector3(0, 0.5, 0)
	
	play_audio(ProceduralCinematicAudio.create_water_splash_sfx())
	emit_signal("traversal_state_changed", old_state, current_state)
	emit_signal("water_entered", water_surface_y)

func exit_water() -> void:
	if current_state == TraversalState.SWIMMING:
		var old_state = current_state
		current_state = TraversalState.NORMAL
		emit_signal("traversal_state_changed", old_state, current_state)
		emit_signal("water_exited")

func record_dry_ground(pos: Vector3) -> void:
	if current_state == TraversalState.NORMAL:
		last_dry_ground_pos = pos

# -------------------------------------------------------------
# MASTER TRAVERSAL UPDATE TICK
# -------------------------------------------------------------

func update_traversal_physics(
	delta: float,
	current_velocity: Vector3,
	input_vector: Vector2,
	camera_basis: Basis,
	player_pos: Vector3,
	is_sprint: bool,
	current_stamina: float
) -> Dictionary:
	var result = {
		"state": current_state,
		"velocity": current_velocity,
		"stamina_drain": 0.0,
		"snap_position_y": -999.0,
		"face_direction": Vector3.ZERO,
		"anim_hint": ""
	}

	match current_state:
		TraversalState.CLIMBING:
			# If stamina depleted, drop off wall
			if current_stamina <= 0.0:
				stop_climbing()
				emit_signal("stamina_exhausted_fall")
				result["state"] = TraversalState.NORMAL
				result["velocity"] = Vector3.DOWN * 2.0
				return result

			# Calculate wall tangent coordinate frame
			# Up vector along wall: Vector3.UP
			# Right vector along wall: cross(wall_normal, Vector3.UP)
			var wall_right = wall_normal.cross(Vector3.UP).normalized()
			var wall_up = Vector3.UP

			var move_input_active = input_vector.length_squared() > 0.04
			var active_speed = CLIMB_SPRINT_SPEED if is_sprint else CLIMB_SPEED
			
			var climb_vel = Vector3.ZERO
			if move_input_active:
				climb_vel += wall_right * input_vector.x * active_speed
				climb_vel += wall_up * (-input_vector.y) * active_speed # -y is forward in Godot input
				result["stamina_drain"] = (CLIMB_STAMINA_DRAIN_SPRINT if is_sprint else CLIMB_STAMINA_DRAIN_MOVE) * delta
				result["anim_hint"] = "climb_move"
			else:
				result["stamina_drain"] = CLIMB_STAMINA_DRAIN_IDLE * delta
				result["anim_hint"] = "climb_idle"

			result["velocity"] = climb_vel
			result["face_direction"] = -wall_normal

		TraversalState.SWIMMING:
			# If stamina reaches zero in water, trigger drowning recovery
			if current_stamina <= 0.0:
				exit_water()
				emit_signal("drowned", last_dry_ground_pos)
				result["state"] = TraversalState.NORMAL
				result["velocity"] = Vector3.ZERO
				result["snap_position_y"] = last_dry_ground_pos.y
				return result

			# Keep player floating at water level
			var target_float_y = water_surface_y - WATER_IMMERSION_DEPTH
			result["snap_position_y"] = target_float_y

			# Horizontal swimming motion relative to camera
			var cam_fwd = -camera_basis.z
			cam_fwd.y = 0.0
			cam_fwd = cam_fwd.normalized()
			var cam_right = camera_basis.x
			cam_right.y = 0.0
			cam_right = cam_right.normalized()

			var swim_dir = (cam_right * input_vector.x + cam_fwd * (-input_vector.y))
			var moving = swim_dir.length_squared() > 0.04
			var speed = SWIM_SPRINT_SPEED if is_sprint else SWIM_SPEED

			var swim_vel = Vector3.ZERO
			if moving:
				swim_dir = swim_dir.normalized()
				swim_vel = swim_dir * speed
				result["face_direction"] = swim_dir
				result["stamina_drain"] = (SWIM_STAMINA_DRAIN_SPRINT if is_sprint else SWIM_STAMINA_DRAIN_MOVE) * delta
				result["anim_hint"] = "swim_stroke"

				# Rhythmic stroke audio feedback
				swim_stroke_timer += delta
				if swim_stroke_timer >= (0.42 if is_sprint else 0.75):
					swim_stroke_timer = 0.0
					play_audio(ProceduralCinematicAudio.create_swim_stroke_sfx())
			else:
				result["stamina_drain"] = SWIM_STAMINA_DRAIN_IDLE * delta
				result["anim_hint"] = "swim_idle"

			swim_vel.y = 0.0
			result["velocity"] = swim_vel

		TraversalState.NORMAL:
			result["anim_hint"] = "locomotion"

	return result

func serialize() -> Dictionary:
	return {
		"state": current_state,
		"wall_normal": [wall_normal.x, wall_normal.y, wall_normal.z],
		"water_surface_y": water_surface_y,
		"last_dry_ground": [last_dry_ground_pos.x, last_dry_ground_pos.y, last_dry_ground_pos.z]
	}

func deserialize(data: Dictionary) -> void:
	if data.has("state"):
		current_state = int(data["state"])
	if data.has("water_surface_y"):
		water_surface_y = float(data["water_surface_y"])
	if data.has("last_dry_ground") and data["last_dry_ground"] is Array:
		var arr = data["last_dry_ground"]
		if arr.size() == 3:
			last_dry_ground_pos = Vector3(arr[0], arr[1], arr[2])

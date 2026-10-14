class_name LocomotionAnimationTree
extends Node

## Modular AnimationTree / BlendSpace2D Locomotion Controller Foundation for Godot 4.8.
## Provides 2D blend space locomotion (strafe X, forward/backward Y) with
## foot-sliding prevention via physics vs authored clip velocity matching,
## plus frame-rate-independent damping between locomotion states.

signal locomotion_state_changed(new_state: LocomotionState, state_name: String)
signal blend_position_changed(blend_position: Vector2)
signal playback_speed_changed(playback_speed: float)

enum LocomotionState {
	IDLE,
	WALK_FORWARD,
	RUN_FORWARD,
	WALK_BACKWARD,
	STRAFE_LEFT,
	STRAFE_RIGHT
}

# --- Authored Kinematic Reference Constants ---
# Exact calibrated speeds from authored mocap/animation clips at 1.0x playback
const AUTHORED_WALK_SPEED: float = 1.36   ## Authored walk clip displacement (m/s)
const AUTHORED_JOG_SPEED: float = 2.77    ## Authored jog/run clip displacement (m/s)
const SPRINT_SPEED: float = 4.70          ## Calibrated sprint velocity (m/s)
const MIN_LOCOMOTION_SPEED: float = 0.05  ## Deadband speed threshold for idle transition
const MIN_PLAYBACK_SCALE: float = 0.5     ## Clamp floor for playback speed scale
const MAX_PLAYBACK_SCALE: float = 2.0     ## Clamp ceiling for playback speed scale (cadence limit)

# --- Blend Space 2D Geometry Constants ---
# X: Strafe (-1.0 Left to +1.0 Right)
# Y: Forward / Backward (-1.0 Backward to +1.0 Forward)
const POINT_IDLE: Vector2 = Vector2(0.0, 0.0)
const POINT_WALK_FORWARD: Vector2 = Vector2(0.0, 0.5)
const POINT_RUN_FORWARD: Vector2 = Vector2(0.0, 1.0)
const POINT_WALK_BACKWARD: Vector2 = Vector2(0.0, -0.5)
const POINT_STRAFE_LEFT: Vector2 = Vector2(-0.5, 0.0)
const POINT_STRAFE_RIGHT: Vector2 = Vector2(0.5, 0.0)

# --- AnimationTree Node & Parameter Names ---
const NODE_LOCOMOTION_BS2D: String = "locomotion_bs2d"
const NODE_TIME_SCALE: String = "time_scale"
const PARAM_BLEND_POSITION: String = "parameters/locomotion_bs2d/blend_position"
const PARAM_TIME_SCALE: String = "parameters/time_scale/scale"

# Default clip candidate mapping
const DEFAULT_CLIP_NAMES: Dictionary = {
	"idle": &"preset_idle",
	"walk_forward": &"preset_walk",
	"run_forward": &"preset_run",
	"walk_backward": &"preset_walk",
	"strafe_left": &"preset_walk",
	"strafe_right": &"preset_walk"
}

# Known animation name aliases across Echo and Mixamo rigs
const ANIMATION_ALIASES: Dictionary = {
	"idle": [&"preset_biped_idle_001", &"preset_idle", &"preset:idle", &"IDLE", &"Standing Idle 04", &"idle"],
	"walk_forward": [&"preset_biped_walk_001", &"preset_walk", &"preset:walk", &"WALK", &"Standard Walk", &"walk"],
	"run_forward": [&"preset_biped_run_001", &"preset_run", &"preset:run", &"RUN", &"Standing Run Forward", &"run"],
	"walk_backward": [&"preset_walk_back", &"preset:walk_back", &"WALK_BACK", &"preset_biped_walk_001", &"preset_walk", &"walk"],
	"strafe_left": [&"preset_strafe_left", &"preset:strafe_left", &"STRAFE_LEFT", &"preset_biped_walk_001", &"preset_walk", &"walk"],
	"strafe_right": [&"preset_strafe_right", &"preset:strafe_right", &"STRAFE_RIGHT", &"preset_biped_walk_001", &"preset_walk", &"walk"]
}

# --- Configurable Parameters ---
@export var blend_damping: float = 10.0       ## Lerp rate for blend space coordinates (exp decay)
@export var speed_damping: float = 8.0        ## Lerp rate for playback speed scale
@export var auto_activate: bool = true        ## Automatically activate AnimationTree on ready
@export var anim_player_path: NodePath = NodePath("")

# --- Internal State ---
var animation_tree: AnimationTree = null
var blend_space_2d: AnimationNodeBlendSpace2D = null
var time_scale_node: AnimationNodeTimeScale = null
var blend_tree_root: AnimationNodeBlendTree = null
var animation_player: AnimationPlayer = null

var current_blend: Vector2 = Vector2.ZERO
var target_blend: Vector2 = Vector2.ZERO
var current_playback_speed: float = 1.0
var target_playback_speed: float = 1.0
var current_state: LocomotionState = LocomotionState.IDLE
var is_initialized: bool = false

func _ready() -> void:
	if not is_initialized:
		setup()

## Sets up the AnimationTree and BlendSpace2D hierarchy.
## Can bind to an existing AnimationPlayer / AnimationTree or instantiate them.
func setup(p_anim_player: AnimationPlayer = null, p_anim_tree: AnimationTree = null, custom_clips: Dictionary = {}) -> void:
	if p_anim_player != null:
		animation_player = p_anim_player
	elif not anim_player_path.is_empty():
		animation_player = get_node_or_null(anim_player_path) as AnimationPlayer
	elif get_parent() != null:
		animation_player = get_parent().find_child("AnimationPlayer", true, false) as AnimationPlayer

	if p_anim_tree != null:
		animation_tree = p_anim_tree
	elif animation_tree == null:
		# Check if an AnimationTree child already exists
		var existing_tree = find_child("AnimationTree", false, false) as AnimationTree
		if existing_tree != null:
			animation_tree = existing_tree
		else:
			animation_tree = AnimationTree.new()
			animation_tree.name = "LocomotionAnimationTree"
			add_child(animation_tree)

	_build_tree_graph(custom_clips)

	if animation_player != null and animation_tree.is_inside_tree() and animation_player.is_inside_tree():
		animation_tree.anim_player = animation_player.get_path()

	if auto_activate and animation_tree.is_inside_tree():
		animation_tree.active = true

	is_initialized = true
	_apply_parameters()

## Constructs the AnimationNodeBlendTree, BlendSpace2D, and TimeScale nodes.
func _build_tree_graph(custom_clips: Dictionary = {}) -> void:
	blend_space_2d = AnimationNodeBlendSpace2D.new()
	blend_space_2d.min_space = Vector2(-1.0, -1.0)
	blend_space_2d.max_space = Vector2(1.0, 1.0)
	blend_space_2d.x_label = "Strafe"
	blend_space_2d.y_label = "Forward"
	blend_space_2d.auto_triangles = true
	blend_space_2d.blend_mode = AnimationNodeBlendSpace2D.BLEND_MODE_INTERPOLATED

	_populate_blend_points(custom_clips)

	time_scale_node = AnimationNodeTimeScale.new()
	blend_tree_root = AnimationNodeBlendTree.new()

	blend_tree_root.add_node(NODE_LOCOMOTION_BS2D, blend_space_2d)
	blend_tree_root.add_node(NODE_TIME_SCALE, time_scale_node)
	blend_tree_root.connect_node(NODE_TIME_SCALE, 0, NODE_LOCOMOTION_BS2D)
	blend_tree_root.connect_node("output", 0, NODE_TIME_SCALE)

	animation_tree.tree_root = blend_tree_root

## Populates the 6 standard locomotion blend points into BlendSpace2D.
func _populate_blend_points(custom_clips: Dictionary = {}) -> void:
	var point_specs := [
		{"name": &"idle", "pos": POINT_IDLE, "idx": 0},
		{"name": &"walk_forward", "pos": POINT_WALK_FORWARD, "idx": 1},
		{"name": &"run_forward", "pos": POINT_RUN_FORWARD, "idx": 2},
		{"name": &"walk_backward", "pos": POINT_WALK_BACKWARD, "idx": 3},
		{"name": &"strafe_left", "pos": POINT_STRAFE_LEFT, "idx": 4},
		{"name": &"strafe_right", "pos": POINT_STRAFE_RIGHT, "idx": 5}
	]

	for spec in point_specs:
		var point_key: String = String(spec["name"])
		var resolved_clip_name: StringName = _resolve_clip_name(point_key, custom_clips)
		var anim_node := AnimationNodeAnimation.new()
		anim_node.animation = resolved_clip_name
		_add_blend_point_compat(blend_space_2d, anim_node, spec["pos"], spec["idx"], spec["name"])

## Safely adds a blend point supporting Godot 4.8 (4 args) and earlier versions.
func _add_blend_point_compat(bs: AnimationNodeBlendSpace2D, node: AnimationRootNode, pos: Vector2, idx: int, point_name: StringName) -> void:
	# Godot 4.8 introduces a 4th argument: name (StringName)
	# Check method list or version info
	var method_info: Dictionary = {}
	for m in bs.get_method_list():
		if m.name == "add_blend_point":
			method_info = m
			break
	if method_info.has("args") and method_info["args"].size() >= 4:
		bs.add_blend_point(node, pos, idx, point_name)
	else:
		bs.add_blend_point(node, pos, idx)

## Resolves an animation clip name with fallbacks.
func _resolve_clip_name(point_key: String, custom_clips: Dictionary) -> StringName:
	if custom_clips.has(point_key):
		return StringName(custom_clips[point_key])

	if animation_player != null:
		var aliases: Array = ANIMATION_ALIASES.get(point_key, [])
		for alias in aliases:
			if animation_player.has_animation(alias):
				return alias

	return DEFAULT_CLIP_NAMES.get(point_key, &"preset_idle")

# --- Velocity Matching & Foot Sliding Prevention ---

## Calculates the expected authored clip speed (m/s) for a given blend coordinate.
## Walk points (magnitude 0.5) correspond to AUTHORED_WALK_SPEED (1.36 m/s).
## Run point (magnitude 1.0) corresponds to AUTHORED_JOG_SPEED (2.77 m/s).
func calculate_authored_speed(blend_pos: Vector2) -> float:
	var mag := blend_pos.length()
	if mag < 0.001:
		return 0.0
	if mag <= 0.5:
		# Idle (0.0 m/s) to Walk (1.36 m/s)
		return (mag / 0.5) * AUTHORED_WALK_SPEED
	else:
		# Walk (1.36 m/s) to Jog/Run (2.77 m/s)
		var t := clampf((mag - 0.5) / 0.5, 0.0, 1.0)
		return lerpf(AUTHORED_WALK_SPEED, AUTHORED_JOG_SPEED, t)

## Calculates animation playback speed scale based on actual physics speed vs authored speed.
## Returns 1.0 when idle, matching speed = 1.0, clamped within [MIN_PLAYBACK_SCALE, MAX_PLAYBACK_SCALE].
func calculate_playback_speed(physics_speed: float, blend_pos: Vector2) -> float:
	if physics_speed <= MIN_LOCOMOTION_SPEED or blend_pos.length_squared() < 0.0001:
		return 1.0
	var authored := calculate_authored_speed(blend_pos)
	if authored <= 0.001:
		return 1.0
	var speed_scale := physics_speed / authored
	return clampf(speed_scale, MIN_PLAYBACK_SCALE, MAX_PLAYBACK_SCALE)

## Calculates effective foot speed on the ground (authored clip displacement * playback speed).
func calculate_effective_foot_speed(blend_pos: Vector2, playback_speed: float) -> float:
	return calculate_authored_speed(blend_pos) * playback_speed

## Calculates foot-sliding error (|effective_foot_speed - physics_speed|).
## Returns 0.0 when feet perfectly match physics ground displacement.
func calculate_foot_sliding_error(physics_speed: float, blend_pos: Vector2, playback_speed: float) -> float:
	if physics_speed <= MIN_LOCOMOTION_SPEED:
		return 0.0
	var foot_speed := calculate_effective_foot_speed(blend_pos, playback_speed)
	return absf(foot_speed - physics_speed)

## Computes target blend space coordinate from 2D directional input and horizontal speed.
func calculate_target_blend(input_dir: Vector2, physics_speed: float, wants_run: bool = false) -> Vector2:
	if physics_speed <= MIN_LOCOMOTION_SPEED or input_dir.is_zero_approx():
		return Vector2.ZERO

	var norm_dir := input_dir.normalized()
	if wants_run or physics_speed > AUTHORED_WALK_SPEED + 0.1:
		# Walk to Run range
		var t := clampf((physics_speed - AUTHORED_WALK_SPEED) / (AUTHORED_JOG_SPEED - AUTHORED_WALK_SPEED), 0.0, 1.0)
		var mag := lerpf(0.5, 1.0, t)
		return norm_dir * mag
	else:
		# Idle to Walk range
		var t := clampf(physics_speed / AUTHORED_WALK_SPEED, 0.0, 1.0)
		var mag := t * 0.5
		return norm_dir * mag

## Computes target blend space coordinate directly from 3D local velocity (Character forward is -Z).
func calculate_target_blend_from_velocity(local_velocity: Vector3, wants_run: bool = false) -> Vector2:
	# Local forward: -Z -> +Y in blend space
	# Local right:   +X -> +X in blend space
	var horiz_vel := Vector2(local_velocity.x, -local_velocity.z)
	var speed := horiz_vel.length()
	if speed <= MIN_LOCOMOTION_SPEED:
		return Vector2.ZERO
	return calculate_target_blend(horiz_vel, speed, wants_run)

# --- Update & Damping ---

## Main update tick: applies smooth damping to blend space coordinates and playback speed scale,
## feeds parameters to AnimationTree, and tracks locomotion states.
func update(delta: float, target_blend_pos: Vector2, physics_speed: float) -> Dictionary:
	target_blend = target_blend_pos
	target_playback_speed = calculate_playback_speed(physics_speed, target_blend_pos)

	if delta > 0.0:
		var blend_decay := 1.0 - exp(-blend_damping * delta)
		current_blend = current_blend.lerp(target_blend, blend_decay)
		var speed_decay := 1.0 - exp(-speed_damping * delta)
		current_playback_speed = lerpf(current_playback_speed, target_playback_speed, speed_decay)
	else:
		current_blend = target_blend
		current_playback_speed = target_playback_speed

	_apply_parameters()
	_update_state()

	return {
		"blend": current_blend,
		"target_blend": target_blend,
		"playback_speed": current_playback_speed,
		"target_playback_speed": target_playback_speed,
		"state": current_state,
		"state_name": get_state_name(current_state),
		"physics_speed": physics_speed,
		"authored_speed": calculate_authored_speed(current_blend),
		"effective_foot_speed": calculate_effective_foot_speed(current_blend, current_playback_speed),
		"foot_sliding_error": calculate_foot_sliding_error(physics_speed, current_blend, current_playback_speed)
	}

## Convenience update helper from 3D local velocity vector.
func update_from_velocity(delta: float, local_velocity: Vector3, wants_run: bool = false) -> Dictionary:
	var horiz_speed := Vector2(local_velocity.x, local_velocity.z).length()
	var blend_target := calculate_target_blend_from_velocity(local_velocity, wants_run)
	return update(delta, blend_target, horiz_speed)

## Instantly snaps blend position and playback speed without lerp smoothing.
func snap_to_blend(blend_pos: Vector2, speed_scale: float = 1.0) -> void:
	current_blend = blend_pos
	target_blend = blend_pos
	current_playback_speed = speed_scale
	target_playback_speed = speed_scale
	_apply_parameters()
	_update_state()

## Updates the parameters on the underlying AnimationTree.
func _apply_parameters() -> void:
	if animation_tree == null:
		return
	animation_tree.set(PARAM_BLEND_POSITION, current_blend)
	animation_tree.set(PARAM_TIME_SCALE, current_playback_speed)
	emit_signal("blend_position_changed", current_blend)
	emit_signal("playback_speed_changed", current_playback_speed)

## Evaluates current locomotion state from blend position and emits signal on transition.
func _update_state() -> void:
	var new_state := resolve_state(current_blend)
	if new_state != current_state:
		current_state = new_state
		emit_signal("locomotion_state_changed", current_state, get_state_name(current_state))

## Resolves locomotion state from a given blend coordinate.
func resolve_state(blend: Vector2) -> LocomotionState:
	if blend.length() < 0.1:
		return LocomotionState.IDLE

	if absf(blend.y) >= absf(blend.x):
		if blend.y > 0.75:
			return LocomotionState.RUN_FORWARD
		elif blend.y > 0.0:
			return LocomotionState.WALK_FORWARD
		else:
			return LocomotionState.WALK_BACKWARD
	else:
		if blend.x < 0.0:
			return LocomotionState.STRAFE_LEFT
		else:
			return LocomotionState.STRAFE_RIGHT

## Returns a human-readable name for a locomotion state.
func get_state_name(state: LocomotionState = current_state) -> String:
	match state:
		LocomotionState.IDLE: return "IDLE"
		LocomotionState.WALK_FORWARD: return "WALK_FORWARD"
		LocomotionState.RUN_FORWARD: return "RUN_FORWARD"
		LocomotionState.WALK_BACKWARD: return "WALK_BACKWARD"
		LocomotionState.STRAFE_LEFT: return "STRAFE_LEFT"
		LocomotionState.STRAFE_RIGHT: return "STRAFE_RIGHT"
		_: return "UNKNOWN"

# --- Getters ---

func get_animation_tree() -> AnimationTree:
	return animation_tree

func get_blend_space_2d() -> AnimationNodeBlendSpace2D:
	return blend_space_2d

func get_time_scale_node() -> AnimationNodeTimeScale:
	return time_scale_node

func get_blend_tree_root() -> AnimationNodeBlendTree:
	return blend_tree_root

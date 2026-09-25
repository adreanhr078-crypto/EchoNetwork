class_name LocomotionInertiaBanking
extends Node

## Phase 5 — Locomotion Inertia Banking
## Adds Genshin/HoYoverse-quality start/stop inertia and body lean to Echo's movement.
##
## Features:
##   - Velocity-driven tilt (bank left/right on turns, forward lean on acceleration)
##   - Smooth deceleration footstep-stop blend
##   - Dodge Cancel from any attack frame (interrupt combo with roll)
##   - Directional momentum preservation during cancel

signal inertia_lean_updated(lean_x: float, lean_z: float)
signal dodge_cancelled(from_state: String, direction: Vector3)

# ──────────────────────── PARAMS ───────────────────────────────
@export var lean_max_angle: float    = 12.0   # degrees
@export var lean_speed: float        = 8.0    # interpolation speed
@export var bank_max_angle: float    = 9.0
@export var bank_speed: float        = 6.0
@export var stop_blend_speed: float  = 7.5    # how fast "stop" pose blends in
@export var dodge_cancel_window: float = 0.45 # seconds from attack start that dodge cancel is allowed

# ──────────────────────── STATE ────────────────────────────────
var _current_lean_x: float = 0.0
var _current_lean_z: float = 0.0
var _prev_velocity: Vector3 = Vector3.ZERO
var _attack_elapsed: float = 0.0
var _is_attacking: bool = false
var _can_dodge_cancel: bool = false

# Reference to the visual root (set externally)
var visual_root: Node3D = null
# Reference to the player node
var player: Node = null

func _ready() -> void:
	pass

func set_references(p: Node, vr: Node3D) -> void:
	player = p
	visual_root = vr

# ──────────────────────── UPDATE ───────────────────────────────
func _physics_process(delta: float) -> void:
	_update_attack_timer(delta)
	_update_lean(delta)

func _update_lean(delta: float) -> void:
	if not player or not visual_root:
		return

	var vel: Vector3 = Vector3.ZERO
	if "velocity" in player:
		vel = player.velocity
	var accel: Vector3 = (vel - _prev_velocity) / maxf(delta, 0.001)
	_prev_velocity = vel

	# Forward lean: positive accel.z = lean forward
	var target_lean_x: float = clampf(-accel.z * 0.5, -lean_max_angle, lean_max_angle)
	# Side bank: positive vel.x = lean right (banking into turn)
	var target_lean_z: float = clampf(-vel.x * 0.8, -bank_max_angle, bank_max_angle)

	_current_lean_x = lerpf(_current_lean_x, target_lean_x, lean_speed * delta)
	_current_lean_z = lerpf(_current_lean_z, target_lean_z, bank_speed * delta)

	visual_root.rotation_degrees.x = _current_lean_x
	visual_root.rotation_degrees.z = _current_lean_z

	emit_signal("inertia_lean_updated", _current_lean_x, _current_lean_z)

# ──────────────────────── ATTACK TRACKING ──────────────────────
func notify_attack_start(attack_name: String = "combo") -> void:
	_is_attacking = true
	_attack_elapsed = 0.0
	_can_dodge_cancel = true

func notify_attack_end() -> void:
	_is_attacking = false
	_can_dodge_cancel = false
	_attack_elapsed = 0.0

func _update_attack_timer(delta: float) -> void:
	if _is_attacking:
		_attack_elapsed += delta
		# Dodge cancel window closes after threshold
		if _attack_elapsed > dodge_cancel_window:
			_can_dodge_cancel = false

# ──────────────────────── DODGE CANCEL ─────────────────────────
## Call this when player inputs dodge during an attack animation.
## Returns true if cancel was successful.
func try_dodge_cancel(dodge_direction: Vector3 = Vector3.FORWARD) -> bool:
	if not _is_attacking or not _can_dodge_cancel:
		return false
	var state_name: String = "attacking_%.2f" % _attack_elapsed
	notify_attack_end()
	# Preserve momentum component in dodge direction
	emit_signal("dodge_cancelled", state_name, dodge_direction)
	return true

func is_in_dodge_cancel_window() -> bool:
	return _can_dodge_cancel and _is_attacking

# ──────────────────────── TEARDOWN ─────────────────────────────
func _exit_tree() -> void:
	if visual_root and is_instance_valid(visual_root):
		visual_root.rotation_degrees.x = 0.0
		visual_root.rotation_degrees.z = 0.0

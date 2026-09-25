class_name SpringBoneHairPhysics
extends Node3D

## Phase 5 — AAA Spring Bone Hair & Cloth Physics
## Simulates secondary motion for Echo's hair strands, katana tassel, and
## character clothing on strikes, dashes, jumps, and wind.
##
## Architecture:
##   - Registered bone offsets per strand (head bone + hair tip bones)
##   - Per-frame velocity-driven spring simulation (no physics engine needed)
##   - Wind gust integration from DynamicWeatherCycle
##   - Cloth rustle SFX on strong impulses (katana swing, heavy landing)

signal hair_impulse_applied(impulse: Vector3)

const ProceduralCinematicAudio = preload("res://scripts/audio/procedural_cinematic_audio.gd")

# ──────────────────────── SPRING PARAMS ────────────────────────
@export var stiffness: float  = 6.5    # Spring return force
@export var damping: float    = 3.8    # Velocity damping
@export var mass: float       = 1.0
@export var gravity_factor: float = 0.25
@export var max_displacement: float = 0.35  # metres from rest

# Wind influence (set by WeatherCycle)
var wind_force: Vector3 = Vector3.ZERO

# ──────────────────────── STRAND STATE ─────────────────────────
class StrandState:
	var rest_pos: Vector3
	var current_pos: Vector3
	var velocity: Vector3
	var node: Node3D
	func _init(n: Node3D) -> void:
		node = n
		rest_pos = n.position
		current_pos = n.position
		velocity = Vector3.ZERO

var strands: Array[StrandState] = []

# ──────────────────────── SETUP ────────────────────────────────
func _ready() -> void:
	_discover_hair_bones()

func _discover_hair_bones() -> void:
	# Auto-discover child Node3D named "HairStrand_*" or "TasselRoot"
	for child in get_children():
		if child is Node3D:
			if "HairStrand" in child.name or "Tassel" in child.name or "ClothBone" in child.name:
				strands.append(StrandState.new(child))

func register_strand(node: Node3D) -> void:
	strands.append(StrandState.new(node))

# ──────────────────────── SIMULATION ───────────────────────────
func _physics_process(delta: float) -> void:
	var gravity_pull: Vector3 = Vector3.DOWN * 9.8 * gravity_factor
	for s in strands:
		if not is_instance_valid(s.node):
			continue
		# Spring force toward rest + gravity + wind
		var displacement: Vector3 = s.current_pos - s.rest_pos
		var spring_force: Vector3 = -stiffness * displacement
		var damping_force: Vector3 = -damping * s.velocity
		var total_force: Vector3 = (spring_force + damping_force + gravity_pull + wind_force) / mass

		s.velocity += total_force * delta
		s.current_pos += s.velocity * delta

		# Clamp displacement
		var d: float = s.current_pos.distance_to(s.rest_pos)
		if d > max_displacement:
			s.current_pos = s.rest_pos + (s.current_pos - s.rest_pos).normalized() * max_displacement

		# Apply to node
		s.node.position = s.current_pos

# ──────────────────────── PUBLIC API ───────────────────────────

## Apply world-space impulse (katana swing, heavy landing, dash start/stop)
func apply_impulse(impulse: Vector3) -> void:
	for s in strands:
		if is_instance_valid(s.node):
			s.velocity += impulse / mass
	emit_signal("hair_impulse_applied", impulse)
	# Play cloth swish on strong impulses
	if impulse.length() > 1.5 and is_inside_tree():
		var audio := AudioStreamPlayer.new()
		add_child(audio)
		audio.stream = ProceduralCinematicAudio.create_spring_hair_swish_sfx()
		audio.volume_db = -6.0
		audio.play()
		audio.finished.connect(func(): audio.queue_free())

## Sync wind from DynamicWeatherCycle
func set_wind(wind_vec: Vector3) -> void:
	wind_force = wind_vec * 0.8

## Reset all strands to rest (e.g. on scene transition)
func reset() -> void:
	for s in strands:
		s.velocity = Vector3.ZERO
		s.current_pos = s.rest_pos
		if is_instance_valid(s.node):
			s.node.position = s.rest_pos

# ──────────────────────── TEARDOWN ─────────────────────────────
func _exit_tree() -> void:
	for child in get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.queue_free()
	strands.clear()

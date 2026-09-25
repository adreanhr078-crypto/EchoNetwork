class_name VehicleRigidbodyController
extends VehicleBody3D

## AAA GTA-Style Rigidbody Vehicle Controller — Phase 4
## Converts kinematic vehicle movement to true Godot VehicleBody3D with
## VehicleWheel3D suspension, drift physics, and engine audio synthesis.
##
## Covers: Bicycle, 50cc Scooter, Kei-Car (Suzuki Alto style), Skateboard
## Drop-in replacement for RideableVehicle's CharacterBody3D movement.

signal vehicle_mounted(driver: Node)
signal vehicle_dismounted(driver: Node)
signal drift_started()
signal drift_ended()
signal horn_honked()

const ProceduralCinematicAudio = preload("res://scripts/audio/procedural_cinematic_audio.gd")

# ─────────────────────────── EXPORT PARAMS ─────────────────────
@export_enum("BICYCLE", "SCOOTER", "KEI_CAR", "SKATEBOARD") var vehicle_type: String = "KEI_CAR":
	set(v):
		vehicle_type = v
		mass = _get_vehicle_mass()
@export var engine_force_max: float  = 2800.0   # Newtons forward
@export var brake_force_max: float   = 3500.0
@export var steer_max_angle: float   = 28.0     # degrees
@export var steer_speed: float       = 3.5      # deg/s interpolation
@export var drift_friction: float    = 0.45     # 0=ice, 1=grip
@export var normal_friction: float   = 0.90
@export var top_speed_kmh: float     = 80.0

# ─────────────────────────── RUNTIME STATE ─────────────────────
var is_mounted: bool = false
var driver: Node = null
var current_steer: float = 0.0
var is_drifting: bool = false
var engine_audio: AudioStreamPlayer = null
var speed_kmh: float = 0.0

# Wheel references (set up in _ready)
var wheel_fl: VehicleWheel3D = null
var wheel_fr: VehicleWheel3D = null
var wheel_rl: VehicleWheel3D = null
var wheel_rr: VehicleWheel3D = null

# Body mesh
var body_mesh: MeshInstance3D = null

# ───────────────────────────────────────────────────────────────
func _init() -> void:
	mass = _get_vehicle_mass()

func _enter_tree() -> void:
	if wheel_fl == null:
		_build_vehicle_chassis()
		_create_wheels()
		_setup_engine_audio()

func _ready() -> void:
	if wheel_fl == null:
		_build_vehicle_chassis()
		_create_wheels()
		_setup_engine_audio()
	mass = _get_vehicle_mass()
	linear_damp = 0.3
	angular_damp = 5.0

func _get_vehicle_mass() -> float:
	match vehicle_type:
		"BICYCLE":   return  18.0
		"SCOOTER":   return  95.0
		"KEI_CAR":   return 680.0
		_:           return  4.5  # skateboard

# ─────────────────────────── CHASSIS MESH ──────────────────────
func _build_vehicle_chassis() -> void:
	if find_child("VehicleBodyMesh", true, false):
		return
	body_mesh = MeshInstance3D.new()
	body_mesh.name = "VehicleBodyMesh"
	var box := BoxMesh.new()
	match vehicle_type:
		"KEI_CAR":
			box.size = Vector3(1.55, 0.7, 3.4)
		"SCOOTER":
			box.size = Vector3(0.5, 0.65, 1.6)
		"BICYCLE":
			box.size = Vector3(0.25, 0.55, 1.55)
		_:
			box.size = Vector3(0.2, 0.06, 0.75)
	body_mesh.mesh = box
	body_mesh.position = Vector3(0, 0.38, 0)
	var mat := StandardMaterial3D.new()
	match vehicle_type:
		"KEI_CAR":  mat.albedo_color = Color(0.85, 0.88, 0.9, 1.0)  # Pearl white
		"SCOOTER":  mat.albedo_color = Color(0.1, 0.1, 0.15, 1.0)   # Obsidian
		"BICYCLE":  mat.albedo_color = Color(0.12, 0.12, 0.18, 1.0)
		_:          mat.albedo_color = Color(0.08, 0.08, 0.1, 1.0)
	mat.metallic = 0.6
	mat.roughness = 0.4
	body_mesh.material_override = mat
	add_child(body_mesh)

# ─────────────────────────── WHEEL SETUP ───────────────────────
func _create_wheels() -> void:
	if vehicle_type == "SKATEBOARD":
		return  # Skateboard uses simplified single-axle

	var configs: Array[Dictionary] = _get_wheel_configs()
	var wheel_refs: Array = [null, null, null, null]

	for i in range(configs.size()):
		var cfg: Dictionary = configs[i]
		var wheel := VehicleWheel3D.new()
		wheel.name = cfg["name"]
		wheel.position = cfg["pos"]
		wheel.use_as_steering = cfg.get("steer", false)
		wheel.use_as_traction = cfg.get("traction", false)

		wheel.wheel_radius         = cfg.get("radius", 0.33)
		wheel.wheel_friction_slip  = normal_friction
		wheel.suspension_travel    = cfg.get("travel", 0.2)
		wheel.suspension_stiffness = cfg.get("stiffness", 22.0)
		wheel.damping_compression  = 0.35
		wheel.damping_relaxation   = 0.25

		# Simple wheel mesh
		var wm := MeshInstance3D.new()
		wm.name = "WheelMesh"
		var cyl := CylinderMesh.new()
		cyl.top_radius    = wheel.wheel_radius
		cyl.bottom_radius = wheel.wheel_radius
		cyl.height = 0.2
		wm.mesh = cyl
		var wmat := StandardMaterial3D.new()
		wmat.albedo_color = Color(0.06, 0.06, 0.06)
		wmat.roughness = 0.9
		wm.material_override = wmat
		wm.rotation_degrees = Vector3(0, 0, 90)
		wheel.add_child(wm)

		add_child(wheel)
		wheel_refs[i] = wheel

	wheel_fl = wheel_refs[0]
	wheel_fr = wheel_refs[1]
	wheel_rl = wheel_refs[2]
	wheel_rr = wheel_refs[3]

func _get_wheel_configs() -> Array[Dictionary]:
	match vehicle_type:
		"KEI_CAR":
			return [
				{"name":"WheelFL","pos":Vector3(-0.72,0.0, 1.3),"steer":true, "traction":false,"radius":0.33,"stiffness":22.0,"travel":0.22},
				{"name":"WheelFR","pos":Vector3( 0.72,0.0, 1.3),"steer":true, "traction":false,"radius":0.33,"stiffness":22.0,"travel":0.22},
				{"name":"WheelRL","pos":Vector3(-0.72,0.0,-1.3),"steer":false,"traction":true, "radius":0.33,"stiffness":24.0,"travel":0.20},
				{"name":"WheelRR","pos":Vector3( 0.72,0.0,-1.3),"steer":false,"traction":true, "radius":0.33,"stiffness":24.0,"travel":0.20},
			]
		"SCOOTER":
			return [
				{"name":"WheelF","pos":Vector3(0, 0.0, 0.75),"steer":true, "traction":false,"radius":0.24,"stiffness":18.0,"travel":0.15},
				{"name":"WheelR","pos":Vector3(0, 0.0,-0.75),"steer":false,"traction":true, "radius":0.24,"stiffness":20.0,"travel":0.14},
				{"name":"WheelSL","pos":Vector3(-0.05,0.0,0.0),"steer":false,"traction":false,"radius":0.04,"stiffness":1.0,"travel":0.01},
				{"name":"WheelSR","pos":Vector3( 0.05,0.0,0.0),"steer":false,"traction":false,"radius":0.04,"stiffness":1.0,"travel":0.01},
			]
		_:  # BICYCLE
			return [
				{"name":"WheelF","pos":Vector3(0, 0.0, 0.70),"steer":true, "traction":false,"radius":0.28,"stiffness":14.0,"travel":0.10},
				{"name":"WheelR","pos":Vector3(0, 0.0,-0.70),"steer":false,"traction":true, "radius":0.28,"stiffness":16.0,"travel":0.10},
				{"name":"WheelSL","pos":Vector3(-0.02,0.0,0.0),"steer":false,"traction":false,"radius":0.02,"stiffness":1.0,"travel":0.01},
				{"name":"WheelSR","pos":Vector3( 0.02,0.0,0.0),"steer":false,"traction":false,"radius":0.02,"stiffness":1.0,"travel":0.01},
			]

# ─────────────────────────── ENGINE AUDIO ──────────────────────
func _setup_engine_audio() -> void:
	if vehicle_type == "BICYCLE" or vehicle_type == "SKATEBOARD":
		return
	engine_audio = AudioStreamPlayer.new()
	engine_audio.name = "EngineAudio"
	engine_audio.stream = ProceduralCinematicAudio.create_scooter_engine_sfx()
	engine_audio.volume_db = -12.0
	engine_audio.autoplay = false
	add_child(engine_audio)

# ─────────────────────────── INPUT/PHYSICS ─────────────────────
func _physics_process(delta: float) -> void:
	if not is_mounted or not driver:
		engine_force = 0.0
		brake = brake_force_max * 0.1
		return

	speed_kmh = linear_velocity.length() * 3.6

	var throttle: float = Input.get_axis("ui_down", "ui_up")      # Up=forward
	var steer_input: float = Input.get_axis("ui_right", "ui_left") # Right=right
	var handbrake: bool = Input.is_action_pressed("ui_accept")

	# Speed limiter
	var speed_factor: float = clampf(1.0 - (speed_kmh / top_speed_kmh), 0.0, 1.0)
	engine_force = throttle * engine_force_max * speed_factor

	# Smooth steering
	current_steer = lerpf(current_steer, steer_input * deg_to_rad(steer_max_angle), steer_speed * delta)
	if wheel_fl:
		wheel_fl.steering = current_steer
	if wheel_fr:
		wheel_fr.steering = current_steer

	# Drift / handbrake
	if handbrake and speed_kmh > 8.0:
		if not is_drifting:
			is_drifting = true
			emit_signal("drift_started")
		_set_wheel_friction(drift_friction)
		brake = brake_force_max * 0.6
	else:
		if is_drifting:
			is_drifting = false
			emit_signal("drift_ended")
		_set_wheel_friction(normal_friction)
		brake = 0.0 if throttle > 0.0 else brake_force_max * 0.05

	# Engine audio pitch follows speed
	if engine_audio and engine_audio.playing:
		engine_audio.pitch_scale = 0.7 + (speed_kmh / top_speed_kmh) * 1.1

func _set_wheel_friction(fr: float) -> void:
	for w in [wheel_fl, wheel_fr, wheel_rl, wheel_rr]:
		if w and is_instance_valid(w):
			w.wheel_friction_slip = fr

# ─────────────────────────── MOUNT / DISMOUNT ──────────────────
func mount(player: Node) -> Dictionary:
	if is_mounted:
		return {"success": false, "reason": "Already occupied"}
	is_mounted = true
	driver = player
	emit_signal("vehicle_mounted", player)
	if engine_audio:
		engine_audio.play()
	return {"success": true, "vehicle_type": vehicle_type}

func dismount() -> Dictionary:
	if not is_mounted:
		return {"success": false, "reason": "Not mounted"}
	var prev_driver = driver
	is_mounted = false
	driver = null
	engine_force = 0.0
	brake = brake_force_max
	emit_signal("vehicle_dismounted", prev_driver)
	if engine_audio:
		engine_audio.stop()
	return {"success": true, "speed_kmh_at_dismount": speed_kmh}

func honk_horn() -> void:
	emit_signal("horn_honked")
	if is_inside_tree():
		var horn := AudioStreamPlayer.new()
		add_child(horn)
		horn.stream = ProceduralCinematicAudio.create_vehicle_horn_sfx()
		horn.play()
		horn.finished.connect(func(): horn.queue_free())

# ─────────────────────────── TEARDOWN ──────────────────────────
func _exit_tree() -> void:
	if engine_audio and is_instance_valid(engine_audio):
		engine_audio.stop()
		engine_audio.queue_free()
	for child in get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.queue_free()
		elif child is MeshInstance3D:
			if child.material_override != null:
				child.material_override = null

class_name RideableVehicle
extends CharacterBody3D

signal driver_mounted(driver: Node)
signal driver_dismounted()
signal horn_or_bell_triggered()

enum VehicleType {
	BICYCLE,
	SCOOTER,
	SKATEBOARD,
	CAR
}

@export var vehicle_type: VehicleType = VehicleType.BICYCLE
@export var vehicle_name: String = "Mamachari Bicycle // ママチャリ"
@export var max_speed: float = 9.5
@export var acceleration: float = 8.0
@export var turn_speed: float = 2.8
@export var brake_deceleration: float = 14.0

const InteractableComponent = preload("res://scripts/interaction/interactable_component.gd")

var current_driver: Node = null
var is_occupied: bool = false
var audio_player: AudioStreamPlayer3D = null
var _headlight: SpotLight3D = null
var headlight: SpotLight3D:
	get:
		if not _headlight:
			_headlight = find_child("Headlight", true, false) as SpotLight3D
		return _headlight
	set(val):
		_headlight = val
var current_drive_speed: float = 0.0

@onready var interactable = find_child("VehicleInteractable", true, false) as InteractableComponent

func _ready() -> void:
	if not audio_player:
		audio_player = AudioStreamPlayer3D.new()
		audio_player.max_distance = 25.0
		add_child(audio_player)
	
	if headlight:
		headlight.visible = false
	
	if not interactable:
		interactable = find_child("VehicleInteractable", true, false) as InteractableComponent
	if interactable:
		interactable.verb = InteractableComponent.InteractionVerb.RIDE if "RIDE" in InteractableComponent.InteractionVerb else InteractableComponent.InteractionVerb.OPEN
		interactable.prompt_target_name = vehicle_name

func on_interacted(interactor: Node3D, verb: int) -> Dictionary:
	if is_occupied:
		if interactor == current_driver:
			return dismount()
		else:
			return {"success": false, "reason": "vehicle_occupied"}
	else:
		return mount(interactor)

func mount(driver: Node) -> Dictionary:
	if is_occupied:
		return {"success": false, "reason": "already_occupied"}
	
	current_driver = driver
	is_occupied = true
	
	# Hide or seat driver visual if applicable
	if driver.has_method("set_mounted_vehicle"):
		driver.set_mounted_vehicle(self)
	
	# Enable lights if scooter/car
	if headlight:
		headlight.visible = true
	
	# Initial sound
	play_start_sound()
	
	emit_signal("driver_mounted", driver)
	
	return {
		"success": true,
		"vehicle": vehicle_name,
		"type": int(vehicle_type),
		"max_speed": max_speed,
		"message": "Mounted %s." % vehicle_name
	}

func dismount() -> Dictionary:
	if not is_occupied or not current_driver:
		return {"success": false, "reason": "not_mounted"}
	
	var prev_driver = current_driver
	current_driver = null
	is_occupied = false
	current_drive_speed = 0.0
	velocity = Vector3.ZERO
	
	if prev_driver.has_method("set_mounted_vehicle"):
		prev_driver.set_mounted_vehicle(null)
	
	if headlight:
		headlight.visible = false
	
	if audio_player and audio_player.playing:
		audio_player.stop()
	
	emit_signal("driver_dismounted")
	
	return {
		"success": true,
		"message": "Dismounted %s." % vehicle_name
	}

func trigger_bell_or_horn() -> void:
	if audio_player:
		match vehicle_type:
			VehicleType.BICYCLE:
				audio_player.stream = ProceduralCinematicAudio.create_bicycle_bell()
				audio_player.play()
			VehicleType.SCOOTER, VehicleType.CAR:
				audio_player.stream = ProceduralCinematicAudio.create_engine_throttle()
				audio_player.play()
			VehicleType.SKATEBOARD:
				audio_player.stream = ProceduralCinematicAudio.create_skateboard_roll()
				audio_player.play()
	emit_signal("horn_or_bell_triggered")

func play_start_sound() -> void:
	if not audio_player:
		return
	match vehicle_type:
		VehicleType.BICYCLE:
			audio_player.stream = ProceduralCinematicAudio.create_bicycle_bell()
			audio_player.play()
		VehicleType.SCOOTER:
			audio_player.stream = ProceduralCinematicAudio.create_engine_throttle()
			audio_player.play()
		VehicleType.SKATEBOARD:
			audio_player.stream = ProceduralCinematicAudio.create_skateboard_roll()
			audio_player.play()

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= 14.0 * delta

	if is_occupied and current_driver:
		var input_dir = Vector2.ZERO
		if Input.is_action_pressed("move_forward"): input_dir.y += 1.0
		if Input.is_action_pressed("move_backward"): input_dir.y -= 1.0
		if Input.is_action_pressed("move_left"): input_dir.x -= 1.0
		if Input.is_action_pressed("move_right"): input_dir.x += 1.0

		# Mobile/synthetic input fallback
		if "mobile_input_vector" in current_driver and current_driver.mobile_input_vector != Vector2.ZERO:
			input_dir = current_driver.mobile_input_vector

		# Steer
		if input_dir.x != 0.0:
			rotation.y -= input_dir.x * turn_speed * delta

		# Accelerate
		if input_dir.y > 0.0:
			current_drive_speed = min(max_speed, current_drive_speed + acceleration * delta)
		elif input_dir.y < 0.0:
			current_drive_speed = max(-max_speed * 0.4, current_drive_speed - brake_deceleration * delta)
		else:
			# Coasting friction
			current_drive_speed = move_toward(current_drive_speed, 0.0, 4.0 * delta)

		var forward = -transform.basis.z
		velocity.x = forward.x * current_drive_speed
		velocity.z = forward.z * current_drive_speed

		# Keep driver positioned on vehicle
		if current_driver is Node3D and current_driver != self:
			current_driver.global_position = global_position + Vector3(0, 0.4, 0)
			current_driver.rotation.y = rotation.y

		move_and_slide()
	else:
		if not is_on_floor():
			move_and_slide()

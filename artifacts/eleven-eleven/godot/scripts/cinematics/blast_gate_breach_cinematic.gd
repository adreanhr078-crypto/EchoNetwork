class_name BlastGateBreachCinematic
extends Node

## Genshin-style dynamic cutscene sequence for Sector 11 Blast Gate breach.
## Triggers dramatic camera framing, mechanical trauma shake, steam venting,
## and a seamless transition back to player exploration.

signal cinematic_started()
signal cinematic_completed()

@export var cinematic_duration: float = 3.6

var _subject: Node3D
var _gate: Node3D
var _camera_boom: SpringArm3D
var _player_camera: Camera3D
var _camera_tween: Tween
var _is_playing: bool = false
var _shake_timer: float = 0.0
var _shake_intensity: float = 0.0

func play(subject: Node3D, gate: Node3D) -> void:
	if _is_playing:
		return
	_subject = subject
	_gate = gate
	if not _subject or not is_instance_valid(_subject):
		return
	_camera_boom = _subject.find_child("CameraBoom", true, false) as SpringArm3D
	_player_camera = _subject.find_child("Camera3D", true, false) as Camera3D
	if not _camera_boom or not _player_camera:
		return

	_is_playing = true
	emit_signal("cinematic_started")

	# Temporarily freeze player velocity
	if _subject is CharacterBody3D:
		_subject.velocity = Vector3.ZERO

	# Unlock and trigger gate mechanical opening
	if _gate and _gate.has_method("unlock_gate"):
		_gate.unlock_gate()

	# Stage 1: Fast sweep & zoom towards the Blast Gate with a low-angle dramatic look
	_camera_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_camera_tween.tween_property(_camera_boom, "rotation:y", 0.0, 0.5)
	_camera_tween.parallel().tween_property(_camera_boom, "rotation:x", deg_to_rad(-16.0), 0.5)
	_camera_tween.parallel().tween_property(_camera_boom, "spring_length", 4.2, 0.6)
	_camera_tween.parallel().tween_property(_player_camera, "fov", 62.0, 0.6)

	# Stage 2: Mechanical lock release and steam discharge
	_camera_tween.chain().tween_callback(func():
		_shake_intensity = 0.28
		_shake_timer = 1.4
		if _gate and _gate.has_method("open_gate"):
			_gate.open_gate()
	)

	# Stage 3: Dynamic camera rise tracking the opening door
	_camera_tween.chain().tween_interval(0.4)
	_camera_tween.chain().tween_property(_camera_boom, "rotation:x", deg_to_rad(-8.0), 1.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_camera_tween.parallel().tween_property(_player_camera, "fov", 72.0, 1.8)

	# Stage 4: Smooth return to default gameplay third-person shoulder view
	_camera_tween.chain().tween_property(_camera_boom, "rotation:x", deg_to_rad(-19.6), 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_camera_tween.parallel().tween_property(_camera_boom, "spring_length", 3.0, 0.8)
	_camera_tween.parallel().tween_property(_player_camera, "fov", 75.0, 0.8)

	_camera_tween.chain().tween_callback(func():
		finish()
	)

func _process(delta: float) -> void:
	if not _is_playing:
		return
	if not _subject or not is_instance_valid(_subject):
		finish()
		return

	# Handle skip on click or interact
	if Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("attack_light"):
		finish()
		return

	# Procedural camera rumble during heavy hydraulic slide
	if _shake_timer > 0.0 and _player_camera:
		_shake_timer -= delta
		var noise_x = (randf() * 2.0 - 1.0) * _shake_intensity
		var noise_y = (randf() * 2.0 - 1.0) * _shake_intensity
		_player_camera.h_offset = noise_x
		_player_camera.v_offset = noise_y
	elif _player_camera:
		_player_camera.h_offset = lerp(_player_camera.h_offset, 0.0, 10.0 * delta)
		_player_camera.v_offset = lerp(_player_camera.v_offset, 0.0, 10.0 * delta)

func finish() -> void:
	if not _is_playing:
		return
	_is_playing = false
	if _camera_tween and _camera_tween.is_running():
		_camera_tween.kill()

	if _player_camera and is_instance_valid(_player_camera):
		_player_camera.h_offset = 0.0
		_player_camera.v_offset = 0.0
		_player_camera.fov = 75.0

	if _camera_boom and is_instance_valid(_camera_boom):
		_camera_boom.rotation.y = 0.0
		_camera_boom.rotation.x = deg_to_rad(-19.6)
		_camera_boom.spring_length = 3.0

	# Ensure gate is opened
	if _gate and is_instance_valid(_gate) and _gate.has_method("open_gate"):
		_gate.open_gate()

	emit_signal("cinematic_completed")

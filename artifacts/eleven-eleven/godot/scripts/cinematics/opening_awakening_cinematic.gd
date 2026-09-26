extends Node

@export var camera_duration: float = 3.04

var _subject: Node3D
var _camera_boom: SpringArm3D
var _player_camera: Camera3D
var _guide_pod: Node
var _camera_tween: Tween
var _is_playing: bool = false
var _original_pod_offset: Vector3

func play(subject: Node3D) -> void:
	if not subject or not is_instance_valid(subject):
		return
	_camera_boom = subject.find_child("CameraBoom", true, false) as SpringArm3D
	_player_camera = subject.find_child("Camera3D", true, false) as Camera3D
	if not _camera_boom or not _player_camera:
		return
	_subject = subject
	_is_playing = true
	# Keep the first frame inside the authored chamber instead of facing the void beyond it.
	_camera_boom.rotation.y = TAU - 0.35
	_camera_boom.spring_length = 3.0
	_player_camera.fov = 65.0
	_guide_pod = _subject.get_parent().get_node_or_null("FloatingPod") if _subject.get_parent() else null
	if _guide_pod:
		_original_pod_offset = _guide_pod.get("float_offset")
		_guide_pod.set("float_offset", Vector3(-0.65, 1.9, 0.25))
	_camera_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_camera_tween.tween_property(_camera_boom, "rotation:y", TAU, camera_duration)
	_camera_tween.parallel().tween_property(_camera_boom, "spring_length", 3.0, camera_duration)
	_camera_tween.parallel().tween_property(_player_camera, "fov", 75.0, camera_duration)

func _process(_delta: float) -> void:
	if not _is_playing:
		return
	if not _subject or not is_instance_valid(_subject):
		finish()
		return
	if Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("interact"):
		finish()

func finish() -> void:
	if not _is_playing:
		return
	_is_playing = false
	if _camera_tween and _camera_tween.is_running():
		_camera_tween.kill()
	if _camera_boom and is_instance_valid(_camera_boom):
		_camera_boom.rotation.y = 0.0
		_camera_boom.spring_length = 3.0
	if _player_camera and is_instance_valid(_player_camera):
		_player_camera.fov = 75.0
	if _guide_pod and is_instance_valid(_guide_pod):
		_guide_pod.set("float_offset", _original_pod_offset)
	if _subject and is_instance_valid(_subject) and _subject.has_method("finish_opening_recovery"):
		_subject.finish_opening_recovery()

class_name HospitalSlidingDoors
extends Node3D

signal doors_opened()
signal doors_closed()

@export var open_distance: float = 1.25
@export var open_speed: float = 2.5

var is_open: bool = false
var target_offset: float = 0.0
var current_offset: float = 0.0

@onready var left_door: Node3D = find_child("DoorLeft", true, false)
@onready var right_door: Node3D = find_child("DoorRight", true, false)
@onready var sensor_area: Area3D = find_child("SensorArea", true, false) as Area3D
@onready var audio_player: AudioStreamPlayer3D = find_child("AudioPlayer", true, false) as AudioStreamPlayer3D

func _ready() -> void:
	if sensor_area:
		sensor_area.body_entered.connect(_on_sensor_entered)
		sensor_area.body_exited.connect(_on_sensor_exited)

func _process(delta: float) -> void:
	if not left_door or not right_door:
		return
	if abs(current_offset - target_offset) > 0.005:
		current_offset = move_toward(current_offset, target_offset, open_speed * delta)
		left_door.position.x = -0.7 - current_offset
		right_door.position.x = 0.7 + current_offset

func open_doors() -> void:
	if not is_open:
		is_open = true
		target_offset = open_distance
		if audio_player:
			audio_player.stream = ProceduralCinematicAudio.create_sliding_door_whoosh()
			audio_player.play()
		emit_signal("doors_opened")

func close_doors() -> void:
	if is_open:
		is_open = false
		target_offset = 0.0
		if audio_player:
			audio_player.stream = ProceduralCinematicAudio.create_sliding_door_whoosh()
			audio_player.play()
		emit_signal("doors_closed")

func _on_sensor_entered(body: Node3D) -> void:
	if body.is_in_group("player") or body.name == "EchoPlayer" or body.has_method("perform_attack"):
		open_doors()

func _on_sensor_exited(body: Node3D) -> void:
	if body.is_in_group("player") or body.name == "EchoPlayer" or body.has_method("perform_attack"):
		close_doors()

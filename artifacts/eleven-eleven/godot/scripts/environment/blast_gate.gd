extends Node3D

signal gate_unlocked
signal gate_opened
signal gate_closed

enum GateState {
	LOCKED,
	UNLOCKED,
	OPENING,
	OPENED,
	CLOSING
}

@export var state: GateState = GateState.LOCKED
@export var slide_distance: float = 6.5
@export var open_duration: float = 2.4

@onready var door_panel: MeshInstance3D = $DoorFrame/SlidingDoor if has_node("DoorFrame/SlidingDoor") else null
@onready var collision_shape: CollisionShape3D = $GateCollider/CollisionShape3D if has_node("GateCollider/CollisionShape3D") else null
@onready var indicator_light: OmniLight3D = $DoorFrame/IndicatorLight if has_node("DoorFrame/IndicatorLight") else null
@onready var steam_particles: GPUParticles3D = $SteamExhaust if has_node("SteamExhaust") else null

var initial_door_y: float = 3.25

func get_door_panel() -> MeshInstance3D:
	if not door_panel:
		door_panel = find_child("SlidingDoor", true, false) as MeshInstance3D
	return door_panel

func get_collision_shape() -> CollisionShape3D:
	if not collision_shape:
		collision_shape = find_child("CollisionShape3D", true, false) as CollisionShape3D
	return collision_shape

func get_indicator_light() -> OmniLight3D:
	if not indicator_light:
		indicator_light = find_child("IndicatorLight", true, false) as OmniLight3D
	return indicator_light

func _ready() -> void:
	var door = get_door_panel()
	if door:
		initial_door_y = door.position.y
	_update_visual_state()

func _update_visual_state() -> void:
	var light = get_indicator_light()
	if light:
		match state:
			GateState.LOCKED:
				light.light_color = Color(1.0, 0.15, 0.1, 1.0) # Crimson warning
				light.light_energy = 2.2
			GateState.UNLOCKED, GateState.OPENING:
				light.light_color = Color(1.0, 0.75, 0.1, 1.0) # Amber transit
				light.light_energy = 3.0
			GateState.OPENED:
				light.light_color = Color(0.0, 0.94, 1.0, 1.0) # Cyan cleared
				light.light_energy = 2.5

func unlock_gate() -> void:
	if state == GateState.LOCKED:
		state = GateState.UNLOCKED
		_update_visual_state()
		emit_signal("gate_unlocked")

func open_gate() -> void:
	if state == GateState.OPENED or state == GateState.OPENING:
		return
	state = GateState.OPENING
	_update_visual_state()

	var steam = steam_particles if steam_particles else find_child("SteamExhaust", true, false) as GPUParticles3D
	if steam:
		steam.emitting = true

	var door = get_door_panel()
	var col = get_collision_shape()
	if col:
		col.disabled = true

	var tree = get_tree() if is_inside_tree() else null
	if tree and door:
		var target_y: float = initial_door_y + slide_distance
		var tween = tree.create_tween().set_parallel(true)
		tween.tween_property(door, "position:y", target_y, open_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		var light = get_indicator_light()
		if light:
			tween.tween_property(light, "light_color", Color(0.0, 0.94, 1.0, 1.0), open_duration * 0.5)

		tween.chain().tween_callback(func():
			state = GateState.OPENED
			_update_visual_state()
			if steam:
				steam.emitting = false
			emit_signal("gate_opened")
		)
	else:
		if door:
			door.position.y = initial_door_y + slide_distance
		state = GateState.OPENED
		_update_visual_state()
		emit_signal("gate_opened")

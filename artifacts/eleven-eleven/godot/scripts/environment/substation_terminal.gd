extends Node3D

signal terminal_accessed
signal terminal_hacked_complete

@export var is_hacked: bool = false
var player_in_range: bool = false

@onready var screen_mesh: MeshInstance3D = $TerminalScreen if has_node("TerminalScreen") else null
@onready var prompt_label: Label3D = $InteractionPrompt if has_node("InteractionPrompt") else null
@onready var terminal_light: OmniLight3D = $TerminalLight if has_node("TerminalLight") else null

func _ready() -> void:
	var area = $InteractionArea if has_node("InteractionArea") else null
	if area:
		area.body_entered.connect(_on_body_entered)
		area.body_exited.connect(_on_body_exited)
	_update_visuals()

func _update_visuals() -> void:
	if not prompt_label:
		prompt_label = find_child("InteractionPrompt", true, false) as Label3D
	if not terminal_light:
		terminal_light = find_child("TerminalLight", true, false) as OmniLight3D

	if prompt_label:
		prompt_label.visible = player_in_range and not is_hacked

	if terminal_light:
		if is_hacked:
			terminal_light.light_color = Color(0.0, 0.95, 1.0, 1.0)
			terminal_light.light_energy = 2.8
		else:
			terminal_light.light_color = Color(1.0, 0.65, 0.1, 1.0)
			terminal_light.light_energy = 1.8

func _on_body_entered(body: Node) -> void:
	if body.name == "EchoPlayer" or body.is_in_group("player"):
		player_in_range = true
		_update_visuals()

func _on_body_exited(body: Node) -> void:
	if body.name == "EchoPlayer" or body.is_in_group("player"):
		player_in_range = false
		_update_visuals()

func interact() -> void:
	if is_hacked:
		return
	emit_signal("terminal_accessed")

func complete_hack() -> void:
	is_hacked = true
	player_in_range = false
	_update_visuals()
	emit_signal("terminal_hacked_complete")

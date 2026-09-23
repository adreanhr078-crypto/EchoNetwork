extends Node3D

signal terminal_accessed
signal terminal_hacked_complete

@export var is_hacked: bool = false
var player_in_range: bool = false

@onready var screen_mesh: MeshInstance3D = $TerminalScreen if has_node("TerminalScreen") else null
@onready var terminal_light: OmniLight3D = $TerminalLight if has_node("TerminalLight") else null

func _ready() -> void:
	var area = $InteractionArea if has_node("InteractionArea") else null
	if area:
		area.body_entered.connect(_on_body_entered)
		area.body_exited.connect(_on_body_exited)
		if area.has_signal("interaction_executed"):
			area.interaction_executed.connect(_on_interaction_executed)
	_update_visuals()

func _on_interaction_executed(_interactor: Node3D, _verb: int) -> void:
	interact()

func _update_visuals() -> void:
	if not terminal_light:
		terminal_light = find_child("TerminalLight", true, false) as OmniLight3D

	if terminal_light:
		if is_hacked:
			terminal_light.light_color = Color(0.0, 0.95, 1.0, 1.0)
			terminal_light.light_energy = 0.4
		else:
			terminal_light.light_color = Color(1.0, 0.65, 0.1, 1.0)
			terminal_light.light_energy = 0.18

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
	var area = $InteractionArea if has_node("InteractionArea") else null
	if area and area.get("current_interactor") and area.get("current_interactor").has_method("unregister_nearby_interactable"):
		area.get("current_interactor").unregister_nearby_interactable(area)
	if area:
		area.set("is_enabled", false)
	_update_visuals()
	emit_signal("terminal_hacked_complete")

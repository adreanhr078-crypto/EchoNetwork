class_name RestraintChair
extends Node3D

signal subject_restrained(subject_name: String)
signal neural_surge_started(intensity: float)
signal restraints_shattered()

enum ChairState {
	IDLE,
	SUBJECT_RESTRAINED,
	NEURAL_SURGE,
	BROKEN_FREE
}

var current_state: ChairState = ChairState.IDLE
var is_restrained: bool = false
var neural_surge_active: bool = false
var restraints_locked: bool = false

@onready var model_node: Node3D = get_node_or_null("Model") if has_node("Model") else null
@onready var surge_light: OmniLight3D = get_node_or_null("NeuralSurgeLight") if has_node("NeuralSurgeLight") else null

func _ensure_nodes() -> void:
	if not model_node: model_node = find_child("Model", true, false) as Node3D
	if not surge_light: surge_light = find_child("NeuralSurgeLight", true, false) as OmniLight3D

func _ready() -> void:
	_ensure_nodes()
	if surge_light:
		surge_light.visible = false

func restrain_subject(subject_name: String = "ECHO_EX011") -> void:
	_ensure_nodes()
	current_state = ChairState.SUBJECT_RESTRAINED
	is_restrained = true
	restraints_locked = true
	emit_signal("subject_restrained", subject_name)

func trigger_neural_surge(intensity: float = 1.5) -> void:
	_ensure_nodes()
	current_state = ChairState.NEURAL_SURGE
	neural_surge_active = true
	if surge_light:
		surge_light.visible = true
		surge_light.light_energy = 4.5 * intensity
		surge_light.light_color = Color(0.95, 0.1, 0.25, 1.0) # Crimson torture surge
	emit_signal("neural_surge_started", intensity)

func break_restraints() -> void:
	_ensure_nodes()
	current_state = ChairState.BROKEN_FREE
	is_restrained = false
	restraints_locked = false
	neural_surge_active = false
	if surge_light:
		surge_light.visible = true
		surge_light.light_energy = 6.0
		surge_light.light_color = Color(0.0, 0.95, 1.0, 1.0) # Zero awakened cyan explosion
		var tree = get_tree() if is_inside_tree() else null
		if tree:
			tree.create_timer(0.4).timeout.connect(func():
				if surge_light: surge_light.visible = false
			)
	emit_signal("restraints_shattered")

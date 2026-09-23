class_name DrKinga
extends CharacterBody3D

signal confrontation_started()
signal dialogue_advanced(line_index: int)
signal injection_administered()
signal scientist_terrified()

enum State {
	IDLE,
	CONFRONTATION,
	ADMINISTERING_INJECTION,
	OBSERVING_TORTURE,
	TERRIFIED
}

var current_state: State = State.IDLE

var _monocle_light: OmniLight3D
var monocle_light: OmniLight3D:
	get:
		if not _monocle_light:
			_monocle_light = get_node_or_null("MonocleLight") as OmniLight3D
			if not _monocle_light:
				_monocle_light = find_child("MonocleLight", true, false) as OmniLight3D
		return _monocle_light
	set(val):
		_monocle_light = val

var _syringe_glow: OmniLight3D
var syringe_glow: OmniLight3D:
	get:
		if not _syringe_glow:
			_syringe_glow = get_node_or_null("SyringeGlow") as OmniLight3D
			if not _syringe_glow:
				_syringe_glow = find_child("SyringeGlow", true, false) as OmniLight3D
		return _syringe_glow
	set(val):
		_syringe_glow = val

func _ready() -> void:
	if monocle_light:
		monocle_light.visible = true
		monocle_light.light_color = Color(1.0, 0.2, 0.1, 1.0)
		monocle_light.light_energy = 2.4
	if syringe_glow:
		syringe_glow.visible = false

func start_confrontation() -> void:
	current_state = State.CONFRONTATION
	emit_signal("confrontation_started")

func prepare_injection() -> void:
	current_state = State.ADMINISTERING_INJECTION
	if syringe_glow:
		syringe_glow.visible = true
		syringe_glow.light_color = Color(0.1, 1.0, 0.35, 1.0) # Toxic neuro-sedative
		syringe_glow.light_energy = 3.5

func administer_injection() -> void:
	if syringe_glow:
		syringe_glow.light_color = Color(1.0, 0.1, 0.25, 1.0) # Crimson bio-synthetic catalyst
	emit_signal("injection_administered")

func react_to_zero_singularity() -> void:
	current_state = State.TERRIFIED
	if monocle_light:
		monocle_light.light_color = Color(1.0, 0.05, 0.05, 1.0)
		monocle_light.light_energy = 5.0
	# Stumble backward in terror
	var tree = get_tree() if is_inside_tree() else null
	if tree:
		var tween = tree.create_tween()
		tween.tween_property(self, "position", position + transform.basis.z * 3.5, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	emit_signal("scientist_terrified")

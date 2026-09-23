extends Node3D

signal wing_manifested(intensity)
signal wing_dismissed

@export var is_wing_manifested: bool = false
@export var base_scale: Vector3 = Vector3(1.0, 1.0, 1.0)

@onready var wing_mesh: Node3D = $WingRoot if has_node("WingRoot") else null
@onready var shadow_particles: GPUParticles3D = $ShadowMistParticles if has_node("ShadowMistParticles") else null
@onready var wing_light: OmniLight3D = $WingGlowLight if has_node("WingGlowLight") else null

func _ensure_nodes() -> void:
	if not wing_mesh: wing_mesh = find_child("WingRoot", true, false) as Node3D
	if not shadow_particles: shadow_particles = find_child("ShadowMistParticles", true, false) as GPUParticles3D
	if not wing_light: wing_light = find_child("WingGlowLight", true, false) as OmniLight3D

func _ready() -> void:
	_ensure_nodes()
	visible = is_wing_manifested
	if not is_wing_manifested:
		dismiss_wing()

func manifest_wing(intensity: float = 1.0) -> void:
	_ensure_nodes()
	is_wing_manifested = true
	visible = true

	if wing_light:
		wing_light.visible = true
		wing_light.light_energy = 3.2 * intensity

	if shadow_particles:
		shadow_particles.emitting = true

	if wing_mesh:
		wing_mesh.scale = Vector3.ZERO
		var tree = get_tree() if is_inside_tree() else null
		if tree:
			var tween = tree.create_tween()
			tween.tween_property(wing_mesh, "scale", base_scale * intensity, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		else:
			wing_mesh.scale = base_scale * intensity

	emit_signal("wing_manifested", intensity)

func dismiss_wing() -> void:
	_ensure_nodes()
	is_wing_manifested = false
	if wing_light:
		wing_light.visible = false
	if shadow_particles:
		shadow_particles.emitting = false

	if wing_mesh:
		var tree = get_tree() if is_inside_tree() else null
		if tree:
			var tween = tree.create_tween()
			tween.tween_property(wing_mesh, "scale", Vector3.ZERO, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tween.tween_callback(func(): visible = false)
		else:
			wing_mesh.scale = Vector3.ZERO
			visible = false
	else:
		visible = false

	emit_signal("wing_dismissed")

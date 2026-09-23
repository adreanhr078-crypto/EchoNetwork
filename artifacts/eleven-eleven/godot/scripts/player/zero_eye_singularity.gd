extends Node3D

signal singularity_activated(intensity)
signal singularity_deactivated

@export var is_singularity_active: bool = false
@export var base_energy: float = 2.8

@onready var eye_light: OmniLight3D = $EyeLight if has_node("EyeLight") else null
@onready var eye_flare: GPUParticles3D = $EyeFlareParticles if has_node("EyeFlareParticles") else null

func _ready() -> void:
	if not eye_light:
		eye_light = find_child("EyeLight", true, false) as OmniLight3D
	if not eye_flare:
		eye_flare = find_child("EyeFlareParticles", true, false) as GPUParticles3D

	if not is_singularity_active:
		deactivate_singularity()
	else:
		activate_singularity(1.0)

func activate_singularity(intensity: float = 1.0) -> void:
	is_singularity_active = true
	if not eye_light:
		eye_light = find_child("EyeLight", true, false) as OmniLight3D
	if not eye_flare:
		eye_flare = find_child("EyeFlareParticles", true, false) as GPUParticles3D

	if eye_light:
		eye_light.visible = true
		eye_light.light_energy = base_energy * intensity
	if eye_flare:
		eye_flare.emitting = true
	emit_signal("singularity_activated", intensity)

func deactivate_singularity() -> void:
	is_singularity_active = false
	if not eye_light:
		eye_light = find_child("EyeLight", true, false) as OmniLight3D
	if not eye_flare:
		eye_flare = find_child("EyeFlareParticles", true, false) as GPUParticles3D

	if eye_light:
		eye_light.visible = false
	if eye_flare:
		eye_flare.emitting = false
	emit_signal("singularity_deactivated")

func pulse_singularity(duration: float = 0.6) -> void:
	activate_singularity(1.8)
	var tree = get_tree() if is_inside_tree() else null
	if tree:
		tree.create_timer(duration).timeout.connect(func():
			if is_singularity_active:
				activate_singularity(1.0)
		)

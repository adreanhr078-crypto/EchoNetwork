extends Node3D

signal shadow_burst_triggered

@export var is_active_shadow: bool = true
@export var flame_energy: float = 3.5

@onready var flame_particles: GPUParticles3D = $DarkFlameParticles if has_node("DarkFlameParticles") else null
@onready var blade_glow: OmniLight3D = $BladeGlowLight if has_node("BladeGlowLight") else null
@onready var slash_arc: MeshInstance3D = $ShadowSlashArc if has_node("ShadowSlashArc") else null
@onready var blade_mesh: MeshInstance3D = $BladeRoot/BladeMesh if has_node("BladeRoot/BladeMesh") else null

func _ready() -> void:
	if slash_arc:
		slash_arc.visible = false
	set_flame_intensity(1.0)

func set_flame_intensity(factor: float) -> void:
	if not blade_glow:
		blade_glow = find_child("BladeGlowLight", true, false) as OmniLight3D
	if blade_glow:
		blade_glow.light_energy = flame_energy * factor

	if not flame_particles:
		flame_particles = find_child("DarkFlameParticles", true, false) as GPUParticles3D
	if flame_particles:
		flame_particles.amount_ratio = clamp(factor, 0.2, 1.0)

func trigger_shadow_burst() -> void:
	set_flame_intensity(2.2)
	var tree = get_tree() if is_inside_tree() else null
	if tree:
		tree.create_timer(0.4).timeout.connect(func():
			set_flame_intensity(1.0)
		)
	emit_signal("shadow_burst_triggered")

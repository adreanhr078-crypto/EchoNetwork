class_name EchoMonarchAwakeningController
extends Node3D

## AAA Echo Monarch Awakening & Kagune Sovereign Controller
## (Solo Leveling System Window + Tokyo Ghoul Kagune Tendril Awakening)
##
## Features:
##   - Monarch Awakening mode: 4 glowing Void-Crimson tendrils from Echo's back
##   - Dark Void Flame Katana infusion (+50% DMG, +35% ATK speed)
##   - Holographic 3D System Window with glass shatter dismiss SFX
##   - "ARISE // 起きろ" Shadow extraction resonance on defeated enemies

signal monarch_mode_activated(duration: float)
signal monarch_mode_deactivated()
signal system_window_displayed(title: String, subtitle: String)
signal shadow_extraction_performed(target_name: String)

const ProceduralCinematicAudio = preload("res://scripts/audio/procedural_cinematic_audio.gd")

# ─────────────────── RUNTIME PARAMS ─────────────────────────────
@export var is_monarch_active: bool = false
@export var awakening_duration: float = 30.0
@export var damage_boost_multiplier: float = 1.50
@export var attack_speed_multiplier: float = 1.35

var player: CharacterBody3D = null
var _awakening_timer: float = 0.0
var _tendril_nodes: Array[MeshInstance3D] = []
var _tendril_lights: Array[OmniLight3D] = []
var _void_particles: GPUParticles3D = null
var _system_window_mesh: MeshInstance3D = null
var _time_accum: float = 0.0

const TENDRIL_COUNT: int = 4
const TENDRIL_LENGTH: float = 1.85

func _ready() -> void:
	pass

func setup(p_player: CharacterBody3D) -> void:
	player = p_player

# ─────────────────── MONARCH AWAKENING ─────────────────────────

## Activates the full Shadow Monarch + Kagune transformation
func activate_monarch_mode(duration: float = 30.0) -> Dictionary:
	if is_monarch_active:
		_awakening_timer = duration
		return {"success": true, "extended": true, "duration": duration}

	is_monarch_active = true
	_awakening_timer = duration

	_spawn_kagune_wings()
	_spawn_mana_flame_particles()

	# Audio surge: demonic whisper + shadow resonance
	if is_inside_tree():
		var audio := AudioStreamPlayer.new()
		add_child(audio)
		audio.stream = ProceduralCinematicAudio.create_shadow_blink_sfx()
		audio.volume_db = 5.0
		audio.play()
		audio.finished.connect(func(): audio.queue_free())

	emit_signal("monarch_mode_activated", duration)

	# Show Solo Leveling System Alert Window
	show_system_window(
		"[SYSTEM: MONARCH AWAKENING DETECTED]",
		"Subject EX-011 Sovereign Protocol Engaged. All limits released."
	)

	return {
		"success": true,
		"is_monarch_active": true,
		"duration": duration,
		"damage_boost": damage_boost_multiplier,
		"attack_speed_boost": attack_speed_multiplier
	}

## Spawns the 4 organic Kagune tendril meshes radiating from Echo's back
func _spawn_kagune_wings() -> void:
	for i in range(TENDRIL_COUNT):
		var tendril := MeshInstance3D.new()
		tendril.name = "EchoKaguneWing_%d" % i
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.02
		cyl.bottom_radius = 0.08
		cyl.height = TENDRIL_LENGTH
		tendril.mesh = cyl

		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.65, 0.04, 0.12, 0.92) # Crimson Void
		mat.emission_enabled = true
		mat.emission = Color(0.9, 0.08, 0.18)
		mat.emission_energy_multiplier = 3.5
		mat.roughness = 0.15
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		tendril.material_override = mat

		var angle: float = (TAU / TENDRIL_COUNT) * i + PI / 4.0
		var bx: float = cos(angle) * 0.28
		var bz: float = sin(angle) * 0.28
		tendril.position = Vector3(bx, 1.25, bz - 0.12)
		tendril.rotation_degrees = Vector3(35.0 + i * 6.0, rad_to_deg(angle), 0.0)

		add_child(tendril)
		_tendril_nodes.append(tendril)

		var tip_light := OmniLight3D.new()
		tip_light.name = "KaguneTipLight_%d" % i
		tip_light.light_color = Color(1.0, 0.1, 0.2)
		tip_light.light_energy = 2.5
		tip_light.omni_range = 2.2
		tip_light.position = Vector3(bx * 2.2, 1.25 + TENDRIL_LENGTH * 0.6, bz * 2.2)
		add_child(tip_light)
		_tendril_lights.append(tip_light)

## Spawns blue Hunter mana flame particle aura
func _spawn_mana_flame_particles() -> void:
	if _void_particles and is_instance_valid(_void_particles):
		return
	var gp := GPUParticles3D.new()
	gp.name = "MonarchManaFlames"
	gp.amount = 120
	gp.lifetime = 1.2
	gp.position = Vector3(0, 0.9, 0)
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 45.0
	pm.initial_velocity_min = 0.6
	pm.initial_velocity_max = 2.2
	pm.gravity = Vector3(0, 0.2, 0) # upward rising flame
	pm.color = Color(0.12, 0.45, 0.95, 0.8) # Electric Solo Leveling Blue
	pm.scale_min = 0.06
	pm.scale_max = 0.18
	gp.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.1, 0.1)
	gp.draw_pass_1 = q
	add_child(gp)
	_void_particles = gp

# ─────────────────── SOLO LEVELING SYSTEM WINDOW ───────────────

## Displays the 3D holographic blue floating window
func show_system_window(title: String, subtitle: String) -> void:
	if _system_window_mesh and is_instance_valid(_system_window_mesh):
		_system_window_mesh.queue_free()

	_system_window_mesh = MeshInstance3D.new()
	_system_window_mesh.name = "HolographicSystemWindow"
	var quad := QuadMesh.new()
	quad.size = Vector2(2.6, 1.3)
	_system_window_mesh.mesh = quad
	_system_window_mesh.position = Vector3(0, 1.8, -1.5)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.04, 0.15, 0.35, 0.75) # Cyber Monarch Blue
	mat.emission_enabled = true
	mat.emission = Color(0.1, 0.5, 1.0)
	mat.emission_energy_multiplier = 2.2
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_system_window_mesh.material_override = mat

	add_child(_system_window_mesh)
	emit_signal("system_window_displayed", title, subtitle)

## Closes the holographic window with glass shatter SFX
func dismiss_system_window() -> void:
	if _system_window_mesh and is_instance_valid(_system_window_mesh):
		_system_window_mesh.queue_free()
		_system_window_mesh = null

	# Glass shatter acoustic feedback
	if is_inside_tree():
		var audio := AudioStreamPlayer.new()
		add_child(audio)
		audio.stream = ProceduralCinematicAudio.create_glass_shatter_sfx()
		audio.play()
		audio.finished.connect(func(): audio.queue_free())

# ─────────────────── SHADOW EXTRACTION (ARISE) ─────────────────

## Executes the iconic "ARISE // 起きろ" shadow extraction on fallen enemy
func trigger_shadow_extraction(target_enemy: Node) -> Dictionary:
	var enemy_name: String = target_enemy.name if target_enemy else "Fallen Aberration"

	if is_inside_tree():
		var audio := AudioStreamPlayer.new()
		add_child(audio)
		audio.stream = ProceduralCinematicAudio.create_energy_blade_draw_sfx()
		audio.play()
		audio.finished.connect(func(): audio.queue_free())

	emit_signal("shadow_extraction_performed", enemy_name)

	return {
		"success": true,
		"command": "ARISE // 起きろ",
		"target_name": enemy_name,
		"shadow_rank": "SHADOW_INFANTRY_ELITE",
		"loyalty": 100.0
	}

# ─────────────────── UPDATE & TEARDOWN ─────────────────────────

func _process(delta: float) -> void:
	if is_monarch_active:
		_time_accum += delta
		_awakening_timer -= delta
		# Sinusoidal breathing sway on tendril wings
		for i in range(_tendril_nodes.size()):
			var node = _tendril_nodes[i]
			if is_instance_valid(node):
				node.rotation.x = deg_to_rad(35.0 + sin(_time_accum * 3.5 + i) * 12.0)
				node.rotation.z = deg_to_rad(cos(_time_accum * 2.8 + i) * 8.0)
		if _awakening_timer <= 0.0:
			deactivate_monarch_mode()

func deactivate_monarch_mode() -> void:
	is_monarch_active = false
	for t in _tendril_nodes:
		if is_instance_valid(t):
			t.queue_free()
	_tendril_nodes.clear()
	for l in _tendril_lights:
		if is_instance_valid(l):
			l.queue_free()
	_tendril_lights.clear()
	if is_instance_valid(_void_particles):
		_void_particles.queue_free()
		_void_particles = null
	dismiss_system_window()
	emit_signal("monarch_mode_deactivated")

func _exit_tree() -> void:
	deactivate_monarch_mode()
	for child in get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.queue_free()

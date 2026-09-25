class_name SpecimenEX000
extends CharacterBody3D

signal hp_changed(current_hp: float, max_hp: float)
signal phase_changed(new_phase: int)
signal stagger_changed(is_staggered: bool)
signal slam_warning(is_active: bool)
signal shockwave_triggered(center: Vector3, radius: float)
signal boss_defeated()

const MAX_HP: float = 1000.0
const PHASE2_THRESHOLD: float = 350.0

var hp: float = MAX_HP
var phase: int = 1
var is_staggered: bool = false
var stagger_timer: float = 0.0

var attack_cooldown: float = 2.0
var attack_count: int = 0
var is_slam_windup: bool = false
var slam_windup_timer: float = 0.0
var shockwave_timer: float = 0.0
var shockwave_radius: float = 0.5

@export var target_player: Node3D

@onready var visual_root: Node3D = $ModelRoot if has_node("ModelRoot") else self
@onready var telegraph_ring: Node3D = $SlamTelegraphRing if has_node("SlamTelegraphRing") else null
@onready var target_reticle: Node3D = $TargetReticle if has_node("TargetReticle") else null
@onready var core_light: OmniLight3D = $ModelRoot/BioEnergyCoreLight if has_node("ModelRoot/BioEnergyCoreLight") else null

func _ready() -> void:
	emit_signal("hp_changed", hp, MAX_HP)
	if telegraph_ring:
		telegraph_ring.visible = false
	if target_reticle:
		target_reticle.visible = false
	if not core_light:
		core_light = find_child("BioEnergyCoreLight", true, false) as OmniLight3D
	if core_light:
		core_light.light_color = Color(0, 0.94, 1, 1)
		core_light.light_energy = 3.2

func set_targeted(active: bool) -> void:
	if not target_reticle:
		target_reticle = find_child("TargetReticle", true, false)
	if target_reticle:
		target_reticle.visible = active

func _physics_process(delta: float) -> void:
	if hp <= 0.0:
		return

	# Handle Stagger
	if is_staggered:
		stagger_timer -= delta
		if stagger_timer <= 0.0:
			is_staggered = false
			emit_signal("stagger_changed", false)
		return

	# Handle Slam Windup (0.55s telegraph)
	if is_slam_windup:
		slam_windup_timer -= delta
		if telegraph_ring:
			telegraph_ring.visible = true
			var t_prog = 1.0 - (slam_windup_timer / 0.55)
			telegraph_ring.scale = Vector3(0.5 + t_prog * 3.8, 1.0, 0.5 + t_prog * 3.8)
		if slam_windup_timer <= 0.0:
			execute_ground_slam()
		return

	# Handle Expanding Shockwave
	if shockwave_timer > 0.0:
		shockwave_timer -= delta
		var progress: float = 1.0 - (shockwave_timer / 0.75)
		shockwave_radius = 0.5 + progress * 3.8
		if telegraph_ring:
			telegraph_ring.visible = true
			telegraph_ring.scale = Vector3(shockwave_radius, 1.0, shockwave_radius)
		emit_signal("shockwave_triggered", global_position, shockwave_radius)
	else:
		if telegraph_ring and not is_slam_windup:
			telegraph_ring.visible = false

	# AI Tracking & Attack Selection
	if target_player:
		var diff: Vector3 = target_player.global_position - global_position
		diff.y = 0.0
		var dist: float = diff.length()

		# Rotate to face player
		if dist > 0.1:
			var target_yaw: float = atan2(diff.x, diff.z)
			rotation.y = lerp_angle(rotation.y, target_yaw, 8.0 * delta)

		var move_speed: float = 2.2 if phase == 2 else 1.4
		if dist > 2.2 and dist < 15.0:
			velocity.x = (diff.normalized().x) * move_speed
			velocity.z = (diff.normalized().z) * move_speed
		else:
			velocity.x = move_toward(velocity.x, 0, 4.0 * delta)
			velocity.z = move_toward(velocity.z, 0, 4.0 * delta)

		attack_cooldown -= delta
		if dist <= 3.2 and attack_cooldown <= 0.0:
			attack_cooldown = 1.8 if phase == 2 else 2.5
			attack_count += 1
			if phase == 2 and attack_count % 2 == 1:
				start_slam_windup()
			else:
				claw_attack()

	move_and_slide()

func start_slam_windup() -> void:
	is_slam_windup = true
	slam_windup_timer = 0.55
	emit_signal("slam_warning", true)

const ImpactSpawner = preload("res://scripts/combat/impact_spawner.gd")

func execute_ground_slam() -> void:
	is_slam_windup = false
	emit_signal("slam_warning", false)
	shockwave_timer = 0.75
	shockwave_radius = 0.5

	var parent = get_parent()
	if parent:
		var slam_pos = global_position if is_inside_tree() else position
		ImpactSpawner.spawn_boss_slam_crater(parent, slam_pos)

	if target_player and target_player.has_method("take_damage"):
		var cam = target_player.get("player_camera") as Camera3D
		if cam:
			ImpactSpawner.trigger_screen_shake(cam, 0.22, 0.32)
		var dist: float = global_position.distance_to(target_player.global_position) if is_inside_tree() else position.distance_to(target_player.position)
		if dist <= 4.2:
			target_player.take_damage(30.0, self)

func claw_attack() -> void:
	if target_player and target_player.has_method("take_damage"):
		var dist: float = global_position.distance_to(target_player.global_position)
		if dist <= 2.6:
			target_player.take_damage(25.0, self)

func apply_counter_stagger() -> void:
	is_slam_windup = false
	emit_signal("slam_warning", false)
	is_staggered = true
	stagger_timer = 2.8
	emit_signal("stagger_changed", true)

func take_damage(amount: float, hit_source_pos: Vector3 = Vector3.ZERO) -> void:
	# Directional hit flinch & recoil
	if hit_source_pos != Vector3.ZERO:
		var diff: Vector3 = (global_position if is_inside_tree() else position) - hit_source_pos
		diff.y = 0.0
		if diff.length() > 0.01:
			var recoil_dir := diff.normalized()
			velocity += recoil_dir * clampf(amount * 0.05, 0.8, 5.0)
		if visual_root:
			visual_root.rotation.z = randf_range(-0.12, 0.12)
			var tree := get_tree() if is_inside_tree() else null
			if tree:
				var tween := tree.create_tween()
				tween.tween_property(visual_root, "rotation:z", 0.0, 0.16)

	# Kinetic counter trigger during slam windup
	if is_slam_windup:
		is_slam_windup = false
		emit_signal("slam_warning", false)
		is_staggered = true
		stagger_timer = 3.5
		emit_signal("stagger_changed", true)
		amount *= 2.0 # 2x damage during counter stagger
	elif is_staggered:
		amount *= 2.0

	hp = max(0.0, hp - amount)
	emit_signal("hp_changed", hp, MAX_HP)

	# Phase 2 Transition
	if hp <= PHASE2_THRESHOLD and phase == 1:
		phase = 2
		emit_signal("phase_changed", 2)
		if not core_light:
			core_light = find_child("BioEnergyCoreLight", true, false) as OmniLight3D
		if core_light:
			core_light.light_color = Color(1.0, 0.12, 0.25, 1.0)
			core_light.light_energy = 6.0

	if hp <= 0.0 and not is_dying:
		trigger_dissolve_defeat()

var is_dying: bool = false
const DissolveShader = preload("res://shaders/monster_dissolve.gdshader")

func trigger_dissolve_defeat() -> void:
	if is_dying:
		return
	is_dying = true
	emit_signal("boss_defeated")
	set_targeted(false)

	var dissolve_mat := ShaderMaterial.new()
	dissolve_mat.shader = DissolveShader
	dissolve_mat.set_shader_parameter("dissolve_amount", 0.0)
	dissolve_mat.set_shader_parameter("burn_color", Color(1.0, 0.15, 0.25, 1.0))

	if visual_root:
		for child in visual_root.find_children("*", "MeshInstance3D", true, false):
			(child as MeshInstance3D).material_override = dissolve_mat

	var tree = get_tree() if is_inside_tree() else null
	if tree:
		var tween := tree.create_tween()
		tween.tween_method(func(val: float): dissolve_mat.set_shader_parameter("dissolve_amount", val), 0.0, 1.0, 2.4)
		tween.tween_callback(func(): visible = false)

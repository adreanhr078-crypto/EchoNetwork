class_name Sector11SecurityDroid
extends CharacterBody3D

## Sector 11 Autonomous Security Drone
## Patrols facility corridors, fires stun lasers, and provides combat practice.

signal hp_changed(current_hp: float, max_hp: float)
signal droid_defeated(droid_node: Node)

const MAX_HP: float = 120.0
var hp: float = MAX_HP
var is_dead: bool = false
var is_staggered: bool = false
var stagger_timer: float = 0.0

var attack_cooldown: float = 2.2
var is_charging_laser: bool = false
var charge_timer: float = 0.0

@export var target_player: Node3D = null

@onready var scanner_light: OmniLight3D = $ModelRoot/ScannerLight if has_node("ModelRoot/ScannerLight") else null
@onready var telegraph_beam: MeshInstance3D = $ModelRoot/TelegraphBeam if has_node("ModelRoot/TelegraphBeam") else null
@onready var spark_particles: GPUParticles3D = $ModelRoot/Sparks if has_node("ModelRoot/Sparks") else null

var _hover_time: float = 0.0
var _base_y: float = 1.15

func _ready() -> void:
	add_to_group("enemies")
	add_to_group("damageable")
	emit_signal("hp_changed", hp, MAX_HP)
	if telegraph_beam:
		telegraph_beam.visible = false

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	_hover_time += delta
	# Hover bobbing
	position.y = _base_y + sin(_hover_time * 2.8) * 0.08

	if is_staggered:
		stagger_timer -= delta
		if stagger_timer <= 0.0:
			is_staggered = false
		move_and_slide()
		return

	if not target_player:
		var players = get_tree().get_nodes_in_group("player") if is_inside_tree() else []
		if players.size() > 0:
			target_player = players[0]
		else:
			var parent = get_parent()
			if parent and parent.has_node("EchoPlayer"):
				target_player = parent.get_node("EchoPlayer")

	if not target_player:
		return

	var diff: Vector3 = target_player.global_position - global_position
	diff.y = 0.0
	var dist: float = diff.length()

	# Rotate to face player
	if dist > 0.2:
		var target_yaw: float = atan2(diff.x, diff.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, 7.0 * delta)

	# Movement & Combat Tracking
	if is_charging_laser:
		charge_timer -= delta
		velocity = Vector3.ZERO
		if charge_timer <= 0.0:
			_fire_laser()
	else:
		attack_cooldown -= delta
		if dist > 2.8 and dist < 16.0:
			var move_speed: float = 2.4
			velocity.x = (diff.normalized().x) * move_speed
			velocity.z = (diff.normalized().z) * move_speed
		else:
			velocity.x = move_toward(velocity.x, 0.0, 5.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 5.0 * delta)

		if dist <= 4.5 and attack_cooldown <= 0.0:
			_start_laser_charge()

	move_and_slide()

func _start_laser_charge() -> void:
	is_charging_laser = true
	charge_timer = 0.45
	if telegraph_beam:
		telegraph_beam.visible = true
	if scanner_light:
		scanner_light.light_color = Color(1.0, 0.1, 0.1, 1.0)
		scanner_light.light_energy = 4.0

func _fire_laser() -> void:
	is_charging_laser = false
	attack_cooldown = 2.2
	if telegraph_beam:
		telegraph_beam.visible = false
	if scanner_light:
		scanner_light.light_color = Color(0.0, 0.9, 1.0, 1.0)
		scanner_light.light_energy = 2.0

	# Deal damage if player in line of sight
	if target_player and target_player.has_method("take_damage"):
		var dist = global_position.distance_to(target_player.global_position)
		if dist <= 5.5:
			target_player.take_damage(12.0, self)
			var impact_spawner = load("res://scripts/combat/impact_spawner.gd")
			if impact_spawner:
				var cam = target_player.get("player_camera") as Camera3D
				if cam:
					impact_spawner.trigger_screen_shake(cam, 0.15, 0.2)

func take_damage(amount: float, hit_source_pos: Vector3 = Vector3.ZERO) -> void:
	if is_dead:
		return

	hp -= amount
	emit_signal("hp_changed", hp, MAX_HP)

	# Hit flinch
	is_staggered = true
	stagger_timer = 0.25
	is_charging_laser = false
	if telegraph_beam:
		telegraph_beam.visible = false

	if hit_source_pos != Vector3.ZERO:
		var knock_dir = (global_position - hit_source_pos).normalized()
		knock_dir.y = 0.0
		velocity = knock_dir * 3.8

	# Spawn Damage Numbers
	var spawner = load("res://scripts/combat/damage_number_spawner.gd")
	if spawner:
		spawner.spawn_damage_number(self, amount, amount > 40.0)

	# Spawn sparks & Sumi-e Ink
	var impact_spawner = load("res://scripts/combat/impact_spawner.gd")
	if impact_spawner:
		impact_spawner.spawn_impact_burst(get_parent(), global_position, amount > 40.0)

	if hp <= 0.0:
		_die()

func _die() -> void:
	is_dead = true
	hp = 0.0
	velocity = Vector3.ZERO
	emit_signal("droid_defeated", self)

	# Sound & explosion
	var tree = get_tree() if is_inside_tree() else null
	if tree:
		var tween = tree.create_tween()
		tween.tween_property(self, "scale", Vector3.ZERO, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tween.tween_callback(queue_free)
	else:
		queue_free()

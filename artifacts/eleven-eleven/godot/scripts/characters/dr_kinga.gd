class_name DrKinga
extends CharacterBody3D

## Dr. Kinga — Chief Cybernetic Neuro-Scientist
## Dynamic boss encounter with real-time in-game dialogue, hexagonal energy shield,
## neural laser blasts, and toxic syringe lunges. Player retains 100% movement freedom.

signal confrontation_started()
signal dialogue_advanced(line_index: int)
signal injection_administered()
signal scientist_terrified()
signal kinga_defeated()
signal hp_changed(current_hp: float, max_hp: float)

enum State {
	IDLE,
	CONFRONTATION,
	ADMINISTERING_INJECTION,
	OBSERVING_TORTURE,
	TERRIFIED,
	IN_COMBAT
}

var current_state: State = State.IDLE

const MAX_HP: float = 600.0
var hp: float = MAX_HP
var is_active: bool = false
var is_defeated: bool = false
var is_staggered: bool = false
var stagger_timer: float = 0.0

# Combat Abilities
var hex_shield_active: bool = true
var hex_shield_health: int = 3
var attack_cooldown: float = 2.0
var is_firing_laser: bool = false
var laser_charge_timer: float = 0.0
var is_lunging: bool = false
var lunge_timer: float = 0.0
var dialogue_index: int = 0
var dialogue_timer: float = 0.0

@export var target_player: Node3D = null

func start_confrontation() -> void:
	current_state = State.CONFRONTATION
	emit_signal("confrontation_started")

func prepare_injection() -> void:
	current_state = State.ADMINISTERING_INJECTION
	if syringe_glow:
		syringe_glow.visible = true
		syringe_glow.light_color = Color(0.1, 1.0, 0.35, 1.0)
		syringe_glow.light_energy = 3.5

func administer_injection() -> void:
	if syringe_glow:
		syringe_glow.light_color = Color(1.0, 0.1, 0.25, 1.0)
	emit_signal("injection_administered")

var _monocle_light: OmniLight3D
var monocle_light: OmniLight3D:
	get:
		if not _monocle_light:
			_monocle_light = get_node_or_null("MonocleLight") as OmniLight3D
			if not _monocle_light:
				_monocle_light = find_child("MonocleLight", true, false) as OmniLight3D
		if _monocle_light and not _monocle_light.visible:
			_monocle_light.visible = true
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

var _hex_shield: MeshInstance3D
var hex_shield: MeshInstance3D:
	get:
		if not _hex_shield:
			_hex_shield = get_node_or_null("HexShield") as MeshInstance3D
			if not _hex_shield:
				_hex_shield = find_child("HexShield", true, false) as MeshInstance3D
		return _hex_shield
	set(val):
		_hex_shield = val

var _laser_beam: MeshInstance3D
var laser_beam: MeshInstance3D:
	get:
		if not _laser_beam:
			_laser_beam = get_node_or_null("NeuralLaserBeam") as MeshInstance3D
			if not _laser_beam:
				_laser_beam = find_child("NeuralLaserBeam", true, false) as MeshInstance3D
		return _laser_beam
	set(val):
		_laser_beam = val

var _model_root: Node3D
var model_root: Node3D:
	get:
		if not _model_root:
			_model_root = get_node_or_null("Model") as Node3D
			if not _model_root:
				_model_root = find_child("Model", true, false) as Node3D
		return _model_root
	set(val):
		_model_root = val

const DIALOGUE_LINES: Array[String] = [
	"«النموذج EX-011... هل تجاوزت حقول الحجر الصحي؟! كلما أظهرت مقاومة أصبحت أكثر قيمة للتشريح!»",
	"«مشابكك العصبية صُنعت بيدي! لن تستطيع التمرد على صانعك يا ملك التجارب الفاشلة!»",
	"«مستحيل... معدل نبضك لا يرتفع خوفاً... بل يتناغم مع هاوية المحيط المظلمة؟!»"
]

func _ready() -> void:
	add_to_group("enemies")
	add_to_group("damageable")
	emit_signal("hp_changed", hp, MAX_HP)
	if hex_shield:
		hex_shield.visible = false
	if laser_beam:
		laser_beam.visible = false
	if syringe_glow:
		syringe_glow.visible = false
	if monocle_light:
		monocle_light.visible = true
		monocle_light.light_color = Color(1.0, 0.15, 0.1, 1.0)
		monocle_light.light_energy = 2.5

func start_combat_encounter(player: Node3D) -> void:
	target_player = player
	is_active = true
	hex_shield_active = true
	hex_shield_health = 3
	if hex_shield:
		hex_shield.visible = true
	emit_signal("confrontation_started")
	_speak_line(0)

func _speak_line(idx: int) -> void:
	dialogue_index = idx
	dialogue_timer = 5.0
	emit_signal("dialogue_advanced", idx)
	var tree = get_tree() if is_inside_tree() else null
	if tree:
		var hud = tree.get_first_node_in_group("hud")
		if not hud:
			hud = get_parent().find_child("GameplayHUD", true, false) if get_parent() else null
		if hud and hud.has_method("notify_in_game_dialogue"):
			hud.notify_in_game_dialogue("DR. KINGA", DIALOGUE_LINES[idx], Color(1.0, 0.25, 0.2))

func _physics_process(delta: float) -> void:
	if not is_active or is_defeated:
		return

	# In-game dialogue timer
	if dialogue_timer > 0.0:
		dialogue_timer -= delta
		if dialogue_timer <= 0.0 and dialogue_index < DIALOGUE_LINES.size() - 1:
			_speak_line(dialogue_index + 1)

	# Handle Stagger
	if is_staggered:
		stagger_timer -= delta
		if stagger_timer <= 0.0:
			is_staggered = false
			hex_shield_active = true
			hex_shield_health = 3
			if hex_shield:
				hex_shield.visible = true
		move_and_slide()
		return

	if not target_player:
		var players = get_tree().get_nodes_in_group("player") if is_inside_tree() else []
		if players.size() > 0:
			target_player = players[0]
		else:
			return

	var diff: Vector3 = target_player.global_position - global_position
	diff.y = 0.0
	var dist: float = diff.length()

	# Rotate to face player smoothly
	if dist > 0.1:
		var target_yaw: float = atan2(diff.x, diff.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, 8.0 * delta)

	# Combat State Execution
	if is_firing_laser:
		laser_charge_timer -= delta
		velocity = Vector3.ZERO
		if laser_charge_timer <= 0.0:
			_execute_neural_laser_hit()
	elif is_lunging:
		lunge_timer -= delta
		if lunge_timer <= 0.0:
			is_lunging = false
			if syringe_glow:
				syringe_glow.visible = false
	else:
		# Tactical Spacing & Strafing (maintain 4-7m)
		attack_cooldown -= delta
		if dist < 4.0:
			# Back away
			velocity.x = -diff.normalized().x * 2.8
			velocity.z = -diff.normalized().z * 2.8
		elif dist > 7.5:
			# Close in
			velocity.x = diff.normalized().x * 3.2
			velocity.z = diff.normalized().z * 3.2
		else:
			# Lateral tactical strafing
			var strafe_dir = diff.normalized().cross(Vector3.UP)
			velocity.x = strafe_dir.x * 2.0
			velocity.z = strafe_dir.z * 2.0

		if attack_cooldown <= 0.0:
			if dist <= 4.5 and randf() > 0.5:
				_start_syringe_lunge(diff)
			else:
				_start_neural_laser()

	move_and_slide()

func _start_neural_laser() -> void:
	is_firing_laser = true
	laser_charge_timer = 0.5
	attack_cooldown = 2.8
	if laser_beam:
		laser_beam.visible = true
		laser_beam.scale = Vector3(0.3, 1.0, 0.3)
	if monocle_light:
		monocle_light.light_energy = 5.5

func _execute_neural_laser_hit() -> void:
	is_firing_laser = false
	if laser_beam:
		laser_beam.scale = Vector3(1.2, 1.0, 1.2)
		var tree = get_tree() if is_inside_tree() else null
		if tree:
			tree.create_timer(0.15).timeout.connect(func(): if laser_beam: laser_beam.visible = false)
		else:
			laser_beam.visible = false

	if monocle_light:
		monocle_light.light_energy = 2.4

	if target_player and target_player.has_method("take_damage"):
		var dist = global_position.distance_to(target_player.global_position)
		if dist <= 12.0:
			target_player.take_damage(18.0, self)
			var impact_spawner = load("res://scripts/combat/impact_spawner.gd")
			if impact_spawner:
				var cam = target_player.get("player_camera") as Camera3D
				if cam:
					impact_spawner.trigger_screen_shake(cam, 0.22, 0.3)

func _start_syringe_lunge(diff: Vector3) -> void:
	is_lunging = true
	lunge_timer = 0.4
	attack_cooldown = 2.4
	if syringe_glow:
		syringe_glow.visible = true
		syringe_glow.light_color = Color(0.1, 1.0, 0.35, 1.0)
	velocity = diff.normalized() * 7.5

	if target_player and target_player.has_method("take_damage"):
		var tree = get_tree() if is_inside_tree() else null
		if tree:
			tree.create_timer(0.2).timeout.connect(func():
				if is_lunging and global_position.distance_to(target_player.global_position) <= 2.8:
					target_player.take_damage(25.0, self)
			)

func take_damage(amount: float, hit_source_pos: Vector3 = Vector3.ZERO) -> void:
	if is_defeated:
		return

	# Hex Shield Absorption
	if hex_shield_active:
		hex_shield_health -= 1
		# Shield pulse
		if hex_shield:
			var tree = get_tree() if is_inside_tree() else null
			if tree:
				var tween = tree.create_tween()
				tween.tween_property(hex_shield, "scale", Vector3(1.3, 1.3, 1.3), 0.08)
				tween.tween_property(hex_shield, "scale", Vector3(1.0, 1.0, 1.0), 0.12)
		if hex_shield_health <= 0:
			hex_shield_active = false
			if hex_shield:
				hex_shield.visible = false
			is_staggered = true
			stagger_timer = 2.5
			# Shield shatter sound and particles
			var impact_spawner = load("res://scripts/combat/impact_spawner.gd")
			if impact_spawner and get_parent():
				impact_spawner.spawn_impact_burst(get_parent(), global_position + Vector3(0, 1.0, 0), true)
		return

	hp = max(0.0, hp - amount)
	emit_signal("hp_changed", hp, MAX_HP)

	# Flinch
	if hit_source_pos != Vector3.ZERO:
		var knock = (global_position - hit_source_pos).normalized()
		knock.y = 0.0
		velocity = knock * 2.8

	# Damage Numbers
	var spawner = load("res://scripts/combat/damage_number_spawner.gd")
	if spawner:
		spawner.spawn_damage_number(self, amount, amount > 50.0)

	var impact_spawner_ref = load("res://scripts/combat/impact_spawner.gd")
	if impact_spawner_ref and is_inside_tree() and get_parent():
		impact_spawner_ref.spawn_impact_burst(get_parent(), global_position, amount > 50.0)

	# Defeat / Climax Trigger at 20% HP
	if hp <= 120.0 and not is_defeated:
		trigger_climax_defeat()

func trigger_climax_defeat() -> void:
	is_defeated = true
	velocity = Vector3.ZERO
	if hex_shield:
		hex_shield.visible = false
	if laser_beam:
		laser_beam.visible = false
	react_to_zero_singularity()
	emit_signal("kinga_defeated")

func react_to_zero_singularity() -> void:
	current_state = State.TERRIFIED
	if monocle_light:
		monocle_light.light_color = Color(1.0, 0.05, 0.05, 1.0)
		monocle_light.light_energy = 6.0
	# Stumble backward in terror
	var tree = get_tree() if is_inside_tree() else null
	if tree:
		var tween = tree.create_tween()
		tween.tween_property(self, "position", position + transform.basis.z * 4.0, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	emit_signal("scientist_terrified")

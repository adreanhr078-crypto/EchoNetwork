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
var max_hp: float:
	get:
		return MAX_HP
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

var _skeleton: Skeleton3D
var skeleton: Skeleton3D:
	get:
		if not _skeleton or not is_instance_valid(_skeleton):
			_setup_skeleton()
		return _skeleton
	set(val):
		_skeleton = val

# Procedural Skeletal Controller state
var _bones: Dictionary = {}
var _axes: Dictionary = {}
var _rests: Dictionary = {}
var _anim_phase: float = 0.0
var _walk_phase: float = 0.0
var reduced_motion: bool = false

const DIALOGUE_LINES: Array[String] = [
	"«النموذج EX-011... هل تجاوزت حقول الحجر الصحي؟! كلما أظهرت مقاومة أصبحت أكثر قيمة للتشريح!»",
	"«مشابكك العصبية صُنعت بيدي! لن تستطيع التمرد على صانعك يا ملك التجارب الفاشلة!»",
	"«مستحيل... معدل نبضك لا يرتفع خوفاً... بل يتناغم مع هاوية المحيط المظلمة؟!»"
]

func _ready() -> void:
	add_to_group("enemies")
	add_to_group("damageable")
	_setup_skeleton()
	emit_signal("hp_changed", hp, MAX_HP)
	if hex_shield:
		hex_shield.visible = false
	if laser_beam:
		laser_beam.visible = false
	if syringe_glow:
		syringe_glow.visible = false
	if monocle_light:
		monocle_light.visible = true
		# Red #FF261A ominous rim light at 2.4 energy
		monocle_light.light_color = Color(1.0, 0.14902, 0.10196, 1.0)
		monocle_light.light_energy = 2.4
	_apply_anime_cel_shading()

func _apply_anime_cel_shading() -> void:
	var kinga_model := get_node_or_null("Model")
	if kinga_model:
		var cel_shader = load("res://shaders/anime_cel.gdshader")
		var outline_shader = load("res://shaders/anime_outline.gdshader")
		var applicator = load("res://scripts/combat/shader_applicator.gd")
		if cel_shader and applicator:
			applicator.apply_cel_shader(
				kinga_model,
				cel_shader,
				Color(1.0, 1.0, 1.0, 1.0),
				Color(1.0, 0.149, 0.102, 1.0),
				Color(0.28, 0.24, 0.35, 1.0),
				2.8,
				0.85,
				outline_shader
			)

func _process(delta: float) -> void:
	update_procedural_skeleton(delta)

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

# ---------------------------------------------------------------------------
# Procedural Skeletal Controller Methods
# ---------------------------------------------------------------------------

func _setup_skeleton() -> void:
	if _skeleton and is_instance_valid(_skeleton) and _bones.size() > 0:
		return
	_skeleton = find_child("Skeleton3D", true, false) as Skeleton3D
	if not _skeleton:
		return
	_bones.clear()
	_axes.clear()
	_rests.clear()
	for i in _skeleton.get_bone_count():
		var bname: String = _skeleton.get_bone_name(i)
		_bones[bname] = i
		_axes[bname] = _skeleton.get_bone_global_rest(i).basis.inverse()
		_rests[bname] = _skeleton.get_bone_rest(i).basis.get_rotation_quaternion()

func _reset_bone_poses() -> void:
	if not _skeleton:
		return
	for index in _bones.values():
		_skeleton.reset_bone_pose(index)

func _set_bone_rotation(label: String, axis: Vector3, degrees: float) -> void:
	if not _skeleton or not _bones.has(label):
		return
	var b_idx: int = _bones[label]
	var local: Vector3 = (_axes[label] * axis).normalized()
	_skeleton.set_bone_pose_rotation(b_idx, _rests[label] * Quaternion(local, deg_to_rad(degrees)))

func _add_bone_rotation(label: String, axis: Vector3, degrees: float) -> void:
	if not _skeleton or not _bones.has(label):
		return
	var b_idx: int = _bones[label]
	var local: Vector3 = (_axes[label] * axis).normalized()
	var current: Quaternion = _skeleton.get_bone_pose_rotation(b_idx)
	_skeleton.set_bone_pose_rotation(b_idx, current * Quaternion(local, deg_to_rad(degrees)))

func update_procedural_skeleton(delta: float) -> void:
	if not _skeleton or not is_instance_valid(_skeleton) or _bones.size() == 0:
		_setup_skeleton()
		if not _skeleton:
			return

	_anim_phase += delta
	_reset_bone_poses()

	# 1. Terrified / Climax Defeat pose
	if current_state == State.TERRIFIED or is_defeated:
		_apply_terrified_cower_pose(delta)
	# 2. Stagger / Flinch pose
	elif is_staggered:
		_apply_stagger_flinch_pose(delta)
	# 3. Firing Neural Laser
	elif is_firing_laser:
		_apply_neural_laser_pose(delta)
	# 4. Syringe Lunge
	elif is_lunging:
		_apply_syringe_lunge_pose(delta)
	# 5. Injection Administering
	elif current_state == State.ADMINISTERING_INJECTION:
		_apply_injection_pose(delta)
	# 6. Locomotion / Moving
	elif velocity.length() > 0.1:
		_apply_locomotion_pose(delta)
	# 7. Idle Breathing
	else:
		_apply_idle_breathing_pose(delta)

func _apply_terrified_cower_pose(delta: float) -> void:
	var shiver: float = 0.0 if reduced_motion else sin(_anim_phase * 24.0) * 3.5
	var breath: float = 0.0 if reduced_motion else sin(_anim_phase * 2.5) * 2.0

	_set_bone_rotation("Spine", Vector3.BACK, 15.0 + breath)
	_set_bone_rotation("Spine1", Vector3.BACK, 12.0)
	_set_bone_rotation("Chest", Vector3.BACK, 18.0)

	_set_bone_rotation("Neck", Vector3.BACK, -12.0)
	_set_bone_rotation("Head", Vector3.BACK, -16.0 + shiver * 0.4)
	_add_bone_rotation("Head", Vector3.RIGHT, shiver * 0.5)

	_set_bone_rotation("RightShoulder", Vector3.UP, 15.0)
	_set_bone_rotation("LeftShoulder", Vector3.UP, -15.0)
	_add_bone_rotation("RightShoulder", Vector3.BACK, 10.0)
	_add_bone_rotation("LeftShoulder", Vector3.BACK, 10.0)

	_set_bone_rotation("RightArm", Vector3.BACK, 70.0)
	_add_bone_rotation("RightArm", Vector3.UP, -10.0)
	_set_bone_rotation("RightForeArm", Vector3.UP, 50.0)
	_add_bone_rotation("RightForeArm", Vector3.BACK, 15.0 + shiver)

	_set_bone_rotation("LeftArm", Vector3.BACK, 70.0)
	_add_bone_rotation("LeftArm", Vector3.UP, 10.0)
	_set_bone_rotation("LeftForeArm", Vector3.UP, -50.0)
	_add_bone_rotation("LeftForeArm", Vector3.BACK, 15.0 - shiver)

	_set_bone_rotation("LeftUpLeg", Vector3.BACK, 8.0)
	_set_bone_rotation("RightUpLeg", Vector3.BACK, -8.0)
	_set_bone_rotation("LeftLeg", Vector3.BACK, -12.0)
	_set_bone_rotation("RightLeg", Vector3.BACK, -10.0)

	for column in 5:
		for row in 2:
			var wave: float = 0.0 if reduced_motion else sin(_anim_phase * 14.0 + column) * 2.5
			_set_bone_rotation("Coat_%d_%d" % [column, row], Vector3.BACK, wave)

func _apply_stagger_flinch_pose(delta: float) -> void:
	var flinch_strength: float = 0.8 if reduced_motion else clampf(stagger_timer / 2.0, 0.4, 1.0)
	var tremor: float = 0.0 if reduced_motion else sin(_anim_phase * 18.0) * 3.5 * flinch_strength

	_set_bone_rotation("Spine", Vector3.BACK, -18.0 * flinch_strength)
	_set_bone_rotation("Spine1", Vector3.BACK, -12.0 * flinch_strength)
	_set_bone_rotation("Chest", Vector3.BACK, -22.0 * flinch_strength)
	_set_bone_rotation("Neck", Vector3.BACK, -8.0)
	_set_bone_rotation("Head", Vector3.BACK, -15.0 * flinch_strength + tremor)
	_add_bone_rotation("Head", Vector3.RIGHT, tremor * 0.5)

	_set_bone_rotation("LeftShoulder", Vector3.RIGHT, -12.0 * flinch_strength)
	_set_bone_rotation("RightShoulder", Vector3.RIGHT, 12.0 * flinch_strength)

	_set_bone_rotation("LeftArm", Vector3.BACK, -25.0 * flinch_strength)
	_set_bone_rotation("RightArm", Vector3.BACK, -20.0 * flinch_strength)
	_set_bone_rotation("LeftForeArm", Vector3.BACK, 22.0 * flinch_strength)
	_set_bone_rotation("RightForeArm", Vector3.BACK, 25.0 * flinch_strength)

	_set_bone_rotation("LeftUpLeg", Vector3.BACK, -14.0 * flinch_strength)
	_set_bone_rotation("RightUpLeg", Vector3.BACK, 14.0 * flinch_strength)

	for column in 5:
		for row in 2:
			var wave: float = 0.0 if reduced_motion else sin(_anim_phase * 8.0 + column * 0.8) * 6.0 * flinch_strength
			_set_bone_rotation("Coat_%d_%d" % [column, row], Vector3.BACK, wave)

func _apply_neural_laser_pose(delta: float) -> void:
	_set_bone_rotation("RightShoulder", Vector3.BACK, 8.0)
	_set_bone_rotation("RightArm", Vector3.BACK, 82.0)
	_set_bone_rotation("RightForeArm", Vector3.BACK, 12.0)

	_set_bone_rotation("Spine", Vector3.BACK, 4.0)
	_set_bone_rotation("Chest", Vector3.BACK, 8.0)
	_set_bone_rotation("Head", Vector3.BACK, -6.0)

	_set_bone_rotation("LeftArm", Vector3.BACK, -15.0)
	_set_bone_rotation("LeftForeArm", Vector3.BACK, 22.0)

	_set_bone_rotation("LeftUpLeg", Vector3.BACK, 10.0)
	_set_bone_rotation("RightUpLeg", Vector3.BACK, -10.0)

	for column in 5:
		for row in 2:
			var wave: float = -10.0 - row * 5.0 + (0.0 if reduced_motion else sin(_anim_phase * 10.0 + column) * 3.0)
			_set_bone_rotation("Coat_%d_%d" % [column, row], Vector3.BACK, wave)

func _apply_syringe_lunge_pose(delta: float) -> void:
	_set_bone_rotation("Spine", Vector3.BACK, 24.0)
	_set_bone_rotation("Spine1", Vector3.BACK, 15.0)
	_set_bone_rotation("Chest", Vector3.BACK, 18.0)
	_set_bone_rotation("Head", Vector3.BACK, -18.0)

	_set_bone_rotation("RightShoulder", Vector3.BACK, 15.0)
	_set_bone_rotation("RightArm", Vector3.BACK, 88.0)
	_set_bone_rotation("RightForeArm", Vector3.BACK, 6.0)

	_set_bone_rotation("LeftArm", Vector3.BACK, -35.0)
	_set_bone_rotation("LeftForeArm", Vector3.BACK, 15.0)

	_set_bone_rotation("LeftUpLeg", Vector3.BACK, 32.0)
	_set_bone_rotation("LeftLeg", Vector3.BACK, -28.0)
	_set_bone_rotation("RightUpLeg", Vector3.BACK, -32.0)
	_set_bone_rotation("RightLeg", Vector3.BACK, -10.0)

	for column in 5:
		for row in 2:
			_set_bone_rotation("Coat_%d_%d" % [column, row], Vector3.BACK, -24.0 - row * 10.0)

func _apply_injection_pose(delta: float) -> void:
	_set_bone_rotation("RightArm", Vector3.BACK, 55.0)
	_set_bone_rotation("RightForeArm", Vector3.BACK, 45.0)
	_set_bone_rotation("Spine", Vector3.BACK, 4.0)
	_set_bone_rotation("Chest", Vector3.BACK, 6.0)
	_set_bone_rotation("Head", Vector3.BACK, -8.0)

	var breath: float = 0.0 if reduced_motion else sin(_anim_phase * 1.8) * 1.5
	_add_bone_rotation("Chest", Vector3.BACK, breath)

	for column in 5:
		for row in 2:
			var wave: float = 0.0 if reduced_motion else sin(_anim_phase * 1.5 + column * 0.7) * (2.5 + row * 1.5)
			_set_bone_rotation("Coat_%d_%d" % [column, row], Vector3.BACK, wave)

func _apply_locomotion_pose(delta: float) -> void:
	var speed: float = velocity.length()
	_walk_phase += delta * speed * 3.8

	var swing_amp: float = 20.0 if reduced_motion else clampf(speed * 8.0, 16.0, 32.0)
	var leg_sin: float = 0.5 if reduced_motion else sin(_walk_phase)

	_set_bone_rotation("LeftUpLeg", Vector3.BACK, leg_sin * swing_amp)
	_set_bone_rotation("RightUpLeg", Vector3.BACK, -leg_sin * swing_amp)

	var left_knee: float = -maxf(0.0, -leg_sin) * (swing_amp * 0.85)
	var right_knee: float = -maxf(0.0, leg_sin) * (swing_amp * 0.85)
	_set_bone_rotation("LeftLeg", Vector3.BACK, left_knee)
	_set_bone_rotation("RightLeg", Vector3.BACK, right_knee)

	var arm_amp: float = swing_amp * 0.65
	_set_bone_rotation("LeftArm", Vector3.BACK, -leg_sin * arm_amp)
	_set_bone_rotation("RightArm", Vector3.BACK, leg_sin * arm_amp)
	_set_bone_rotation("LeftForeArm", Vector3.BACK, 15.0 + maxf(0.0, -leg_sin) * 8.0)
	_set_bone_rotation("RightForeArm", Vector3.BACK, 15.0 + maxf(0.0, leg_sin) * 8.0)

	_set_bone_rotation("Spine", Vector3.BACK, 4.0)
	_add_bone_rotation("Spine", Vector3.UP, -leg_sin * 3.0)
	_set_bone_rotation("Chest", Vector3.UP, leg_sin * 2.5)
	_set_bone_rotation("Head", Vector3.UP, -leg_sin * 1.5)

	for column in 5:
		for row in 2:
			var coat_lag: float = column * 0.6
			var coat_wave: float = 0.0 if reduced_motion else (sin(_walk_phase - coat_lag) * (8.0 + row * 4.0) - (speed * 2.8))
			_set_bone_rotation("Coat_%d_%d" % [column, row], Vector3.BACK, coat_wave)

func _apply_idle_breathing_pose(delta: float) -> void:
	var breath_sin: float = 0.0 if reduced_motion else sin(_anim_phase * 1.6)
	var breath_chest: float = breath_sin * 2.8
	var breath_spine: float = breath_sin * 1.6

	_set_bone_rotation("Spine", Vector3.BACK, breath_spine)
	_set_bone_rotation("Spine1", Vector3.BACK, breath_spine * 0.6)
	_set_bone_rotation("Chest", Vector3.BACK, breath_chest)
	_set_bone_rotation("Head", Vector3.BACK, -breath_chest * 0.35)

	_set_bone_rotation("LeftArm", Vector3.BACK, -2.0 + breath_spine * 0.4)
	_set_bone_rotation("RightArm", Vector3.BACK, -2.0 + breath_spine * 0.4)
	_set_bone_rotation("LeftForeArm", Vector3.BACK, 8.0)
	_set_bone_rotation("RightForeArm", Vector3.BACK, 8.0)

	_set_bone_rotation("LeftUpLeg", Vector3.BACK, 0.0)
	_set_bone_rotation("RightUpLeg", Vector3.BACK, 0.0)

	for column in 5:
		for row in 2:
			var coat_wave: float = 0.0 if reduced_motion else (sin(_anim_phase * 1.4 + column * 0.7) * (2.5 + row * 2.0))
			_set_bone_rotation("Coat_%d_%d" % [column, row], Vector3.BACK, coat_wave)


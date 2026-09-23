class_name EchoPlayer
extends CharacterBody3D

signal hp_changed(current_hp: float, max_hp: float)
signal stamina_changed(current_stamina: float, max_stamina: float)
signal combo_changed(combo_count: int, combo_multiplier: int)
signal perfect_dodge_triggered()
signal attack_hit(damage: int, is_crit: bool)
signal weapon_sheathed()
signal iai_charged()
signal iai_executed(damage: int)
signal shadow_step_executed(from_pos: Vector3, to_pos: Vector3)

const ImpactSpawner = preload("res://scripts/combat/impact_spawner.gd")
const GhostTrailSpawner = preload("res://scripts/player/ghost_trail_spawner.gd")
const EconomyManager = preload("res://scripts/systems/economy_manager.gd")
const PlayerInventory = preload("res://scripts/systems/player_inventory.gd")
const PlayerNeeds = preload("res://scripts/systems/player_needs.gd")
const LocomotionAnimController = preload("res://scripts/player/locomotion_anim_controller.gd")
const SpatialVoiceManagerScript = preload("res://scripts/audio/spatial_voice_manager.gd")

var wallet: EconomyManager = EconomyManager.new()
var inventory: PlayerInventory = PlayerInventory.new()
var needs: PlayerNeeds = PlayerNeeds.new()
var locomotion_controller: LocomotionAnimController = LocomotionAnimController.new()
var spatial_voice_manager: SpatialVoiceManagerScript = null
var nearby_interactables: Array = []

const MAX_HP: float = 200.0
const MAX_STAMINA: float = 100.0
const WALK_SPEED: float = 4.2
const SPRINT_SPEED: float = 7.2
const JUMP_VELOCITY: float = 5.4
const DODGE_SPEED: float = 9.8
const GRAVITY: float = 14.0

var hp: float = MAX_HP
var stamina: float = MAX_STAMINA
var is_invulnerable: bool = false
var is_dodging: bool = false
var dodge_timer: float = 0.0
var dodge_direction: Vector3 = Vector3.ZERO
var perfect_dodge_surge: bool = false

var combo_count: int = 0
var combo_multiplier: int = 1
var combo_reset_timer: float = 0.0

var is_charging_iai: bool = false
var iai_charge: float = 0.0
var mobile_input_vector: Vector2 = Vector2.ZERO
var ghost_trail_timer: float = 0.0

var _visual_root: Node3D = null
var visual_root: Node3D:
	get:
		if not _visual_root:
			_visual_root = get_node_or_null("ModelRoot") if has_node("ModelRoot") else self
		return _visual_root
	set(val):
		_visual_root = val
var animation_player: AnimationPlayer = null
var player_camera: Camera3D = null
var current_anim: String = ""
var is_locked_on: bool = false
var lock_target: Node3D = null

func _ready() -> void:
	if not locomotion_controller.is_inside_tree():
		add_child(locomotion_controller)
	# Instantiate and wire SpatialVoiceManager as a child of the player
	spatial_voice_manager = SpatialVoiceManagerScript.new()
	spatial_voice_manager.name = "SpatialVoiceManager"
	add_child(spatial_voice_manager)
	animation_player = find_child("AnimationPlayer", true, false)
	player_camera = find_child("Camera3D", true, false) as Camera3D
	if animation_player:
		for anim_name in animation_player.get_animation_list():
			var anim: Animation = animation_player.get_animation(anim_name)
			anim.loop_mode = Animation.LOOP_LINEAR
		play_anim("preset_biped_idle_001", 0.1)

	emit_signal("hp_changed", hp, MAX_HP)
	emit_signal("stamina_changed", stamina, MAX_STAMINA)

	# Strict Narrative Mandate: Zero's Eye and Shadow Wing are strictly dormant at start
	set_zero_eye_active(false)
	dismiss_zero_wing()

func play_anim(anim_name: String, blend_time: float = 0.2) -> void:
	if not animation_player:
		animation_player = find_child("AnimationPlayer", true, false)
	if not animation_player:
		return
	if not animation_player.has_animation(anim_name):
		return
	if current_anim == anim_name and animation_player.is_playing():
		return
	current_anim = anim_name
	animation_player.play(anim_name, blend_time)

func _physics_process(delta: float) -> void:
	# Add Gravity
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	# Handle Dodge Physics & I-Frames
	if is_dodging:
		dodge_timer -= delta
		velocity.x = dodge_direction.x * DODGE_SPEED
		velocity.z = dodge_direction.z * DODGE_SPEED
		ghost_trail_timer -= delta
		if ghost_trail_timer <= 0.0:
			ghost_trail_timer = 0.08
			var parent = get_parent()
			if parent:
				GhostTrailSpawner.spawn_ghost(parent, visual_root, 0.28, Color(0.0, 0.94, 1.0, 0.65))
		if dodge_timer <= 0.0:
			is_dodging = false
			is_invulnerable = false
		move_and_slide()
		return

	# Handle Iai Charging State
	if is_charging_iai:
		update_iai_charge(delta)

	# Handle Combo Reset Window (2.5s)
	if combo_count > 0:
		combo_reset_timer -= delta
		if combo_reset_timer <= 0.0:
			combo_count = 0
			combo_multiplier = 1
			emit_signal("combo_changed", combo_count, combo_multiplier)

	# Handle Jump
	if Input.is_action_just_pressed("jump") and is_on_floor():
		perform_jump()

	# Handle Dodge Input & Attack Canceling (Dodge Cancel)
	if Input.is_action_just_pressed("dodge") and stamina >= 15.0:
		is_attacking = false
		start_dodge()
		return

	# Handle 3-Hit Combo Reset Timer
	if combo_step_timer > 0.0:
		combo_step_timer -= delta
		if combo_step_timer <= 0.0:
			combo_step = 1

	# Handle Lock-On Toggle Input
	if Input.is_action_just_pressed("lock_on"):
		toggle_lock_on()

	# Lock-On Camera Orientation
	if is_locked_on and lock_target:
		var target_diff: Vector3 = lock_target.global_position - global_position
		target_diff.y = 0.0
		if target_diff.length() > 0.1:
			var lock_yaw: float = atan2(target_diff.x, target_diff.z)
			visual_root.rotation.y = lerp_angle(visual_root.rotation.y, lock_yaw, 10.0 * delta)

	# Dynamic FOV Warping
	var is_sprinting: bool = Input.is_action_pressed("sprint") and stamina > 5.0
	if player_camera:
		var target_fov: float = 82.0 if is_sprinting else 75.0
		player_camera.fov = lerp(player_camera.fov, target_fov, 6.0 * delta)

	# Attack & Iai Charge Input (Keyboard/Mouse)
	if Input.is_action_just_pressed("attack_light"):
		start_iai_charge()
	if Input.is_action_just_released("attack_light"):
		execute_iai_slash()

	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	if mobile_input_vector.length() > 0.05:
		input_dir = mobile_input_vector

	var direction: Vector3 = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	is_sprinting = is_sprinting and direction.length() > 0.1

	if is_sprinting:
		stamina = max(0.0, stamina - 12.0 * delta)
		emit_signal("stamina_changed", stamina, MAX_STAMINA)
	else:
		stamina = min(MAX_STAMINA, stamina + 18.0 * delta)
		emit_signal("stamina_changed", stamina, MAX_STAMINA)

	var current_speed: float = SPRINT_SPEED if is_sprinting else WALK_SPEED
	var loco_data: Dictionary = locomotion_controller.update(delta, input_dir, velocity.length(), is_sprinting, is_attacking)

	if loco_data["root_velocity"].length() > 0.1:
		velocity.x = loco_data["root_velocity"].x
		velocity.z = loco_data["root_velocity"].z
	elif loco_data["is_skid"]:
		velocity.x = move_toward(velocity.x, 0.0, 18.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 18.0 * delta)
	elif direction.length() > 0.1:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
		# Rotate visual model towards move direction unless locked-on
		if not is_locked_on or not lock_target:
			var target_yaw: float = atan2(direction.x, direction.z)
			var turn_diff: float = wrapf(target_yaw - visual_root.rotation.y, -PI, PI)
			visual_root.rotation.y = lerp_angle(visual_root.rotation.y, target_yaw, 14.0 * delta)
			# Procedural Lean into sharp turns (Genshin style banking)
			var lean_angle: float = clamp(turn_diff * 0.22, -0.28, 0.28)
			visual_root.rotation.z = lerp_angle(visual_root.rotation.z, -lean_angle, 8.0 * delta)
		play_anim(loco_data["anim_name"], 0.15)
	else:
		velocity.x = move_toward(velocity.x, 0.0, current_speed)
		velocity.z = move_toward(velocity.z, 0.0, current_speed)
		visual_root.rotation.z = lerp_angle(visual_root.rotation.z, 0.0, 10.0 * delta)
		play_anim(loco_data["anim_name"], 0.2)

	move_and_slide()

func perform_jump() -> void:
	if is_on_floor():
		velocity.y = JUMP_VELOCITY

func set_mobile_input_vector(vec: Vector2) -> void:
	mobile_input_vector = vec

func start_iai_charge() -> void:
	if is_sheathed:
		unsheath_weapon()
	is_charging_iai = true
	iai_charge = 0.0
	var katana = find_child("KatanaBlade", true, false)
	if katana:
		var glow = katana.find_child("BladeGlowLight", true, false) as OmniLight3D
		if glow:
			glow.light_energy = 3.5

func update_iai_charge(delta: float) -> void:
	if not is_charging_iai:
		return
	iai_charge = min(1.0, iai_charge + delta * 2.2)
	if iai_charge >= 1.0:
		emit_signal("iai_charged")
		var katana = find_child("KatanaBlade", true, false)
		if katana:
			var glow = katana.find_child("BladeGlowLight", true, false) as OmniLight3D
			if glow:
				glow.light_energy = 5.5

func execute_iai_slash(charge_ratio: float = -1.0) -> void:
	var eff_ratio: float = charge_ratio if charge_ratio >= 0.0 else iai_charge
	is_charging_iai = false
	iai_charge = 0.0

	var katana = find_child("KatanaBlade", true, false)
	if katana:
		var glow = katana.find_child("BladeGlowLight", true, false) as OmniLight3D
		if glow:
			glow.light_energy = 1.8

	# If charged >= 0.7 -> FULL CHARGED IAI SLASH: BLINK DASH + 180 (or 240) CRITICAL DAMAGE
	if eff_ratio >= 0.7:
		var parent = get_parent()
		var dash_dist: float = 5.5
		var dash_dir: Vector3 = -visual_root.transform.basis.z if visual_root else -transform.basis.z
		dash_dir.y = 0.0
		if dash_dir.length() < 0.1:
			dash_dir = -transform.basis.z
		dash_dir = dash_dir.normalized()

		var start_pos: Vector3 = position

		# Spawn Ghost Trail phantoms along trajectory (Purple/Black if Shadow Katana)
		if parent:
			var trail_col: Color = Color(0.18, 0.03, 0.38, 0.9) if is_shadow_katana_equipped else Color(0.0, 0.94, 1.0, 0.8)
			for i in range(3):
				GhostTrailSpawner.spawn_ghost(parent, visual_root, 0.35, trail_col)

		if is_shadow_katana_equipped:
			set_zero_eye_active(true, 2.2)


		# Instant Blink Dash forward
		position += dash_dir * dash_dist
		if is_inside_tree():
			move_and_slide()

		var end_pos: Vector3 = position

		# Flash massive heavy slash arc
		var slash_arc = find_child("SlashArc", true, false)
		if slash_arc:
			slash_arc.visible = true
			slash_arc.scale = Vector3(2.5, 2.5, 2.5)
			slash_arc.rotation.z = 0.785
			var tree = get_tree() if is_inside_tree() else null
			if tree:
				tree.create_timer(0.25).timeout.connect(func():
					if slash_arc:
						slash_arc.visible = false
						slash_arc.scale = Vector3(1.0, 1.0, 1.0)
				)

		# Apply massive damage to enemies in trajectory (between start and end)
		var iai_dmg: int = 180
		if parent:
			for child in parent.get_children():
				if child != self and child.has_method("take_damage"):
					var diff_start: Vector3 = child.position - start_pos
					diff_start.y = 0.0
					var diff_end: Vector3 = child.position - end_pos
					diff_end.y = 0.0
					if diff_start.length() <= (dash_dist + 4.0) or diff_end.length() <= 6.0:
						child.take_damage(iai_dmg)
						register_hit_landed(iai_dmg)
						var hit_pos: Vector3 = (start_pos + child.position) * 0.5 + Vector3(0, 1.0, 0)
						ImpactSpawner.spawn_katana_sparks(parent, hit_pos, Vector3.UP, true)
						if player_camera:
							ImpactSpawner.trigger_screen_shake(player_camera, 0.22, 0.35)
						trigger_hit_stop(0.09)
						emit_signal("iai_executed", iai_dmg)
						break
	else:
		# Quick tap -> Regular combo attack
		perform_attack()

var is_shadow_katana_equipped: bool = false
var contract_with_zero_sealed: bool = false

func equip_shadow_katana() -> void:
	var standard_katana = find_child("KatanaBlade", true, false)
	var shadow_katana = find_child("ShadowKatana", true, false)
	if standard_katana:
		standard_katana.visible = false
	if shadow_katana:
		shadow_katana.visible = true
	is_shadow_katana_equipped = true
	# Strict narrative constraint: Shadow Katana equip does NOT manifest Zero's eye or wing.
	# Zero's Singularity and Monarch Wing appear strictly after the Zero Pact is forged.

func awaken_zero_pact(intensity: float = 1.6) -> void:
	contract_with_zero_sealed = true
	set_zero_eye_active(true, intensity)
	manifest_zero_wing(intensity)

func manifest_zero_wing(intensity: float = 1.0) -> void:
	var wing = find_child("ZeroShadowWing", true, false)
	if wing and wing.has_method("manifest_wing"):
		wing.manifest_wing(intensity)

func dismiss_zero_wing() -> void:
	var wing = find_child("ZeroShadowWing", true, false)
	if wing and wing.has_method("dismiss_wing"):
		wing.dismiss_wing()

func set_zero_eye_active(active: bool, intensity: float = 1.0) -> void:
	var eye = find_child("ZeroEyeSingularity", true, false)
	if eye and eye.has_method("activate_singularity"):
		if active:
			eye.activate_singularity(intensity)
		else:
			eye.deactivate_singularity()

var shadow_step_unlocked: bool = false
var shadow_gauge: float = 100.0
var trauma_limp_factor: float = 0.0

func unlock_shadow_step() -> void:
	shadow_step_unlocked = true

func perform_shadow_step(target: Node3D = null) -> bool:
	if not shadow_step_unlocked:
		return false
	
	var cur_pos: Vector3 = global_position if is_inside_tree() else position
	var chosen_target = target if target else lock_target
	if not chosen_target:
		var parent = get_parent()
		if parent:
			var min_dist: float = 14.0
			for child in parent.get_children():
				if child != self and child.has_method("take_damage"):
					var child_pos = child.global_position if child.is_inside_tree() else child.position
					var d = (child_pos - cur_pos).length()
					if d < min_dist:
						min_dist = d
						chosen_target = child

	var to_pos: Vector3 = Vector3.ZERO
	if chosen_target:
		var target_pos: Vector3 = chosen_target.global_position if chosen_target.is_inside_tree() else chosen_target.position
		to_pos = target_pos - chosen_target.transform.basis.z * 1.8
		to_pos.y = cur_pos.y
	else:
		to_pos = cur_pos - transform.basis.z * 6.0

	var from_pos: Vector3 = cur_pos

	var parent = get_parent()
	if parent:
		GhostTrailSpawner.spawn_ghost(parent, visual_root, 0.45, Color(0.12, 0.02, 0.28, 0.85))
	
	if is_inside_tree():
		global_position = to_pos
	else:
		position = to_pos

	if chosen_target:
		var target_pos: Vector3 = chosen_target.global_position if chosen_target.is_inside_tree() else chosen_target.position
		var my_pos: Vector3 = global_position if is_inside_tree() else position
		var face_dir = (target_pos - my_pos).normalized()
		face_dir.y = 0.0
		if face_dir.length() > 0.01:
			visual_root.rotation.y = atan2(face_dir.x, face_dir.z)

	perfect_dodge_surge = true
	is_invulnerable = true
	dodge_timer = 0.25
	
	var tree = get_tree() if is_inside_tree() else null
	if tree:
		Engine.time_scale = 0.2
		var timer = tree.create_timer(0.25 * 0.2)
		timer.timeout.connect(func(): Engine.time_scale = 1.0)
	
	emit_signal("shadow_step_executed", from_pos, to_pos)
	return true

var combo_step: int = 1
var combo_step_timer: float = 0.0
var is_attacking: bool = false
var is_sheathed: bool = false

const KATANA_READY_TRANSFORM := Transform3D(Basis(Vector3(0.965926, -0.258819, 0), Vector3(0.258819, 0.965926, 0), Vector3(0, 0, 1)), Vector3(0.42, 0.75, 0.15))
const KATANA_SHEATHED_TRANSFORM := Transform3D(Basis(Vector3(0.866, 0, -0.5), Vector3(0, 1, 0), Vector3(0.5, 0, 0.866)), Vector3(-0.28, 0.62, 0.08))

func perform_attack() -> void:
	if is_sheathed:
		unsheath_weapon()
	is_attacking = true
	var current_step: int = combo_step
	combo_step = 1 if combo_step >= 3 else combo_step + 1
	combo_step_timer = 0.85

	var forward_dir: Vector3 = -visual_root.transform.basis.z if visual_root else -transform.basis.z
	locomotion_controller.trigger_combo_root_motion(current_step, forward_dir)

	# AAA Japanese combat voice — step-matched anime action yell
	if spatial_voice_manager:
		var voice_id: String = "attack_haa"
		if current_step == 2:
			voice_id = "attack_osoi"
		elif current_step == 3:
			voice_id = "attack_kiero"
		var vpos: Vector3 = global_position if is_inside_tree() else position
		spatial_voice_manager.play_voice(voice_id, vpos)

	# Flash Katana Slash Arc Ribbon Mesh with step-based angle
	var slash_arc = find_child("SlashArc", true, false)
	if slash_arc:
		slash_arc.visible = true
		if current_step == 1:
			slash_arc.rotation.z = 0.0 # Horizontal sweep
		elif current_step == 2:
			slash_arc.rotation.z = 0.785 # 45-deg rising slash
		else:
			slash_arc.rotation.z = 1.57 # Downward heavy cleave
		var tree = get_tree() if is_inside_tree() else null
		if tree:
			tree.create_timer(0.2).timeout.connect(func(): if slash_arc: slash_arc.visible = false)

	# Dynamic secondary motion impulse to Katana tassel
	var tassel = find_child("TasselRoot", true, false)
	if tassel and tassel.has_method("apply_impulse"):
		tassel.apply_impulse(Vector3(randf_range(-14.0, 14.0), randf_range(8.0, 18.0), randf_range(-8.0, 8.0)))

	var parent = get_parent()
	if parent:
		for child in parent.get_children():
			if child != self and child.has_method("take_damage"):
				var diff: Vector3 = child.position - position if not is_inside_tree() else child.global_position - global_position
				diff.y = 0.0
				var dist: float = diff.length()
				if dist <= 4.5:
					var base_dmg: int = 35
					var hit_stop_dur: float = 0.05
					if current_step == 2:
						base_dmg = 48
						hit_stop_dur = 0.06
					elif current_step == 3:
						base_dmg = 70
						hit_stop_dur = 0.08

					var eff_dmg: int = base_dmg * combo_multiplier
					if perfect_dodge_surge:
						eff_dmg = base_dmg * 3
					register_hit_landed(base_dmg)
					child.take_damage(eff_dmg)

					# Spawn impact sparks & ground slash decal
					var hit_pos: Vector3 = (global_position + child.global_position) * 0.5 + Vector3(0, 1.0, 0) if is_inside_tree() else position + Vector3(0, 1.0, -1.0)
					ImpactSpawner.spawn_katana_sparks(parent, hit_pos, Vector3.UP, current_step == 3)
					if current_step == 3 and player_camera:
						ImpactSpawner.trigger_screen_shake(player_camera, 0.15, 0.22)

					# Apply Visceral Hit-Stop (impact freeze)
					trigger_hit_stop(hit_stop_dur)
					break

func trigger_hit_stop(duration: float = 0.06) -> void:
	Engine.time_scale = 0.05
	var tree = get_tree() if is_inside_tree() else null
	if tree:
		tree.create_timer(duration * 0.05).timeout.connect(func():
			Engine.time_scale = 0.2 if perfect_dodge_surge else 1.0
		)

func toggle_lock_on(target: Node3D = null) -> void:
	if is_locked_on and lock_target and lock_target.has_method("set_targeted"):
		lock_target.set_targeted(false)

	is_locked_on = not is_locked_on
	if is_locked_on:
		if target:
			lock_target = target
		else:
			var parent = get_parent()
			if parent:
				for child in parent.get_children():
					if child != self and child.has_method("take_damage"):
						lock_target = child
						break
		if lock_target and lock_target.has_method("set_targeted"):
			lock_target.set_targeted(true)
	else:
		lock_target = null

func start_dodge() -> void:
	if is_sheathed:
		unsheath_weapon()
	locomotion_controller.cancel_root_motion()
	is_dodging = true
	is_invulnerable = true
	dodge_timer = 0.45
	stamina = max(0.0, stamina - 20.0)
	emit_signal("stamina_changed", stamina, MAX_STAMINA)

	# AAA dodge voice — whispered Japanese perception line
	if spatial_voice_manager:
		var vpos: Vector3 = global_position if is_inside_tree() else position
		spatial_voice_manager.play_voice("dodge_mieta", vpos)

	var tassel = find_child("TasselRoot", true, false)
	if tassel and tassel.has_method("apply_impulse"):
		tassel.apply_impulse(Vector3(0, 10.0, -14.0))

	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	if input_dir.length() > 0.1:
		dodge_direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	else:
		dodge_direction = -transform.basis.z

func sheath_weapon() -> void:
	var katana = find_child("KatanaBlade", true, false) as Node3D
	if not katana:
		emit_signal("weapon_sheathed")
		return
	is_sheathed = true
	var tree = get_tree() if is_inside_tree() else null
	if tree:
		var tween = tree.create_tween()
		tween.tween_property(katana, "transform", KATANA_SHEATHED_TRANSFORM, 0.85).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_callback(func():
			var glow = katana.find_child("BladeGlowLight", true, false) as OmniLight3D
			if glow:
				glow.light_energy = 5.0
				var glow_tween = tree.create_tween()
				glow_tween.tween_property(glow, "light_energy", 1.2, 0.4)
			emit_signal("weapon_sheathed")
		)
	else:
		katana.transform = KATANA_SHEATHED_TRANSFORM
		emit_signal("weapon_sheathed")

func unsheath_weapon() -> void:
	var katana = find_child("KatanaBlade", true, false) as Node3D
	if not katana:
		return
	is_sheathed = false
	katana.transform = KATANA_READY_TRANSFORM

func register_hit_landed(base_damage: int) -> void:
	combo_count += 1
	combo_reset_timer = 2.5
	if combo_count >= 10:
		combo_multiplier = 3
	elif combo_count >= 5:
		combo_multiplier = 2
	else:
		combo_multiplier = 1

	emit_signal("combo_changed", combo_count, combo_multiplier)

	var effective_damage: int = base_damage * combo_multiplier
	var is_crit: bool = combo_multiplier >= 3 or perfect_dodge_surge

	if perfect_dodge_surge:
		effective_damage = base_damage * 3
		perfect_dodge_surge = false

	emit_signal("attack_hit", effective_damage, is_crit)

func take_damage(amount: float) -> void:
	if is_invulnerable:
		trigger_perfect_dodge()
		return

	hp = max(0.0, hp - amount)
	combo_count = 0
	combo_multiplier = 1
	emit_signal("combo_changed", combo_count, combo_multiplier)
	emit_signal("hp_changed", hp, MAX_HP)

func trigger_perfect_dodge() -> void:
	perfect_dodge_surge = true
	emit_signal("perfect_dodge_triggered")
	# Bullet time time dilation
	Engine.time_scale = 0.2
	var tree = get_tree() if is_inside_tree() else null
	if tree:
		tree.create_timer(1.2 * 0.2).timeout.connect(func(): Engine.time_scale = 1.0)

func get_wallet() -> EconomyManager:
	return wallet

func get_inventory() -> PlayerInventory:
	return inventory

func register_nearby_interactable(interactable: Node) -> void:
	if not nearby_interactables.has(interactable):
		nearby_interactables.append(interactable)

func unregister_nearby_interactable(interactable: Node) -> void:
	nearby_interactables.erase(interactable)

func get_nearest_interactable() -> Node:
	if nearby_interactables.is_empty():
		return null
	var my_pos = global_position if is_inside_tree() else position
	var nearest: Node = null
	var min_dist: float = 999.0
	for item in nearby_interactables:
		if is_instance_valid(item):
			var item_pos = item.global_position if item.is_inside_tree() else item.position
			var d = (item_pos - my_pos).length()
			if d < min_dist:
				min_dist = d
				nearest = item
	return nearest

func interact_with_nearest() -> Dictionary:
	var target = get_nearest_interactable()
	if not target:
		return {"success": false, "reason": "none_nearby"}
	if target.has_method("trigger_interaction"):
		return target.trigger_interaction(self)
	return {"success": false, "reason": "invalid_target"}

func restore_stamina(amount: float) -> void:
	stamina = min(MAX_STAMINA, stamina + amount)
	emit_signal("stamina_changed", stamina, MAX_STAMINA)

func drink_item(item_id: String) -> Dictionary:
	var result = inventory.use_item(item_id, self)
	if result.get("success", false):
		var tree = get_tree() if is_inside_tree() else null
		if tree:
			var player_audio = AudioStreamPlayer.new()
			add_child(player_audio)
			player_audio.stream = ProceduralCinematicAudio.create_drink_gulp()
			player_audio.play()
			player_audio.finished.connect(func(): player_audio.queue_free())
	return result

func eat_item(item_id: String) -> Dictionary:
	var result = inventory.use_item(item_id, self)
	if result.get("success", false):
		var tree = get_tree() if is_inside_tree() else null
		if tree:
			var player_audio = AudioStreamPlayer.new()
			add_child(player_audio)
			player_audio.stream = ProceduralCinematicAudio.create_food_crunch()
			player_audio.play()
			player_audio.finished.connect(func(): player_audio.queue_free())
	return result

func get_needs() -> PlayerNeeds:
	return needs

func restore_hunger(amount: float) -> void:
	if needs:
		needs.consume_food(amount, 0.0, 0.0)

func restore_thirst(amount: float) -> void:
	if needs:
		needs.consume_drink(amount, 0.0)

func restore_energy(amount: float) -> void:
	if needs:
		needs.restore_energy(amount)



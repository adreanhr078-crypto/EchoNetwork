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
signal nearby_interactable_changed(interactable: Node)
signal opening_recovery_completed()
signal perfect_deflect_triggered(attacker: Node)
signal visceral_strike_executed(target: Node, damage: int)
signal combat_roll_executed(direction: Vector3)
signal hard_landing_executed(impact_speed: float)
signal idle_bark_triggered(bark_id: String, text_ja: String)
signal team_swapped(previous_slot: int, new_slot: int, character_data: Dictionary)
signal ultimate_burst_fired(slot: int, character_name: String, damage: int)

const ImpactSpawner = preload("res://scripts/combat/impact_spawner.gd")
const GhostTrailSpawner = preload("res://scripts/player/ghost_trail_spawner.gd")
const EconomyManager = preload("res://scripts/systems/economy_manager.gd")
const PlayerInventory = preload("res://scripts/systems/player_inventory.gd")
const PlayerNeeds = preload("res://scripts/systems/player_needs.gd")
const LocomotionAnimController = preload("res://scripts/player/locomotion_anim_controller.gd")
const SpatialVoiceManagerScript = preload("res://scripts/audio/spatial_voice_manager.gd")
const EchoFacialControllerScript = preload("res://scripts/player/echo_facial_controller.gd")
const EchoFootstepSystemScript = preload("res://scripts/player/echo_footstep_system.gd")
const PlayerTraversalController = preload("res://scripts/player/player_traversal_controller.gd")
const VisceralCombatControllerScript = preload("res://scripts/combat/visceral_combat_controller.gd")
const TeamSwapControllerScript = preload("res://scripts/systems/team_swap_controller.gd")
const ContactShadowBlob = preload("res://scripts/effects/contact_shadow_blob.gd")
const ShadowWaveProjectile = preload("res://scripts/combat/shadow_wave_projectile.gd")
const MixamoAnimationBridgeScript = preload("res://scripts/player/mixamo_animation_bridge.gd")
const ProceduralCinematicAudio = preload("res://scripts/audio/procedural_cinematic_audio.gd")

var wallet: EconomyManager = EconomyManager.new()
var inventory: PlayerInventory = PlayerInventory.new()
var needs: PlayerNeeds = PlayerNeeds.new()
var locomotion_controller: LocomotionAnimController = LocomotionAnimController.new()
var spatial_voice_manager: SpatialVoiceManagerScript = null
var visceral_combat: VisceralCombatControllerScript = null
var team_swap: TeamSwapControllerScript = null
var nearby_interactables: Array = []

var idle_motionless_timer: float = 0.0
const IDLE_BARK_INTERVAL: float = 12.0
var combat_activity_timer: float = 0.0
const COMBAT_STANCE_DURATION: float = 6.0
var _last_airborne_velocity_y: float = 0.0

const MAX_HP: float = 200.0
const MAX_STAMINA: float = 100.0
const WALK_SPEED: float = 1.55
const SPRINT_SPEED: float = 5.8
const AUTHORED_WALK_SPEED: float = 1.0111
const AUTHORED_RUN_SPEED: float = 1.7484
const DEFLECT_WINDOW: float = 0.15
const JUMP_VELOCITY: float = 5.4
const DODGE_SPEED: float = 9.8
const GRAVITY: float = 14.0
const GROUND_ACCEL: float = 18.0
const GROUND_BRAKE: float = 22.0
const AIR_ACCEL: float = 6.0
const MODEL_FORWARD_YAW_OFFSET: float = -PI * 0.5

var hp: float = MAX_HP
var stamina: float = MAX_STAMINA
var is_invulnerable: bool = false
var is_dodging: bool = false
var dodge_timer: float = 0.0
var dodge_direction: Vector3 = Vector3.ZERO
var perfect_dodge_surge: bool = false

var deflect_window_timer: float = 0.0
var _facial_controller: Node = null
var facial_controller: Node:
	get:
		if not _facial_controller:
			_facial_controller = find_child("EchoFacialController", true, false)
			if not _facial_controller and is_inside_tree():
				_facial_controller = EchoFacialControllerScript.new()
				_facial_controller.name = "EchoFacialController"
				add_child(_facial_controller)
		return _facial_controller
	set(val):
		_facial_controller = val

var _footstep_system: Node = null
var footstep_system: Node:
	get:
		if not _footstep_system:
			_footstep_system = find_child("EchoFootstepSystem", true, false)
			if not _footstep_system and is_inside_tree():
				_footstep_system = EchoFootstepSystemScript.new()
				_footstep_system.name = "EchoFootstepSystem"
				add_child(_footstep_system)
		return _footstep_system
	set(val):
		_footstep_system = val

var _traversal_controller: PlayerTraversalController = null
var traversal: PlayerTraversalController:
	get:
		if not _traversal_controller:
			_traversal_controller = find_child("PlayerTraversalController", true, false) as PlayerTraversalController
			if not _traversal_controller and is_inside_tree():
				_traversal_controller = PlayerTraversalController.new()
				_traversal_controller.name = "PlayerTraversalController"
				add_child(_traversal_controller)
			elif not _traversal_controller:
				_traversal_controller = PlayerTraversalController.new()
				_traversal_controller.name = "PlayerTraversalController"
		return _traversal_controller
	set(val):
		_traversal_controller = val

var combo_count: int = 0
var combo_multiplier: int = 1
var combo_reset_timer: float = 0.0

var is_charging_iai: bool = false
var iai_charge: float = 0.0
var mobile_input_vector: Vector2 = Vector2.ZERO
var ghost_trail_timer: float = 0.0

var _visual_root: Node3D = null
var _recovery_skeleton: Skeleton3D = null
var _recovery_left_toe: int = -1
var _recovery_right_toe: int = -1
var visual_root: Node3D:
	get:
		if not _visual_root:
			_visual_root = get_node_or_null("ModelRoot") if has_node("ModelRoot") else self
		return _visual_root
	set(val):
		_visual_root = val
var animation_player: AnimationPlayer = null
var player_camera: Camera3D = null
var camera_boom: SpringArm3D = null
@export var mouse_look_sensitivity: float = 0.0022
var current_anim: String = ""
var is_locked_on: bool = false
var lock_target: Node3D = null
var combat_available: bool = true
var opening_recovery_active: bool = false
var _opening_tween: Tween = null
var _landing_recoil: float = 0.0
var _last_safe_ground_position: Vector3 = Vector3.ZERO
var _suppress_attack_until_release: bool = false

func _ready() -> void:
	floor_snap_length = 0.45
	floor_stop_on_slope = true
	floor_max_angle = deg_to_rad(45.0)
	floor_constant_speed = true
	_last_safe_ground_position = global_position
	if not locomotion_controller.is_inside_tree():
		add_child(locomotion_controller)
	# Instantiate and wire SpatialVoiceManager as a child of the player
	spatial_voice_manager = SpatialVoiceManagerScript.new()
	spatial_voice_manager.name = "SpatialVoiceManager"
	add_child(spatial_voice_manager)
	animation_player = find_child("AnimationPlayer", true, false)
	_recovery_skeleton = find_child("Skeleton3D", true, false) as Skeleton3D
	if _recovery_skeleton:
		_recovery_left_toe = _recovery_skeleton.find_bone("tripo__1_Left_Limb_3")
		_recovery_right_toe = _recovery_skeleton.find_bone("tripo__1_Right_Limb_3")
	player_camera = find_child("Camera3D", true, false) as Camera3D
	camera_boom = find_child("CameraBoom", true, false) as SpringArm3D
	if animation_player:
		MixamoAnimationBridgeScript.inject_animations(animation_player)
		for anim_name in animation_player.get_animation_list():
			var anim: Animation = animation_player.get_animation(anim_name)
			var loops := anim_name in ["IDLE", "WALK", "RUN", "preset_idle", "preset_walk", "preset_run", "preset_biped_idle_001", "preset_biped_walk_001", "preset_biped_run_001", "preset:idle", "preset:walk", "preset:run", "preset:biped:idle.001", "preset:biped:walk.001", "preset:biped:run.001"]
			anim.loop_mode = Animation.LOOP_LINEAR if loops else Animation.LOOP_NONE
		opening_recovery_active = true
		call_deferred("_play_opening_recovery")

	emit_signal("hp_changed", hp, MAX_HP)
	emit_signal("stamina_changed", stamina, MAX_STAMINA)

	facial_controller = find_child("EchoFacialController", true, false)
	if not facial_controller:
		facial_controller = EchoFacialControllerScript.new()
		facial_controller.name = "EchoFacialController"
		add_child(facial_controller)

	footstep_system = find_child("EchoFootstepSystem", true, false)
	if not footstep_system:
		footstep_system = EchoFootstepSystemScript.new()
		footstep_system.name = "EchoFootstepSystem"
		add_child(footstep_system)

	visceral_combat = find_child("VisceralCombatController", true, false)
	if not visceral_combat:
		visceral_combat = VisceralCombatControllerScript.new()
		visceral_combat.name = "VisceralCombatController"
		add_child(visceral_combat)

	# Strict Narrative Mandate: Zero's Eye and Shadow Wing are strictly dormant at start
	set_zero_eye_active(false)
	dismiss_zero_wing()

	# Grounding: Add stylized contact shadow blob for Intel UHD compatibility
	var shadow_blob := ContactShadowBlob.new()
	shadow_blob.name = "ContactShadowBlob"
	add_child(shadow_blob)

	call_deferred("_setup_weapon_attachment")

func play_anim(anim_name: String, blend_time: float = 0.2) -> void:
	if not animation_player:
		animation_player = find_child("AnimationPlayer", true, false)
	if not animation_player:
		return
	var resolved_anim := anim_name
	if not animation_player.has_animation(resolved_anim):
		var candidate_aliases := {
			"IDLE": ["preset_idle", "preset:idle", "preset:biped:idle.001", "preset_biped_idle_001"],
			"WALK": ["preset_walk", "preset:walk", "preset:biped:walk.001", "preset_biped_walk_001"],
			"RUN": ["preset_run", "preset:run", "preset:biped:run.001", "preset_biped_run_001"],
			"WAKEUP": ["preset_wakeup", "preset:wakeup", "preset:biped:wakeup.001", "preset_biped_wakeup_001"],
			"preset_idle": ["IDLE", "preset:idle", "preset:biped:idle.001", "preset_biped_idle_001"],
			"preset_walk": ["WALK", "preset:walk", "preset:biped:walk.001", "preset_biped_walk_001"],
			"preset_run": ["RUN", "preset:run", "preset:biped:run.001", "preset_biped_run_001"],
			"preset_biped_idle_001": ["preset_idle", "IDLE", "preset:idle", "preset:biped:idle.001"],
			"preset_biped_fight_idle_001": ["Fight_Idle", "preset_fight_idle", "preset:fight_idle", "IDLE", "preset_biped_idle_001"],
			"preset_biped_roll_001": ["Run_To_Rolling", "preset_roll", "preset:roll", "preset_biped_run_001"],
			"preset_biped_hard_landing_001": ["Hard_Landing", "preset_hard_landing", "preset:hard_landing", "IDLE", "preset_biped_idle_001"],
			"preset_biped_walk_001": ["preset_walk", "WALK", "preset:walk", "preset:biped:walk.001"],
			"preset_biped_run_001": ["preset_run", "RUN", "preset:run", "preset:biped:run.001"],
			"preset_biped_interact_001": ["INTERACT"],
			"preset_biped_wakeup_001": ["preset_wakeup", "WAKEUP"],
			"preset_biped_standup_001": ["STANDUP"],
			"ATTACK_1": ["preset_biped_slash_001", "preset_slash", "Great Sword Slash", "Sword And Shield Attack", "Great_Sword_Slash", "preset_biped_attack_001", "preset_biped_fight_idle_001", "IDLE"],
			"ATTACK_2": ["preset_biped_attack_001", "Melee_Attack_Downward", "Melee Attack Downward", "preset_slash_2", "Great Sword Slash", "preset_biped_slash_001", "preset_biped_fight_idle_001"],
			"ATTACK_3": ["Flip Kick", "Flip_Kick", "preset_biped_kick_001", "Great Sword Slash", "Backflip", "Melee_Attack_Downward", "preset_biped_roll_001", "preset_biped_fight_idle_001"],
			"FALL": ["preset_fall", "preset_biped_fall_001", "Jump_To_Hang", "IDLE", "preset_biped_idle_001"],
			"LAUGH": ["preset_biped_laugh_001", "preset_biped_fight_idle_001", "IDLE"],
		}
		var candidates: Array = candidate_aliases.get(anim_name, [])
		for candidate in candidates:
			if animation_player.has_animation(candidate):
				resolved_anim = candidate
				break
	if not animation_player.has_animation(resolved_anim):
		return
	if current_anim == resolved_anim and animation_player.is_playing():
		return
	var previous_anim := current_anim
	var gait_phase := -1.0
	if animation_player.is_playing() and previous_anim in ["preset_walk", "preset_run"] and resolved_anim in ["preset_walk", "preset_run"]:
		var previous_length := animation_player.get_animation(previous_anim).length
		if previous_length > 0.0:
			gait_phase = fposmod(animation_player.current_animation_position / previous_length, 1.0)
	current_anim = resolved_anim
	animation_player.play(resolved_anim, blend_time)
	# Both locomotion takes start on the same contact. Preserve that contact
	# when changing pace instead of restarting on an unrelated foot.
	if gait_phase >= 0.0:
		animation_player.seek(gait_phase * animation_player.get_animation(resolved_anim).length)

func _play_opening_recovery() -> void:
	if not animation_player:
		opening_recovery_active = false
		emit_signal("opening_recovery_completed")
		return
	visual_root.position = Vector3.ZERO
	visual_root.rotation = Vector3(0.0, PI * 0.5, 0.0)
	var recovery_clip := ""
	for candidate in ["preset_wakeup", "preset:wakeup", "WAKEUP"]:
		if animation_player.has_animation(candidate):
			recovery_clip = candidate
			break
	if not recovery_clip.is_empty():
		play_anim(recovery_clip, 0.0)
		while opening_recovery_active and is_inside_tree() and animation_player.is_playing() and animation_player.current_animation == recovery_clip:
			await get_tree().process_frame
			_align_recovery_feet_to_floor()
		if not is_inside_tree() or not opening_recovery_active:
			return
		_align_recovery_feet_to_floor()
	else:
		# Keep a restrained fallback for older character assets without the authored clip.
		play_anim("IDLE", 0.0)
		visual_root.position.y = -0.08
		visual_root.rotation.x = 0.12
		_opening_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_opening_tween.tween_property(visual_root, "position:y", 0.0, 1.25)
		_opening_tween.parallel().tween_property(visual_root, "rotation:x", 0.0, 1.25)
		await _opening_tween.finished
		if not is_inside_tree() or not opening_recovery_active:
			return
	finish_opening_recovery()

func _align_recovery_feet_to_floor() -> void:
	visual_root.position.y = 0.0

func finish_opening_recovery() -> void:
	if not opening_recovery_active:
		return
	if _opening_tween and _opening_tween.is_running():
		_opening_tween.kill()
	visual_root.position.y = 0.0
	visual_root.rotation.x = 0.0
	visual_root.rotation.y = 0.0
	visual_root.rotation.z = 0.0
	opening_recovery_active = false
	play_anim("IDLE", 0.18)
	emit_signal("opening_recovery_completed")

func _physics_process(delta: float) -> void:
	if opening_recovery_active:
		velocity = Vector3.ZERO
		move_and_slide()
		return

	# Handle Genshin Traversal: Climbing & Swimming
	if traversal.is_climbing() or traversal.is_swimming():
		var cam_basis = Basis()
		if player_camera:
			cam_basis = player_camera.global_transform.basis
		elif get_viewport() and get_viewport().get_camera_3d():
			cam_basis = get_viewport().get_camera_3d().global_transform.basis

		var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
		if mobile_input_vector.length() > 0.05:
			input_dir = mobile_input_vector

		var is_sprint_active: bool = Input.is_action_pressed("sprint")
		var trav_res: Dictionary = traversal.update_traversal_physics(
			delta,
			velocity,
			input_dir,
			cam_basis,
			global_position,
			is_sprint_active,
			stamina
		)
		velocity = trav_res["velocity"]
		if trav_res["snap_position_y"] != -999.0:
			global_position.y = lerpf(global_position.y, trav_res["snap_position_y"], 12.0 * delta)
		if trav_res["face_direction"] != Vector3.ZERO and visual_root:
			var target_yaw: float = atan2(trav_res["face_direction"].x, trav_res["face_direction"].z) + MODEL_FORWARD_YAW_OFFSET
			visual_root.rotation.y = lerp_angle(visual_root.rotation.y, target_yaw, 14.0 * delta)
		if trav_res["stamina_drain"] > 0.0:
			stamina = maxf(0.0, stamina - trav_res["stamina_drain"])
			emit_signal("stamina_changed", stamina, MAX_STAMINA)

		# Wall jump handling
		if traversal.is_climbing() and Input.is_action_just_pressed("jump"):
			var jump_res = traversal.climb_jump(stamina)
			if jump_res["success"]:
				stamina -= jump_res["stamina_cost"]
				emit_signal("stamina_changed", stamina, MAX_STAMINA)
				velocity = jump_res["impulse"]
				traversal.stop_climbing()

		move_and_slide()
		return

	# Add Gravity & Track Airborne Velocity
	if not is_on_floor():
		_last_airborne_velocity_y = velocity.y
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

	deflect_window_timer = maxf(0.0, deflect_window_timer - delta)

	# Handle Combo Reset Window (2.5s)
	if combo_count > 0:
		combo_reset_timer -= delta
		if combo_reset_timer <= 0.0:
			combo_count = 0
			combo_multiplier = 1
			emit_signal("combo_changed", combo_count, combo_multiplier)
			if facial_controller and not is_charging_iai:
				facial_controller.set_combat_focus(0.0, 0.3)

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
			var lock_yaw: float = atan2(target_diff.x, target_diff.z) + MODEL_FORWARD_YAW_OFFSET
			visual_root.rotation.y = lerp_angle(visual_root.rotation.y, lock_yaw, 10.0 * delta)

	# Dynamic FOV Warping
	var is_sprinting: bool = Input.is_action_pressed("sprint") and stamina > 5.0
	if player_camera:
		var target_fov: float = 82.0 if is_sprinting else 75.0
		player_camera.fov = lerp(player_camera.fov, target_fov, 6.0 * delta)

	# Attack & Iai Charge Input (Keyboard/Mouse)
	if Input.is_action_just_pressed("attack_light") and not _suppress_attack_until_release:
		start_iai_charge()
	if Input.is_action_just_released("attack_light") and not _suppress_attack_until_release:
		execute_iai_slash()
	if not Input.is_action_pressed("attack_light"):
		_suppress_attack_until_release = false

	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	if mobile_input_vector.length() > 0.05:
		input_dir = mobile_input_vector

	var direction: Vector3 = Vector3(input_dir.x, 0, input_dir.y).normalized()
	if player_camera:
		var camera_right: Vector3 = player_camera.global_transform.basis.x
		var camera_forward: Vector3 = -player_camera.global_transform.basis.z
		camera_right.y = 0.0
		camera_forward.y = 0.0
		direction = (camera_right.normalized() * input_dir.x - camera_forward.normalized() * input_dir.y).normalized()
	is_sprinting = is_sprinting and direction.length() > 0.1

	if is_sprinting:
		stamina = max(0.0, stamina - 12.0 * delta)
		emit_signal("stamina_changed", stamina, MAX_STAMINA)
		# Handle Sprint Slide Input (C or Ctrl)
		if (Input.is_action_just_pressed("crouch") or Input.is_physical_key_pressed(KEY_C) or Input.is_physical_key_pressed(KEY_CTRL)) and is_on_floor() and not is_sliding:
			perform_slide()
	else:
		stamina = min(MAX_STAMINA, stamina + 18.0 * delta)
		emit_signal("stamina_changed", stamina, MAX_STAMINA)

	var current_speed: float = SPRINT_SPEED if is_sprinting else WALK_SPEED
	var horizontal_speed: float = Vector2(velocity.x, velocity.z).length()
	var loco_data: Dictionary = locomotion_controller.update(delta, input_dir, horizontal_speed, is_sprinting, is_attacking)
	if is_attacking and not locomotion_controller.root_motion_active:
		is_attacking = false

	combat_activity_timer = maxf(0.0, combat_activity_timer - delta)
	locomotion_controller.set_combat_stance(combat_activity_timer > 0.0 or not is_sheathed)

	if loco_data.get("is_hard_landing", false):
		velocity.x = move_toward(velocity.x, 0.0, 32.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 32.0 * delta)
	elif loco_data["root_velocity"].length() > 0.1:
		velocity.x = loco_data["root_velocity"].x
		velocity.z = loco_data["root_velocity"].z
	elif loco_data["is_skid"]:
		velocity.x = move_toward(velocity.x, 0.0, 18.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 18.0 * delta)
	elif direction.length() > 0.1:
		var acceleration: float = GROUND_ACCEL if is_on_floor() else AIR_ACCEL
		velocity.x = move_toward(velocity.x, direction.x * current_speed, acceleration * delta)
		velocity.z = move_toward(velocity.z, direction.z * current_speed, acceleration * delta)
		# Rotate visual model towards move direction unless locked-on
		if not is_locked_on or not lock_target:
			var target_yaw: float = atan2(direction.x, direction.z) + MODEL_FORWARD_YAW_OFFSET
			visual_root.rotation.y = lerp_angle(visual_root.rotation.y, target_yaw, 14.0 * delta)
			visual_root.rotation.z = lerp_angle(visual_root.rotation.z, 0.0, 12.0 * delta)
	else:
		var braking: float = GROUND_BRAKE if is_on_floor() else AIR_ACCEL
		velocity.x = move_toward(velocity.x, 0.0, braking * delta)
		velocity.z = move_toward(velocity.z, 0.0, braking * delta)
		visual_root.rotation.z = lerp_angle(visual_root.rotation.z, 0.0, 12.0 * delta)
	var grounded_before_move: bool = is_on_floor()
	var landing_speed: float = absf(velocity.y)
	move_and_slide()
	if is_on_floor() and not grounded_before_move:
		_landing_recoil = minf(0.18, landing_speed * 0.025 + 0.04)
		if absf(_last_airborne_velocity_y) > 8.5:
			locomotion_controller.trigger_hard_landing(absf(_last_airborne_velocity_y))
			emit_signal("hard_landing_executed", absf(_last_airborne_velocity_y))
			if is_inside_tree():
				var land_audio = AudioStreamPlayer.new()
				add_child(land_audio)
				land_audio.stream = ProceduralCinematicAudio.create_hard_landing_sfx()
				land_audio.play()
				land_audio.finished.connect(func(): land_audio.queue_free())
			if player_camera:
				ImpactSpawner.trigger_screen_shake(player_camera, 0.28, 0.35)
	if is_on_floor():
		_last_safe_ground_position = global_position
		_landing_recoil = move_toward(_landing_recoil, 0.0, 2.0 * delta)
		visual_root.rotation.x = lerpf(visual_root.rotation.x, _landing_recoil, minf(1.0, 12.0 * delta))
		if not locomotion_controller.root_motion_active:
			var actual_speed: float = Vector2(velocity.x, velocity.z).length()
			var clip: String = "IDLE"
			var target_blend_time: float = 0.22
			if loco_data.get("is_hard_landing", false):
				clip = "preset_biped_hard_landing_001"
				target_blend_time = 0.08
				visual_root.rotation.x = lerpf(visual_root.rotation.x, 0.24, minf(1.0, 16.0 * delta))
			elif loco_data.get("is_rolling", false):
				clip = "preset_biped_roll_001"
				target_blend_time = 0.1
			elif loco_data.get("is_skid", false):
				clip = "IDLE"
				target_blend_time = 0.12
				visual_root.rotation.x = lerpf(visual_root.rotation.x, 0.08, minf(1.0, 14.0 * delta))
			elif actual_speed > 0.2:
				if is_sprinting and actual_speed > 3.8:
					clip = "RUN"
					target_blend_time = 0.2
				else:
					clip = "WALK"
					target_blend_time = 0.25
			else:
				if combat_activity_timer > 0.0 or not is_sheathed:
					clip = "preset_biped_fight_idle_001"
					target_blend_time = 0.2
				else:
					clip = "IDLE"
					target_blend_time = 0.25

			play_anim(clip, target_blend_time)
			if animation_player:
				var ref_speed: float = AUTHORED_RUN_SPEED if clip == "RUN" else AUTHORED_WALK_SPEED
				animation_player.speed_scale = clampf(actual_speed / ref_speed, 0.4, 3.5) if (clip in ["WALK", "RUN"]) else 1.0

			# Handle Character Soul Idle Barks (Genshin Idle System)
			if actual_speed < 0.1 and not is_attacking and not is_dodging and combat_activity_timer <= 0.0 and not loco_data.get("is_hard_landing", false):
				idle_motionless_timer += delta
				if idle_motionless_timer >= IDLE_BARK_INTERVAL:
					idle_motionless_timer = 0.0
					trigger_idle_bark()
			else:
				idle_motionless_timer = 0.0
	else:
		# Keep the authored jump through its airborne phase; ledge falls use a
		# stable pose until a separate playable fall cycle is authored.
		if current_anim != "preset_jump" or not animation_player or not animation_player.is_playing():
			play_anim("FALL", 0.14)
			if animation_player:
				animation_player.speed_scale = 1.0
		visual_root.rotation.x = lerpf(visual_root.rotation.x, -0.12 if velocity.y > 0.0 else 0.16, minf(1.0, 9.0 * delta))
		if global_position.y < _last_safe_ground_position.y - 3.0:
			global_position = _last_safe_ground_position + Vector3.UP * 0.12
			velocity = Vector3.ZERO

func perform_jump() -> void:
	if is_on_floor():
		velocity.y = JUMP_VELOCITY
		play_anim("preset_jump", 0.12)
		if animation_player:
			animation_player.speed_scale = 2.5
		var tree := get_tree() if is_inside_tree() else null
		if tree and get_parent():
			var hud = get_parent().find_child("GameplayHUD", true, false)
			if hud and hud.has_method("complete_tutorial_action"):
				hud.complete_tutorial_action("TOAST_JUMP")

func set_mobile_input_vector(vec: Vector2) -> void:
	mobile_input_vector = vec

func set_combat_available(available: bool) -> void:
	combat_available = available
	var standard_katana = find_child("KatanaBlade", true, false) as Node3D
	if standard_katana:
		standard_katana.visible = available and not is_shadow_katana_equipped
	var touch_ui = get_tree().root.find_child("MobileTouchControls", true, false) if is_inside_tree() else null
	if touch_ui and touch_ui.has_method("set_combat_available"):
		touch_ui.set_combat_available(available)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return
	if opening_recovery_active:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and camera_boom:
		camera_boom.rotation.y -= event.relative.x * mouse_look_sensitivity
		camera_boom.rotation.x = clampf(camera_boom.rotation.x - event.relative.y * mouse_look_sensitivity, -0.3, 0.8)
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		var root := get_tree().root
		var dialogue := root.find_child("DialogueOverlay", true, false) as Control
		var puzzle := root.find_child("TerminalHackPuzzle", true, false) as Control
		var window := root.find_child("SystemWindow", true, false) as Control
		if not ((dialogue and dialogue.visible) or (puzzle and puzzle.visible) or (window and window.visible)):
			_suppress_attack_until_release = true
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return
	if event.is_action_pressed("interact") and not event.is_echo():
		interact_with_nearest()
		return
	if event.is_action_pressed("guard") or (event is InputEventKey and event.pressed and (event.keycode == KEY_F or event.keycode == KEY_K)):
		trigger_deflect_attempt()
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_V:
		toggle_void_sight()
		return

var is_void_sight_active: bool = false

func toggle_void_sight() -> void:
	is_void_sight_active = not is_void_sight_active
	set_zero_eye_active(is_void_sight_active, 999.0 if is_void_sight_active else 0.0)
	var hud_node = get_tree().root.find_child("GameplayHUD", true, false) if is_inside_tree() else null
	if hud_node and hud_node.has_method("set_directive"):
		if is_void_sight_active:
			hud_node.set_directive("VOID SIGHT // رصد طاقة الفراغ", "العين القرمزية الميكانيكية واليسرى البنفسجية مفعلتان — كشف الذكريات والطاقة الخفية.")
		else:
			hud_node.set_directive("STANDARD SIGHT // الرؤية العادية", "تم تعطيل رصد طاقة الفراغ.")

func trigger_deflect_attempt() -> void:
	if not combat_available:
		return
	if is_sheathed:
		unsheath_weapon()
	deflect_window_timer = DEFLECT_WINDOW
	if facial_controller:
		facial_controller.set_combat_focus(1.0, 0.08)

func start_iai_charge() -> void:
	if not combat_available:
		return
	if is_sheathed:
		unsheath_weapon()
	is_charging_iai = true
	iai_charge = 0.0
	if facial_controller:
		facial_controller.set_combat_focus(1.0, 0.12)
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
	if not combat_available:
		is_charging_iai = false
		iai_charge = 0.0
		return
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

		# Spawn Solo Leveling Sumi Ink Shadow Wave Projectile
		if parent:
			var wave = ShadowWaveProjectile.new()
			wave.position = global_position + Vector3(0, 1.0, 0)
			wave.direction = dash_dir
			parent.add_child(wave)

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
						ImpactSpawner.spawn_damage_number(parent, hit_pos + Vector3(0, 0.4, 0), iai_dmg, true)
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
		if _hand_weapon_socket and shadow_katana.get_parent() != _hand_weapon_socket:
			shadow_katana.owner = null
			shadow_katana.get_parent().remove_child(shadow_katana)
			_hand_weapon_socket.add_child(shadow_katana)
			var s: float = 1.0 / 1.81
			shadow_katana.transform = Transform3D(
				Basis(Vector3(1, 0, 0), deg_to_rad(-90)).scaled(Vector3.ONE * s),
				Vector3(0.01, 0.04, 0.06)
			)
		shadow_katana.visible = true
	is_shadow_katana_equipped = true
	set_combat_available(true)
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
	if not combat_available:
		return
	if is_sheathed:
		unsheath_weapon()
	is_attacking = true
	var current_step: int = combo_step
	combo_step = 1 if combo_step >= 3 else combo_step + 1
	combo_step_timer = 0.85

	var forward_dir: Vector3 = visual_root.transform.basis.x if visual_root else -transform.basis.z
	locomotion_controller.trigger_combo_root_motion(current_step, forward_dir)

	# Play Authored Character Attack Animation on Skeleton & Trigger Wing on Finisher
	var anim_clip := "ATTACK_1"
	if current_step == 2:
		anim_clip = "ATTACK_2"
	elif current_step == 3:
		anim_clip = "ATTACK_3"
		manifest_zero_wing()
		var tree = get_tree() if is_inside_tree() else null
		if tree:
			tree.create_timer(4.5).timeout.connect(func():
				if combat_activity_timer <= 0.5:
					dismiss_zero_wing()
			)
	play_anim(anim_clip, 0.08)

	# AAA Japanese combat voice — step-matched anime action yell
	if spatial_voice_manager:
		var voice_id: String = "attack_haa"
		if current_step == 2:
			voice_id = "attack_osoi"
		elif current_step == 3:
			voice_id = "attack_kiero"
		var vpos: Vector3 = global_position if is_inside_tree() else position
		spatial_voice_manager.play_voice(voice_id, vpos)

	# Razor-sharp Katana swing whoosh audio
	if is_inside_tree():
		var whoosh_audio := AudioStreamPlayer.new()
		whoosh_audio.bus = "Master"
		whoosh_audio.stream = ProceduralCinematicAudio.create_katana_whoosh_sfx(1.0 + float(current_step) * 0.15)
		add_child(whoosh_audio)
		whoosh_audio.play()
		whoosh_audio.finished.connect(func(): if is_instance_valid(whoosh_audio): whoosh_audio.queue_free())

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
					var is_crit_hit: bool = current_step == 3 or perfect_dodge_surge or combo_multiplier >= 2
					ImpactSpawner.spawn_damage_number(parent, hit_pos + Vector3(0, 0.35, 0), eff_dmg, is_crit_hit)
					if facial_controller:
						facial_controller.set_combat_focus(1.0, 0.12)
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
	if not combat_available:
		return
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

	combat_activity_timer = COMBAT_STANCE_DURATION

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

	var horiz_speed: float = Vector2(velocity.x, velocity.z).length()
	var is_sprint_active: bool = Input.is_action_pressed("sprint")
	if horiz_speed > 2.8 or is_sprint_active:
		# Trigger Combat Roll (Mixamo Run_To_Rolling)
		locomotion_controller.trigger_roll(dodge_direction)
		emit_signal("combat_roll_executed", dodge_direction)
		if is_inside_tree():
			var roll_audio = AudioStreamPlayer.new()
			add_child(roll_audio)
			roll_audio.stream = ProceduralCinematicAudio.create_combat_roll_sfx()
			roll_audio.play()
			roll_audio.finished.connect(func(): roll_audio.queue_free())

var _hand_weapon_socket: BoneAttachment3D = null
var _hip_weapon_socket: BoneAttachment3D = null
var _hip_weapon_mesh: Node3D = null
var is_sliding: bool = false

func _setup_weapon_attachment() -> void:
	var skeleton = find_child("Skeleton3D", true, false) as Skeleton3D
	if not skeleton:
		return
	var hand_bone = "tripo__0_Right_Limb_2"
	if skeleton.find_bone(hand_bone) == -1:
		return

	var s: float = 1.0 / 1.81

	_hand_weapon_socket = skeleton.get_node_or_null("RightHandWeaponSocket") as BoneAttachment3D
	if not _hand_weapon_socket:
		_hand_weapon_socket = BoneAttachment3D.new()
		_hand_weapon_socket.name = "RightHandWeaponSocket"
		_hand_weapon_socket.bone_name = hand_bone
		skeleton.add_child(_hand_weapon_socket)

	var katana = find_child("KatanaBlade", true, false) as Node3D
	if katana and katana.get_parent() != _hand_weapon_socket:
		katana.owner = null
		katana.get_parent().remove_child(katana)
		_hand_weapon_socket.add_child(katana)
		katana.transform = Transform3D(
			Basis(Vector3(1, 0, 0), deg_to_rad(-90)).scaled(Vector3.ONE * s),
			Vector3(0.01, 0.04, 0.06)
		)

	# Build or locate hip scabbard socket attached to pelvis bone
	var pelvis_bone = "tripo__Spine_0"
	if skeleton.find_bone(pelvis_bone) != -1:
		_hip_weapon_socket = skeleton.get_node_or_null("HipWeaponSocket") as BoneAttachment3D
		if not _hip_weapon_socket:
			_hip_weapon_socket = BoneAttachment3D.new()
			_hip_weapon_socket.name = "HipWeaponSocket"
			_hip_weapon_socket.bone_name = pelvis_bone
			skeleton.add_child(_hip_weapon_socket)

		if not _hip_weapon_mesh:
			var scabbard_scene = load("res://scenes/player/katana_blade.tscn")
			if scabbard_scene:
				_hip_weapon_mesh = scabbard_scene.instantiate()
				_hip_weapon_mesh.name = "KatanaHipScabbard"
				var hip_basis := Basis.from_euler(Vector3(deg_to_rad(-35), deg_to_rad(15), deg_to_rad(10))).scaled(Vector3.ONE * s)
				_hip_weapon_mesh.transform = Transform3D(hip_basis, Vector3(-0.16, -0.04, 0.05))
				_hip_weapon_socket.add_child(_hip_weapon_mesh)
				_hip_weapon_mesh.visible = is_sheathed
				if katana:
					katana.visible = not is_sheathed

func sheath_weapon() -> void:
	is_sheathed = true
	var katana = find_child("KatanaBlade", true, false) as Node3D
	if katana:
		katana.visible = false
	if _hip_weapon_mesh:
		_hip_weapon_mesh.visible = true
	emit_signal("weapon_sheathed")

func unsheath_weapon() -> void:
	is_sheathed = false
	var katana = find_child("KatanaBlade", true, false) as Node3D
	if katana:
		katana.visible = true
	if _hip_weapon_mesh:
		_hip_weapon_mesh.visible = false

func perform_slide() -> void:
	if is_sliding or stamina < 10.0:
		return
	is_sliding = true
	stamina = max(0.0, stamina - 10.0)
	emit_signal("stamina_changed", stamina, MAX_STAMINA)

	var move_forward = -visual_root.global_transform.basis.z if visual_root else -transform.basis.z
	move_forward.y = 0.0
	velocity += move_forward.normalized() * 5.8

	if locomotion_controller and locomotion_controller.has_method("trigger_running_slide"):
		locomotion_controller.trigger_running_slide()

	# Lower camera boom dynamically during slide
	if camera_boom:
		var cam_tween = create_tween()
		cam_tween.tween_property(camera_boom, "position:y", 0.95, 0.18)
		cam_tween.tween_interval(0.35)
		cam_tween.tween_property(camera_boom, "position:y", 1.4, 0.22)

	# Lower collision capsule to slide under half-opened gates
	var col = find_child("CollisionShape3D", true, false) as CollisionShape3D
	if col and col.shape is CapsuleShape3D:
		col.shape.height = 0.85
		col.position.y = 0.42

	# Complete HUD tutorial action if active
	var tree = get_tree() if is_inside_tree() else null
	if tree:
		var hud = get_parent().find_child("GameplayHUD", true, false) if get_parent() else null
		if hud and hud.has_method("complete_tutorial_action"):
			hud.complete_tutorial_action("TOAST_SLIDE")
		tree.create_timer(0.75).timeout.connect(func():
			is_sliding = false
			if col and col.shape is CapsuleShape3D:
				col.shape.height = 1.8
				col.position.y = 0.9
		)
	else:
		is_sliding = false

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

func take_damage(amount: float, attacker: Node = null) -> void:
	if deflect_window_timer > 0.0:
		trigger_perfect_deflect(attacker)
		return
	if is_invulnerable:
		trigger_perfect_dodge()
		return

	hp = max(0.0, hp - amount)
	combo_count = 0
	combo_multiplier = 1
	emit_signal("combo_changed", combo_count, combo_multiplier)
	emit_signal("hp_changed", hp, MAX_HP)
	if facial_controller:
		facial_controller.trigger_damage_grimace(0.9, 0.38)

func trigger_perfect_deflect(attacker: Node = null) -> void:
	deflect_window_timer = 0.0
	perfect_dodge_surge = true
	stamina = min(MAX_STAMINA, stamina + 30.0)
	emit_signal("stamina_changed", stamina, MAX_STAMINA)
	emit_signal("perfect_deflect_triggered", attacker)

	var hit_pos: Vector3 = global_position + Vector3(0, 1.1, 0) - visual_root.global_transform.basis.z * 0.7 if is_inside_tree() else position + Vector3(0, 1.1, -0.7)
	var parent := get_parent()
	if parent:
		ImpactSpawner.spawn_deflect_burst(parent, hit_pos)
		if player_camera:
			ImpactSpawner.trigger_screen_shake(player_camera, 0.22, 0.25)

		var tree := get_tree() if is_inside_tree() else null
		if tree:
			var parry_audio := AudioStreamPlayer.new()
			add_child(parry_audio)
			parry_audio.stream = ProceduralCinematicAudio.create_katana_parry_clash()
			parry_audio.play()
			parry_audio.finished.connect(func(): parry_audio.queue_free())

	if attacker:
		if attacker.has_method("apply_counter_stagger"):
			attacker.apply_counter_stagger()
		elif "is_staggered" in attacker and "stagger_timer" in attacker:
			attacker.is_staggered = true
			attacker.stagger_timer = 2.5
			if attacker.has_signal("stagger_changed"):
				attacker.emit_signal("stagger_changed", true)

	trigger_hit_stop(0.08)

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
		if get_nearest_interactable() == interactable:
			emit_signal("nearby_interactable_changed", interactable)

func unregister_nearby_interactable(interactable: Node) -> void:
	var was_nearest: bool = get_nearest_interactable() == interactable
	nearby_interactables.erase(interactable)
	if was_nearest:
		emit_signal("nearby_interactable_changed", get_nearest_interactable())

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
	if opening_recovery_active:
		return {"success": false, "reason": "opening_recovery"}
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

func get_traversal() -> PlayerTraversalController:
	return traversal

func is_climbing() -> bool:
	return traversal.is_climbing()

func is_swimming() -> bool:
	return traversal.is_swimming()

func start_climbing(normal: Vector3, contact_point: Vector3) -> bool:
	return traversal.start_climbing(normal, contact_point)

func stop_climbing() -> void:
	traversal.stop_climbing()

func climb_jump() -> bool:
	var jump_res = traversal.climb_jump(stamina)
	if jump_res.get("success", false):
		stamina = maxf(0.0, stamina - jump_res["stamina_cost"])
		emit_signal("stamina_changed", stamina, MAX_STAMINA)
		velocity = jump_res["impulse"]
		traversal.stop_climbing()
		return true
	return false

func enter_water(surface_y: float) -> void:
	var player_pos: Vector3 = global_position if is_inside_tree() else position
	traversal.enter_water(surface_y, player_pos)

func exit_water() -> void:
	traversal.exit_water()

func get_spatial_voice_manager() -> SpatialVoiceManagerScript:
	if not spatial_voice_manager:
		spatial_voice_manager = find_child("SpatialVoiceManager", true, false)
		if not spatial_voice_manager and is_inside_tree():
			spatial_voice_manager = SpatialVoiceManagerScript.new()
			spatial_voice_manager.name = "SpatialVoiceManager"
			add_child(spatial_voice_manager)
		elif not spatial_voice_manager:
			spatial_voice_manager = SpatialVoiceManagerScript.new()
	return spatial_voice_manager

func trigger_idle_bark() -> void:
	var svm = get_spatial_voice_manager()
	var barks = ["idle_breeze", "idle_sword", "idle_memory"]
	var chosen_bark: String = barks[randi() % barks.size()]
	var text_ja: String = ""
	if svm:
		var vpos = global_position if is_inside_tree() else position
		svm.play_voice(chosen_bark, vpos)
		var catalog_entry: Dictionary = svm.VOICE_CATALOG.get(chosen_bark, {})
		text_ja = catalog_entry.get("text_ja", "")
	emit_signal("idle_bark_triggered", chosen_bark, text_ja)

func get_visceral_combat() -> VisceralCombatControllerScript:
	if not visceral_combat:
		visceral_combat = find_child("VisceralCombatController", true, false)
		if not visceral_combat and is_inside_tree():
			visceral_combat = VisceralCombatControllerScript.new()
			visceral_combat.name = "VisceralCombatController"
			add_child(visceral_combat)
		elif not visceral_combat:
			visceral_combat = VisceralCombatControllerScript.new()
			visceral_combat.name = "VisceralCombatController"
	return visceral_combat

func can_execute_visceral(target: Node) -> bool:
	var vc = get_visceral_combat()
	if not vc:
		return false
	return vc.can_execute(self, target)

func execute_visceral_strike(target: Node, cine_camera_director: CineCameraDirector = null) -> Dictionary:
	var vc = get_visceral_combat()
	if not vc:
		return {"success": false, "reason": "no_visceral_controller"}
	combat_activity_timer = COMBAT_STANCE_DURATION
	if is_sheathed:
		unsheath_weapon()
	var res = vc.execute_visceral_strike(self, target, cine_camera_director)
	if res.get("success", false):
		emit_signal("visceral_strike_executed", target, res.get("damage", 0))
	return res

func get_team_swap() -> TeamSwapControllerScript:
	if not team_swap:
		team_swap = find_child("TeamSwapController", true, false)
		if not team_swap and is_inside_tree():
			team_swap = TeamSwapControllerScript.new()
			team_swap.name = "TeamSwapController"
			add_child(team_swap)
		elif not team_swap:
			team_swap = TeamSwapControllerScript.new()
			team_swap.name = "TeamSwapController"
	return team_swap

func swap_team_member(slot: int, cine_camera_director: CineCameraDirector = null) -> Dictionary:
	var ts = get_team_swap()
	if not ts:
		return {"success": false, "reason": "no_team_swap_controller"}
	var res = ts.swap_to_slot(slot, self, cine_camera_director)
	if res.get("success", false):
		emit_signal("team_swapped", res["previous_slot"], res["new_slot"], res["character"])
	return res

func add_burst_energy(amount: float) -> void:
	var ts = get_team_swap()
	if ts:
		ts.add_burst_energy(amount)

func can_use_burst() -> bool:
	var ts = get_team_swap()
	if not ts:
		return false
	return ts.can_execute_burst()

func execute_team_burst(target: Node = null, cine_camera_director: CineCameraDirector = null) -> Dictionary:
	var ts = get_team_swap()
	if not ts:
		return {"success": false, "reason": "no_team_swap_controller"}
	var res = ts.execute_ultimate_burst(self, target, cine_camera_director)
	if res.get("success", false):
		emit_signal("ultimate_burst_fired", res["slot"], res["character"], res["damage"])
	return res




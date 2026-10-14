class_name EchoFootstepSystem
extends Node3D

## Surface-Aware Footstep Audio & VFX System
## Senses the ground material beneath Echo's feet (metal grate, wet concrete, tatami/wood, water)
## and triggers synchronized 16-bit PCM foley audio and subtle ground dust/splash VFX.
##
## Synchronized to baked locomotion bone contact curves (30 FPS):
## - RUN (0.80s cycle, 24 frame intervals = 25 samples):
##     Right foot lowest Z at Frame 7 (0.233s, phase 0.2917), toe plant at Frame 8 (0.267s, phase 0.3333)
##     Left foot lowest Z at Frame 20 (0.667s, phase 0.8333), toe plant at Frame 20 (0.667s, phase 0.8333)
## - WALK (1.20s cycle, 36 frame intervals = 37 samples):
##     Right foot lowest Z at Frame 10 (0.333s, phase 0.2778), toe plant at Frame 11 (0.367s, phase 0.3056)
##     Left foot lowest Z at Frame 29 (0.967s, phase 0.8056), toe plant at Frame 30 (1.000s, phase 0.8333)

signal footstep_triggered(is_left: bool, surface_type: String, is_run: bool, world_pos: Vector3)

const ProceduralCinematicAudioScript = preload("res://scripts/audio/procedural_cinematic_audio.gd")
const EchoRigProfileScript = preload("res://scripts/player/echo_rig_profile.gd")

# Exact foot contact phases derived from baked animation bone data (30 FPS)
# Right foot touches down and reaches lowest elevation in early cycle; Left foot in late cycle.
const RUN_RIGHT_PHASE: float = 7.0 / 24.0 # Frame 7 / 24 (0.233s)
const RUN_LEFT_PHASE: float = 20.0 / 24.0  # Frame 20 / 24 (0.667s)

const WALK_RIGHT_PHASE: float = 10.0 / 36.0 # Frame 10 / 36 (0.333s)
const WALK_LEFT_PHASE: float = 29.0 / 36.0  # Frame 29 / 36 (0.967s)

@export var volume_db_offset: float = 0.0

var player: CharacterBody3D = null
var anim_player: AnimationPlayer = null
var footstep_audio_player: AudioStreamPlayer3D = null

var _last_phase: float = 0.0
var _step_cooldown: float = 0.0

func _ready() -> void:
	player = get_parent() as CharacterBody3D
	footstep_audio_player = AudioStreamPlayer3D.new()
	footstep_audio_player.name = "FootstepAudioPlayer"
	footstep_audio_player.unit_size = 2.0
	footstep_audio_player.max_distance = 25.0
	var sfx_bus := AudioServer.get_bus_index("SFX")
	footstep_audio_player.bus = "SFX" if sfx_bus >= 0 else "Master"
	add_child(footstep_audio_player)

func _crossed_phase(target: float, last_p: float, cur_p: float) -> bool:
	if last_p <= cur_p:
		return last_p < target and cur_p >= target
	else:
		return last_p < target or cur_p >= target

func _physics_process(delta: float) -> void:
	if not player or not player.is_inside_tree() or not player.is_on_floor():
		return

	if not anim_player:
		anim_player = player.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if not anim_player or not anim_player.is_playing():
		return

	var current_anim: String = anim_player.current_animation.to_lower()
	var is_walk := current_anim.contains("walk")
	var is_run := current_anim.contains("run")

	if not (is_walk or is_run):
		_last_phase = 0.0
		return

	_step_cooldown = maxf(0.0, _step_cooldown - delta)
	var anim_length := anim_player.current_animation_length
	if anim_length <= 0.0:
		return

	var phase := fposmod(anim_player.current_animation_position / anim_length, 1.0)

	var target_right := RUN_RIGHT_PHASE if is_run else WALK_RIGHT_PHASE
	var target_left := RUN_LEFT_PHASE if is_run else WALK_LEFT_PHASE

	var crossed_right := _crossed_phase(target_right, _last_phase, phase)
	var crossed_left := _crossed_phase(target_left, _last_phase, phase)

	if crossed_right and _step_cooldown <= 0.0:
		_step_cooldown = 0.16 if is_run else 0.24
		_trigger_footstep(false, is_run)
	elif crossed_left and _step_cooldown <= 0.0:
		_step_cooldown = 0.16 if is_run else 0.24
		_trigger_footstep(true, is_run)

	_last_phase = phase

func _get_foot_world_position(is_left: bool) -> Vector3:
	if player:
		var skeleton := player.find_child("Skeleton3D", true, false) as Skeleton3D
		if skeleton:
			var role := "left_toe" if is_left else "right_toe"
			var bone_name := EchoRigProfileScript.bone(skeleton, role)
			if bone_name.is_empty():
				bone_name = ("LeftToeBase" if is_left else "RightToeBase")
				if skeleton.find_bone(bone_name) < 0:
					bone_name = ("LeftFoot" if is_left else "RightFoot")
				if skeleton.find_bone(bone_name) < 0:
					bone_name = ("mixamorig_LeftToeBase" if is_left else "mixamorig_RightToeBase")
				if skeleton.find_bone(bone_name) < 0:
					bone_name = ("mixamorig_LeftFoot" if is_left else "mixamorig_RightFoot")
				if skeleton.find_bone(bone_name) < 0:
					bone_name = ("tripo__1_Left_Limb_3" if is_left else "tripo__1_Right_Limb_3")
			var bone_idx := skeleton.find_bone(bone_name)
			if bone_idx >= 0:
				return skeleton.global_transform * skeleton.get_bone_global_pose(bone_idx).origin

		var foot_offset_x := -0.16 if is_left else 0.16
		return player.global_position + player.global_transform.basis.x * foot_offset_x

	return global_position

func _trigger_footstep(is_left: bool, is_run: bool) -> void:
	var foot_world := _get_foot_world_position(is_left)
	var surface_type := _detect_surface(foot_world)
	_play_step_audio(surface_type, is_run, foot_world)
	_spawn_step_vfx(surface_type, foot_world)
	footstep_triggered.emit(is_left, surface_type, is_run, foot_world)

func _detect_surface(origin: Vector3) -> String:
	if not player or not player.is_inside_tree():
		return "concrete"

	var space_state := player.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		origin + Vector3.UP * 0.35,
		origin - Vector3.UP * 0.6,
		1
	)
	query.exclude = [player.get_rid()]
	var result := space_state.intersect_ray(query)
	if result.is_empty():
		return "concrete"

	var collider = result.get("collider")
	if not collider:
		return "concrete"

	var name_lower: String = String(collider.name).to_lower()
	var parent_name: String = String(collider.get_parent().name).to_lower() if collider.get_parent() else ""
	var combined: String = name_lower + " " + parent_name

	if combined.contains("metal") or combined.contains("grate") or combined.contains("catwalk") or combined.contains("panel") or combined.contains("facility") or combined.contains("floor_plate"):
		return "metal"
	elif combined.contains("wood") or combined.contains("tatami") or combined.contains("residence") or combined.contains("house") or combined.contains("board"):
		return "wood"
	elif combined.contains("water") or combined.contains("puddle") or combined.contains("ocean") or combined.contains("sea") or combined.contains("flood"):
		return "water"

	return "concrete"

func _is_audio_muted() -> bool:
	if AudioServer.is_bus_mute(0):
		return true
	var sfx_bus := AudioServer.get_bus_index("SFX")
	if sfx_bus >= 0 and AudioServer.is_bus_mute(sfx_bus):
		return true
	if player:
		if player.get("audio_muted") == true or (player.has_meta("audio_muted") and player.get_meta("audio_muted") == true):
			return true
		var ancestor: Node = player.get_parent()
		while ancestor:
			if ancestor.get("audio_muted") == true or (ancestor.has_meta("audio_muted") and ancestor.get_meta("audio_muted") == true):
				return true
			ancestor = ancestor.get_parent()
	return false

func _play_step_audio(surface_type: String, is_run: bool, world_pos: Vector3) -> void:
	if not footstep_audio_player:
		return
	if _is_audio_muted():
		return

	var stream: AudioStreamWAV = ProceduralCinematicAudioScript.create_footstep(surface_type, is_run)
	if stream:
		var sfx_bus := AudioServer.get_bus_index("SFX")
		footstep_audio_player.bus = "SFX" if sfx_bus >= 0 else "Master"
		footstep_audio_player.global_position = world_pos
		footstep_audio_player.stream = stream
		footstep_audio_player.pitch_scale = randf_range(0.93, 1.07)
		var base_vol: float = 1.0 if is_run else -1.5
		footstep_audio_player.volume_db = base_vol + volume_db_offset
		footstep_audio_player.play()

func _is_reduced_motion() -> bool:
	if player:
		if player.get("reduced_camera_motion") == true or player.get("reduced_motion") == true or (player.has_meta("reduced_motion") and player.get_meta("reduced_motion") == true):
			return true
		var ancestor: Node = player.get_parent()
		while ancestor:
			if ancestor.get("reduced_motion") == true or (ancestor.has_meta("reduced_motion") and ancestor.get_meta("reduced_motion") == true):
				return true
			ancestor = ancestor.get_parent()
	return false

func _spawn_step_vfx(surface_type: String, foot_pos: Vector3) -> void:
	var parent := player.get_parent() if player else null
	if not parent:
		return

	var reduced := _is_reduced_motion()

	var vfx := GPUParticles3D.new()
	vfx.name = "FootstepPuff"
	vfx.position = Vector3(foot_pos.x, foot_pos.y + 0.04, foot_pos.z)
	vfx.emitting = true
	vfx.one_shot = true
	vfx.amount = 3 if reduced else 8
	vfx.lifetime = 0.20 if reduced else 0.28
	vfx.explosiveness = 0.3 if reduced else 0.9

	var p_mat := ParticleProcessMaterial.new()
	p_mat.direction = Vector3.UP
	p_mat.spread = 35.0 if reduced else 70.0
	p_mat.initial_velocity_min = 0.15 if reduced else 0.6
	p_mat.initial_velocity_max = 0.40 if reduced else 1.6
	p_mat.gravity = Vector3(0, -1.0, 0) if reduced else Vector3(0, -2.5, 0)
	p_mat.scale_min = 0.015 if reduced else 0.02
	p_mat.scale_max = 0.035 if reduced else 0.06

	match surface_type:
		"water":
			p_mat.color = Color(0.65, 0.9, 1.0, 0.50 if reduced else 0.75)
		"metal":
			p_mat.color = Color(0.85, 0.95, 1.0, 0.35 if reduced else 0.50)
		"wood":
			p_mat.color = Color(0.7, 0.6, 0.5, 0.30 if reduced else 0.40)
		_:
			p_mat.color = Color(0.75, 0.75, 0.8, 0.30 if reduced else 0.45)

	vfx.process_material = p_mat

	var draw_mesh := BoxMesh.new()
	var mesh_size := 0.025 if reduced else 0.04
	draw_mesh.size = Vector3(mesh_size, mesh_size, mesh_size)
	var m_mat := StandardMaterial3D.new()
	m_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	m_mat.albedo_color = p_mat.color
	draw_mesh.material = m_mat
	vfx.draw_pass_1 = draw_mesh

	parent.add_child(vfx)

	var tree := parent.get_tree()
	if tree:
		# Bound receiver disconnects when the room frees its puff before timeout.
		tree.create_timer(0.35).timeout.connect(vfx.queue_free)


class_name EchoFootstepSystem
extends Node3D

## Surface-Aware Footstep Audio & VFX System
## Senses the ground material beneath Echo's feet (metal grate, wet concrete, tatami/wood, water)
## and triggers synchronized 16-bit PCM foley audio and subtle ground dust/splash VFX.

const ProceduralCinematicAudioScript = preload("res://scripts/audio/procedural_cinematic_audio.gd")

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
	add_child(footstep_audio_player)

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
	
	# Left foot contact around 0.15, right foot contact around 0.65
	var crossed_left := (_last_phase < 0.15 and phase >= 0.15) or (_last_phase > 0.85 and phase < 0.2)
	var crossed_right := (_last_phase < 0.65 and phase >= 0.65)
	
	if (crossed_left or crossed_right) and _step_cooldown <= 0.0:
		_step_cooldown = 0.18 if is_run else 0.28
		var is_left: bool = crossed_left
		_trigger_footstep(is_left, is_run)

	_last_phase = phase

func _trigger_footstep(is_left: bool, is_run: bool) -> void:
	var foot_offset_x := -0.16 if is_left else 0.16
	var foot_world := player.global_position + player.global_transform.basis.x * foot_offset_x
	
	var surface_type := _detect_surface(foot_world)
	_play_step_audio(surface_type, is_run, foot_world)
	_spawn_step_vfx(surface_type, foot_world)

func _detect_surface(origin: Vector3) -> String:
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
	elif combined.contains("water") or combined.contains("puddle") or combined.contains("ocean") or combined.contains("sea"):
		return "water"

	return "concrete"

func _play_step_audio(surface_type: String, is_run: bool, world_pos: Vector3) -> void:
	var stream: AudioStreamWAV = ProceduralCinematicAudioScript.create_footstep(surface_type, is_run)
	if stream and footstep_audio_player:
		footstep_audio_player.global_position = world_pos
		footstep_audio_player.stream = stream
		footstep_audio_player.pitch_scale = randf_range(0.93, 1.07)
		footstep_audio_player.volume_db = 1.0 if is_run else -1.5
		footstep_audio_player.play()

func _spawn_step_vfx(surface_type: String, foot_pos: Vector3) -> void:
	var parent := player.get_parent()
	if not parent:
		return

	var vfx := GPUParticles3D.new()
	vfx.name = "FootstepPuff"
	vfx.position = Vector3(foot_pos.x, foot_pos.y + 0.04, foot_pos.z)
	vfx.emitting = true
	vfx.one_shot = true
	vfx.amount = 8
	vfx.lifetime = 0.28
	vfx.explosiveness = 0.9

	var p_mat := ParticleProcessMaterial.new()
	p_mat.direction = Vector3.UP
	p_mat.spread = 70.0
	p_mat.initial_velocity_min = 0.6
	p_mat.initial_velocity_max = 1.6
	p_mat.gravity = Vector3(0, -2.5, 0)
	p_mat.scale_min = 0.02
	p_mat.scale_max = 0.06

	match surface_type:
		"water":
			p_mat.color = Color(0.65, 0.9, 1.0, 0.75)
		"metal":
			p_mat.color = Color(0.85, 0.95, 1.0, 0.5)
		"wood":
			p_mat.color = Color(0.7, 0.6, 0.5, 0.4)
		_:
			p_mat.color = Color(0.75, 0.75, 0.8, 0.45)

	vfx.process_material = p_mat

	var draw_mesh := BoxMesh.new()
	draw_mesh.size = Vector3(0.04, 0.04, 0.04)
	var m_mat := StandardMaterial3D.new()
	m_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	m_mat.albedo_color = p_mat.color
	draw_mesh.material = m_mat
	vfx.draw_pass_1 = draw_mesh

	parent.add_child(vfx)

	var tree := parent.get_tree()
	if tree:
		tree.create_timer(0.35).timeout.connect(func():
			if is_instance_valid(vfx): vfx.queue_free()
		)

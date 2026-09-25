class_name CinematicPostProcessor
extends Node

## 11.11 Cinematic Post-Processing & Atmosphere Director (Genshin Impact Benchmark)
## Applies world-class Forward+ visual styling: ACES filmic tonemapping, rich color saturation (1.25),
## Screen-Space Reflections (SSR 64 steps), Screen-Space Ambient Occlusion (SSAO 2.4), Softlight bloom,
## and procedural anime sky dome.

const AnimeSkyShader = preload("res://shaders/anime_sky.gdshader")

var world_env: WorldEnvironment = null
var current_sky_mat: ShaderMaterial = null
var is_active: bool = false

func _ready() -> void:
	apply_world_class_visuals()

func apply_world_class_visuals() -> void:
	if not world_env:
		if get_parent() and get_parent().has_node("WorldEnvironment"):
			world_env = get_parent().get_node("WorldEnvironment") as WorldEnvironment
		elif get_tree() and get_tree().root:
			world_env = get_tree().root.find_child("WorldEnvironment", true, false) as WorldEnvironment

	if not world_env:
		# If scene has no WorldEnvironment, instantiate one dynamically
		world_env = WorldEnvironment.new()
		world_env.name = "WorldEnvironment"
		world_env.environment = Environment.new()
		if get_parent():
			get_parent().add_child(world_env)
		else:
			add_child(world_env)

	if not world_env.environment:
		world_env.environment = Environment.new()

	var env: Environment = world_env.environment

	# 1. ACES Filmic Tonemapping
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.15

	# 2. Rich Saturated Anime Color Grading (Genshin Standard)
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.25
	env.adjustment_contrast = 1.14
	env.adjustment_brightness = 1.02

	# 3. Screen-Space Reflections (SSR)
	env.ssr_enabled = true
	env.ssr_max_steps = 64
	env.ssr_fade_in = 0.15
	env.ssr_fade_out = 2.0
	env.ssr_depth_tolerance = 0.2

	# 4. Screen-Space Ambient Occlusion (SSAO)
	env.ssao_enabled = true
	env.ssao_radius = 1.5
	env.ssao_intensity = 2.4
	env.ssao_power = 1.5
	env.ssao_detail = 0.5
	env.ssao_horizon = 0.06

	# 5. Softlight Anime Glow / Bloom Curves
	env.glow_enabled = true
	env.glow_normalized = true
	env.glow_intensity = 0.95
	env.glow_bloom = 0.25
	env.glow_hdr_threshold = 0.92
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT

	# 6. Subtle Volumetric Fog (Light Shafts & Atmospheric Depth)
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.012
	env.volumetric_fog_albedo = Color(0.24, 0.35, 0.55, 1.0)
	env.volumetric_fog_emission_energy = 0.8
	env.volumetric_fog_anisotropy = 0.35
	env.volumetric_fog_length = 96.0
	env.volumetric_fog_ambient_inject = 0.35

	# 7. Procedural Stylized Anime Sky Dome
	_setup_anime_sky(env)
	is_active = true

func _setup_anime_sky(env: Environment) -> void:
	if not current_sky_mat:
		current_sky_mat = ShaderMaterial.new()
		current_sky_mat.shader = AnimeSkyShader
		current_sky_mat.set_shader_parameter("zenith_color", Color(0.04, 0.06, 0.18, 1.0))
		current_sky_mat.set_shader_parameter("horizon_color", Color(0.14, 0.32, 0.58, 1.0))
		current_sky_mat.set_shader_parameter("horizon_glow_color", Color(0.32, 0.48, 0.72, 1.0))
		current_sky_mat.set_shader_parameter("ground_color", Color(0.015, 0.02, 0.04, 1.0))
		current_sky_mat.set_shader_parameter("horizon_blur", 0.45)
		current_sky_mat.set_shader_parameter("sun_direction", Vector3(0.4, 0.6, -0.6))
		current_sky_mat.set_shader_parameter("sun_disk_color", Color(1.0, 0.96, 0.82, 1.0))
		current_sky_mat.set_shader_parameter("sun_disk_size", 0.025)
		current_sky_mat.set_shader_parameter("sun_halo_size", 0.15)
		current_sky_mat.set_shader_parameter("stars_intensity", 2.2)
		current_sky_mat.set_shader_parameter("cloud_color", Color(0.22, 0.36, 0.65, 0.65))
		current_sky_mat.set_shader_parameter("cloud_rim_color", Color(0.42, 0.60, 0.88, 0.85))
		current_sky_mat.set_shader_parameter("cloud_coverage", 0.40)
		current_sky_mat.set_shader_parameter("cloud_speed", 0.014)

	var sky := Sky.new()
	sky.sky_material = current_sky_mat
	env.sky = sky
	env.background_mode = Environment.BG_SKY

func is_visual_post_processing_active() -> bool:
	return is_active and world_env != null and world_env.environment != null

func get_color_saturation() -> float:
	if world_env and world_env.environment and world_env.environment.adjustment_enabled:
		return world_env.environment.adjustment_saturation
	return 1.0

func get_tonemap_mode() -> int:
	if world_env and world_env.environment:
		return world_env.environment.tonemap_mode
	return -1

func is_volumetric_fog_active() -> bool:
	return world_env != null and world_env.environment != null and world_env.environment.volumetric_fog_enabled

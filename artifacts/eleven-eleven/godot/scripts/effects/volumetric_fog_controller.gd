class_name VolumetricFogController
extends Node

enum FogProfile {
	SECTOR11_LAB,
	ABYSS_VOID,
	HOSPITAL_SUNLIGHT
}

@export var current_profile: FogProfile = FogProfile.SECTOR11_LAB
@export var target_world_environment: WorldEnvironment = null

var custom_env: Environment = null

func _ready() -> void:
	_init_environment()
	apply_profile(current_profile)

func _init_environment() -> void:
	if not target_world_environment:
		target_world_environment = get_parent().find_child("WorldEnvironment", true, false) as WorldEnvironment
	
	if target_world_environment and target_world_environment.environment:
		custom_env = target_world_environment.environment
	else:
		custom_env = Environment.new()
		if not target_world_environment:
			target_world_environment = WorldEnvironment.new()
			target_world_environment.name = "WorldEnvironment"
			add_child(target_world_environment)
		target_world_environment.environment = custom_env

func apply_profile(profile: FogProfile, duration: float = 0.8) -> void:
	current_profile = profile
	if not custom_env:
		_init_environment()
	if not custom_env:
		return

	custom_env.volumetric_fog_enabled = true
	
	var target_density: float = 0.02
	var target_albedo: Color = Color(0.1, 0.14, 0.22)
	var target_emission: Color = Color(0.01, 0.02, 0.04)

	match profile:
		FogProfile.SECTOR11_LAB:
			target_density = 0.022
			target_albedo = Color(0.12, 0.16, 0.25)
			target_emission = Color(0.02, 0.04, 0.06)
		FogProfile.ABYSS_VOID:
			target_density = 0.048
			target_albedo = Color(0.01, 0.02, 0.05)
			target_emission = Color(0.0, 0.01, 0.02)
		FogProfile.HOSPITAL_SUNLIGHT:
			target_density = 0.012
			target_albedo = Color(0.92, 0.88, 0.82)
			target_emission = Color(0.15, 0.14, 0.1)

	var tree = get_tree() if is_inside_tree() else null
	if tree and duration > 0.0:
		var tween = tree.create_tween().set_parallel(true)
		tween.tween_property(custom_env, "volumetric_fog_density", target_density, duration)
		tween.tween_property(custom_env, "volumetric_fog_albedo", target_albedo, duration)
		tween.tween_property(custom_env, "volumetric_fog_emission", target_emission, duration)
	else:
		custom_env.volumetric_fog_density = target_density
		custom_env.volumetric_fog_albedo = target_albedo
		custom_env.volumetric_fog_emission = target_emission

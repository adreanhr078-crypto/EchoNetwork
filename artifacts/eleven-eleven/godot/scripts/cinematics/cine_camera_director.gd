class_name CineCameraDirector
extends Node

signal trauma_applied(amount: float)
signal fov_punched(target_fov: float)
signal dutch_tilt_changed(degrees: float)
signal bullet_time_triggered(scale: float, duration: float)
signal combat_finisher_triggered(impact_point: Vector3)

@export var camera_path: NodePath
var active_camera: Camera3D

# Trauma-based 3D Rotational & Translational Shake
var trauma: float = 0.0
var trauma_power: float = 2.0
var trauma_decay: float = 1.6
var max_pitch: float = deg_to_rad(4.5)
var max_yaw: float = deg_to_rad(5.5)
var max_roll: float = deg_to_rad(6.5)
var max_offset: Vector3 = Vector3(0.35, 0.35, 0.25)
var noise_time: float = 0.0
var noise_frequency: float = 28.0

# Directional Trauma Shake (recoil along impact axis)
var directional_trauma_vector: Vector3 = Vector3.ZERO
var directional_trauma_decay: float = 7.5

# Dynamic Dutch Tilt & FOV
var base_fov: float = 70.0
var current_dutch_tilt: float = 0.0
var original_camera_rotation: Vector3 = Vector3.ZERO
var is_active: bool = true

func _ready() -> void:
	_resolve_camera()

func _resolve_camera() -> void:
	if active_camera:
		return
	if camera_path and has_node(camera_path):
		active_camera = get_node(camera_path) as Camera3D
	if not active_camera and get_viewport():
		active_camera = get_viewport().get_camera_3d()
	if not active_camera and get_parent() is Camera3D:
		active_camera = get_parent() as Camera3D
	if active_camera:
		base_fov = active_camera.fov

func _process(delta: float) -> void:
	if not is_active:
		return
	_resolve_camera()
	if not active_camera:
		return

	# Handle Trauma Decay
	if trauma > 0.0:
		trauma = max(0.0, trauma - trauma_decay * delta)
		noise_time += delta * noise_frequency
		var shake_amount = pow(trauma, trauma_power)
		
		# Multi-octave pseudo-perlin shake
		var shake_roll = max_roll * shake_amount * sin(noise_time * 1.3)
		var shake_pitch = max_pitch * shake_amount * sin(noise_time * 1.7 + 0.8)
		var shake_yaw = max_yaw * shake_amount * cos(noise_time * 1.1 + 1.2)
		
		var shake_offset_x = max_offset.x * shake_amount * sin(noise_time * 1.9)
		var shake_offset_y = max_offset.y * shake_amount * cos(noise_time * 2.3)
		var shake_offset_z = max_offset.z * shake_amount * sin(noise_time * 1.5 + 2.0)
		
		active_camera.h_offset = shake_offset_x
		active_camera.v_offset = shake_offset_y
		active_camera.rotation.z = deg_to_rad(current_dutch_tilt) + shake_roll
	else:
		active_camera.h_offset = lerp(active_camera.h_offset, 0.0, 10.0 * delta)
		active_camera.v_offset = lerp(active_camera.v_offset, 0.0, 10.0 * delta)
		active_camera.rotation.z = lerp(active_camera.rotation.z, deg_to_rad(current_dutch_tilt), 12.0 * delta)

	# Handle Directional Trauma Decay & Offset
	if directional_trauma_vector.length() > 0.001:
		directional_trauma_vector = directional_trauma_vector.move_toward(Vector3.ZERO, directional_trauma_decay * delta)
		active_camera.h_offset += directional_trauma_vector.x
		active_camera.v_offset += directional_trauma_vector.y
		active_camera.rotation.z += directional_trauma_vector.x * 0.15
		active_camera.rotation.x -= directional_trauma_vector.z * 0.12

## Apply trauma (0.0 to 1.0) with exponential decay
func apply_trauma(amount: float) -> void:
	trauma = clamp(trauma + amount, 0.0, 1.0)
	emit_signal("trauma_applied", trauma)

## Apply directional trauma opposing attack angle
func apply_directional_trauma(recoil_direction: Vector3, intensity: float = 0.6) -> void:
	apply_trauma(intensity * 0.65)
	var dir = recoil_direction.normalized() if recoil_direction.length() > 0.01 else Vector3.BACK
	directional_trauma_vector += Vector3(dir.x, dir.y, dir.z) * intensity * 0.45

## Cinematic Preset: Dynamic Combat Finisher Zoom & Stagger Strike
func preset_combat_finisher(impact_point: Vector3 = Vector3.ZERO, striker_forward: Vector3 = Vector3.BACK) -> void:
	emit_signal("combat_finisher_triggered", impact_point)
	apply_trauma(0.85)
	var lateral_sign: float = -1.0 if randf() > 0.5 else 1.0
	apply_directional_trauma(striker_forward * 0.6 + Vector3.RIGHT * lateral_sign * 0.4, 0.8)
	punch_fov(48.0, 0.04, 0.42)
	set_dutch_tilt(5.5 * lateral_sign, 0.2)
	trigger_bullet_time(0.12, 0.35)

## Rapid FOV punch with smooth recovery
func punch_fov(target_fov: float, punch_in_time: float = 0.08, restore_time: float = 0.45) -> void:
	_resolve_camera()
	if not active_camera:
		return
	emit_signal("fov_punched", target_fov)
	var tree = get_tree() if is_inside_tree() else null
	if not tree:
		active_camera.fov = target_fov
		return
	
	var tween = tree.create_tween()
	tween.tween_property(active_camera, "fov", target_fov, punch_in_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(active_camera, "fov", base_fov, restore_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

## Anime-style diagonal Dutch tilt
func set_dutch_tilt(degrees: float, duration: float = 0.35) -> void:
	current_dutch_tilt = degrees
	emit_signal("dutch_tilt_changed", degrees)
	var tree = get_tree() if is_inside_tree() else null
	if tree and active_camera:
		var tween = tree.create_tween()
		tween.tween_property(self, "current_dutch_tilt", degrees, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

## Slow-motion bullet-time curve
func trigger_bullet_time(time_scale: float = 0.15, real_duration: float = 0.4) -> void:
	emit_signal("bullet_time_triggered", time_scale, real_duration)
	Engine.time_scale = time_scale
	var tree = get_tree() if is_inside_tree() else null
	if tree:
		var timer = tree.create_timer(real_duration * time_scale)
		timer.timeout.connect(func(): Engine.time_scale = 1.0)

## Cinematic Preset: Combat Critical Strike
func preset_combat_critical() -> void:
	apply_trauma(0.75)
	punch_fov(52.0, 0.06, 0.35)
	set_dutch_tilt(-4.5, 0.25)
	trigger_bullet_time(0.2, 0.3)

## Cinematic Preset: Zero Covenant Sealed Explosion
func preset_zero_awakening() -> void:
	apply_trauma(1.0)
	punch_fov(42.0, 0.1, 0.7)
	set_dutch_tilt(8.0, 0.5)
	trigger_bullet_time(0.12, 0.6)

## Cinematic Preset: Hospital Awakening Serenity & Realization
func preset_hospital_awakening() -> void:
	trauma = 0.0
	current_dutch_tilt = 0.0
	if active_camera:
		active_camera.fov = 68.0
	set_dutch_tilt(1.5, 1.2)

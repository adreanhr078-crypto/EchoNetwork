class_name ProceduralFootIK
extends Node3D

## Procedural Foot Placement & Terrain Adaptation IK
## Casts dynamic raycasts to align feet and pelvis with slopes, catwalk grates, and debris.

@export var ray_length: float = 1.1
@export var ray_origin_height: float = 0.55
@export var foot_spread: float = 0.22
@export var ik_strength: float = 1.0
@export var smooth_speed: float = 14.0

var _left_ray: RayCast3D = null
var left_ray: RayCast3D:
	get:
		if not _left_ray:
			init_rays()
		return _left_ray
	set(val):
		_left_ray = val

var _right_ray: RayCast3D = null
var right_ray: RayCast3D:
	get:
		if not _right_ray:
			init_rays()
		return _right_ray
	set(val):
		_right_ray = val

var pelvis_offset: float = 0.0
var target_pelvis_offset: float = 0.0
var target_tilt: Vector3 = Vector3.ZERO
var current_tilt: Vector3 = Vector3.ZERO
var is_ground_adapted: bool = false

func _enter_tree() -> void:
	init_rays()

func _ready() -> void:
	init_rays()

func init_rays() -> void:
	if _left_ray and _right_ray:
		return

	if not _left_ray:
		_left_ray = RayCast3D.new()
		_left_ray.name = "LeftFootRay"
		_left_ray.position = Vector3(-foot_spread, ray_origin_height, 0.0)
		_left_ray.target_position = Vector3(0, -ray_length, 0)
		_left_ray.collision_mask = 1
		_left_ray.enabled = true
		add_child(_left_ray)

	if not _right_ray:
		_right_ray = RayCast3D.new()
		_right_ray.name = "RightFootRay"
		_right_ray.position = Vector3(foot_spread, ray_origin_height, 0.0)
		_right_ray.target_position = Vector3(0, -ray_length, 0)
		_right_ray.collision_mask = 1
		_right_ray.enabled = true
		add_child(_right_ray)

func _physics_process(delta: float) -> void:
	if not is_inside_tree() or delta <= 0.0:
		return

	var player = get_parent() as CharacterBody3D
	if not player:
		return

	if not player.is_on_floor():
		target_pelvis_offset = 0.0
		target_tilt = Vector3.ZERO
		is_ground_adapted = false
	else:
		var left_hit: bool = left_ray.is_colliding() if left_ray else false
		var right_hit: bool = right_ray.is_colliding() if right_ray else false

		if left_hit or right_hit:
			var left_dist: float = (left_ray.global_position.y - left_ray.get_collision_point().y) if left_hit else ray_origin_height
			var right_dist: float = (right_ray.global_position.y - right_ray.get_collision_point().y) if right_hit else ray_origin_height

			var max_dist: float = max(left_dist, right_dist)
			var height_diff: float = max_dist - ray_origin_height
			target_pelvis_offset = -clamp(height_diff * 0.75, 0.0, 0.35)

			# Ground normal alignment tilt
			var norm: Vector3 = Vector3.UP
			if left_hit and right_hit:
				norm = ((left_ray.get_collision_normal() + right_ray.get_collision_normal()) * 0.5).normalized()
			elif left_hit:
				norm = left_ray.get_collision_normal()
			elif right_hit:
				norm = right_ray.get_collision_normal()

			var ground_slope_x = atan2(norm.x, norm.y)
			var ground_slope_z = atan2(norm.z, norm.y)
			target_tilt = Vector3(-ground_slope_z * 0.45, 0, ground_slope_x * 0.45)
			is_ground_adapted = true
		else:
			target_pelvis_offset = 0.0
			target_tilt = Vector3.ZERO
			is_ground_adapted = false

	# Smooth interpolation
	pelvis_offset = lerp(pelvis_offset, target_pelvis_offset, smooth_speed * delta)
	current_tilt = current_tilt.lerp(target_tilt, smooth_speed * delta)

	# Apply to visual root
	var visual_root = player.get_node_or_null("ModelRoot")
	if visual_root:
		visual_root.position.y = pelvis_offset

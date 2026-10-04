class_name TraversalPlatform
extends AnimatableBody3D

## Physics-owned lift/platform. CharacterBody3D supplies floor carry exactly once.
@export var travel := Vector3(0, 3.4, 0)
@export var speed := 0.85
@export var acceleration := 1.6
@export var dwell := 1.0
@export var running := true
@export var obstruction_mask := 1
var blocked := false
var _origin := Vector3.ZERO
var _distance := 0.0
var _direction := 1.0
var _speed := 0.0
var _wait := 0.0

func _ready() -> void:
	_origin = position
	sync_to_physics = true
	process_physics_priority = -20

func _physics_process(delta: float) -> void:
	blocked = false
	if not running or travel.length() < 0.001:
		_speed = 0.0
		return
	if _wait > 0:
		_wait = maxf(0, _wait - delta)
		return
	var remaining := travel.length() - _distance if _direction > 0 else _distance
	var target_speed := minf(maxf(0.01, speed), sqrt(maxf(0, 2 * maxf(0.01, acceleration) * remaining)))
	_speed = move_toward(_speed, target_speed, maxf(0.01, acceleration) * delta)
	var step := minf(remaining, _speed * delta)
	var parent_basis: Basis = get_parent().global_basis if get_parent() is Node3D else Basis.IDENTITY
	var motion := parent_basis * travel.normalized() * step * _direction
	if _obstructed(motion):
		_speed = 0
		blocked = true
		return
	_distance = clampf(_distance + step * _direction, 0, travel.length())
	position = _origin + travel.normalized() * _distance
	if remaining <= step + 0.00001:
		_direction *= -1
		_speed = 0
		_wait = maxf(0, dwell)

func _obstructed(motion: Vector3) -> bool:
	if motion.length_squared() < 0.00000001: return false
	var space := get_world_3d().direct_space_state
	var shapes := find_children("*", "CollisionShape3D", false, false)
	for shape_node in shapes:
		var collision := shape_node as CollisionShape3D
		if collision.disabled or not collision.shape: continue
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = collision.shape
		query.transform = collision.global_transform
		query.motion = motion
		query.collision_mask = obstruction_mask
		query.exclude = [get_rid()]
		query.margin = 0.002
		# Ignore a rider as an obstruction, but sweep its headroom too. A lift
		# stops before pinching the rider against a ceiling, not after contact.
		var candidates := query
		candidates.transform.origin += Vector3.UP * 0.05
		var overlaps := space.intersect_shape(candidates, 16)
		candidates.transform.origin -= Vector3.UP * 0.05
		var excluded: Array[RID] = [get_rid()]
		for hit in overlaps:
			var rider := hit.collider as CharacterBody3D
			if rider and rider.is_on_floor() and rider.global_position.y >= global_position.y:
				excluded.append(rider.get_rid())
				if _rider_obstructed(rider, motion): return true
		query.exclude = excluded
		var fractions := space.cast_motion(query)
		if fractions[0] < 1.0: return true
	return false

func _rider_obstructed(rider: CharacterBody3D, motion: Vector3) -> bool:
	var collider := rider.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if not collider: return true
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = collider.shape
	query.transform = collider.global_transform
	query.motion = motion
	query.collision_mask = rider.collision_mask
	query.exclude = [get_rid(), rider.get_rid()]
	var space := get_world_3d().direct_space_state
	return not space.intersect_shape(query, 1).is_empty() or space.cast_motion(query)[0] < 1.0

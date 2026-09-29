extends RefCounted

## Collision-led human traversal. Opt-in until animation/device acceptance.
signal ledge_reached
signal mantle_completed
const REACH := 0.9
const HANG_HEIGHT := 1.5
const ASSIST_LIMIT := 0.25
var hanging := false
var latch_cooldown := 0.0
var _mantle_points: Array[Vector3] = []
var _mantle_elapsed := 0.0
var _mantle_duration := 1.0
var _mantle_visual_origin := Vector3.ZERO
var _mantle_visual_active := false

func _ray(body: CharacterBody3D, from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to, body.collision_mask, [body.get_rid()])
	return body.get_world_3d().direct_space_state.intersect_ray(query)

func _climbable(hit: Dictionary) -> bool:
	return not hit.is_empty() and hit.collider is Node and hit.collider.is_in_group("climbable") and absf(hit.normal.y) < 0.2

func _wall(body: CharacterBody3D, direction: Vector3, height: float = 1.0) -> Dictionary:
	var from := body.global_position + Vector3.UP * height
	return _ray(body, from, from + direction * REACH)

func _top(body: CharacterBody3D, normal: Vector3) -> Dictionary:
	var from := body.global_position - normal * 0.65 + Vector3.UP * 1.85
	var hit := _ray(body, from, from - Vector3.UP * 1.3)
	# The rest platform can overlap the tagged wall and be a separate body.
	# Latching still requires an explicitly climbable vertical surface.
	if hit.is_empty() or hit.normal.y < 0.8:
		return {}
	return hit

func _clear_path(body: CharacterBody3D, from: Vector3, to: Vector3) -> bool:
	var pose := body.global_transform
	pose.origin = from
	return not body.test_move(pose, to - from)

func reset(body: CharacterBody3D) -> void:
	if _mantle_visual_active and body.visual_root:
		body.visual_root.position = _mantle_visual_origin
	_mantle_visual_active = false
	hanging = false
	_mantle_points.clear()
	latch_cooldown = 0.4
	body.traversal.stop_climbing()
	if body.animation_player: body.animation_player.speed_scale = 1.0

func _begin_mantle(body: CharacterBody3D) -> bool:
	var top := _top(body, body.traversal.wall_normal)
	if top.is_empty(): return false
	var raised := Vector3(body.global_position.x, top.position.y + 0.06, body.global_position.z)
	var landed: Vector3 = raised - body.traversal.wall_normal * 0.85
	# Sweep the actual player capsule on both segments, including overhead space.
	if not _clear_path(body, body.global_position, raised) or not _clear_path(body, raised, landed):
		return false
	_mantle_points.assign([raised, landed])
	_mantle_elapsed = 0.0
	_mantle_duration = (body.global_position.distance_to(raised) + raised.distance_to(landed)) / 2.4
	if body.visual_root:
		_mantle_visual_origin = body.visual_root.position
		_mantle_visual_active = true
	hanging = false
	body.velocity = Vector3.ZERO
	if body.animation_player and body.animation_player.has_animation("PARKOUR_MANTLE"):
		# Manual physics-time seeking cannot advance a paused blend weight.
		body.play_anim("PARKOUR_MANTLE", 0.0)
		body.animation_player.speed_scale = 0.0
		body.animation_player.seek(0.0, true)
	return true

func tick(body: CharacterBody3D, delta: float, input: Vector2, jump: bool, drop: bool) -> bool:
	latch_cooldown = maxf(0.0, latch_cooldown - delta)
	if not _mantle_points.is_empty():
		_mantle_elapsed += delta
		if _mantle_visual_active:
			# Fold the legs as the capsule clears the lip. The torso stays low
			# enough for the hands to push, then settles back to the same origin.
			var phase := clampf(_mantle_elapsed / _mantle_duration, 0.0, 1.0)
			body.visual_root.position = _mantle_visual_origin - Vector3.UP * (0.65 * sin(PI * phase))
		if body.animation_player and body.animation_player.has_animation("PARKOUR_MANTLE"):
			var clip: Animation = body.animation_player.get_animation("PARKOUR_MANTLE")
			body.animation_player.seek(minf(clip.length, _mantle_elapsed / _mantle_duration * clip.length), true)
		var target := _mantle_points[0]
		var step := (target - body.global_position).limit_length(2.4 * delta)
		if not _clear_path(body, body.global_position, body.global_position + step):
			reset(body)
			body.velocity = Vector3.DOWN
			return true
		body.global_position += step
		if body.global_position.distance_to(target) < 0.005:
			_mantle_points.pop_front()
			if _mantle_points.is_empty():
				reset(body)
				body.velocity = Vector3.ZERO
				mantle_completed.emit()
		return true
	if not body.traversal.is_climbing():
		if body.traversal.is_swimming() or latch_cooldown > 0.0 or not jump or input.y > -0.15 or body.stamina <= 0.0:
			return false
		var direction := Vector3(input.x, 0, input.y)
		if body.player_camera:
			var basis: Basis = body.player_camera.global_basis
			direction = basis.x * input.x + basis.z * input.y
		direction.y = 0.0
		var wall := _wall(body, direction.normalized())
		if not _climbable(wall): return false
		body.traversal.start_climbing(wall.normal, wall.position)
		body.jump_buffer_timer = 0.0
		body.coyote_timer = 0.0
		body.velocity = Vector3.ZERO
		return true
	var normal: Vector3 = body.traversal.wall_normal
	if drop or body.stamina <= 0.0:
		reset(body)
		body.velocity = normal * 1.2 + Vector3.DOWN
		body.move_and_slide()
		return true
	if jump:
		body.jump_buffer_timer = 0.0
		body.coyote_timer = 0.0
		if hanging and input.y < -0.15 and _begin_mantle(body):
			return true
		var result: Dictionary = body.traversal.climb_jump(body.stamina)
		if result.success:
			body.stamina = maxf(0.0, body.stamina - result.stamina_cost)
			reset(body)
			body.velocity = result.impulse
			body.stamina_changed.emit(body.stamina, body.MAX_STAMINA)
			body.move_and_slide()
			return true
	var wall := _wall(body, -normal)
	if not _climbable(wall) or wall.normal.dot(normal) < 0.85:
		reset(body)
		body.velocity = Vector3.DOWN
		return true
	if not hanging and input.y < -0.15:
		var top := _top(body, normal)
		if not top.is_empty():
			var correction: float = top.position.y - HANG_HEIGHT - body.global_position.y
			if absf(correction) <= ASSIST_LIMIT and _clear_path(body, body.global_position, body.global_position + Vector3.UP * correction):
				body.global_position.y += correction
				hanging = true
				ledge_reached.emit()
	var speed: float = 1.4 if hanging else 1.0
	var tangent := Vector3.UP.cross(normal).normalized()
	body.velocity = tangent * input.x * speed
	if not hanging: body.velocity.y = -input.y * speed
	body.velocity -= normal * 0.5
	var drain := 1.5 if input.length_squared() < 0.04 or (hanging and absf(input.x) < 0.05) else 10.0
	body.stamina = maxf(0.0, body.stamina - drain * delta)
	body.stamina_changed.emit(body.stamina, body.MAX_STAMINA)
	if body.visual_root:
		body.visual_root.rotation.y = atan2(-normal.x, -normal.z) + body.MODEL_FORWARD_YAW_OFFSET
		body.visual_root.rotation.x = 0.0
		body.visual_root.rotation.z = 0.0
	var clip := "PARKOUR_HANG" if hanging else "PARKOUR_CLIMB"
	if body.animation_player and body.animation_player.has_animation(clip):
		body.play_anim(clip, 0.12)
		body.animation_player.speed_scale = 1.0 if hanging else (1.82 if input.length_squared() >= 0.04 else 0.0)
	body.move_and_slide()
	if body.is_on_floor() and input.y > 0.15: reset(body)
	return true

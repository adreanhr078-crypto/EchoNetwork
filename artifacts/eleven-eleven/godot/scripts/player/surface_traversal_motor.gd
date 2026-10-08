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
var _contact_body: Node3D
var _contact_local := Vector3.ZERO
var _normal_local := Vector3.BACK
var _body_local := Vector3.ZERO
var _transition_support: Node3D
var _transition_kind := ""
var _transition_clip := ""
var _transition_local_points: Array[Vector3] = []
var last_catch_correction := 0.0

func _capsule_clear(body: CharacterBody3D, at: Vector3) -> bool:
	var collision := body.get_node("CollisionShape3D") as CollisionShape3D
	var query := PhysicsShapeQueryParameters3D.new()
	# Ignore the solver's sub-millimetre resting contact when checking a
	# destination; the sweep still uses the full physical capsule.
	var capsule := collision.shape.duplicate() as CapsuleShape3D
	capsule.radius = maxf(0.01, capsule.radius - 0.003)
	capsule.height -= 0.006
	query.shape = capsule
	query.transform = body.global_transform * collision.transform
	query.transform.origin += at - body.global_position
	query.collision_mask = body.collision_mask
	query.exclude = [body.get_rid()]
	query.margin = 0.0001
	return body.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

func _supported(body: CharacterBody3D, at: Vector3) -> bool:
	# Check the capsule footprint, not just a ray that can land on a narrow lip.
	for offset in [Vector3.ZERO, Vector3(0.28,0,0), Vector3(-0.28,0,0), Vector3(0,0,0.28), Vector3(0,0,-0.28)]:
		var hit := _ray(body, at + offset + Vector3.UP * 0.04, at + offset - Vector3.UP * 0.18)
		if hit.is_empty() or hit.normal.y < 0.8: return false
	return true

func _remember_contact(body: CharacterBody3D, hit: Dictionary) -> void:
	_contact_body = hit.collider as Node3D
	_contact_local = _contact_body.to_local(hit.position)
	_normal_local = _contact_body.global_basis.inverse() * hit.normal
	_body_local = _contact_body.to_local(body.global_position)

func try_start_climb(body: CharacterBody3D, normal: Vector3, contact: Vector3) -> bool:
	if latch_cooldown > 0 or body.stamina <= 0 or not normal.is_finite() or not contact.is_finite(): return false
	var wall := _wall(body, -normal.normalized())
	if not _climbable(wall) or wall.normal.dot(normal.normalized()) < 0.85 or wall.position.distance_to(contact) > ASSIST_LIMIT: return false
	_remember_contact(body, wall)
	return body.traversal.start_climbing(wall.normal, wall.position)

func _catch(body: CharacterBody3D, wall: Dictionary) -> bool:
	var top := _top(body, wall.normal)
	if top.is_empty(): return false
	var collision := body.get_node("CollisionShape3D") as CollisionShape3D
	var radius: float = collision.shape.radius
	var destination: Vector3 = wall.position + wall.normal * (radius + 0.025)
	destination.y = top.position.y - HANG_HEIGHT
	last_catch_correction = destination.distance_to(body.global_position)
	if last_catch_correction > ASSIST_LIMIT + 0.00001 or not _capsule_clear(body, destination) or not _clear_path(body, body.global_position, destination): return false
	body.global_position = destination
	_remember_contact(body, wall)
	body.traversal.start_climbing(wall.normal, wall.position)
	hanging = true
	body.jump_buffer_timer = 0.0
	body.coyote_timer = 0.0
	body.cancel_roll()
	body.velocity = Vector3.ZERO
	ledge_reached.emit()
	return true

func _begin_transition(body: CharacterBody3D, points: Array[Vector3], support: Node3D, kind: String, clip: String) -> bool:
	var previous := body.global_position
	var distance := 0.0
	for point in points:
		if not _capsule_clear(body, point) or not _clear_path(body, previous, point): return false
		distance += previous.distance_to(point)
		previous = point
	if not _supported(body, points.back()): return false
	_transition_support = support
	_transition_local_points.clear()
	for point in points: _transition_local_points.append(support.to_local(point))
	_mantle_points.assign(points)
	_transition_kind = kind
	_transition_clip = clip
	_mantle_elapsed = 0.0
	_mantle_duration = maxf(0.05, distance / 2.4)
	if kind == "mantle" and body.visual_root:
		_mantle_visual_origin = body.visual_root.position
		_mantle_visual_active = true
	hanging = false
	body.cancel_roll()
	body.velocity = Vector3.ZERO
	body.jump_buffer_timer = 0.0
	body.coyote_timer = 0.0
	if body.animation_player and body.animation_player.has_animation(clip):
		body.play_anim(clip, 0.0)
		body.animation_player.speed_scale = 0.0
		body.animation_player.seek(0.0, true)
	return true

func _begin_vault(body: CharacterBody3D, direction: Vector3) -> bool:
	if not body.is_on_floor(): return false
	var wall := _wall(body, direction, 0.35)
	if wall.is_empty() or not wall.collider.is_in_group("vaultable") or absf(wall.normal.y) > 0.2: return false
	var probe: Vector3 = wall.position + direction * 0.08
	var top := _ray(body, Vector3(probe.x, body.global_position.y + 1.05, probe.z), Vector3(probe.x, body.global_position.y + 0.4, probe.z))
	if top.is_empty() or top.normal.y < 0.8 or top.collider != wall.collider: return false
	var height: float = top.position.y - body.global_position.y
	if height < 0.45 or height > 1.0: return false
	# Find ground beyond the obstacle, then validate both the path and capsule.
	for sample in range(5, 19):
		var beyond: Vector3 = wall.position + direction * (sample * 0.1)
		var ground := _ray(body, Vector3(beyond.x, body.global_position.y + 0.2, beyond.z), Vector3(beyond.x, body.global_position.y - 0.12, beyond.z))
		if ground.is_empty() or ground.normal.y < 0.8: continue
		var raised := Vector3(body.global_position.x, top.position.y + 0.06, body.global_position.z)
		var landed: Vector3 = ground.position + Vector3.UP * 0.06
		var across := Vector3(landed.x, raised.y, landed.z)
		var points: Array[Vector3] = [raised, across, landed]
		var clip := "PARKOUR_VAULT" if body.animation_player and body.animation_player.has_animation("PARKOUR_VAULT") else "preset_jump"
		if _begin_transition(body, points, ground.collider, "vault", clip): return true
	return false

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
	_transition_local_points.clear()
	_transition_support = null
	_contact_body = null
	_transition_kind = ""
	_transition_clip = ""
	latch_cooldown = 0.4
	body.traversal.stop_climbing()
	if body.animation_player: body.animation_player.speed_scale = 1.0

func _begin_mantle(body: CharacterBody3D) -> bool:
	var top := _top(body, body.traversal.wall_normal)
	if top.is_empty(): return false
	var raised := Vector3(body.global_position.x, top.position.y + 0.06, body.global_position.z)
	var landed: Vector3 = raised - body.traversal.wall_normal * 0.85
	# Sweep the actual player capsule on both segments, including overhead space.
	var points: Array[Vector3] = [raised, landed]
	return _begin_transition(body, points, top.collider, "mantle", "PARKOUR_MANTLE")

func tick(body: CharacterBody3D, delta: float, input: Vector2, jump: bool, drop: bool) -> bool:
	latch_cooldown = maxf(0.0, latch_cooldown - delta)
	if not _mantle_points.is_empty():
		if drop or not is_instance_valid(_transition_support):
			reset(body)
			body.velocity = Vector3.DOWN
			return true
		for index in range(_mantle_points.size()):
			_mantle_points[index] = _transition_support.to_global(_transition_local_points[index])
		if not _supported(body, _mantle_points.back()) or not _capsule_clear(body, _mantle_points.back()):
			reset(body)
			body.velocity = Vector3.DOWN
			return true
		_mantle_elapsed += delta
		if _mantle_visual_active:
			# Fold the legs as the capsule clears the lip. The torso stays low
			# enough for the hands to push, then settles back to the same origin.
			var phase := clampf(_mantle_elapsed / _mantle_duration, 0.0, 1.0)
			body.visual_root.position = _mantle_visual_origin - Vector3.UP * (0.65 * sin(PI * phase))
		if body.animation_player and body.animation_player.has_animation(_transition_clip):
			var clip: Animation = body.animation_player.get_animation(_transition_clip)
			body.animation_player.seek(minf(clip.length, _mantle_elapsed / _mantle_duration * clip.length), true)
		var target := _mantle_points[0]
		var phase := clampf(_mantle_elapsed / _mantle_duration, 0.0, 1.0)
		var ease_curve := sin(PI * clampf(phase, 0.08, 0.92)) * 1.4 + 0.6
		var step := (target - body.global_position).limit_length(2.4 * delta * ease_curve)
		if not _clear_path(body, body.global_position, body.global_position + step) or not _capsule_clear(body, body.global_position + step):
			reset(body)
			body.velocity = Vector3.DOWN
			return true
		body.global_position += step

		# Watchdog timer to prevent freeze if distance threshold or step is impeded
		const MANTLE_WATCHDOG_EXTRA := 0.35
		if _mantle_elapsed > _mantle_duration + MANTLE_WATCHDOG_EXTRA:
			var final_target: Vector3 = _mantle_points.back() if not _mantle_points.is_empty() else body.global_position
			if _capsule_clear(body, final_target):
				body.global_position = final_target
			var completed_kind := _transition_kind
			reset(body)
			body.velocity = Vector3.ZERO
			if completed_kind == "mantle": mantle_completed.emit()
			return true

		if body.global_position.distance_to(target) < 0.03:
			_mantle_points.pop_front()
			_transition_local_points.pop_front()
			if _mantle_points.is_empty():
				var completed_kind := _transition_kind
				reset(body)
				body.velocity = Vector3.ZERO
				if completed_kind == "mantle": mantle_completed.emit()
		return true
	if not body.traversal.is_climbing():
		if body.traversal.is_swimming() or latch_cooldown > 0.0 or input.y > -0.15 or body.stamina <= 0.0:
			return false
		var direction: Vector3 = body.movement_world_direction(input)
		if jump and _begin_vault(body, direction): return true
		var wall := _wall(body, direction)
		if not _climbable(wall): return false
		if not body.is_on_floor():
			if body.velocity.y <= 1.0 and _catch(body, wall): return true
			if jump:
				_remember_contact(body, wall)
				body.traversal.start_climbing(wall.normal, wall.position)
				body.jump_buffer_timer = 0.0
				body.coyote_timer = 0.0
				body.velocity = Vector3.ZERO
				return true
			return false
		if not jump and not (input.y < -0.6 and (body.mobile_sprint_active or body.velocity.length() > 1.5)): return false
		_remember_contact(body, wall)
		body.traversal.start_climbing(wall.normal, wall.position)
		body.jump_buffer_timer = 0.0
		body.coyote_timer = 0.0
		body.velocity = Vector3.ZERO
		return true
	var normal: Vector3 = body.traversal.wall_normal
	if is_instance_valid(_contact_body):
		# Hanging uses local wall anchors. CharacterBody floor carry is not added.
		var destination := _contact_body.to_global(_body_local)
		if destination.distance_squared_to(body.global_position) > 0.00000001 and (not _clear_path(body, body.global_position, destination) or not _capsule_clear(body, destination)):
			reset(body)
			body.velocity = Vector3.DOWN
			return true
		body.global_position = destination
		normal = (_contact_body.global_basis * _normal_local).normalized()
		body.traversal.wall_normal = normal
		body.traversal.wall_contact_point = _contact_body.to_global(_contact_local)
	if drop or body.stamina <= 0.0:
		reset(body)
		body.velocity = normal * 1.2 + Vector3.DOWN
		body.move_and_slide()
		return true
	if jump:
		body.jump_buffer_timer = 0.0
		body.coyote_timer = 0.0
		if hanging and input.y <= 0.2 and _begin_mantle(body):
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
			_catch(body, wall)
	var speed: float = 1.4 if hanging else 1.0
	var tangent := Vector3.UP.cross(normal).normalized()
	body.velocity = tangent * input.x * speed
	if not hanging: body.velocity.y = -input.y * speed
	var proposed: Vector3 = body.global_position + body.velocity * delta
	if body.velocity.length_squared() > 0.00001:
		var next_wall := _ray(body, proposed + Vector3.UP, proposed + Vector3.UP - normal * REACH)
		var valid: bool = _climbable(next_wall) and next_wall.normal.dot(normal) >= 0.98 and next_wall.collider == wall.collider
		if hanging:
			var edge_top := _ray(body, proposed - normal * 0.65 + Vector3.UP * 1.85, proposed - normal * 0.65 + Vector3.UP * 0.55)
			valid = valid and not edge_top.is_empty() and edge_top.normal.y >= 0.8 and absf(edge_top.position.y - HANG_HEIGHT - proposed.y) <= 0.04
			for hand in [-0.2,0.2]:
				var hand_wall := _ray(body, proposed + tangent * hand + Vector3.UP, proposed + tangent * hand + Vector3.UP - normal * REACH)
				valid = valid and _climbable(hand_wall) and hand_wall.collider == wall.collider and hand_wall.normal.dot(normal) >= 0.98
		if not valid or not _capsule_clear(body, proposed) or not _clear_path(body, body.global_position, proposed): body.velocity = Vector3.ZERO
	body.velocity -= normal * 0.5
	var drain := 1.5 if input.length_squared() < 0.04 or (hanging and absf(input.x) < 0.05) else 10.0
	body.stamina = maxf(0.0, body.stamina - drain * delta)
	body.stamina_changed.emit(body.stamina, body.MAX_STAMINA)
	if body.visual_root:
		body.visual_root.rotation.y = atan2(-normal.x, -normal.z) + body.model_forward_yaw_offset
		body.visual_root.rotation.x = 0.0
		body.visual_root.rotation.z = 0.0
	var clip := "PARKOUR_HANG" if hanging else "PARKOUR_CLIMB"
	if body.animation_player and body.animation_player.has_animation(clip):
		body.play_anim(clip, 0.12)
		body.animation_player.speed_scale = 1.0 if hanging else (1.82 if input.length_squared() >= 0.04 else 0.0)
	body.move_and_slide()
	if is_instance_valid(_contact_body): _body_local = _contact_body.to_local(body.global_position)
	if body.is_on_floor() and input.y > 0.15: reset(body)
	return true

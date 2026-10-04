extends SceneTree

var world: Node3D
var player: EchoPlayer
var wall: StaticBody3D
var observations := {}

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	world = Node3D.new()
	root.add_child(world)
	player = load("res://scenes/player/echo_player.tscn").instantiate()
	player.position = Vector3(0, 1.7, 0)
	world.add_child(player)
	player.finish_opening_recovery()
	player.surface_traversal_enabled = true
	player.set_gameplay_orbit(Vector3.ZERO)
	player.set_physics_process(false)
	wall = _box(Vector3(2,3.4,2), Vector3(0,1.7,-1.4))
	wall.add_to_group("climbable")
	await _steps(3)
	# The full correction, including horizontal reach, is bounded by 25cm.
	for distance in [0.24, 0.26]:
		player.surface_motor.reset(player)
		player.surface_motor.latch_cooldown = 0
		player.position = Vector3(0, 1.9 - distance, 0.025)
		player.velocity = Vector3.DOWN
		var caught: bool = player.surface_motor.tick(player, 1.0/60, Vector2(0,-1), false, false)
		if not _check(caught == (distance < 0.25) and player.surface_motor.hanging == caught, "catch tolerance: " + str(distance)): return
		if caught and not _check(player.surface_motor.last_catch_correction <= 0.25, "catch corrected more than 25cm"): return
	observations["catch_24cm_accept_26cm_reject"] = "PASS"
	# Runtime public entry cannot accept an invented normal/contact on untagged geometry.
	player.surface_motor.reset(player)
	player.surface_motor.latch_cooldown = 0
	player.position = Vector3(0,1.9,0.025)
	wall.remove_from_group("climbable")
	if not _check(not player.start_climbing(Vector3.BACK, Vector3(0,2.9,-0.4)), "untagged external latch bypass"): return
	if not _check(not player.surface_motor.tick(player, 1.0/60, Vector2(0,-1), false, false), "untagged airborne catch"): return
	wall.add_to_group("climbable")
	if not _check(player.surface_motor.tick(player, 1.0/60, Vector2(0,-1), false, false), "valid airborne catch needs second Jump"): return
	# Both directions sidle to the end, then stop instead of moving around a corner.
	for sign in [-1.0,1.0]:
		player.position.x = 0
		player.surface_motor._body_local = wall.to_local(player.position)
		for i in range(100):
			player.surface_motor.tick(player, 1.0/60, Vector2(sign,0), false, false)
		if not _check(absf(player.position.x) <= 1.01 and player.surface_motor.hanging, "sidle crossed wall end"): return
		var stop := player.position
		for i in range(15): player.surface_motor.tick(player, 1.0/60, Vector2(sign,0), false, false)
		if not _check(player.position.distance_to(stop) < 0.002, "sidle end kept drifting"): return
	observations["sidle_both_ends"] = "PASS"
	# DROP is one edge and cannot re-latch during the 400ms lockout.
	player.surface_motor.tick(player, 1.0/60, Vector2(0,-1), false, true)
	if not _check(not player.is_climbing() and player.surface_motor.latch_cooldown >= 0.39, "drop cooldown missing"): return
	for i in range(20):
		if not _check(not player.surface_motor.tick(player, 1.0/60, Vector2(0,-1), false, false), "drop immediately re-latched"): return
	observations["drop_lockout"] = "PASS"
	# A mantle with no floor behind the lip is rejected before motion starts.
	wall.queue_free()
	await _steps(3)
	wall = _box(Vector3(2,3.4,0.1), Vector3(0,1.7,-0.45))
	wall.add_to_group("climbable")
	player.position = Vector3(0,1.9,0.025)
	player.traversal.start_climbing(Vector3.BACK, Vector3(0,2.9,-0.4))
	player.surface_motor.hanging = true
	await _steps(3)
	if not _check(not player.surface_motor._begin_mantle(player), "mantle accepted a destination without ground"): return
	wall.queue_free()
	player.surface_motor.reset(player)
	await _steps(3)
	# Contextual vault uses the existing capsule and authored jump, never a new clip.
	var floor := _box(Vector3(12,0.4,12), Vector3(0,-0.2,0))
	var obstacle := _box(Vector3(2,0.7,0.3), Vector3(0,0.35,-0.65))
	obstacle.add_to_group("vaultable")
	player.position = Vector3(0,0.06,0)
	player.velocity = Vector3.DOWN
	player.move_and_slide()
	await _steps(3)
	for i in range(6): player.move_and_slide()
	if not _check(player.is_on_floor(), "vault fixture not grounded"): return
	var ceiling := _box(Vector3(3,0.2,3), Vector3(0,2.1,-0.65))
	await _steps(3)
	if not _check(not player.surface_motor._begin_vault(player, Vector3.FORWARD), "vault crossed low ceiling"): return
	ceiling.queue_free()
	await _steps(3)
	if not _check(player.surface_motor._begin_vault(player, Vector3.FORWARD), "safe 70cm tagged vault rejected"): return
	for i in range(160):
		player.surface_motor.tick(player, 1.0/60, Vector2.ZERO, false, false)
		if player.surface_motor._mantle_points.is_empty(): break
	if not _check(player.position.z < -1.2 and player.position.y < 0.1, "vault did not reach the safe floor"): return
	obstacle.remove_from_group("vaultable")
	player.position = Vector3(0,0.05,0)
	player.velocity = Vector3.DOWN
	player.move_and_slide()
	if not _check(not player.surface_motor._begin_vault(player, Vector3.FORWARD), "untagged vault accepted"): return
	observations["vault_tag_headroom_support_and_landing"] = "PASS"
	print("PASS traversal reliability ", JSON.stringify(observations))
	world.queue_free()
	await _steps(3)
	await create_timer(0.1).timeout
	quit(0)

func _box(size: Vector3, at: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	body.position = at
	world.add_child(body)
	return body

func _steps(count: int) -> void:
	for i in range(count): await physics_frame

func _check(condition: bool, detail: String) -> bool:
	if not condition:
		push_error(detail)
		quit(1)
	return condition

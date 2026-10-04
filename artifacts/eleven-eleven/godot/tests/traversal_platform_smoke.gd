extends SceneTree

const PLATFORM = preload("res://scripts/environment/traversal_platform.gd")
var world: Node3D
var player: EchoPlayer
var lift: AnimatableBody3D

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	world = Node3D.new()
	root.add_child(world)
	lift = load("res://scenes/environment/traversal_platform.tscn").instantiate()
	lift.position = Vector3(0,1,0)
	lift.travel = Vector3(2,2,0)
	lift.running = false
	world.add_child(lift)
	player = load("res://scenes/player/echo_player.tscn").instantiate()
	player.position = Vector3(0,1.2,0)
	world.add_child(player)
	player.finish_opening_recovery()
	await _steps(20)
	if not _check(player.is_on_floor(), "rider not on lift"): return
	var anchor := lift.to_local(player.global_position)
	lift.running = true
	var max_drift := 0.0
	var reversals := 0
	var previous_direction: float = lift._direction
	for i in range(3600):
		await physics_frame
		var drift := lift.to_local(player.global_position).distance_to(anchor)
		max_drift = maxf(max_drift, drift)
		if lift._direction != previous_direction:
			reversals += 1
			previous_direction = lift._direction
		if not _check(player.is_on_floor() and drift <= 0.02, "60s ride drift/floor loss at frame %d: %.6fm" % [i,drift]): return
		if i % 900 == 899: print("RIDE ", (i+1)/60.0, "s drift=",max_drift)
	if not _check(reversals >= 4, "lift never reversed"): return
	print("PASS 60s ride max_drift_m=",max_drift," reversals=",reversals)
	# Actual upward headroom must stop a rider before a ceiling pinches them.
	lift.running = false
	lift._wait = 0
	lift._direction = 1
	lift.travel = Vector3(0,4,0)
	lift._origin = lift.position
	lift._distance = 0
	var ceiling := _box(Vector3(5,0.2,5), player.global_position + Vector3.UP * 2.4)
	lift.running = true
	for i in range(240):
		await physics_frame
		if lift.blocked: break
	if not _check(lift.blocked and player.global_position.y + 1.8 < ceiling.global_position.y - 0.08, "lift failed to stop below rider headroom"): return
	var stopped := lift.position
	await _steps(25)
	if not _check(lift.position.distance_to(stopped) < 0.001, "blocked elevator kept advancing"): return
	ceiling.queue_free()
	await _steps(35)
	if not _check(not lift.blocked and lift.position.y > stopped.y + 0.1, "elevator did not resume after obstruction cleared"): return
	lift.running = false
	player.request_jump()
	await _steps(4)
	if not _check(not player.is_on_floor() and player.velocity.y > 0, "rider jump did not detach"): return
	# Local hanging/mantling anchors follow another moving platform.
	lift.queue_free()
	player.set_physics_process(false)
	await _steps(3)
	lift = PLATFORM.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(4,3.4,2)
	collision.shape = shape
	lift.add_child(collision)
	lift.position = Vector3(0,1.7,-1.4)
	lift.travel = Vector3(0.5,0.5,0)
	lift.running = false
	lift.add_to_group("climbable")
	world.add_child(lift)
	player.position = Vector3(0,1.9,0.025)
	player.velocity = Vector3.DOWN
	player.surface_traversal_enabled = true
	player.surface_motor.reset(player)
	player.surface_motor.latch_cooldown = 0
	await _steps(3)
	if not _check(player.surface_motor.tick(player,1.0/60,Vector2(0,-1),false,false), "moving fixture catch failed"): return
	player.set_mobile_input_vector(Vector2.ZERO,true)
	player.set_physics_process(true)
	await _steps(5)
	anchor = lift.to_local(player.global_position)
	lift.running = true
	max_drift = 0
	for i in range(90):
		await physics_frame
		max_drift = maxf(max_drift, lift.to_local(player.global_position).distance_to(anchor))
		if not _check(player.surface_motor.hanging and max_drift <= 0.02, "local hanging anchor lost/drifted"): return
	player.set_mobile_input_vector(Vector2(0,-1),true)
	player.request_jump()
	for i in range(160):
		await physics_frame
		if not player.is_climbing(): break
	player.set_mobile_input_vector(Vector2.ZERO,true)
	await _steps(10)
	if not _check(player.is_on_floor() and lift.to_local(player.global_position).y > 1.69, "moving mantle did not land on live platform"): return
	print("PASS lift obstruction/resume, jump, local hang/mantle drift_m=",max_drift)
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

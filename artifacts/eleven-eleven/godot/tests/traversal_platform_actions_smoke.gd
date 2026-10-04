extends SceneTree

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var lift = load("res://scenes/environment/traversal_platform.tscn").instantiate()
	lift.position.y = 2
	lift.travel = Vector3(0,2,0)
	lift.running = false
	world.add_child(lift)
	var player: EchoPlayer = load("res://scenes/player/echo_player.tscn").instantiate()
	player.position = Vector3(0,2.2,0)
	world.add_child(player)
	player.finish_opening_recovery()
	var neutral_clip := player.current_anim
	await _steps(20)
	if not _check(player.current_anim == neutral_clip and not player.combat_available, "pre-contract platform rider entered combat/fall pose on the floor"): return
	lift.running = true
	await _steps(35)
	for direction in [1.0,-1.0]:
		for i in range(300):
			await physics_frame
			if player.is_on_floor() and lift._direction == direction and absf(player.get_platform_velocity().y) > 0.6: break
		if not _check(player.is_on_floor() and lift._direction == direction, "moving jump fixture not ready"): return
		var platform_velocity := player.get_platform_velocity().y
		player.request_jump()
		await _steps(2)
		var expected := player.JUMP_VELOCITY + maxf(0,platform_velocity)
		if not _check(not player.is_on_floor() and absf(player.velocity.y - expected) < 0.5, "jump lost height or added platform velocity twice"): return
		for i in range(150):
			await physics_frame
			if player.is_on_floor(): break
		if not _check(player.is_on_floor(), "jump did not reboard moving platform"): return
		await _steps(3)
		if not _check(player.current_anim == neutral_clip, "landed platform rider kept a falling pose"): return
	# Walking is relative to the deck, even during travel and reversal.
	var start: Vector3 = lift.to_local(player.global_position)
	player.set_mobile_input_vector(Vector2(0.3,0),true)
	await _steps(30)
	player.set_mobile_input_vector(Vector2.ZERO,true)
	await _steps(15)
	var displacement: Vector3 = lift.to_local(player.global_position) - start
	if not _check(displacement.x > 0.15 and displacement.x < 0.5 and absf(displacement.z) < 0.01, "walk gained platform motion or slipped sideways"): return
	lift.running = false
	await _steps(4)
	var stopped: Vector3 = lift.position
	var local: Vector3 = lift.to_local(player.global_position)
	await _steps(25)
	if not _check(lift.position.distance_to(stopped) < 0.001 and lift.to_local(player.global_position).distance_to(local) < 0.002, "stopped platform/rider jittered"): return
	lift.running = true
	await _steps(30)
	if not _check(lift.position.distance_to(stopped) > 0.05 and player.is_on_floor(), "platform did not resume smoothly"): return
	print("PASS moving platforms: jump up/down without double velocity or lost jump height, reboard, relative walk, stop/resume")
	world.queue_free()
	await _steps(3)
	await create_timer(0.1).timeout
	quit(0)

func _steps(count: int) -> void:
	for i in range(count): await physics_frame

func _check(condition: bool, detail: String) -> bool:
	if not condition:
		push_error(detail)
		quit(1)
	return condition

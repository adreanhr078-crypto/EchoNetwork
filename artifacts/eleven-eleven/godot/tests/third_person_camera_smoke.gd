extends SceneTree

var world: Node3D
var player: EchoPlayer

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	world = Node3D.new()
	root.add_child(world)
	player = load("res://scenes/player/echo_player.tscn").instantiate()
	player.position = Vector3(0,2,0)
	world.add_child(player)
	player.finish_opening_recovery()
	player.set_physics_process(false)
	player.set_process(false)
	await _steps(3)
	var response := []
	for fps in [30,60,120]:
		player.set_gameplay_orbit(Vector3.ZERO)
		player.apply_touch_camera_look(Vector2(-300,30))
		for i in range(fps / 2): player._process(1.0 / fps)
		response.append(player.camera_boom.rotation)
		if not _check(absf(player.camera_boom.rotation.y - 0.9) < 0.001, "orbit not responsive at " + str(fps)): return
		# Both natural and skipped inserts enter the same 350ms live return.
		for skip in [false,true]:
			player.set_gameplay_orbit(Vector3(-0.1,1.2,0))
			player.suspend_gameplay_camera()
			player.camera_boom.rotation = Vector3(0.4,-1.1,0)
			player.camera_boom.spring_length = 4.2
			player.player_camera.position.z = 4.2
			player.player_camera.fov = 58
			var old := player.player_camera.global_position
			player._process(1.0 / fps)
			if not _check(player.player_camera.fov == 58 and absf(player.camera_boom.rotation.y + 1.1) < 0.00001, "Gameplay wrote cinematic camera"): return
			player.position.x += 2.0
			player.resume_gameplay_camera()
			for i in range(ceili(0.35 * fps)):
				player._process(1.0 / fps)
				if i == 0 and not _check(player.player_camera.position.z > 4.15, "unobstructed distance snapped at " + str(fps)): return
			if not _check(absf(angle_difference(player.camera_boom.rotation.y,1.2)) < 0.001 and is_equal_approx(player.player_camera.fov,65), "return failed at %d skip=%s" % [fps,skip]): return
			if not _check(absf(player.player_camera.position.z-3.0) < 0.01, "return distance did not settle at " + str(fps)): return
			if not _check(player.player_camera.global_position.distance_to(old) > 1.0 and absf(player.camera_boom.global_position.y - (player.position.y+1.4)) <= 0.2, "return reused stale position"): return
		player.reduced_camera_motion = true
		player.suspend_gameplay_camera()
		player.camera_boom.rotation.y = -2
		player.player_camera.fov = 75
		player.resume_gameplay_camera()
		if not _check(player._camera_return_remaining == 0 and player.player_camera.fov == 65 and absf(angle_difference(player.camera_boom.rotation.y,1.2)) < 0.001, "Reduced Motion return was not immediate"): return
		player.reduced_camera_motion = false
	if not _check(response[0].distance_to(response[2]) < 0.00001, "orbit depends on FPS"): return
	# A separate cinematic camera also owns the lens during a pending return.
	var insert := Camera3D.new()
	world.add_child(insert)
	player.suspend_gameplay_camera()
	player.player_camera.fov = 58
	player.resume_gameplay_camera()
	insert.make_current()
	player._process(1.0/60)
	if not _check(player.player_camera.fov == 58, "pending Gameplay return wrote a lens owned by another camera"): return
	player.player_camera.make_current()
	insert.queue_free()
	# Exercise the actual breach's natural and skipped exit, not just the helper.
	var breach := BlastGateBreachCinematic.new()
	world.add_child(breach)
	for skip in [false,true]:
		player.set_gameplay_orbit(Vector3(-0.1,1.2,0))
		breach.play(player,null)
		if skip: breach.finish()
		else: await create_timer(3.1).timeout
		if not _check(not breach._is_playing and not player._camera_suspended and is_equal_approx(player._camera_return_remaining,0.35), "actual breach did not share the live 350ms return"): return
		var before_distance := player.player_camera.position.z
		player._process(1.0/60)
		if not _check(absf(player.player_camera.position.z-before_distance) < 0.05, "cinematic return snapped the unobstructed boom distance"): return
		for i in range(20): player._process(1.0/60)
		if not _check(absf(angle_difference(player.camera_boom.rotation.y,1.2)) < 0.001 and is_equal_approx(player.player_camera.fov,65), "breach returned to an old default pose"): return
	# Safe distance shrinks immediately, then extends gradually when clear.
	player.position = Vector3(0,2,0)
	player.set_gameplay_orbit(Vector3.ZERO)
	player._process(1.0/60)
	var wall := _box(Vector3(4,5,0.2), Vector3(0,3,1))
	await _steps(3)
	player._process(1.0/120)
	if not _check(player.camera_boom.spring_length < 0.7 and player.player_camera.global_position.z < 0.8, "arm did not retract in first render"): return
	wall.queue_free()
	await _steps(3)
	var shortened := player.camera_boom.spring_length
	player._process(1.0/120)
	if not _check(player.camera_boom.spring_length > shortened and player.camera_boom.spring_length < 1.0, "arm extension jumped"): return
	# The vertical follow lag remains bounded during a moving platform/telemetry step.
	player.position.y += 1.0
	player._process(1.0/120)
	if not _check(absf(player.camera_boom.global_position.y - (player.position.y+1.4)) <= 0.20001, "vertical camera lag exceeds 20cm"): return
	print("PASS camera: 30/60/120 response, free yaw, cinematic ownership/live return 350ms, Reduced Motion, immediate collision retraction/smooth extension, bounded follow")
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

extends SceneTree

var player: EchoPlayer
var world: Node3D
var landings := 0
var heavy_landings := 0
var rolls := 0

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	world = Node3D.new()
	root.add_child(world)
	var floor := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(30,0.4,30)
	collision.shape = box
	floor.add_child(collision)
	floor.position.y = -0.2
	world.add_child(floor)
	player = load("res://scenes/player/echo_player.tscn").instantiate()
	player.position.y = 3
	world.add_child(player)
	player.finish_opening_recovery()
	player.set_physics_process(false)
	player.set_process(false)
	player.landing_executed.connect(func(_speed: float, heavy: bool):
		landings += 1
		if heavy: heavy_landings += 1)
	player.combat_roll_executed.connect(func(_dir: Vector3): rolls += 1)
	await _steps(3)
	for age in [0.119,0.121]:
		_airborne()
		player.coyote_timer = 0.12
		player.request_jump()
		player._physics_process(age)
		if not _check((player.velocity.y > 0) == (age < 0.12), "coyote boundary: " + str(age)): return
	for age in [0.149,0.151]:
		_airborne()
		player.coyote_timer = 0
		player.request_jump()
		player._physics_process(0.001)
		player._physics_process(age)
		player.position.y = 0.01
		player.velocity = Vector3.DOWN
		player.move_and_slide()
		if not _check(player.is_on_floor(), "buffer fixture did not touch ground"): return
		player._physics_process(0.0001)
		if not _check((player.velocity.y > 0) == (age < 0.15), "buffer boundary: " + str(age)): return
	# Heavy classification uses actual pre-impact speed, including gravity.
	for impact in [8.49,8.51]:
		_airborne()
		player.position.y = 0.05
		player.velocity = Vector3.DOWN * impact
		var count := landings
		var heavy_count := heavy_landings
		player._move_and_detect_landing()
		if not _check(landings == count+1 and heavy_landings == heavy_count + (1 if impact > 8.5 else 0), "impact classification at " + str(impact)): return
		for i in range(5): player._move_and_detect_landing()
		if not _check(landings == count+1, "landing event repeated on ground"): return
	# A fall greater than three metres stays airborne until a real failure volume.
	_airborne()
	player.position = Vector3(0,8,0)
	player._last_safe_ground_position = Vector3(0,12,0)
	player._physics_process(1.0/60)
	if not _check(player.position.y < 8 and player.position.y > 7.9, "3m fall autorespawn still exists"): return
	player.clear_traversal_input()
	player.position = Vector3(0,0.02,0)
	player.velocity = Vector3.DOWN
	player.move_and_slide()
	player.stamina = 100
	player.locomotion_controller.is_hard_landing = false
	player.set_physics_process(true)
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await _steps(12)
	Input.action_press("dodge")
	# The native Roll now lasts 720ms. At the old observation point one step
	# can leave 3.33ms; keep Ctrl held beyond the complete clip to test repeats.
	await _steps(60)
	if not _check(rolls == 1 and not player.is_sliding and not player.is_dodging and not player.locomotion_controller.is_rolling, "held Ctrl repeated Roll or started Slide: rolls=%d slide=%s dodge=%s rolling=%s timer=%.6f" % [rolls,player.is_sliding,player.is_dodging,player.locomotion_controller.is_rolling,player.dodge_timer]): return
	Input.action_release("dodge")
	Input.action_release("sprint")
	Input.action_release("move_forward")
	# Hysteresis changes animation/stamina state without a discontinuous speed.
	for sample in [Vector2(0.86,1),Vector2(0.8,1),Vector2(0.74,0),Vector2(0.8,0)]:
		player.set_mobile_input_vector(Vector2(0,-sample.x),true)
		await _steps(2)
		if not _check(player.mobile_sprint_active == bool(sample.y), "run hysteresis at " + str(sample)): return
	print("PASS controller boundaries: coyote119/121ms, buffer149/151ms, impact8.49/8.51m/s once, vertical fall, Ctrl edge without Slide, Run hysteresis")
	world.queue_free()
	await _steps(3)
	await create_timer(0.1).timeout
	quit(0)

func _airborne() -> void:
	player.clear_traversal_input()
	player.cancel_roll()
	player.position = Vector3(0,3,0)
	player.velocity = Vector3.UP * 0.01
	player.move_and_slide()
	player.velocity = Vector3.ZERO

func _steps(count: int) -> void:
	for i in range(count): await physics_frame

func _check(condition: bool, detail: String) -> bool:
	if not condition:
		push_error(detail)
		quit(1)
	return condition

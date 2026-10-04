extends SceneTree

var world: Node3D
var player: EchoPlayer
var touch: MobileTouchControls
var rolls := 0

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	world = Node3D.new()
	root.add_child(world)
	var floor := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(80, 0.4, 80)
	shape.shape = box
	floor.add_child(shape)
	floor.position.y = -0.2
	world.add_child(floor)
	player = load("res://scenes/player/echo_player.tscn").instantiate()
	world.add_child(player)
	player.finish_opening_recovery()
	player.combat_roll_executed.connect(func(_direction: Vector3): rolls += 1)
	touch = load("res://scenes/ui/mobile_touch_controls.tscn").instantiate()
	root.add_child(touch)
	touch._platform_touch_enabled = true
	touch.set_interaction_blocked(false)
	touch.joystick_moved.connect(func(v: Vector2): player.set_mobile_input_vector(v, touch.is_joystick_active))
	touch.dodge_tapped.connect(player.request_dodge)
	touch.jump_tapped.connect(player.request_jump)
	touch.input_reset.connect(player.clear_traversal_input)
	await _steps(12)
	if not _check(player.is_on_floor() and touch.dodge_btn.visible and not touch.sprint_btn.visible, "real player floor / separate Roll visibility"): return
	# The real player speed must retain analog amplitude in every camera direction.
	for magnitude in [0.25, 0.75, 1.0]:
		for yaw in [0.0, PI / 2, PI]:
			player.camera_boom.rotation = Vector3(0.6, yaw, 0)
			player.set_mobile_input_vector(Vector2(0, -magnitude), true)
			player.stamina = 100
			await _steps(30)
			var expected: float = 1.55 * magnitude / 0.75 if magnitude <= 0.75 else 5.8
			if not _check(absf(Vector2(player.velocity.x, player.velocity.z).length() - expected) < 0.05, "analog speed differs by magnitude/yaw"): return
	# Diagonal input and a neutral owned stick do not increase speed/fall back to WASD.
	player.set_mobile_input_vector(Vector2(1, -1), true)
	await _steps(30)
	if not _check(absf(Vector2(player.velocity.x, player.velocity.z).length() - 5.8) < 0.05, "diagonal speed gain"): return
	Input.action_press("move_forward")
	player.set_mobile_input_vector(Vector2.ZERO, true)
	await _steps(30)
	if not _check(Vector2(player.velocity.x, player.velocity.z).length() < 0.01, "owned neutral stick leaked keyboard input"): return
	player.set_mobile_input_vector(Vector2.ZERO, false)
	Input.action_press("sprint")
	await _steps(30)
	if not _check(rolls == 0 and player.mobile_sprint_active, "Shift must run without Roll"): return
	Input.action_release("sprint")
	Input.action_release("move_forward")
	await _steps(25)
	player.request_dodge()
	await _steps(3)
	if not _check(rolls == 1 and player.is_dodging, "queued Roll was lost"): return
	player.request_jump()
	await _steps(3)
	if not _check(player.velocity.y > 0 and not player.is_dodging and not player.locomotion_controller.is_rolling, "Jump did not cancel both Roll states"): return
	await _steps(70)
	var initial := rolls
	player.request_dodge()
	player.request_jump()
	await _steps(3)
	if not _check(rolls == initial and player.velocity.y > 0, "same tick Jump must win over Roll"): return
	await _steps(70)
	# A fixed joystick owns its center; deadzone does not shift or jitter it.
	var center := touch.joystick_center
	_touch(0, center, true)
	_drag(0, center + Vector2(touch.joystick_radius() * 0.14, 0))
	if not _check(player.mobile_move_owned and player.mobile_input_vector == Vector2.ZERO and touch.joystick_center == center, "fixed stick/deadzone failed"): return
	_drag(0, center + Vector2(touch.joystick_radius(), 0))
	if not _check(is_equal_approx(player.mobile_input_vector.length(), 1.0), "deadzone range did not remap to one"): return
	_touch(1, touch.dodge_btn.get_global_rect().get_center(), true)
	_touch(1, Vector2.ZERO, false)
	await _steps(3)
	if not _check(rolls == initial + 1, "quick Roll tap between ticks was lost"): return
	_touch(0, center, false)
	# Disabled actions and external Pause controls must block camera acquisition.
	touch.dodge_btn.disabled = true
	_touch(2, touch.dodge_btn.get_global_rect().get_center(), true)
	if not _check(touch.camera_touch_index == -1, "disabled UI acquired camera"): return
	_touch(2, Vector2.ZERO, false)
	var pause_button := Button.new()
	pause_button.position = Vector2(root.get_visible_rect().size.x * 0.65, 10)
	pause_button.size = Vector2(100, 60)
	root.add_child(pause_button)
	_touch(3, pause_button.get_global_rect().get_center(), true)
	if not _check(touch.camera_touch_index == -1, "external Pause UI acquired camera"): return
	_touch(3, Vector2.ZERO, false)
	# Full-stick exhaustion cannot chatter around the five-point threshold.
	player.clear_traversal_input()
	player.stamina = 4.9
	player.set_mobile_input_vector(Vector2(0, -1), true)
	await _steps(100)
	if not _check(not player.mobile_sprint_active and player._run_exhausted, "exhaustion resumed Run without release"): return
	player.set_mobile_input_vector(Vector2.ZERO, true)
	await _steps(3)
	player.set_mobile_input_vector(Vector2(0, -1), true)
	await _steps(3)
	if not _check(player.mobile_sprint_active, "released/recovered Run stayed locked"): return
	Input.action_release("sprint")
	Input.action_release("move_forward")
	touch.queue_free()
	pause_button.queue_free()
	world.queue_free()
	await _steps(3)
	await create_timer(0.1).timeout
	print("PASS third-person controls: analog speed, yaw/diagonal, owned neutral, Shift Run, queued Roll/Jump, fixed radial deadzone, UI blockers, exhaustion")
	quit(0)

func _touch(index: int, pos: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = pos
	event.pressed = pressed
	touch._input(event)

func _drag(index: int, pos: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = pos
	touch._input(event)

func _steps(count: int) -> void:
	for i in range(count): await physics_frame

func _check(condition: bool, message: String) -> bool:
	if not condition:
		push_error(message)
		quit(1)
	return condition

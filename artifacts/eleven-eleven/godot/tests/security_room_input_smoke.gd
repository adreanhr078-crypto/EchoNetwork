extends SceneTree

## Standalone physical route review: staged spawn only; no in-route relocation.
var world: Node3D
var room: Node3D
var player: EchoPlayer
var touch: MobileTouchControls
var retries: Array[Vector3] = []
var passages := 0
var discoveries: Array[String] = []

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	if "boundary-fall" in OS.get_cmdline_user_args():
		await _spawn(Vector3(0,0.1,-0.2))
		touch.joystick_moved.emit(Vector2(0,1))
		for i in range(100): await physics_frame
		touch.joystick_moved.emit(Vector2.ZERO)
		print("BOUNDARY FALL position=",player.position," retry_events=",retries.size())
		if not _check(not retries.is_empty(), "real backward boundary fall never requested safe retry"): return
		await _dispose()
		quit(0)
		return
	if "scanner-loiter" in OS.get_cmdline_user_args():
		await _spawn(Vector3(0,0.1,-8))
		var peak := 0.0
		for i in range(720):
			await physics_frame
			peak = maxf(peak,room.warning)
		print("SCANNER LOITER central uncovered 12s peak_warning=",peak," retry_events=",retries.size())
		await _dispose()
		quit(0)
		return
	for upper in [false, true]:
		await _spawn(Vector3(3.6,0.1,-1.4) if upper else Vector3(-2.6,0.1,-1.4))
		if upper:
			if not await _walk(Vector3(3.6,0,-1.8)): return
			touch.joystick_moved.emit(Vector2(0,-1))
			touch.jump_tapped.emit()
			for i in range(180):
				await physics_frame
				if player.surface_motor.hanging: break
			if not _check(player.surface_motor.hanging, "authored service face did not produce a real climb/hang"): return
			touch.jump_tapped.emit()
			for i in range(140):
				await physics_frame
				if not player.traversal.is_climbing(): break
			touch.joystick_moved.emit(Vector2.ZERO)
			for i in range(12): await physics_frame
			if not _check(player.is_on_floor() and player.position.y > 2.3, "service mantle did not reach upper physical platform"): return
			if not await _walk(Vector3(3.6,2.4,-11.5)): return
			if not _check(room.service_trace and "security_service_trace" in discoveries, "upper passage did not reveal its own trace"): return
			# Sweep the real SpringArm against the right wall through touch look.
			touch.camera_swiped.emit(Vector2(520,0))
			for i in range(12): await physics_frame
			if not _check(absf(player.player_camera.global_position.x) < 4.42, "gameplay camera crossed service-side wall"): return
			touch.camera_swiped.emit(Vector2(-520,0))
			for i in range(12): await physics_frame
			if not await _walk(Vector3(3.6,2.4,-12.5)): return
			if not await _walk(Vector3(3.6,1.34,-14.2)): return
			if not _check(player.position.y > 1.2 and player.position.y < 1.5, "service descent missed its authored intermediate platform"): return
			if not await _walk(Vector3(-1.3,0,-15.2)): return
		else:
			if not await _walk(Vector3(-3.5,0,-1.8)): return
			var station: Node3D = room.get_node("DivertStation")
			if not _check(not room.request_station("gate",player,station).accepted, "station/action substitution opened gate"): return
			player.control_locked = true
			touch.use_tapped.emit()
			if not _check(not room.request_station("divert",player,station).accepted and room.diversion_remaining == 0, "locked player activated station"): return
			player.control_locked = false
			touch.jump_tapped.emit()
			for i in range(5): await physics_frame
			if not _check(not player.is_on_floor(), "airborne interaction fixture did not physically jump"): return
			touch.use_tapped.emit()
			if not _check(not room.request_station("divert",player,station).accepted and room.diversion_remaining == 0, "airborne player activated station"): return
			for i in range(100):
				await physics_frame
				if player.is_on_floor(): break
			if not _use("DivertStation"): return
			if not _check(room.diversion_remaining > 0 and not room.gate_open and room.scanner_trace, "real touch diversion failed or bypassed latch"): return
			if not await _walk(Vector3(-3.5,0,-14.8)): return
			if not await _walk(Vector3(-1.3,0,-15.2)): return
		room.reduced_motion = upper
		if not _use("GateStation"): return
		if not upper:
			if not _check(not room._gate_shape.disabled, "normal gate collision disappeared before lift"): return
			for i in range(20): await physics_frame
			if not _check(not room._gate_shape.disabled and room._gate.position.y < 4.3, "normal gate became passable before animation finished"): return
		if not _check(not room.request_station("gate",player,room.get_node("GateStation")).accepted, "duplicate physical latch replay accepted"): return
		if not await _walk(Vector3(0,0,-15.4)): return
		if not await _walk(Vector3(0,0,-17.55)): return
		for i in range(20): await physics_frame
		if not _check(room.gate_open and passages == 1 and player.is_on_floor(), "physical manual gate/exit route failed or completion repeated"): return
		if not _check(retries.is_empty(), "physical route raised an unhandled scanner retry"): return
		if not _check(not player.combat_available and not player.contract_with_zero_sealed and not player.shadow_step_unlocked, "human passage granted early powers"): return
		print("PASS security input route upper=",upper," position=",player.position," discoveries=",discoveries," passage_events=",passages," camera_hit=",player.camera_boom.get_hit_length())
		await _dispose()
	print("PASS standalone security actual touch routes: main diversion/cover/latch and upper climb/mantle/walkway/descent/latch; no in-route teleports, phase calls or early powers")
	quit(0)

func _spawn(at: Vector3) -> void:
	retries.clear()
	discoveries.clear()
	passages = 0
	world = Node3D.new()
	root.add_child(world)
	room = load("res://scenes/environment/security_checkpoint_room.tscn").instantiate()
	world.add_child(room)
	player = load("res://scenes/player/echo_player.tscn").instantiate()
	player.position = at # Only staged initial spawn, never an in-route relocation.
	world.add_child(player)
	player.finish_opening_recovery()
	player.surface_traversal_enabled = true
	player.camera_boom.rotation.y = 0
	room.player = player
	room.set_audio_muted(true)
	room.reduced_motion = true
	room.retry_requested.connect(func(anchor: Vector3): retries.append(anchor))
	room.passage_ready.connect(func(): passages += 1)
	room.discovery_observed.connect(func(id: String): discoveries.append(id))
	var canvas := CanvasLayer.new()
	world.add_child(canvas)
	touch = load("res://scenes/ui/mobile_touch_controls.tscn").instantiate()
	canvas.add_child(touch)
	touch.is_joystick_active = true
	touch.joystick_moved.connect(func(v: Vector2): player.set_mobile_input_vector(Vector2.ZERO if player.control_locked else v, touch.is_joystick_active and not player.control_locked))
	touch.jump_tapped.connect(player.request_jump)
	touch.dodge_tapped.connect(player.request_dodge)
	touch.use_tapped.connect(player.interact_with_nearest)
	touch.camera_swiped.connect(player.apply_touch_camera_look)
	for i in range(12): await physics_frame

func _walk(target: Vector3) -> bool:
	for i in range(800):
		var delta := target - player.global_position
		delta.y = 0
		if delta.length() < 0.17:
			touch.joystick_moved.emit(Vector2.ZERO)
			for settle in range(8): await physics_frame
			if player.is_on_floor(): return true
			continue
		var magnitude := 1.0 if delta.length() > 1.2 else 0.65
		touch.joystick_moved.emit(Vector2(delta.x,delta.z).normalized() * magnitude)
		await physics_frame
	return _check(false, "physical movement blocked toward %s from %s" % [target,player.global_position])

func _use(station_name: String) -> bool:
	var station := room.get_node(station_name)
	if not _check(player.get_nearest_interactable() == station.get_node("InteractionArea"), "touch use has no physical proximity to " + station_name): return false
	touch.use_tapped.emit()
	return true

func _dispose() -> void:
	touch.joystick_moved.emit(Vector2.ZERO)
	world.queue_free()
	for i in range(4): await process_frame

func _check(condition: bool, detail: String) -> bool:
	if condition: return true
	if is_instance_valid(touch): touch.joystick_moved.emit(Vector2.ZERO)
	push_error(detail)
	quit(1)
	return false

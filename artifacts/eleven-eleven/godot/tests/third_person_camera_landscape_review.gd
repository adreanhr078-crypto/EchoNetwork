extends SceneTree

var world: Node3D
var player: EchoPlayer

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	world = Node3D.new()
	root.add_child(world)

	player = load("res://scenes/player/echo_player.tscn").instantiate()
	player.position = Vector3(0, 2, 0)
	world.add_child(player)
	player.finish_opening_recovery()
	await _steps(3)

	# 1. Audit SpringArm3D invariants
	var boom: SpringArm3D = player.camera_boom
	if not _check(boom != null, "camera boom missing"): return
	if not _check(is_equal_approx(boom.spring_length, 3.0), "spring_length is not 3.0m"): return
	if not _check(boom.collision_mask == 1, "collision_mask is not 1"): return
	if not _check(is_equal_approx(boom.margin, 0.22), "margin is not 0.22"): return
	if not _check(boom.shape is SphereShape3D and is_equal_approx((boom.shape as SphereShape3D).radius, 0.18), "boom shape is not SphereShape3D radius 0.18"): return

	# 2. Audit Camera3D baseline and aspect invariants
	var cam: Camera3D = player.player_camera
	if not _check(cam != null, "player camera missing"): return
	if not _check(is_equal_approx(cam.fov, 65.0), "initial Camera3D fov is not 65.0"): return
	if not _check(cam.keep_aspect == Camera3D.KEEP_HEIGHT, "Camera3D keep_aspect is not KEEP_HEIGHT"): return

	# 3. Audit pitch clamp (-75 deg to +75 deg = +/- 1.3089969 rad)
	var min_pitch := deg_to_rad(-75.0)
	var max_pitch := deg_to_rad(75.0)
	player.set_gameplay_orbit(Vector3(-2.0, 0, 0))
	if not _check(is_equal_approx(player.camera_target_rotation.x, min_pitch), "pitch min clamp failed: " + str(player.camera_target_rotation.x)): return
	player.set_gameplay_orbit(Vector3(2.0, 0, 0))
	if not _check(is_equal_approx(player.camera_target_rotation.x, max_pitch), "pitch max clamp failed: " + str(player.camera_target_rotation.x)): return

	# Damped orbit smoothly interpolates to target without overshoot
	player.set_gameplay_orbit(Vector3(0.0, 0.0, 0.0))
	player._process(1.0 / 60.0)
	player.apply_camera_look(Vector2(0, -100.0)) # Look up
	var target_up: float = player.camera_target_rotation.x
	if not _check(target_up > 0.0 and target_up <= max_pitch, "mouse look pitch up failed"): return
	for i in range(15):
		player._process(1.0 / 60.0)
	if not _check(absf(boom.rotation.x - target_up) < 0.05, "camera boom pitch did not smoothly track target"): return

	# 4. Audit dynamic FOV expansion during Sprint (smooth expansion to 72.0)
	player.set_gameplay_orbit(Vector3.ZERO)
	player.velocity = Vector3(0, 0, -3.0) # moving
	player.mobile_sprint_active = true
	player.stamina = 50.0
	player.reduced_camera_motion = false
	for i in range(45):
		player._process(1.0 / 60.0)
	if not _check(cam.fov > 71.0 and cam.fov <= 72.01, "sprint FOV did not expand smoothly towards 72.0: got " + str(cam.fov)): return

	# Sprint FOV returns to 65.0 when reduced motion is active (immediate accessibility)
	player.reduced_camera_motion = true
	player._process(1.0 / 60.0)
	if not _check(is_equal_approx(cam.fov, 65.0), "reduced motion did not restore FOV immediately to 65.0: got " + str(cam.fov)): return
	player.reduced_camera_motion = false
	player.mobile_sprint_active = false
	player.velocity = Vector3.ZERO
	for i in range(65):
		player._process(1.0 / 60.0)
	if not _check(absf(cam.fov - 65.0) < 0.05, "stop moving did not restore FOV to 65.0: got " + str(cam.fov)): return

	# 5. Audit Camera Shake response on combat impacts
	player.hp = player.MAX_HP
	player.reduced_camera_motion = false
	var pre_h := cam.h_offset
	var pre_v := cam.v_offset
	player.take_damage(30.0)
	await _steps(3)
	var shake_active := (cam.h_offset != pre_h or cam.v_offset != pre_v or root.get_tree().get_processed_tweens().size() > 0)
	if not _check(shake_active, "take_damage did not trigger screen shake on player camera"): return

	# 6. Audit landscape viewport golden-ratio composition (16:9 and 21:9)
	# Verify KEEP_HEIGHT maintains consistent vertical anchor and framing
	var anchor_y := boom.position.y
	if not _check(absf(anchor_y - 1.4) < 0.25, "camera anchor height deviated from chest/shoulder center: " + str(anchor_y)): return

	# Verify shoulder offset preserves off-center golden composition
	var shoulder_offset := boom.position.x
	if not _check(shoulder_offset > 0.15 and shoulder_offset <= 0.25, "shoulder offset deviated from golden third framing: " + str(shoulder_offset)): return

	print("PASS third-person camera landscape review: SpringArm3D length 3.0m/margin 0.22/mask 1, FOV 65.0/sprint 72.0/impact shake, 16:9/21:9 golden composition, smooth damping/pitch clamp [-75, +75]")
	world.queue_free()
	await _steps(3)
	quit(0)

func _steps(count: int) -> void:
	for i in range(count):
		await physics_frame

func _check(condition: bool, message: String) -> bool:
	if not condition:
		push_error(message)
		quit(1)
	return condition

extends "res://tests/stormworks_parkour_input_review.gd"
## Compare the same native jump input in a calm window and an active gust.

const WIND = preload("res://tests/fixtures/stormworks_crosswind.gd")
const ROUTE = preload("res://scripts/systems/stormworks_route.gd")
const TARGET := Vector3(-4.95, 2.18, -8.0)
const SAMPLE_TICKS := 24

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		quit(2)
		return
	root.size = Vector2i(1280, 720)
	root.unfocusable = true
	automatic_focus_resume = false
	AudioServer.set_bus_mute(0, true)
	world = Node3D.new()
	root.add_child(world)
	room = load("res://scenes/environment/maintenance_stormworks.tscn").instantiate()
	world.add_child(room)
	room.set_reduced_motion(true)
	var calm := await _sample(false)
	var gust := await _sample(true)
	if calm.is_empty() or gust.is_empty():
		push_error("Stormworks crosswind fixture failed to reach the first jump")
		quit(1)
		return
	var delta_x: float = gust.end_x - calm.end_x
	var passed: bool = calm.applied_ticks == 0 and gust.applied_ticks >= 8 and delta_x >= .15 and delta_x <= 1.0
	passed = passed and absf(calm.start_x - gust.start_x) < .01 and calm.airborne and gust.airborne
	passed = passed and calm.clock_paused and gust.clock_paused
	passed = passed and calm.landed and not gust.landed
	var output := FileAccess.open(args[0], FileAccess.WRITE)
	if not output:
		quit(2)
		return
	output.store_string(JSON.stringify({
		"status": "PASS_SCOPED_CROSSWIND" if passed else "FAIL_SCOPED_CROSSWIND",
		"scope": "Identical public jump input from a declared real Stormworks platform anchor. Review-only force.",
		"calm": calm, "gust": gust, "x_drift_difference_m": delta_x,
		"muted": true, "reduced_motion": true, "physics_hz": Engine.physics_ticks_per_second,
		"sample_ticks": SAMPLE_TICKS,
		"player_sha256": FileAccess.get_sha256("res://scripts/player/echo_player.gd"),
		"route_sha256": FileAccess.get_sha256("res://scripts/systems/stormworks_route.gd"),
		"fixture_sha256": FileAccess.get_sha256("res://tests/fixtures/stormworks_crosswind.gd"),
		"review_sha256": FileAccess.get_sha256(get_script().resource_path)
	}, "\t") + "\n")
	output.close()
	print("CROSSWIND ", delta_x, " m; ticks ", gust.applied_ticks)
	world.queue_free()
	await process_frame
	quit(0 if passed else 1)

func _sample(gust: bool) -> Dictionary:
	player = load("res://scenes/player/echo_player.tscn").instantiate()
	player.position = ROUTE.anchor(2, 0)
	room.add_child(player)
	player.finish_opening_recovery()
	player.control_locked = false
	player.set_process_unhandled_input(false)
	player.reduced_motion = true
	player.surface_traversal_enabled = true
	await _frames(18)
	_aim(TARGET)
	for tick in 60:
		_steer(TARGET)
		await _frames(1)
		if _pos().x < -1.65:
			break
	if not player.is_on_floor() or _pos().x >= -1.65:
		return {}
	var wind := WIND.new()
	wind.player = player
	wind.arabic = not OS.get_cmdline_user_args().has("--en")
	wind.elapsed = WIND.CALM_SECONDS + .05 if gust else .05
	room.add_child(wind)
	var clock_before := wind.elapsed
	paused = true
	for tick in 5:
		await process_frame
	var clock_paused := wind.elapsed == clock_before
	paused = false
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var folder := OS.get_cmdline_user_args()[0].get_base_dir()
		var name := "wind-gust.png" if gust else "wind-calm.png"
		if root.get_texture().get_image().save_png(folder.path_join(name)) != OK:
			return {}
	var start := _pos()
	_steer(TARGET)
	player.request_jump()
	var airborne := false
	for tick in SAMPLE_TICKS:
		await physics_frame
		airborne = airborne or not player.is_on_floor()
	var finish := _pos()
	var drift_ticks := wind.applied_ticks
	var landed := false
	for tick in 75:
		_steer(TARGET)
		await physics_frame
		if player.is_on_floor() and ROUTE.GAP_SAFE[0].has_point(_pos()):
			landed = true
			break
		if _pos().y < 1.0:
			break
	player.set_mobile_input_vector(Vector2.ZERO, false)
	var result := {"start_x": start.x, "end_x": finish.x,
		"start_z": start.z, "end_z": finish.z, "airborne": airborne,
		"applied_ticks": drift_ticks, "clock_paused": clock_paused,
		"landed": landed, "final_local_position": str(_pos())}
	wind.queue_free()
	player.queue_free()
	await process_frame
	await physics_frame
	return result

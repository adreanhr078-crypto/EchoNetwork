extends "res://tests/opening_player_journey_review.gd"
## Uses the real Room 01, player, pause state, and public interactable.

const PRESSURE = preload("res://tests/fixtures/room01_pressure.gd")

func _capture(id: String) -> void:
	if id.begins_with("pressure-") or id == "04-threshold":
		await super._capture(id)

func _before_room_exit() -> bool:
	var pressure := _mount_pressure()
	if OS.get_cmdline_user_args().has("--manual"):
		root.unfocusable = false
		root.grab_focus()
		player.set_process_unhandled_input(true)
		var title := "ضغط الممر" if pressure.arabic else "Passage pressure"
		var hint := "راقب مؤشر الممر أو افتح الصمام الجانبي." if pressure.arabic else "Watch the passage or open the side valve."
		main.hud.show_tutorial_toast("P24", "11.11", title, hint, 5.0)
		return false

	var was_muted: bool = main.audio_muted
	main.set_audio_muted(true)
	await _capture("pressure-high")
	var start := pressure.elapsed
	paused = true
	for frame in 12:
		await process_frame
	paused = false
	if not _check(pressure.elapsed == start, "Pressure phase advanced while paused"): return false
	player.set_gameplay_orbit(Vector3.ZERO)
	var camera := player.player_camera
	for frame in 90:
		if pressure.failures > 0: break
		player.set_mobile_input_vector(Vector2(0, -1), true)
		await physics_frame
	player.set_mobile_input_vector(Vector2.ZERO, false)
	if not _check(pressure.failures == 1 and pressure.attempts == 1 and player.global_position.z > PRESSURE.ENTRY_Z, "High pressure did not return Echo to the near side"): return false
	if not _check(camera.current and not player.control_locked, "Pressure retry stole gameplay camera or control"): return false
	for frame in 240:
		if pressure.can_cross(): break
		await physics_frame
	if not _check(pressure.can_cross(), "Timed crossing window did not arrive"): return false
	await _capture("pressure-low")
	if not await _walk(Vector3(0, 0, -14.15)): return false
	if not _check(pressure.successful_route == "timing" and pressure.attempts == 2, "Timed path did not succeed after one retry"): return false
	var timing := {"route": pressure.successful_route, "attempts": pressure.attempts, "failures": pressure.failures}
	pressure.queue_free()
	if not await _walk(Vector3(PRESSURE.VALVE_POS.x, 0, -11.75)): return false
	pressure = _mount_pressure()
	await _frames(3)
	if not _check(not pressure.can_cross() and player.get_nearest_interactable() == pressure.valve, "Side valve not reachable before the band"): return false
	var result := player.interact_with_nearest()
	if not _check(result.success and pressure.vent_remaining > PRESSURE.LOW_SECONDS, "Valve did not extend the crossing window"): return false
	if not _check(player.get_nearest_interactable() != pressure.valve, "Valve still accepts duplicate input during venting"): return false
	await _capture("pressure-valve")
	if not await _walk(Vector3(0, 0, -14.15)): return false
	if not _check(pressure.successful_route == "valve" and pressure.failures == 0 and camera.current and not player.control_locked, "Valve crossing failed or lost camera/control"): return false
	var report := FileAccess.open(folder + "pressure.json", FileAccess.WRITE)
	report.store_string(JSON.stringify({
		"engine": Engine.get_version_info().string,
		"display": DisplayServer.get_name(),
		"renderer": RenderingServer.get_current_rendering_method(),
		"adapter": RenderingServer.get_video_adapter_name(),
		"viewport": str(root.size),
		"physics_hz": Engine.physics_ticks_per_second,
		"muted": AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")),
		"reduced_motion": main.reduced_motion,
		"timing": timing,
		"valve": {"route": pressure.successful_route, "attempts": pressure.attempts, "failures": pressure.failures},
		"status": "PASS_REVIEW_FIXTURE",
		"human_playtest": "UNVERIFIED"
	}, "\t"))
	report.close()
	pressure.queue_free()
	main.set_audio_muted(was_muted)
	return true

func _mount_pressure() -> PRESSURE:
	var pressure := PRESSURE.new()
	pressure.player = player
	pressure.arabic = main.presentation_language == "ar"
	main.add_child(pressure)
	return pressure

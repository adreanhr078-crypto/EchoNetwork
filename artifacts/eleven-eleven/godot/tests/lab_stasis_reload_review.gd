extends "res://tests/opening_player_journey_review.gd"

## Reload the public journey's actually earned wish bytes in an isolated PID
## profile. This verifies restored presentation, not a manufactured wish.
func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if not _check(args.size() >= 2, "Expected earned wish checkpoint and evidence folder"):
		return
	root.size = Vector2i(1280, 720)
	root.unfocusable = true
	folder = args[1] + "/"
	DirAccess.make_dir_recursive_absolute(folder)
	var profile := "user://stasis_reload_%d/" % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(profile)
	var source_hashes := {}
	for file in ["opening.json", "maintenance.json", "route.json", "campaign.json", "preferences.cfg"]:
		if not _check(FileAccess.file_exists(args[0] + "/" + file) and
			DirAccess.copy_absolute(args[0] + "/" + file, profile + file) == OK, "Missing earned wish bytes: " + file):
			return
		source_hashes[file] = FileAccess.get_sha256(args[0] + "/" + file)
	main = load("res://scenes/native_journey.tscn").instantiate()
	main.native_checkpoint_path = profile + "opening.json"
	main.native_preferences_path = profile + "preferences.cfg"
	main.get_node("SystemJourneyPreview").checkpoint_path = profile + "maintenance.json"
	main.get_node("NativeJourneyController").checkpoint_path = profile + "route.json"
	main.get_node("NativeCampaignController").checkpoint_path = profile + "campaign.json"
	root.add_child(main)
	player = main.player
	main.set_audio_muted(true)
	main.set_visual_quality("high")
	main.set_reduced_motion(false)
	for tick in 20:
		await process_frame
		await physics_frame
	var campaign: Node = main.get_node("NativeCampaignController")
	var room: Node3D = campaign.rooms[5]
	var architecture: Node = room.find_child("ClinicalLabArchitecture", true, false)
	if not _check(campaign.current == 5 and room.wish_done and room.breach_open,
		"Reload did not restore the actually earned wish before physical hospital transfer"):
		return
	if not _check(room._stasis_digits.visible and room._stasis_digits.text == "11:11" and
		architecture.stasis_display_material.get_shader_parameter("stasis_active") == true,
		"Reload lost original 11:11 or restored the wrong display finish"):
		return
	var progress_before := JSON.stringify(campaign.progress)
	var camera := Camera3D.new()
	room.add_child(camera)
	camera.environment = player.player_camera.environment
	camera.position = Vector3(0, 5, -31)
	camera.look_at(room.to_global(Vector3(0, 5, -39.7)))
	camera.make_current()
	main.hud.hide()
	for tick in 5:
		await process_frame
	await _capture("restored-1111")
	main.set_reduced_motion(true)
	paused = true
	for tick in 3:
		await process_frame
	if not _check(room._stasis_digits.visible and JSON.stringify(campaign.progress) == progress_before,
		"Pause/Reduced Motion changed earned stasis progression or hid the clock"):
		return
	var sources := {}
	for path in ["res://scripts/environment/dr_kinja_lab_room.gd", "res://scripts/environment/clinical_lab_architecture.gd",
		"res://shaders/clinical_stasis_display.gdshader", "res://tests/lab_stasis_reload_review.gd"]:
		sources[path] = FileAccess.get_sha256(path)
	for path in ["res://scripts/environment/lab_memory_cinema.gd","res://scripts/environment/memory_reflection_space.gd","res://shaders/memory_water.gdshader","res://assets/cinematics/memory-screens/city-high.ogv","res://assets/cinematics/memory-screens/friends-high.ogv"]:
		sources[path]=FileAccess.get_sha256(path)
	var output := FileAccess.open(folder + "reload-review.json", FileAccess.WRITE)
	output.store_string(JSON.stringify({"checks": checks, "renderer": RenderingServer.get_current_rendering_method(),
		"source_profile": args[0], "earned_profile_sha256": source_hashes, "source_hashes": sources,
		"scope": "Earned wish byte reload, original digits, static display finish and pause/Reduced Motion; no full-chapter acceptance."}, "\t"))
	output.close()
	print("LAB_STASIS_RELOAD ", checks)
	quit(0)

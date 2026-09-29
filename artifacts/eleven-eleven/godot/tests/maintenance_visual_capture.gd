extends SceneTree

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() == 2:
		# Render at the requested virtual viewport even when the desktop window
		# manager clamps the physical window to its available work area.
		root.content_scale_size = Vector2i(int(args[0]), int(args[1]))
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	var main = load("res://scenes/system_journey_preview.tscn").instantiate()
	main.native_checkpoint_path = "user://maintenance_capture_opening.json"
	main.native_preferences_path = "user://maintenance_capture.cfg"
	root.add_child(main)
	main.get_node("SystemJourneyPreview").checkpoint_path = "user://maintenance_capture.json"
	await process_frame
	main.set_audio_muted(true)
	main.set_reduced_motion(true)
	main.player.finish_opening_recovery()
	var dialogue = main.hud.find_child("DialogueOverlay", true, false)
	for i in range(8):
		if dialogue.is_active: dialogue.continue_button.pressed.emit()
		await process_frame
	main.native_pause_menu.queue_free()
	main.native_pause_menu = null
	# Render fixture only: this intentionally does not prove story progression.
	main.opening_web_handoff.reported_milestones.append("memory_scene_completed")
	for i in range(8): await physics_frame
	main.player.position = Vector3(0,0.1,-23.1)
	main.player.velocity = Vector3.ZERO
	main.player.control_locked = false
	main.player.camera_boom.rotation.y = 0
	main.player.mobile_input_vector = Vector2(0,-1)
	main.player.request_jump()
	for i in range(180):
		await physics_frame
		if main.player.surface_motor.hanging: break
	main.player.mobile_input_vector = Vector2.ZERO
	main.player.set_physics_process(false)
	main.player.camera_boom.rotation.y = 0.35
	for i in range(8): await process_frame
	await RenderingServer.frame_post_draw
	_save_view("hang")
	var skeleton := main.player.find_child("Skeleton3D", true, false) as Skeleton3D
	var contact_report := {"fixture": "actual motor hang; staged entry, no story acceptance", "player": str(main.player.global_position), "ledge_y": 3.4, "wall_front_z": -23.75, "wrists": {}}
	for bone in ["tripo__0_Right_Limb_2", "tripo__0_Left_Limb_1"]:
		var id := skeleton.find_bone(bone)
		var wrist := skeleton.to_global(skeleton.get_bone_global_pose(id).origin)
		contact_report.wrists[bone] = {"position": [wrist.x,wrist.y,wrist.z], "wall_distance": absf(wrist.z+23.75), "ledge_distance": absf(wrist.y-3.4)}
	var contact_file := FileAccess.open("res://../audits/evidence/maintenance-hang-contacts.json", FileAccess.WRITE)
	contact_file.store_string(JSON.stringify(contact_report,"\t"))
	contact_file.close()
	# Inspect the new authored push at its peak. This is a render fixture,
	# not an extra progression test or an accepted in-game cinematic.
	main.player.set_physics_process(true)
	main.player.mobile_input_vector = Vector2(0,-1)
	main.player.request_jump()
	for i in range(26): await physics_frame
	main.player.set_physics_process(false)
	if main.player.surface_motor._mantle_points.is_empty():
		push_error("Capture did not reach an actual mantle phase")
		quit(1)
		return
	await RenderingServer.frame_post_draw
	_save_view("mantle")
	var camera := Camera3D.new()
	main.add_child(camera)
	camera.position = Vector3(3.7,7.4,-20.7)
	camera.look_at(Vector3(1,3,-27))
	camera.fov = 80
	camera.make_current()
	for i in range(8): await process_frame
	await RenderingServer.frame_post_draw
	_save_view("room")
	print("CAPTURE maintenance: room and actual motor hang, staged render fixture only")
	main.queue_free()
	for i in range(3): await process_frame
	for path in ["user://maintenance_capture_opening.json","user://maintenance_capture_opening.json.bak","user://maintenance_capture.cfg","user://maintenance_capture.json","user://maintenance_capture.json.bak"]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	quit()

func _save_view(label: String) -> void:
	var capture := root.get_texture().get_image()
	var path := "res://../audits/evidence/maintenance-%s-%dx%d.png" % [label, capture.get_width(), capture.get_height()]
	if capture.save_png(path) != OK:
		push_error("Maintenance evidence image could not be saved")
		quit(1)

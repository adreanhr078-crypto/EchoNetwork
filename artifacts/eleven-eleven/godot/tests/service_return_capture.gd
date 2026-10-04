extends SceneTree

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var fps := int(args[0]) if args.size() > 0 else 30
	var skip := args.size() > 1 and args[1] == "skip"
	if fps not in [30,60,120]: quit(1); return
	var attempt := args[2] if args.size() > 2 else "final"
	var folder := ProjectSettings.globalize_path("res://../audits/evidence/third-person-foundation-20261001/implementation/render/service-%d-%s-%s/" % [fps,"skip" if skip else "normal",attempt])
	DirAccess.make_dir_recursive_absolute(folder)
	_cleanup()
	root.size = Vector2i(960,540)
	root.content_scale_size = Vector2i(1280,720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	var main = load("res://scenes/system_journey_preview.tscn").instantiate()
	main.native_checkpoint_path = "user://service_return_opening.json"
	main.native_preferences_path = "user://service_return.cfg"
	root.add_child(main)
	var director = main.get_node("SystemJourneyPreview")
	director.checkpoint_path = "user://service_return_journey.json"
	await process_frame
	main.set_audio_muted(true)
	main.player.finish_opening_recovery()
	var dialogue = main.hud.find_child("DialogueOverlay",true,false)
	for i in range(8):
		if dialogue.is_active: dialogue.continue_button.pressed.emit()
		await process_frame
	main.opening_web_handoff.reported_milestones.append("memory_scene_completed")
	for i in range(8): await physics_frame
	director.stage = 5
	director.refresh_objective()
	var player: EchoPlayer = main.player
	player.position = Vector3(1.25,5.42,-30.1)
	player.velocity = Vector3.ZERO
	player.set_gameplay_orbit(Vector3(-0.15,0,0))
	for i in range(35): await physics_frame
	var touch = main.hud.find_child("MobileTouchControls",true,false)
	touch._platform_touch_enabled = true
	touch.set_interaction_blocked(false)
	var result := player.interact_with_nearest()
	if not result.get("data",{}).get("released",false): push_error("capture did not activate actual wheel"); quit(1); return
	var cinematic = director.service_cinematic
	var previous_camera: Camera3D = root.get_camera_3d()
	var last_position := previous_camera.global_position
	var last_rotation := previous_camera.global_basis.get_rotation_quaternion()
	var handoff_step := 0.0
	var handoff_angle := 0.0
	var trace := []
	for frame in range(ceili(fps * (1.3 if skip else 3.8))):
		if skip and frame == ceili(fps*0.6): cinematic._skip.pressed.emit()
		await process_frame
		await RenderingServer.frame_post_draw
		var current_camera: Camera3D = root.get_camera_3d()
		if current_camera != previous_camera:
			handoff_step = current_camera.global_position.distance_to(last_position)
			handoff_angle = rad_to_deg(current_camera.global_basis.get_rotation_quaternion().angle_to(last_rotation))
		var screenshot := root.get_texture().get_image()
		screenshot.resize(960,540)
		screenshot.save_png(folder+"frame-%05d.png" % frame)
		trace.append({"frame":frame,"cinematic_active":cinematic.active,"return_elapsed":cinematic._return_elapsed,"camera":[current_camera.global_position.x,current_camera.global_position.y,current_camera.global_position.z],"fov":current_camera.fov})
		previous_camera = current_camera
		last_position = current_camera.global_position
		last_rotation = current_camera.global_basis.get_rotation_quaternion()
	var file := FileAccess.open(folder+"trace.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"fps_fixed_step":fps,"skip":skip,"staged_entry":true,"handoff_step_m":handoff_step,"handoff_angle_deg":handoff_angle,"frames":trace},"\t"))
	file.close()
	if cinematic.active or root.get_camera_3d() != player.player_camera or handoff_step > 0.1 or handoff_angle > 2:
		push_error("service return discontinuity: position=%sm angle=%sdeg" % [handoff_step,handoff_angle]); quit(1); return
	print("PASS rendered service return fps=",fps," skip=",skip," handoff_m=",handoff_step," angle_deg=",handoff_angle)
	main.queue_free()
	await process_frame
	_cleanup()
	quit(0)

func _cleanup() -> void:
	for base in ["user://service_return_opening.json","user://service_return.cfg","user://service_return_journey.json"]:
		for suffix in ["",".bak",".tmp"]:
			if FileAccess.file_exists(base+suffix): DirAccess.remove_absolute(base+suffix)

extends SceneTree

var main: Node3D
var folder := "res://../audits/evidence/hyper-anime-cp41-20261019/live/"
var checks := 0

func _initialize() -> void: _run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:
		push_error(message)
		quit(1)
		assert(ok,message)

func _run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence="): folder=argument.trim_prefix("--evidence=")+"/"
	folder=ProjectSettings.globalize_path(folder).simplify_path()+"/"
	DirAccess.make_dir_recursive_absolute(folder)
	root.content_scale_size=Vector2i(1280,720)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_VIEWPORT
	main=load("res://scenes/native_journey.tscn").instantiate()
	main.native_checkpoint_path="user://hyper_live_opening.json"
	main.native_preferences_path="user://hyper_live.cfg"
	main.get_node("SystemJourneyPreview").checkpoint_path="user://hyper_live_maintenance.json"
	main.get_node("NativeJourneyController").checkpoint_path="user://hyper_live_route.json"
	main.get_node("NativeCampaignController").checkpoint_path="user://hyper_live_campaign.json"
	root.add_child(main)
	main.set_audio_muted(true)
	for i in 5: await process_frame
	var player: EchoPlayer=main.player
	player.finish_opening_recovery()
	var dialogue: Node=main.hud.find_child("DialogueOverlay",true,false)
	while dialogue.is_active: dialogue.advance_dialogue()
	main.native_pause_menu.resume_button.pressed.emit()
	player.set_process_unhandled_input(false)
	check(player.action_camera_rig!=null,"Actual player has no DynamicActionCameraRig")
	check(root.get_node("HyperAnimeWorldManager").main==main,"Actual scene missing world integration")
	check(root.get_node("KineticVFXOrchestrator").player==player,"Actual player missing VFX integration")
	check(player.action_camera_rig.external and player.action_camera_rig.arm==player.camera_boom,"Camera replaced tested SpringArm")
	check(not main.set_visual_quality("invalid"),"Invalid presentation quality accepted")
	main.native_pause_menu.quality_button.pressed.emit()
	check(main.visual_quality=="low" and is_equal_approx(root.scaling_3d_scale,0.65),"Pause quality control failed low resolution tier")
	var preferences:=ConfigFile.new()
	check(preferences.load(main.native_preferences_path)==OK and preferences.get_value("presentation","visual_quality")=="low","Quality preference did not persist")
	main.set_visual_quality("high")
	main.native_pause_menu.set_session_paused(true)
	await capture("pause-quality-ar")
	main.set_presentation_language("en")
	check(main.native_pause_menu.quality_button.text.contains("High"),"Quality label lost English presentation")
	await capture("pause-quality-en")
	main.set_presentation_language("ar")
	main.native_pause_menu.resume_button.pressed.emit()
	main.set_reduced_motion(true)
	player.set_process(false)
	player.set_physics_process(false)
	player._camera_suspended=false
	player.player_camera.make_current()
	player.action_camera_rig.add_trauma(1.0,Vector3.ONE)
	player._process(0.1)
	check(player.player_camera.rotation.is_zero_approx() and is_equal_approx(player.player_camera.fov,70.0),"Reduced Motion retained shake/lens pumping")
	main.set_reduced_motion(false)
	player.control_locked=false
	player._camera_return_remaining=0.0
	player.velocity=Vector3(9.8,0,0)
	for i in 120: player._process(1.0/60)
	check(player.player_camera.fov>90.0 and player.player_camera.fov<=92.0,"High speed lens failed requested range")
	check(absf(rad_to_deg(player.player_camera.rotation.z))<=3.5,"Camera banking exceeded comfort limit")
	player.action_camera_rig.add_trauma(0.7,Vector3.RIGHT)
	player.suspend_gameplay_camera()
	check(player.player_camera.rotation.is_zero_approx(),"Cinematic suspend retained trauma")
	player.resume_gameplay_camera(0.0)
	player.velocity=Vector3.ZERO
	player.set_process(true)
	player.set_physics_process(true)
	player.set_gameplay_orbit(Vector3(-0.1,0,0))
	for i in 12: await physics_frame
	await capture("room01-current")
	if OS.get_cmdline_user_args().has("--profile"):
		var profiles:={}
		for tier in ["high","low"]:
			root.get_node("HyperAnimeWorldManager").set_quality(tier)
			for i in 30: await process_frame
			var durations: Array[float]=[]
			var last:=Time.get_ticks_usec()
			for i in 90:
				await process_frame
				var now:=Time.get_ticks_usec()
				durations.append(float(now-last)/1000.0)
				last=now
			durations.sort()
			profiles[tier]={"p50_ms":durations[45],"p95_ms":durations[85],"draws":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),"engine_texture_bytes":Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)}
		root.get_node("HyperAnimeWorldManager").set_quality("high")
		var profile_file:=FileAccess.open(folder+"profile.json",FileAccess.WRITE)
		profile_file.store_string(JSON.stringify({"profiles":profiles,"scope":"90 actual process intervals per tier at one stationary actual room01 viewpoint; excludes capture; not GPU frame timing or full-route performance acceptance"},"\t"))
	var portrait:=Camera3D.new()
	main.add_child(portrait)
	portrait.global_position=player.global_position+player.model_local_forward.rotated(Vector3.UP,player.visual_root.rotation.y)*2.4+Vector3.UP*1.25
	portrait.look_at(player.global_position+Vector3.UP*1.15)
	portrait.fov=52
	portrait.make_current()
	for i in 8: await process_frame
	await capture("echo-current-front")
	player.player_camera.make_current()
	portrait.queue_free()
	# Explicit render fixture for the existing room02 motor. This does not
	# grant story progress and is not the full connected route driver.
	main.opening_web_handoff.reported_milestones.append("memory_scene_completed")
	for i in 8: await physics_frame
	player.position=Vector3(0,0.1,-23.1)
	player.velocity=Vector3.ZERO
	player.control_locked=false
	player.set_mobile_input_vector(Vector2(0,-1),true)
	player.request_jump()
	for i in 180:
		await physics_frame
		if player.surface_motor.hanging: break
	player.set_mobile_input_vector(Vector2.ZERO,true)
	check(player.surface_motor.hanging,"Current room02 did not catch ledge")
	player.set_physics_process(false)
	player.set_gameplay_orbit(Vector3(-0.12,0.35,0))
	for i in 10: await process_frame
	await capture("room02-braced-current")
	var body_position:=player.global_position
	var camera:=Camera3D.new()
	main.add_child(camera)
	camera.position=body_position+Vector3(3.0,0.6,1.9)
	camera.look_at(body_position+Vector3.UP*0.9)
	camera.fov=60
	camera.make_current()
	for i in 10: await process_frame
	await capture("room02-braced-contact")
	var report:={"status":"PASS","checks":checks,"scope":"actual native scene integration and staged room02 contact render; connected progression verified separately","renderer":RenderingServer.get_current_rendering_method(),"display":DisplayServer.get_name(),"adapter":RenderingServer.get_video_adapter_name(),"converted_materials":root.get_node("HyperAnimeWorldManager").adapter.converted,"source_hashes":{}}
	for path in ["res://scripts/main.gd","res://scripts/player/echo_player.gd","res://engine_visuals/HyperAnimeWorldManager.gd","res://engine_visuals/camera/DynamicActionCameraRig.gd","res://engine_visuals/vfx/KineticVFXOrchestrator.gd","res://engine_visuals/shaders/hyper_anime_uber.gdshader"]:
		report.source_hashes[path]=FileAccess.get_sha256(path)
	var file:=FileAccess.open(folder+"live-review.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	main.queue_free()
	for i in 5: await process_frame
	for path in ["hyper_live_opening.json","hyper_live.cfg","hyper_live_maintenance.json","hyper_live_route.json","hyper_live_campaign.json"]:
		for suffix in ["",".bak",".tmp"]:
			if FileAccess.file_exists("user://"+path+suffix): DirAccess.remove_absolute("user://"+path+suffix)
	print("HYPER_LIVE_REVIEW ",JSON.stringify(report))
	quit()

func capture(id: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(folder+id+".png")==OK,"Live capture failed")

extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var tag := "current"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		tag = args[0].validate_filename()
	var main = load("res://scenes/opening_native_room.tscn").instantiate()
	main.native_checkpoint_path = "user://opening_visual_capture.json"
	main.native_preferences_path = "user://opening_visual_capture.cfg"
	root.add_child(main)
	await process_frame
	main.set_audio_muted(true)
	main.set_reduced_motion(true)
	main.player.finish_opening_recovery()
	main.native_pause_menu.set_session_paused(false)
	# Window resizes can lose desktop focus. This render-only probe must not
	# capture the pause overlay instead of the scene being compared.
	main.native_pause_menu.queue_free()
	main.native_pause_menu = null
	for i in range(12): await physics_frame
	main.player.animation_player.stop()
	main.player.play_anim("IDLE", 0.0)
	main.player.animation_player.seek(0.0, true)
	main.player.animation_player.advance(0.0)
	main.player.animation_player.pause()
	main.player.set_physics_process(false)
	var skeleton: Skeleton3D = main.player.find_child("Skeleton3D", true, false)
	print("POSE player=", main.player.global_position, " model=", main.player.visual_root.position, " animation=", main.player.animation_player.current_animation)
	for bone in ["tripo__Root", "tripo__1_Left_Limb_2", "tripo__1_Right_Limb_2", "tripo__Head_1"]:
		var index := skeleton.find_bone(bone)
		if index >= 0: print("BONE ", bone, " ", skeleton.to_global(skeleton.get_bone_global_pose(index).origin))
	if tag == "without-outline":
		for mesh in main.player.visual_root.find_children("*", "MeshInstance3D", true, false):
			if mesh.mesh:
				for surface in mesh.mesh.get_surface_count():
					var material = mesh.get_active_material(surface)
					if material is ShaderMaterial: material.next_pass = null
	var environment: Environment = main.get_node("WorldEnvironment").environment
	print("VISUAL exposure=", environment.tonemap_exposure, " saturation=", environment.adjustment_saturation, " glow=", environment.glow_intensity)
	for mesh in main.player.visual_root.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh:
			for surface in mesh.mesh.get_surface_count():
				var material = mesh.get_active_material(surface)
				print("MATERIAL ", mesh.name, " ", material.get_class())
	var evidence := ProjectSettings.globalize_path("res://../audits/evidence/")
	DirAccess.make_dir_recursive_absolute(evidence)
	for size in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = size
		for i in range(4): await process_frame
		await RenderingServer.frame_post_draw
		var file := evidence + "opening-%s-%dx%d.png" % [tag, size.x, size.y]
		root.get_texture().get_image().save_png(file)
		print("CAPTURE ", file)
	main.queue_free()
	await process_frame
	for path in ["user://opening_visual_capture.json", "user://opening_visual_capture.json.bak", "user://opening_visual_capture.cfg"]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	quit(0)

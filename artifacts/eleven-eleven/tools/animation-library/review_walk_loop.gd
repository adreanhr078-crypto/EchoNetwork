extends SceneTree
## Independent manual AnimationPlayer playback; no seeking at loop seams.
func _initialize() -> void:
	call_deferred("review")

func review() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 3:
		quit(1)
		return
	if not FileAccess.file_exists(args[1]):
		push_error("Missing loop metadata")
		quit(1)
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(args[1]))
	if not parsed is Dictionary or not parsed.has("action") or not parsed.has("root_curve_blender_z_up") or parsed.root_curve_blender_z_up.size() < 2:
		push_error("Invalid loop metadata")
		quit(1)
		return
	var metadata: Dictionary = parsed
	var output := args[2]
	DirAccess.make_dir_recursive_absolute(output)
	var world := Node3D.new()
	root.add_child(world)
	var model: Node3D = load(args[0]).instantiate()
	world.add_child(model)
	var skeleton := model.find_child("Skeleton3D",true,false) as Skeleton3D
	var player := model.find_child("AnimationPlayer",true,false) as AnimationPlayer
	if not skeleton or not player or not player.has_animation(metadata.action):
		quit(1)
		return
	var clip := player.get_animation(metadata.action)
	clip.loop_mode = Animation.LOOP_LINEAR
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("202730")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("cad5ef")
	env.environment.ambient_light_energy = 0.55
	world.add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45,-30,0)
	light.light_energy = 1.4
	light.shadow_enabled = true
	world.add_child(light)
	var floor_mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(20,0.1,20)
	floor_mesh.mesh = box
	floor_mesh.position.y = -0.05
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("66717e")
	material.roughness = 0.9
	floor_mesh.material_override = material
	world.add_child(floor_mesh)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.15
	world.add_child(camera)
	camera.current = true
	root.content_scale_size = Vector2i(1280,720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
	var frames_per_cycle := roundi(clip.length*30.0)
	var curve: Array = metadata.root_curve_blender_z_up
	var last: Array = curve[-1]
	var velocity := Vector3(float(last[1]),float(last[3]),-float(last[2]))/clip.length
	var positions: Array = []
	var maximum_step := 0.0
	var maximum_seam_step := 0.0
	var previous := Vector3.ZERO
	var hip := skeleton.find_bone("mixamorig_Hips")
	for view in ["front","side"]:
		player.stop()
		player.play(metadata.action,0)
		player.advance(0)
		for frame in frames_per_cycle*4+1:
			if frame > 0: player.advance(1.0/30.0)
			model.position = velocity*float(frame)/30.0
			await process_frame
			var pelvis := skeleton.to_global(skeleton.get_bone_global_pose(hip).origin)
			if view == "front":
				positions.append([pelvis.x,pelvis.y,pelvis.z])
				if frame > 0:
					var step := pelvis.distance_to(previous)
					maximum_step = maxf(maximum_step,step)
					if frame%frames_per_cycle in [0,1,frames_per_cycle-1]: maximum_seam_step = maxf(maximum_seam_step,step)
				previous = pelvis
			camera.position = model.position+(Vector3(0,1.1,-3) if view == "front" else Vector3(3,1.1,0))
			camera.look_at(model.position+Vector3(0,0.9,0),Vector3.UP)
			if DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(output.path_join("%s-%03d.png" % [view,frame]))
	var displacement := Vector3(positions[-1][0],positions[-1][1],positions[-1][2])-Vector3(positions[0][0],positions[0][1],positions[0][2])
	var expected := velocity*clip.length*4
	var error := Vector2(displacement.x-expected.x,displacement.z-expected.z).length()
	var passed := error < 0.01 and maximum_seam_step < 0.1
	var report := {"status":"PASS" if passed else "FAIL","cycles":4,"fps":30,"frames":positions.size(),
		"duration":clip.length,"pelvis_displacement_m":[displacement.x,displacement.y,displacement.z],
		"expected_displacement_m":[expected.x,expected.y,expected.z],"transport_error_m":error,
		"maximum_pelvis_step_m":maximum_step,"maximum_loop_seam_step_m":maximum_seam_step,
		"limits":"Playback in isolated flat review scene; no controller blending, physical-phone performance or artistic approval."}
	var file := FileAccess.open(output.path_join("loop-playback.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("LOOP_PLAYBACK "+JSON.stringify(report))
	quit(0 if passed else 1)

extends SceneTree
## Run in the isolated review project, never publish a candidate into res://Animations.

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("review")

func point(values: Array) -> Vector3:
	return Vector3(float(values[0]), float(values[2]), -float(values[1]))

func review() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 3:
		push_error("Expected candidate GLB, contact sidecar, output directory")
		quit(1)
		return
	if not FileAccess.file_exists(args[1]):
		push_error("Contact sidecar not found; use an absolute filesystem path")
		quit(1)
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(args[1]))
	if not parsed is Dictionary or not parsed.has("positions") or not parsed.has("root_curve_blender_z_up"):
		push_error("Invalid contact sidecar")
		quit(1)
		return
	var metadata: Dictionary = parsed
	var output := args[2]
	DirAccess.make_dir_recursive_absolute(output)
	var world := Node3D.new()
	root.add_child(world)
	var model: Node3D = load(args[0]).instantiate()
	world.add_child(model)
	var skeleton := model.find_child("Skeleton3D", true, false) as Skeleton3D
	var player := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var clip: String = metadata.action
	if not skeleton or not player or not player.has_animation(clip):
		push_error("Candidate rig or clip missing")
		quit(1)
		return
	var animation := player.get_animation(clip)
	var track_details: Array = []
	for track in animation.get_track_count():
		track_details.append({"path":str(animation.track_get_path(track)),"type":animation.track_get_type(track),"keys":animation.track_get_key_count(track),"interpolation":animation.track_get_interpolation_type(track)})
	animation.loop_mode = Animation.LOOP_NONE
	var duration: float = metadata.baked_duration_seconds
	if absf(animation.length-duration) > 0.001:
		failures.append("Imported timing differs from baked timing")
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
	box.size = Vector3(8,0.1,8)
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
	var left := skeleton.find_bone("mixamorig_LeftToeBase")
	var right := skeleton.find_bone("mixamorig_RightToeBase")
	var samples: Array = metadata.positions
	var root_curve: Array = metadata.root_curve_blender_z_up
	var max_error := 0.0
	var max_length_error := 0.0
	var length_errors := {}
	var measurements: Array = []
	var views := {"front":Vector3(0,1.1,-3),"side":Vector3(3,1.1,0),"back":Vector3(0,1.1,3)}
	for view in views:
		for i in samples.size():
			var sample: Dictionary = samples[i]
			var curve: Array = root_curve[i]
			var transport := point([curve[1],curve[2],curve[3]])
			model.position = transport
			player.play(clip,0.0)
			player.seek(float(i)/30.0,true)
			player.pause()
			await process_frame
			var actual := [skeleton.to_global(skeleton.get_bone_global_pose(left).origin),skeleton.to_global(skeleton.get_bone_global_pose(right).origin)]
			var expected := [point(sample.left),point(sample.right)]
			for foot in range(2):
				max_error = maxf(max_error,actual[foot].distance_to(expected[foot]))
			for bone in skeleton.get_bone_count():
				var parent := skeleton.get_bone_parent(bone)
				if parent < 0: continue
				# Pelvis translation relative to the nondeforming root carries weight
				# transfer; it is not a limb length and must remain animated.
				if skeleton.get_bone_name(bone) == "mixamorig_Hips": continue
				var rest_length := skeleton.get_bone_global_rest(bone).origin.distance_to(skeleton.get_bone_global_rest(parent).origin)
				var pose_length := skeleton.get_bone_global_pose(bone).origin.distance_to(skeleton.get_bone_global_pose(parent).origin)
				if rest_length > 0.001:
					var error := absf(pose_length-rest_length)/rest_length
					max_length_error = maxf(max_length_error,error)
					length_errors[skeleton.get_bone_name(bone)] = maxf(float(length_errors.get(skeleton.get_bone_name(bone),0)),error)
			if view == "front":
				measurements.append({"time":float(i)/30.0,"left":[actual[0].x,actual[0].y,actual[0].z],"right":[actual[1].x,actual[1].y,actual[1].z]})
			camera.position = transport+views[view]
			camera.look_at(transport+Vector3(0,0.9,0),Vector3.UP)
			if DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(output.path_join("%s-%03d.png" % [view,i]))
	if max_error > 0.005: failures.append("Imported feet diverge from baked contact targets")
	if max_length_error > 0.005: failures.append("Animated limb lengths changed")
	var result := {"status":"PASS" if failures.is_empty() else "FAIL","candidate":args[0],"duration":animation.length,
		"import_position_error_m":max_error,"limb_length_relative_error":max_length_error,
		"length_errors":length_errors,
		"track_details":track_details,
		"player_import_id":str(player.get_meta("import_id","PATH:"+str(model.get_path_to(player)))),
		"contact_intervals":metadata.contact_intervals,"positions":measurements,"failures":failures,
		"limits":"Joint contacts only; sole skin contact, twists, loop transitions, controller speed and aesthetic acceptance require visual review."}
	var file := FileAccess.open(output.path_join("godot-contact-review.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"\t"))
	file.close()
	print("CONTACT_IMPORT_REVIEW "+JSON.stringify({"status":result.status,"max_error_m":max_error,"length_error":max_length_error,"failures":failures}))
	world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

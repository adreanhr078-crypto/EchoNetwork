extends SceneTree
## Exact baked GLB in an empty project. No AnimationTree, modifiers or root extraction.

func _initialize() -> void:
	call_deferred("verify")

func verify() -> void:
	var args := OS.get_cmdline_user_args()
	if (args.size() != 3 and args.size() != 4) or not FileAccess.file_exists(args[1]):
		push_error("Expected GLB resource, absolute Blender reference, output JSON")
		quit(1)
		return
	var reference: Variant = JSON.parse_string(FileAccess.get_file_as_string(args[1]))
	if not reference is Dictionary or reference.get("status") != "PASS":
		push_error("Blender gate missing or failed")
		quit(1)
		return
	var model: Node3D = load(args[0]).instantiate()
	root.add_child(model)
	var skeleton := model.find_child("Skeleton3D",true,false) as Skeleton3D
	var player := model.find_child("AnimationPlayer",true,false) as AnimationPlayer
	if not skeleton or not player or not player.has_animation(reference.action):
		push_error("Baked skeleton/action missing")
		quit(1)
		return
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	player.root_motion_track = NodePath("")
	var clip := player.get_animation(reference.action)
	clip.loop_mode = Animation.LOOP_NONE
	var tracks: Array = []
	for track in clip.get_track_count():
		tracks.append({"path":str(clip.track_get_path(track)),"keys":clip.track_get_key_count(track),"type":clip.track_get_type(track)})
	var converter := Basis(Vector3(1,0,0),Vector3(0,0,-1),Vector3(0,1,0))
	var errors: Array[String] = []
	var measurements: Array = []
	var max_position := 0.0
	var max_rotation := 0.0
	var bone_indices := {}
	for role in reference.target_bones:
		var name: String = str(reference.target_bones[role]).replace(":","_")
		var index := skeleton.find_bone(name)
		if index < 0:
			errors.append("Mapped bone missing: "+role)
		bone_indices[role] = index
	if absf(clip.length-float(reference.duration)) > 0.0001:
		errors.append("Duration changed on import")
	for sample in reference.samples:
		player.play(reference.action,0.0)
		player.seek(float(sample.time),true)
		player.pause()
		await process_frame
		var frame_errors := {}
		for role in sample.bones:
			var index: int = bone_indices[role]
			if index < 0:
				continue
			var expected: Dictionary = sample.bones[role]
			var p: Array = expected.position
			var q: Array = expected.quaternion_wxyz
			var expected_position := converter * Vector3(float(p[0]),float(p[1]),float(p[2]))
			# Blender exporter appends a joint-axis C, then swizzles by C/C^-1:
			# C * (R * C) * C^-1 = C * R. Mesh/object TRS has another contract.
			var expected_rotation := (converter * Basis(Quaternion(float(q[1]),float(q[2]),float(q[3]),float(q[0])))).get_rotation_quaternion()
			var actual := skeleton.global_transform * skeleton.get_bone_global_pose(index)
			var position_error := actual.origin.distance_to(expected_position)
			var relative := (actual.basis.orthonormalized().get_rotation_quaternion().inverse()*expected_rotation).normalized()
			# atan2 stays accurate for tiny differences where acos(dot) rounds away precision.
			var rotation_error := rad_to_deg(2.0*atan2(Vector3(relative.x,relative.y,relative.z).length(),absf(relative.w)))
			max_position = maxf(max_position,position_error)
			max_rotation = maxf(max_rotation,rotation_error)
			frame_errors[role] = {"position_m":position_error,"rotation_degrees":rotation_error}
		measurements.append({"time":sample.time,"bones":frame_errors})
	if max_position > 0.0001:
		errors.append("Joint position differs from Blender by more than 0.1 mm")
	if max_rotation > 0.1:
		errors.append("Joint rotation differs from Blender by more than 0.1 degree")
	var report := {"status":"PASS" if errors.is_empty() else "FAIL","errors":errors,
		"tracks":tracks,"animation_names":player.get_animation_list(),
		"animation_tree":false,"blending":false,"root_motion_extraction":false,
		"max_position_error_m":max_position,"max_rotation_error_degrees":max_rotation,
		"sample_count":measurements.size(),"measurements":measurements}
	var output := FileAccess.open(args[2],FileAccess.WRITE)
	output.store_string(JSON.stringify(report,"\t")+"\n")
	print("SINGLE_WALK_GODOT "+JSON.stringify({"status":report.status,"errors":errors,"max_position_error_m":max_position,"max_rotation_error_degrees":max_rotation}))
	if args.size() == 4 and args[3] == "--render":
		var env := WorldEnvironment.new()
		env.environment = Environment.new()
		env.environment.background_mode = Environment.BG_COLOR
		env.environment.background_color = Color("202730")
		env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.environment.ambient_light_color = Color("cad5ef")
		env.environment.ambient_light_energy = 0.6
		root.add_child(env)
		var light := DirectionalLight3D.new()
		light.rotation_degrees = Vector3(-40,-30,0)
		light.light_energy = 1.2
		root.add_child(light)
		var camera := Camera3D.new()
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 2.2
		root.add_child(camera)
		camera.current = true
		var hips: int = bone_indices.hips
		for view in ["back","side"]:
			for frame in 37:
				player.play(reference.action,0.0)
				player.seek(float(frame)/30,true)
				player.pause()
				await process_frame
				var center := skeleton.to_global(skeleton.get_bone_global_pose(hips).origin)
				center.y = 0.9
				camera.position = center+(Vector3(0,0,4) if view == "back" else Vector3(4,0,0))
				camera.look_at(center)
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(args[2].get_base_dir()+"/godot-"+view+"-%04d.png" % frame)
	quit(0 if errors.is_empty() else 1)

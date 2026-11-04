extends SceneTree
## Isolated native skin measurement. No source, keys or runtime files are written.
func _initialize() -> void: _run.call_deferred()

func fail(message: String) -> void:
	push_error(message)
	quit(1)

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2 or DisplayServer.get_name() == "headless":
		fail("Expected candidate scene and new profile output with a real renderer")
		return
	if FileAccess.file_exists(args[1]):
		fail("Preserve the prior measured profile; choose a new output")
		return
	var scene := load(args[0]).instantiate() as Node3D
	root.add_child(scene)
	var skeleton := scene.find_child("Skeleton3D", true, false) as Skeleton3D
	var player := scene.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if not skeleton or skeleton.get_bone_count() != 65 or not player or not player.has_animation("Wake_Source_Retarget"):
		fail("Exact qualified School65 Wake required")
		return
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	player.play("Wake_Source_Retarget", 0.0)
	player.pause()
	var meshes: Array[MeshInstance3D] = []
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		if node.skin:
			meshes.append(node)
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.position = Vector3(3, 1.3, -3)
	camera.look_at(Vector3(0, .9, 0))
	camera.make_current()
	for frame in 4: await process_frame
	var offsets: Array[float] = []
	var vertex_count := 0
	for sample in 481:
		player.seek(player.current_animation_length * sample / 480.0, true)
		player.advance(0.0)
		skeleton.force_update_all_bone_transforms()
		await RenderingServer.frame_post_draw
		var minimum := INF
		var count := 0
		for mesh in meshes:
			var baked := mesh.bake_mesh_from_current_skeleton_pose()
			if not baked:
				fail("Current renderer did not register the imported skin")
				return
			for surface in baked.get_surface_count():
				var vertices: PackedVector3Array = baked.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
				count += vertices.size()
				for vertex in vertices:
					minimum = minf(minimum, (mesh.global_transform * vertex).y)
		if not is_finite(minimum) or count < 1000:
			fail("Empty or nonfinite deformed skin")
			return
		vertex_count = count
		offsets.append(-minimum)
		if sample % 120 == 0: print("WAKE_SKIN_SAMPLE ", sample, " minimum=", minimum)
	var hips := skeleton.find_bone("mixamorig_Hips")
	var final_delta := skeleton.global_basis * (skeleton.get_bone_global_pose(hips).origin - skeleton.get_bone_global_rest(hips).origin)
	var report := {"status":"MEASURED_NATIVE_SKIN_PROFILE", "source_glb_sha256":FileAccess.get_sha256(args[0]),
		"action":"Wake_Source_Retarget", "duration":player.current_animation_length,
		"samples":offsets.size(), "vertices_per_sample":vertex_count, "offsets":offsets,
		"fixed_anchor_xz":[-final_delta.x, -final_delta.z],
		"renderer":RenderingServer.get_current_rendering_method(), "source_keys_changed":false,
		"scope":"481 actual renderer-baked skin minima. Fixed whole-clip XZ anchor; no root curve fit. Independent staggered contact/hand support and runtime transition gates remain open."}
	var file := FileAccess.open(args[1], FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	scene.queue_free()
	camera.queue_free()
	await process_frame
	print("WAKE_SKIN_PROFILE PASS samples=", offsets.size(), " vertices=", vertex_count)
	quit(0)

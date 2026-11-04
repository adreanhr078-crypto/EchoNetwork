extends SceneTree
## Actual candidate player/skin and recovery lifecycle; no save or authority mutation.
var checks := 0
var failures: Array[String] = []
var completed := 0
var captures: Array[String] = []
var folder: String

func _initialize() -> void: _run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
	print("PASS " if ok else "FAIL ", label)

func spawn_school() -> EchoPlayer:
	var actor := load("res://scenes/player/echo_player.tscn").instantiate() as EchoPlayer
	actor.avatar_scene_override = load("res://scenes/characters/echo_school_candidate.tscn")
	root.add_child(actor)
	return actor

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var path := folder.path_join(label+".png")
	root.get_texture().get_image().save_png(path)
	captures.append(path)

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	folder = args[0] if not args.is_empty() else ProjectSettings.globalize_path("res://../audits/evidence/character-school-20261102/wake-native")
	if args.size() > 1: Engine.physics_ticks_per_second = int(args[1])
	DirAccess.make_dir_recursive_absolute(folder)
	root.size = Vector2i(960,540)
	var floor_body := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20,.2,20)
	collider.shape = box
	floor_body.position.y = -.1
	floor_body.add_child(collider)
	var floor_mesh := MeshInstance3D.new()
	var floor_box := BoxMesh.new()
	floor_box.size = box.size
	floor_mesh.mesh = floor_box
	var shader := Shader.new()
	shader.code = "shader_type spatial;void fragment(){ALBEDO=vec3(0.14,0.17,0.20);ROUGHNESS=0.8;}"
	var material := ShaderMaterial.new()
	material.shader = shader
	floor_mesh.material_override = material
	floor_body.add_child(floor_mesh)
	root.add_child(floor_body)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-40,-30,0)
	root.add_child(key)
	var player := spawn_school()
	player.opening_recovery_completed.connect(func(): completed += 1)
	await process_frame
	await physics_frame
	check(player.opening_recovery_active and player.current_anim == "preset_wakeup", "Natural startup selects qualified Wake rather than fallback")
	check(not player.combat_available and not player.contract_with_zero_sealed, "Recovery grants no pact or combat")
	var mixer := player.animation_player
	var clip := mixer.get_animation("preset_wakeup")
	check(clip.get_meta("source_native_fps") == 24 and clip.get_meta("source_native_samples") == 120, "Original24Hz/120samples retained in actual player")
	check(clip.get_track_count() == 195, "Constant supporting-hand tracks retained alongside moving tracks")
	var clock := mixer.current_animation_position
	var position := player.visual_root.position
	paused = true
	for frame in 8: await process_frame
	check(mixer.current_animation_position == clock and player.visual_root.position == position and completed == 0, "Pause freezes source clock, grounding and completion")
	paused = false
	mixer.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var skeleton := player.find_child("Skeleton3D",true,false) as Skeleton3D
	var body := player.find_child("EchoSchoolBody",true,false) as MeshInstance3D
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.fov = 43
	camera.position = Vector3(3,1.5,3)
	camera.look_at(Vector3(0,.75,0))
	camera.make_current()
	var maximum_ground_error := 0.0
	var maximum_cpu_skin_error := 0.0
	var measured: Array = []
	var support_error := 0.0
	var support_samples := 0
	# Exercise the immutable hand tracks after another clip has posed the fingers.
	mixer.play("IDLE",0.0)
	mixer.seek(.7,true)
	mixer.advance(0.0)
	var hand_indices: Dictionary = {"left":[],"right":[]}
	var original_arrays := body.mesh.surface_get_arrays(0)
	var original_vertices: PackedVector3Array = original_arrays[Mesh.ARRAY_VERTEX]
	var original_bones: PackedInt32Array = original_arrays[Mesh.ARRAY_BONES]
	var original_weights: PackedFloat32Array = original_arrays[Mesh.ARRAY_WEIGHTS]
	var influence_count := original_bones.size()/original_vertices.size()
	var bind_names: Array[String] = []
	for bind in body.skin.get_bind_count():
		var bone := body.skin.get_bind_bone(bind)
		bind_names.append(skeleton.get_bone_name(bone) if bone >= 0 else str(body.skin.get_bind_name(bind)))
	for vertex in original_vertices.size():
		for side: String in ["left","right"]:
			var weight := 0.0
			var prefix := "mixamorig_"+side.capitalize()+"Hand"
			for influence in influence_count:
				var index := vertex*influence_count+influence
				if bind_names[original_bones[index]].begins_with(prefix): weight += original_weights[index]
			if weight > .5: hand_indices[side].append(vertex)
	if DisplayServer.get_name() != "headless":
		for sample in 137:
			# Different sample phases from the481 profile knots, including both ends.
			var phase := clampf((sample+.37)/137.0,0.0,.99999)
			mixer.play("preset_wakeup",0.0)
			mixer.seek(clip.length*phase,true)
			mixer.advance(0.0)
			player._align_recovery_feet_to_floor()
			skeleton.force_update_all_bone_transforms()
			await RenderingServer.frame_post_draw
			var baked := body.bake_mesh_from_current_skeleton_pose()
			if not baked:
				check(false,"Renderer did not bake the actual player skin")
				break
			var minimum := INF
			for surface in baked.get_surface_count():
				var vertices: PackedVector3Array = baked.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
				for vertex in vertices: minimum = minf(minimum,(body.global_transform*vertex).y)
				if surface == 0 and phase > .32 and phase < .41:
					var support := INF
					for side: String in ["left","right"]:
						var hand_min := INF
						for index: int in hand_indices[side]: hand_min = minf(hand_min,(body.global_transform*vertices[index]).y)
						support = minf(support,absf(hand_min))
					support_error = maxf(support_error,support)
					support_samples += 1
				if sample % 17 == 0:
					var original := body.mesh.surface_get_arrays(surface)
					var rest: PackedVector3Array = original[Mesh.ARRAY_VERTEX]
					var bones: PackedInt32Array = original[Mesh.ARRAY_BONES]
					var weights: PackedFloat32Array = original[Mesh.ARRAY_WEIGHTS]
					var influences := bones.size()/rest.size()
					var transforms: Array[Transform3D] = []
					for bind in body.skin.get_bind_count():
						var bone := body.skin.get_bind_bone(bind)
						if bone < 0: bone = skeleton.find_bone(body.skin.get_bind_name(bind))
						transforms.append(skeleton.get_bone_global_pose(bone)*body.skin.get_bind_pose(bind))
					for vertex in range(0,rest.size(),maxi(1,rest.size()/512)):
						var skinned := Vector3.ZERO
						for influence in influences:
							var index := vertex*influences+influence
							if weights[index] > 0: skinned += (transforms[bones[index]]*rest[vertex])*weights[index]
						var expected := skeleton.global_transform*skinned
						maximum_cpu_skin_error = maxf(maximum_cpu_skin_error,expected.distance_to(body.global_transform*vertices[vertex]))
			maximum_ground_error = maxf(maximum_ground_error,absf(minimum))
			measured.append({"phase":phase,"skin_min_y":minimum})
			if sample % 27 == 0: await capture("skin-%03d"%sample)
		check(measured.size() == 137 and maximum_ground_error < .008,"137 staggered actual skin samples stay within8mm of the floor")
		check(maximum_cpu_skin_error < .0002,"Independent CPU skin agrees with renderer-baked player vertices")
		# This interval is retained as research, not asserted as authored support:
		# measured reach/actual poses prove it includes hand release.
		if args.has("--require-hand-support"):
			check(support_samples > 8 and support_error < .02,"Research-only late hand-floor assertion; support intent must be qualified first")
	var adapter := player.get_node("ModelRoot/EchoOpeningUniform")
	var first: Vector3 = adapter.opening_contact_alignment(0)
	var last: Vector3 = adapter.opening_contact_alignment(1)
	check(Vector2(first.x,first.z).is_equal_approx(Vector2(last.x,last.z)), "One fixed horizontal anchor preserves the authored recovery path")
	player.finish_opening_recovery()
	player.finish_opening_recovery()
	check(completed == 1 and not player.opening_recovery_active and player.visual_root.position.is_zero_approx(), "Repeated skip completes once and releases the entire grounding offset")
	check(player.current_anim == "IDLE", "Skip returns to qualified Idle")
	player.queue_free()
	await process_frame
	var natural := spawn_school()
	natural.opening_recovery_completed.connect(func(): completed += 1)
	var natural_ground_error := 0.0
	var natural_samples := 0
	for frame in int((clip.length+1.0)*Engine.physics_ticks_per_second):
		await physics_frame
		if DisplayServer.get_name() != "headless" and natural.opening_recovery_active and frame % 12 == 0:
			await RenderingServer.frame_post_draw
			var natural_body := natural.find_child("EchoSchoolBody",true,false) as MeshInstance3D
			var natural_baked := natural_body.bake_mesh_from_current_skeleton_pose()
			var minimum := INF
			for surface in natural_baked.get_surface_count():
				var vertices: PackedVector3Array = natural_baked.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
				for vertex in vertices: minimum = minf(minimum,(natural_body.global_transform*vertex).y)
			natural_ground_error = maxf(natural_ground_error,absf(minimum))
			natural_samples += 1
	if DisplayServer.get_name() != "headless": check(natural_samples > 8 and natural_ground_error < .008,"Natural physics playback grounds the current skin sample without a frame of lag")
	check(not natural.opening_recovery_active and natural.current_anim == "IDLE" and completed == 2, "Full natural source completes once and returns control")
	check(natural.visual_root.position.is_zero_approx() and not natural.combat_available, "Natural completion clears offsets and keeps human state")
	await capture("natural-finished")
	natural.queue_free()
	await process_frame
	var skipped := spawn_school()
	skipped.opening_recovery_completed.connect(func(): completed += 1)
	skipped.finish_opening_recovery()
	for frame in 4: await process_frame
	check(completed == 3 and not skipped.opening_recovery_active and skipped.current_anim == "IDLE", "Skip before deferred startup cannot restart Wake")
	skipped.queue_free()
	await process_frame
	var unloaded := spawn_school()
	unloaded.opening_recovery_completed.connect(func(): completed += 1)
	await process_frame
	unloaded.queue_free()
	for frame in 4: await process_frame
	check(completed == 3, "Unloading a recovering actor emits no completion")
	camera.queue_free()
	var report := {"status":"PASS" if failures.is_empty() else "FAIL","checks":checks,"failures":failures,
		"physics_hz":Engine.physics_ticks_per_second,"maximum_ground_error_m":maximum_ground_error,
		"maximum_cpu_renderer_skin_error_m":maximum_cpu_skin_error,"measurements":measured,"captures":captures,
		"maximum_supporting_palm_gap_m":support_error,"support_samples":support_samples,"source_hashes":{},
		"hand_floor_status":"UNVERIFIED_AUTHORED_SUPPORT_INTENT;late release gap retained,not counted as a hand-contact PASS",
		"natural_ground_error_m":natural_ground_error,"natural_skin_samples":natural_samples,
		"renderer":RenderingServer.get_current_rendering_method(),"skin_reviewed":DisplayServer.get_name()!="headless",
		"scope":"Actual School65 controller/skin grounding and natural/pause/skip/deferred/unload lifecycle. Connected scene/save/camera and artistic acceptance remain separate."}
	for path in ["scripts/player/echo_player.gd","scripts/player/echo_school_motion_adapter.gd","assets/characters/echo_school65_candidate.glb","assets/animations/school65/wake_qualified.res","tests/school_wake_review.gd"]:
		report.source_hashes[path] = FileAccess.get_sha256("res://"+path)
	var file := FileAccess.open(folder.path_join("review.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("SCHOOL_WAKE_REVIEW ",JSON.stringify({"checks":checks,"failures":failures,"ground":maximum_ground_error,"cpu_skin":maximum_cpu_skin_error}))
	quit(0 if failures.is_empty() else 1)

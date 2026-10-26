extends SceneTree

var actor: EchoPlayer
var skeleton: Skeleton3D
var camera: Camera3D
var folder: String
var samples: Array = []
var completions := 0
var checks := 0
var native_frames := 0
var saw_stand := false
var maximum_body_step := 0.0
var maximum_hip_step := 0.0
var previous_body := Vector3.ZERO
var previous_hips := Vector3.ZERO
var observing := false
var cape: Node
var protected_body_unchanged := true
var static_pose_deterministic := true
var minimum_cape_leg_clearance := INF
var worst_cape_contact := {}
var captures: Array = []
var minimum_cape_floor_clearance := INF

class PhysicsSampler:
	extends Node
	var sample: Callable
	func _physics_process(_delta: float) -> void: sample.call()

func _initialize() -> void: _run.call_deferred()

func _check(ok: bool, message: String) -> bool:
	checks += 1
	if not ok:
		push_error(message)
		quit(1)
	return ok

func _steps(count: int) -> void:
	for frame in count:
		await physics_frame
		await process_frame

func _joint(name: String) -> Vector3:
	return skeleton.to_global(skeleton.get_bone_global_pose(skeleton.find_bone(name)).origin)

func _capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	var center := _joint("Hips") - Vector3.UP * 0.08
	camera.position = center + Vector3(2.8, 0.3, 0.8)
	camera.look_at(center)
	camera.fov = 44
	await RenderingServer.frame_post_draw
	var path := folder.path_join(label + ".png")
	root.get_texture().get_image().save_png(path)
	captures.append({"path": path, "sha256": FileAccess.get_sha256(path), "physics_frame": Engine.get_physics_frames(), "native_clock": actor.surface_motor._mantle_elapsed})

func _sample_physics() -> void:
	if not observing: return
	var motor = actor.surface_motor
	if motor.native_mantle_active:
		var before: Array[Transform3D] = []
		for bone in skeleton.get_bone_count(): before.append(skeleton.get_bone_pose(bone))
		cape._process_modification_with_delta(0.0)
		var first: Array[Transform3D] = []
		for bone in skeleton.get_bone_count(): first.append(skeleton.get_bone_pose(bone))
		cape._process_modification_with_delta(0.0)
		for bone in skeleton.get_bone_count():
			if skeleton.get_bone_name(bone).begins_with("Cape_"):
				static_pose_deterministic = static_pose_deterministic and first[bone].is_equal_approx(skeleton.get_bone_pose(bone))
			else:
				protected_body_unchanged = protected_body_unchanged and before[bone].is_equal_approx(skeleton.get_bone_pose(bone))
		for column in 5:
			for row in 3:
				var tip: Vector3 = cape._support_tip(skeleton, column, row)
				var tip_world := skeleton.to_global(tip)
				var ray_start := Vector3(tip_world.x, maxf(_joint("Hips").y + 0.5, tip_world.y + 0.3), tip_world.z)
				var query := PhysicsRayQueryParameters3D.create(ray_start, tip_world - Vector3.UP * 0.1, actor.collision_mask, [actor.get_rid()])
				var floor_hit := actor.get_world_3d().direct_space_state.intersect_ray(query)
				if not floor_hit.is_empty() and floor_hit.normal.y > 0.8:
					minimum_cape_floor_clearance = minf(minimum_cape_floor_clearance, tip_world.y - floor_hit.position.y)
				for leg in cape._legs:
					for segment in 2:
						var start := skeleton.get_bone_global_pose(leg[segment]).origin
						var finish := skeleton.get_bone_global_pose(leg[segment + 1]).origin
						var near := Geometry3D.get_closest_point_to_segment(tip, start, finish)
						var clearance := (tip.distance_to(near) - start.distance_to(finish) * 0.26) * skeleton.global_basis.x.length()
						if clearance < minimum_cape_leg_clearance:
							minimum_cape_leg_clearance = clearance
							worst_cape_contact = {"clock": motor._mantle_elapsed, "column": column, "row": row, "leg": skeleton.get_bone_name(leg[0]), "segment": segment, "tip": skeleton.to_global(tip), "nearest_leg": skeleton.to_global(near)}
	maximum_body_step = maxf(maximum_body_step, actor.global_position.distance_to(previous_body))
	maximum_hip_step = maxf(maximum_hip_step, _joint("Hips").distance_to(previous_hips))
	previous_body = actor.global_position
	previous_hips = _joint("Hips")
	var joints := {}
	for name in ["Hips", "Head", "LeftHand", "RightHand", "LeftFoot", "RightFoot", "Cape_2_0", "Cape_2_1", "Cape_2_2"]: joints[name] = _joint(name)
	samples.append({"physics_frame": Engine.get_physics_frames(), "native": motor.native_mantle_active, "clock": motor._mantle_elapsed, "clip": actor.animation_player.current_animation, "capsule": actor.global_position, "joints": joints})
	if motor.native_mantle_active:
		native_frames += 1
		saw_stand = saw_stand or actor.animation_player.current_animation == "PARKOUR_STAND"

func _run() -> void:
	root.unfocusable = true
	root.size = Vector2i(1280, 720)
	AudioServer.set_bus_mute(0, true)
	var args := OS.get_cmdline_user_args()
	folder = args[0] if not args.is_empty() else ProjectSettings.globalize_path("res://../audits/evidence/chapter-cp45-20261020/stage07/native-mantle/")
	DirAccess.make_dir_recursive_absolute(folder)
	var world := Node3D.new()
	root.add_child(world)
	world.add_child(load("res://scenes/environment/maintenance_vertical.tscn").instantiate())
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("171f2d")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("c7d5e5")
	environment.environment.ambient_light_energy = 0.65
	world.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, -35, 0)
	light.light_energy = 1.5
	world.add_child(light)
	actor = load("res://scenes/player/echo_player.tscn").instantiate()
	actor.position = Vector3(0, 0.1, -5.1)
	world.add_child(actor)
	actor.finish_opening_recovery()
	root.get_node("HyperAnimeWorldManager").attach_scene(world, actor)
	root.get_node("HyperAnimeWorldManager").set_quality("low")
	actor.set_gameplay_orbit(Vector3.ZERO)
	skeleton = actor.find_child("Skeleton3D", true, false)
	cape = actor.find_child("EchoCapeMotion", true, false)
	var sampler := PhysicsSampler.new()
	sampler.process_physics_priority = 1000
	sampler.sample = _sample_physics
	world.add_child(sampler)
	actor.surface_motor.mantle_completed.connect(func(): completions += 1)
	camera = Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(3.9, 3.5, -4.9)
	camera.look_at(Vector3(0, 3.25, -5.9))
	camera.fov = 52
	camera.current = true
	await _steps(12)
	if not _check(actor.animation_player.has_animation("PARKOUR_MANTLE") and actor.animation_player.has_animation("PARKOUR_STAND"), "Qualified native clips unavailable"): return
	actor.set_mobile_input_vector(Vector2(0, -1), true)
	actor.request_jump()
	for frame in 180:
		await _steps(1)
		if actor.surface_motor.hanging: break
	if not _check(actor.surface_motor.hanging, "Public jump did not catch the actual Room02 ledge"): return
	actor.set_mobile_input_vector(Vector2.ZERO, false)
	await _steps(4)
	await _capture("hang")
	previous_body = actor.global_position
	previous_hips = _joint("Hips")
	observing = true
	actor.request_jump()
	var paused_phases: Array[int] = []
	var next_capture := 1
	for frame in 150:
		await _steps(1)
		var motor = actor.surface_motor
		if motor.native_mantle_active:
			if native_frames >= next_capture:
				await _capture("native-%03d" % native_frames)
				next_capture += 8
			var phase: int = motor._native_phase
			if motor._mantle_elapsed > 0.3 and phase not in paused_phases:
				var clock_before: float = motor._mantle_elapsed
				var position_before := actor.global_position
				var hips_before := _joint("Hips")
				paused = true
				for unused in 8: await process_frame
				paused = false
				if not _check(motor._mantle_elapsed == clock_before and actor.global_position == position_before and _joint("Hips").distance_to(hips_before) < 0.0001, "Pause advanced native traversal/visible pose"): return
				paused_phases.append(phase)
		elif native_frames > 0: break
	for frame in 20:
		await _steps(1)
	observing = false
	await _capture("standing")
	var report := {"scope": "Actual Room02/current V31/public-input native mantle; final art and chapter acceptance separate", "checks": checks, "native_frames": native_frames, "saw_stand": saw_stand, "completions": completions, "maximum_body_step_m": maximum_body_step, "maximum_hip_step_m": maximum_hip_step, "protected_body_unchanged": protected_body_unchanged, "static_pose_deterministic": static_pose_deterministic, "minimum_cape_leg_clearance_m": minimum_cape_leg_clearance, "landing": actor.global_position, "samples": samples, "source_hashes": {}}
	for path in ["scenes/environment/maintenance_vertical.tscn", "tests/v31_native_mantle_review.gd", "assets/characters/echo_v31_adopted_high.glb", "scripts/player/surface_traversal_motor.gd", "scripts/player/echo_v31_motion_adapter.gd", "engine_visuals/EchoCapeMotion.gd", "assets/animations/v31/mantle_cp45.res", "assets/animations/v31/stand_cp45.res"]: report.source_hashes[path] = FileAccess.get_sha256("res://" + path)
	report["captures"] = captures
	report["minimum_cape_floor_clearance_m"] = minimum_cape_floor_clearance
	var file := FileAccess.open(folder.path_join("review.json"), FileAccess.WRITE)
	report["worst_cape_contact"] = worst_cape_contact
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	if not _check(native_frames >= 95 and saw_stand and completions == 1, "Native source clock/standing phase/completion not preserved"): return
	if not _check(maximum_body_step < 0.12 and maximum_hip_step < 0.08, "Capsule or visible hips teleported during native handoff"): return
	if not _check(actor.is_on_floor() and actor.position.y > 3.3 and not actor.surface_motor.native_mantle_active and actor.animation_player.speed_scale == 1.0, "Native mantle did not return grounded control/playback"): return
	if not _check(not actor.combat_available and not actor.contract_with_zero_sealed, "Human mantle granted a story power"): return
	if not _check(protected_body_unchanged and static_pose_deterministic, "Static garment solver changed a body joint or accumulated pose"): return
	if not _check(minimum_cape_leg_clearance >= -0.002, "Static garment tips intersect measured leg capsules"): return
	if not _check(minimum_cape_floor_clearance >= -0.002, "Static garment tips intersect actual platform geometry"): return
	report["status"] = "PASS"
	report["checks"] = checks
	file = FileAccess.open(folder.path_join("review.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("NATIVE_MANTLE PASS checks=", checks, " frames=", native_frames, " hip_step=", maximum_hip_step, " body_step=", maximum_body_step)
	world.queue_free()
	await _steps(3)
	quit(0)

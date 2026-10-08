extends SceneTree

## Route review with the real avatar, physics and public mobile input.
## Initial fixture spawn is the only position assignment during traversal.
var player: EchoPlayer
var room: Node3D
var failed := false
var review_kind := ""
var shot := 0
var review_main:Node
var focus_interruptions:=0

func _resume_capture_driver() -> void:
	# Runtime capture uses virtual input. Resume through the real pause UI after
	# tooling changes desktop focus; never disable the product's focus safety.
	if paused and is_instance_valid(review_main):
		focus_interruptions+=1
		review_main.native_pause_menu.resume_button.pressed.emit()
		print("CAPTURE driver resumed through actual pause UI; focus interruptions=",focus_interruptions)

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var kind := args[0] if not args.is_empty() else "mirror"
	review_kind = kind
	root.size = Vector2i(960,540)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.014,0.019,0.028)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.34,0.43,0.6)
	env.environment.ambient_light_energy = 0.72
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	if kind!="hospital": root.add_child(env)
	else: env.free()
	var files := {"mirror":"mirror_chamber_room", "decon":"decontamination_quarantine_wing", "archive":"memory_archive_wing", "reactor":"core_reactor_room", "hospital":"hospital_bedside_room"}
	room = load("res://scenes/environment/" + files[kind] + ".tscn").instantiate()
	room.position = Vector3(23,6,-48)
	room.reduced_motion = true
	root.add_child(room)
	player = load("res://scenes/player/echo_player.tscn").instantiate()
	player.position = room.to_global(room.SAFE_ANCHOR_BEDSIDE+Vector3.UP*0.1 if kind=="hospital" else (Vector3(0,-3.9,-2.5) if kind == "reactor" else (Vector3(-1.7,0.1,0) if kind == "archive" else Vector3(0,0.1,-2))))
	root.add_child(player)
	player.finish_opening_recovery()
	player.set_gameplay_orbit(Vector3.ZERO)
	room.player = player
	if kind == "reactor":
		room.hazard_triggered.connect(func(id: String): print("DISCHARGE ",id," phase=",room.hazard_phase_timer," player=",room.to_local(player.global_position)))
		room.retry_requested.connect(func(anchor: Vector3): print("RETRY from ",room.to_local(player.global_position), " to ",anchor))
	for i in range(15): await physics_frame
	await _capture()
	match kind:
		"hospital":
			room.wake_up_from_bed()
			for point in [Vector3(1.6,0,1.18),Vector3(1.6,0,-1)]:
				if not await _walk(point): return
			player.face_world_direction(room.get_node("VanityMirrorStation").global_position-player.global_position)
			player.set_gameplay_orbit(Vector3(0.04,-PI/2,0))
			for i in 30: await physics_frame
			await _capture()
			if DisplayServer.get_name()!="headless":
				await RenderingServer.frame_post_draw
				room.get_node("WardMirrorReflection").reflection.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../audits/evidence/quality-repair-20261006/room-routes/hospital/reflection.png"))
			if not _use("VanityMirrorStation"): return
		"mirror":
			if args.has("--reflection"):
				if not await _walk(Vector3(6.7,0,-9)): return
				player.set_gameplay_orbit(Vector3(0.04,-PI/2,0))
				for i in range(40): await physics_frame
				await _capture()
				var mirror = room.find_child("ActualReflection",true,false).get_parent()
				var p = mirror.camera.unproject_position(player.global_position+Vector3.UP)
				print("Reflection avatar pixel=",p," camera=",mirror.camera.global_transform," projection=",mirror.camera.size," offset=",mirror.camera.frustum_offset)
				var path := ProjectSettings.globalize_path("res://../audits/evidence/quality-repair-20261006/room-routes/mirror/reflection.png")
				mirror.reflection.get_texture().get_image().save_png(path)
				print("CAPTURED mirror reflection for visual review")
				quit(0)
				return
			for point in [Vector3(7.2,0,-2),Vector3(7.2,0,-14),Vector3(8,0,-14),Vector3(8,0,-16.6),Vector3(3.5,2.4,-16.6),Vector3(1.5,2.4,-18)]:
				if not await _walk(point): return
			if not _use("MasterSecurityTerminal"): return
		"decon":
			for point in [Vector3(-8.5,0,-2),Vector3(-8.5,0,-9),Vector3(-8.5,3.2,-15.5),Vector3(-2,3.2,-16)]:
				if not await _walk(point): return
			if not _use("QuarantineOverrideTerminal"): return
		"archive":
			for point in [Vector3(-1.7,0,-3.2),Vector3(-6,0,-3.2),Vector3(-6,0,4.1),Vector3(-6,0,2.5),Vector3(-16,0,2.5),Vector3(-16,0,-4.1),Vector3(-20,0,-3),Vector3(-20,0,9),Vector3(-3.8,0,9),Vector3(-3.8,3.6,0.5),Vector3(-11,3.6,0)]:
				if not await _walk(point): return
			if not _check(room.collected_shards.size() == 3, "Three shards must be physically reachable"): return
		"reactor":
			for point in [Vector3(0,-4,-5.5),Vector3(0,-4,-7),Vector3(-3,-3.45,-8.42)]:
				if not await _walk(point): return
			await _safe_hazard(false)
			for point in [Vector3(-9.2,-2,-11),Vector3(-11,-2,-12.3),Vector3(-11,-2,-16)]:
				if not await _walk(point): return
			if not _use("BreakerAConsole"): return
			for point in [Vector3(-11,-2,-14.8),Vector3(-8.5,-2,-14.8)]:
				if not await _walk(point): return
			await _safe_hazard(false)
			for point in [Vector3(0,-2,-14.8),Vector3(11,-2,-14.8),Vector3(11,-2,-17.5)]:
				if not await _walk(point): return
			await _safe_hazard(true)
			for point in [Vector3(11,-2,-24.2),Vector3(11,-2,-28)]:
				if not await _walk(point): return
			if not _use("BreakerBConsole"): return
			for i in range(5): await physics_frame
			for point in [Vector3(11,-2,-30.1),Vector3(11,0.2,-35.8),Vector3(0,0.2,-35.8),Vector3(0,0,-40),Vector3(0,0,-43)]:
				if not await _walk(point): return
			if not _check(room.gate_open, "Both physical breakers must open reactor exit"): return
	print("PASS actual room input route: ",kind," endpoint=",room.to_local(player.global_position))
	player.queue_free()
	room.queue_free()
	await process_frame
	quit(0)

func _walk(local: Vector3) -> bool:
	if room.has_signal("hazard_triggered"): print("WALK ",local," from ",room.to_local(player.global_position))
	var target := room.to_global(local)
	for i in range(1000):
		_resume_capture_driver()
		var offset := target - player.global_position
		offset.y = 0
		if offset.length() < 0.18:
			player.set_mobile_input_vector(Vector2.ZERO, false)
			for j in range(8): await physics_frame
			await _capture()
			return _check(player.is_on_floor() and absf(player.global_position.y - target.y) < 0.35, "Unreachable vertical support: %s actual=%s" % [local,room.to_local(player.global_position)])
		var forward:Vector3=-player.player_camera.global_basis.z
		var right:Vector3=player.player_camera.global_basis.x
		forward.y=0.0
		right.y=0.0
		var stick:=Vector2(offset.dot(right.normalized()),-offset.dot(forward.normalized())).normalized()
		player.set_mobile_input_vector(stick * (1.0 if offset.length() > 1.0 else 0.65), true)
		await physics_frame
	return _check(false, "Blocked movement to %s from %s" % [local,room.to_local(player.global_position)])

func _use(name: String) -> bool:
	var target := room.get_node(name)
	if not _check(player.get_nearest_interactable() == target, "Physical terminal not available: " + name): return false
	var result := player.interact_with_nearest()
	return _check(result.get("success", result.get("accepted",false)), "Physical terminal rejected: " + name)

func _check(ok: bool, message: String) -> bool:
	if not ok:
		player.set_mobile_input_vector(Vector2.ZERO,false)
		push_error(message)
		quit(1)
	return ok

func _capture() -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var folder := ProjectSettings.globalize_path("res://../audits/evidence/quality-repair-20261006/room-routes/" + review_kind + "/")
	DirAccess.make_dir_recursive_absolute(folder)
	root.get_texture().get_image().save_png(folder + "%03d.png" % shot)
	shot += 1

func _safe_hazard(second: bool) -> void:
	for i in range(300):
		_resume_capture_driver()
		var phase: float = fmod(room.hazard_phase_timer + (room.CYCLE_TIME * 0.5 if second else 0.0), room.CYCLE_TIME)
		if phase > room.TELEGRAPH_TIME + room.DISCHARGE_TIME + 0.08 and phase < room.TELEGRAPH_TIME + room.DISCHARGE_TIME + 0.3: return
		await physics_frame

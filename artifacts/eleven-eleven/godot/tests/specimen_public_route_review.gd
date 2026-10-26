extends SceneTree

var room: Node3D
var player: EchoPlayer
var retries: Array = []
var samples: Array = []
var folder := ""
var failed := false
var segment := ""

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_watchdog.call_deferred()
	var args := OS.get_cmdline_user_args()
	var phase := float(args[0]) if not args.is_empty() else 3.4
	var diagonal := args.has("--diagonal")
	var direct := args.has("--direct")
	folder = ProjectSettings.globalize_path("res://../audits/evidence/chapter-cp45-20261020/stage08/specimen-route/phase-" + str(phase) + ("-direct" if direct else ("-diagonal" if diagonal else "")) + "/")
	DirAccess.make_dir_recursive_absolute(folder)
	room = load("res://scenes/environment/specimen_containment_wing.tscn").instantiate()
	root.add_child(room)
	player = load("res://scenes/player/echo_player.tscn").instantiate()
	player.position = Vector3(-2.5, .05, 2)
	root.add_child(player)
	player.finish_opening_recovery()
	player.set_process_unhandled_input(false)
	player.set_gameplay_orbit(Vector3.ZERO)
	room.player = player
	room.audio_muted = true
	room.reduced_motion = args.has("--reduced")
	room.retry_requested.connect(func(anchor: Vector3): retries.append({"position": str(player.position), "phase": room._scanner_sweep_angle, "anchor": str(anchor)}))
	for frame in 20: await physics_frame
	for point: Vector3 in [Vector3(-2.5,0,3), Vector3(-13,0,3)]:
		if not await _walk(point): failed = true
	await _window(phase)
	var crossing: Array = [Vector3(-24.65,0,-4.5), Vector3(-24.65,0,-6)] if diagonal else [Vector3(-23,0,3), Vector3(-24.65,0,-6)]
	if direct: crossing = [Vector3(-24.65,0,-6)]
	for point: Vector3 in crossing:
		if not await _walk(point): failed = true
	await _window(.6)
	if not await _walk(Vector3(-26,0,-10.4)): failed = true
	var file := FileAccess.open(folder + "review.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"phase": phase, "reduced_motion": room.reduced_motion, "retries": retries, "samples": samples, "failed": failed, "source_hashes": {"test": FileAccess.get_sha256("res://tests/specimen_public_route_review.gd"), "room": FileAccess.get_sha256("res://scripts/environment/specimen_containment_wing.gd"), "player": FileAccess.get_sha256("res://scripts/player/echo_player.gd")}, "scope": "Isolated actual player/public movement; no scanner mutation or campaign acceptance"}, "\t"))
	file.close()
	print("SPECIMEN_PUBLIC_ROUTE retries=", retries, " movement_failed=", failed)
	player.queue_free()
	room.queue_free()
	for frame in 4: await process_frame
	quit(1 if failed or not retries.is_empty() else 0)

func _sample() -> void:
	var query := PhysicsRayQueryParameters3D.create(room._scanner_head.global_position, player.global_position + Vector3.UP * .9)
	query.exclude = [player.get_rid()]
	var hit := room.get_world_3d().direct_space_state.intersect_ray(query)
	samples.append({"position": [player.position.x, player.position.y, player.position.z], "phase": fposmod(room._scanner_sweep_angle, TAU), "seen": room._scanner_sees(player), "exposure": room._alert_timer, "line_of_sight": hit.is_empty() or hit.collider == player, "segment": segment})

func _watchdog() -> void:
	await create_timer(45).timeout
	push_error("Specimen public route exceeded its bounded diagnostic window")
	quit(2)

func _window(begin: float) -> void:
	segment = "window-" + str(begin)
	for frame in 380:
		_sample()
		var phase: float = fposmod(room._scanner_sweep_angle, TAU)
		if phase > begin and phase < begin + .06: return
		await physics_frame
	failed = true

func _walk(target: Vector3) -> bool:
	segment = str(target)
	for frame in 600:
		_sample()
		var offset := target - player.position
		offset.y = 0
		if offset.length() < .22:
			player.set_mobile_input_vector(Vector2.ZERO, false)
			for settle in 8: await physics_frame
			print("SPECIMEN_WAYPOINT ", target, " phase=", fposmod(room._scanner_sweep_angle, TAU))
			return player.is_on_floor()
		var forward := -player.player_camera.global_basis.z
		var right := player.player_camera.global_basis.x
		forward.y = 0
		right.y = 0
		var stick := Vector2(offset.dot(right.normalized()), -offset.dot(forward.normalized())).normalized()
		player.set_mobile_input_vector(stick * (1.0 if offset.length() > 1 else .65), true)
		await physics_frame
	return false

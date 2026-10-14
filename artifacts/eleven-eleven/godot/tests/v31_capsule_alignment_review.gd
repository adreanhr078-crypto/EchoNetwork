extends SceneTree

## A controller integration gate, separate from frozen source-motion fidelity.
var player: EchoPlayer
var samples: Array = []

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var floor := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = Vector3(50, 0.2, 70)
	floor.position = Vector3(0, -0.1, -15)
	floor.add_child(shape)
	world.add_child(floor)
	player = load("res://scenes/player/echo_player.tscn").instantiate()
	world.add_child(player)
	player.finish_opening_recovery()
	player.set_gameplay_orbit(Vector3.ZERO)
	var skeleton := player.find_child("Skeleton3D", true, false) as Skeleton3D
	var hips := skeleton.find_bone("Hips")
	var maximum := 0.0
	var sources: Dictionary = {}
	for clip in ["idle", "run", "jump"]:
		var path: String = "res://assets/animations/v31/" + clip + "_cp17.res"
		sources[path] = FileAccess.get_sha256(path)
	for frame in 12: await physics_frame
	var start := player.global_position
	player.set_mobile_input_vector(Vector2(0, -1), true)
	for frame in 160:
		await physics_frame
		var pelvis := skeleton.global_transform * skeleton.get_bone_global_pose(hips).origin
		var offset := pelvis - player.global_position
		offset.y = 0
		maximum = maxf(maximum, offset.length())
		if frame % 5 == 0: samples.append({"frame":frame,"offset_m":offset.length(),"capsule":str(player.global_position),"pelvis":str(pelvis)})
	player.set_mobile_input_vector(Vector2.ZERO, false)
	# The existing controller decelerates through its skid; allow that authored
	# transition rather than requiring an instant stop after 200ms.
	for frame in 120:
		await physics_frame
		if Vector2(player.velocity.x, player.velocity.z).length() < 0.02 and player.animation_player.current_animation == "IDLE": break
	var stopped_model: Node3D = player.get_node("ModelRoot/EchoOpeningUniform")
	var stop_restored := stopped_model.position.is_equal_approx(Vector3.ZERO)
	var isolated := load("res://scenes/characters/echo_v31_adopted.tscn").instantiate() as Node3D
	world.add_child(isolated)
	var source_player := isolated.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var source_skeleton := isolated.find_child("Skeleton3D", true, false) as Skeleton3D
	source_player.play("RUN")
	source_player.seek(0.77, true)
	source_player.advance(0.0)
	var raw_pelvis := source_skeleton.get_bone_global_pose(source_skeleton.find_bone("Hips")).origin
	var raw_rest := source_skeleton.get_bone_global_rest(source_skeleton.find_bone("Hips")).origin
	var raw_delta := raw_pelvis - raw_rest
	raw_delta.y = 0
	var isolated_preserved := isolated.position.is_equal_approx(Vector3.ZERO) and raw_delta.length() > 1.0
	var unchanged := true
	for path in sources: unchanged = unchanged and sources[path] == FileAccess.get_sha256(path)
	var args := OS.get_cmdline_user_args()
	var baseline := args.has("--baseline")
	var pass_gate := maximum < 0.35 and unchanged and stop_restored and isolated_preserved and player.global_position.distance_to(start) > 5.0
	var folder := ProjectSettings.globalize_path("res://../audits/evidence/room01-20261012/")
	var file := FileAccess.open(folder + ("capsule-baseline.json" if baseline else "capsule-current.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"status":"PASS" if pass_gate else "FAIL","gate":"live_capsule_horizontal_alignment_only","max_offset_m":maximum,"public_input_distance_m":player.global_position.distance_to(start),"mixer_applied_signal":player.animation_player.has_signal("mixer_applied"),"root_motion_track":str(player.animation_player.root_motion_track),"source_hashes":sources,"sources_unchanged":unchanged,"isolated_source_preserved":isolated_preserved,"isolated_displacement_m":raw_delta.length(),"stopping_restores_origin":stop_restored,"samples":samples,"walk_wake_cape_art_accepted":false},"\t"))
	file.close()
	world.queue_free()
	await process_frame
	print("CAPSULE_ALIGNMENT ", "PASS" if pass_gate else "FAIL", " max=", maximum, " sources_unchanged=", unchanged)
	quit(0 if baseline or pass_gate else 1)

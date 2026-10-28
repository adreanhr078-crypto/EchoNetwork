extends SceneTree

## Isolated actual-engine geometry, shader and Echo input review.
## One declared starting anchor; no chapter state/save progression is granted.
var world: Node3D
var room: Node3D
var player: EchoPlayer
var camera: Camera3D
var out: String
var report := {"scope":"Isolated candidate;not connected chapter acceptance","checks":[],"trajectory":[]}

func _initialize() -> void: _run.call_deferred()

func _frames(count: int) -> void:
	for i in count:
		await process_frame
		await physics_frame

func _check(label: String, passed: bool, detail: Variant = null) -> void:
	report.checks.append({"check":label,"pass":passed,"detail":detail})
	print("STORMWORKS_CHECK ",label," ",passed)

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty(): push_error("Evidence directory required");quit(2);return
	out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(1280,720)
	root.unfocusable = true
	world = Node3D.new()
	root.add_child(world)
	room = load("res://scenes/environment/maintenance_stormworks.tscn").instantiate()
	if room.get_script() == null:
		push_error("Candidate room script failed to load")
		quit(2)
		return
	world.add_child(room)
	player = load("res://scenes/player/echo_player.tscn").instantiate()
	player.position = Vector3(0,.1,.1)
	world.add_child(player)
	player.finish_opening_recovery()
	player.control_locked = false
	player.set_mobile_input_vector(Vector2.ZERO,false)
	player.landing_executed.connect(func(speed: float,_heavy: bool):room.presentation.react_to_landing(player.global_position,speed))
	var manager = root.get_node("HyperAnimeWorldManager")
	manager.attach_scene(world,player)
	manager.set_quality("high")
	manager.set_preset("maintenance_pressure_bay",0.0)
	camera = Camera3D.new()
	world.add_child(camera)
	camera.fov = 75
	camera.make_current()
	await _frames(16)
	_check("source_parts",room.collision_parts == 27,room.collision_parts)
	_check("climbable_roles",get_nodes_in_group("climbable").size() == 11,get_nodes_in_group("climbable").size())
	_check("vaultable_role",get_nodes_in_group("vaultable").size() == 1)
	var sweep_pose := player.global_transform
	sweep_pose.origin = Vector3(0,.32,.1)
	_check("ground_entry_capsule_clear",not player.test_move(sweep_pose,Vector3(0,0,-3.7)))
	var samples := []
	for label in ["Entry","FirstPier","LeftPier","ThirdPier","VaultDeck","ServiceDeck","CampaignExit"]:
		var marker := room.get_node(label) as Marker3D
		var query := PhysicsRayQueryParameters3D.create(marker.global_position+Vector3.UP*.5,marker.global_position-Vector3.UP*.8)
		query.exclude = [player.get_rid()]
		var hit := world.get_world_3d().direct_space_state.intersect_ray(query)
		samples.append({"name":label,"anchor":str(marker.position),"floor":str(hit.get("position")),"normal":str(hit.get("normal"))})
	_check("measured_landing_support",samples.all(func(row: Dictionary):return row.floor != "<null>"),samples)
	for row in [["entry",Vector3(0,1.65,-.4),Vector3(0,3,-12)],
		["interior",Vector3(-6.4,4.6,-6),Vector3(0,3.6,-14)],
		["upper",Vector3(4.7,7.1,-12),Vector3(0,4.6,-17.8)]]:
		camera.position = row[1]
		camera.look_at(row[2])
		await _frames(8)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out.path_join(String(row[0])+".png"))
	var time_before: float = room.presentation._elapsed
	paused = true
	for i in 5: await process_frame
	_check("pause_freezes_water",room.presentation._elapsed == time_before)
	paused = false
	room.set_reduced_motion(true)
	await _frames(5)
	time_before = room.presentation._elapsed
	await _frames(5)
	_check("reduced_motion_freezes_water",room.presentation._elapsed == time_before)
	room.set_reduced_motion(false)
	room.presentation.set_audio_muted(true)
	room.presentation.react_to_landing(Vector3(0,-.2,-10),6)
	_check("landing_ripple_recorded",room.presentation._impacts[0].w > 0)
	# A real mobile/public movement input enters the doorway; no position reset.
	player.camera_boom.rotation.y = 0
	player.set_mobile_input_vector(Vector2(0,-1),true)
	await _frames(40)
	player.set_mobile_input_vector(Vector2.ZERO,false)
	_check("echo_runs_through_entry",player.position.z < -2.8,str(player.position))
	report.renderer = RenderingServer.get_current_rendering_method()
	report.device = RenderingServer.get_video_adapter_name()
	report.status = "PASS_SCOPED" if report.checks.all(func(row: Dictionary):return row.get("pass",false)) else "FAIL_SCOPED"
	var file := FileAccess.open(out.path_join("review.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"));file.close()
	manager.detach_scene()
	world.queue_free()
	await _frames(3)
	quit(0 if report.status == "PASS_SCOPED" else 1)

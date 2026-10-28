extends SceneTree

## Fixed art inspection, deliberately separate from the real-input journey.
func _initialize() -> void:_run.call_deferred()
func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():quit(2);return
	var out: String = args[0]
	var hashes := _source_hashes()
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(1280,720)
	root.unfocusable = true
	var world := Node3D.new()
	root.add_child(world)
	var room = load("res://scenes/environment/maintenance_stormworks.tscn").instantiate()
	world.add_child(room)
	room.set_reduced_motion(true)
	var manager = root.get_node("HyperAnimeWorldManager")
	manager.attach_scene(world,null)
	manager.set_quality("high")
	manager.set_preset("maintenance_pressure_bay",0)
	manager.set_reduced_motion(true)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.fov = 75
	camera.make_current()
	var captures := []
	for row in [["whole-room",Vector3(-6.4,4.6,-6),Vector3(0,3.6,-14)],
		["entry-route",Vector3(-1.15,2,-3.3),Vector3(-3.5,2.8,-10)],
		["service-craft",Vector3(2.8,7,-16.21),Vector3(.4,6.5,-18.11)],
		["reverse-chamber",Vector3(1,6,-16.5),Vector3(0,3,-4)]]:
		camera.position = row[1]
		camera.look_at(row[2])
		for i in 12:await process_frame
		await RenderingServer.frame_post_draw
		var path := out.path_join(row[0]+".png")
		var result := root.get_texture().get_image().save_png(path)
		captures.append({"view":row[0],"path":path,"saved":result == OK})
		print("STORMWORKS_ART ",row[0])
	var file := FileAccess.open(out.path_join("review.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"scope":"Current Forward+High fixed-camera art inspection;not gameplay or performance acceptance","captures":captures,"source_hashes":hashes,"source_snapshot_unchanged":hashes == _source_hashes(),"renderer":RenderingServer.get_current_rendering_method(),"device":RenderingServer.get_video_adapter_name()},"\t"));file.close()
	manager.detach_scene()
	world.queue_free()
	for i in 5:await process_frame
	quit()

func _source_hashes() -> Dictionary:
	var result := {}
	for path in ["scripts/environment/maintenance_stormworks.gd","tests/stormworks_current_art_review.gd","assets/environments/maintenance_stormworks/stormworks_original_pbr_metric_v8.glb","assets/environments/maintenance_stormworks/stormworks_precision_gate_v1.glb","assets/environments/maintenance_stormworks/stormworks_precision_wheel_v1.glb","assets/environments/maintenance_stormworks/stormworks_precision_bulkhead_v1.glb","assets/environments/maintenance_stormworks/stormworks_collision_portal_v7.glb"]:
		result[path] = FileAccess.get_sha256("res://"+path)
	return result

extends SceneTree

## Same camera,lighting and source;only the geometry LOD bias changes.
func _initialize() -> void:_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():quit(2);return
	var out: String = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(1280,720)
	root.unfocusable = true
	var world := Node3D.new()
	root.add_child(world)
	var room = load("res://scenes/environment/maintenance_stormworks.tscn").instantiate()
	if room.get_script() == null:quit(2);return
	world.add_child(room)
	room.set_reduced_motion(true)
	var manager = root.get_node("HyperAnimeWorldManager")
	manager.attach_scene(world,null)
	manager.set_quality("high")
	manager.set_preset("maintenance_pressure_bay",0)
	manager.set_reduced_motion(true)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(-6.4,4.6,-6)
	camera.look_at(Vector3(0,3.6,-14))
	camera.fov = 75
	camera.make_current()
	var rows := []
	for value in [1.0,18.334597,128.0]:
		for mesh: MeshInstance3D in room.source_visual.find_children("*","MeshInstance3D",true,false):mesh.lod_bias = value
		for i in 12:await process_frame
		await RenderingServer.frame_post_draw
		var path := out.path_join("lod-%s.png"%str(value))
		root.get_texture().get_image().save_png(path)
		var primitives := -1
		if ClassDB.class_get_integer_constant_list("Performance").has("RENDER_TOTAL_PRIMITIVES_IN_FRAME"):
			primitives = int(Performance.get_monitor(ClassDB.class_get_integer_constant("Performance","RENDER_TOTAL_PRIMITIVES_IN_FRAME")))
		rows.append({"lod_bias":value,"path":path,"primitives":primitives,"scope":"Controlled art diagnostic,not player/performance acceptance"})
		print("LOD_DIAGNOSTIC ",rows.back())
	var file := FileAccess.open(out.path_join("review.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"renderer":RenderingServer.get_current_rendering_method(),"rows":rows},"\t"));file.close()
	manager.detach_scene()
	world.queue_free()
	for i in 5:await process_frame
	quit()

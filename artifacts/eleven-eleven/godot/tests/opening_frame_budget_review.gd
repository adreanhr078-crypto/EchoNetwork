extends SceneTree

# Native desktop measurement only. No fixed-fps timing or mobile claim.
func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1280,720)
	root.content_scale_size = root.size
	var main = load("res://scenes/opening_native_room.tscn").instantiate()
	main.native_checkpoint_path = "user://opening_frame_budget_review.json"
	main.native_preferences_path = "user://opening_frame_budget_review.cfg"
	root.add_child(main)
	await process_frame
	main.set_audio_muted(true)
	main.set_reduced_motion(true)
	main.player.finish_opening_recovery()
	var dialogue = main.hud.find_child("DialogueOverlay",true,false)
	for i in 8:
		if dialogue.is_active: dialogue.advance_dialogue()
		await process_frame
	main.native_pause_menu.set_session_paused(false)
	main.native_pause_menu.queue_free()
	main.native_pause_menu = null
	main.player.control_locked = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for i in 45: await process_frame
	var intervals:Array[float] = []
	var previous := Time.get_ticks_usec()
	var draw_calls := 0.0
	var primitives := 0.0
	for i in 240:
		main.player.camera_boom.rotation.y += .003
		await process_frame
		var current := Time.get_ticks_usec()
		intervals.append(float(current-previous)/1000.0)
		previous = current
		draw_calls = maxf(draw_calls,Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		primitives = maxf(primitives,Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	intervals.sort()
	var total := 0.0
	for value in intervals: total += value
	var report := {"status":"MEASURED_REVIEW_REQUIRED","renderer":RenderingServer.get_current_rendering_method(),"viewport":[1280,720],"samples":intervals.size(),"mean_ms":total/intervals.size(),"p50_ms":intervals[120],"p95_ms":intervals[228],"p99_ms":intervals[237],"max_draw_calls":draw_calls,"max_primitives":primitives,"scope":"Native Intel-UHD desktop opening, loaded assets, muted/reduced-motion idle plus camera orbit; no fixed FPS, no physical phone or whole-campaign acceptance."}
	var mesh_costs := []
	for node in main.find_children("*","MeshInstance3D",true,false):
		if not node.is_visible_in_tree() or not node.mesh is ArrayMesh: continue
		var triangles := 0
		for surface in node.mesh.get_surface_count():
			if node.mesh.surface_get_primitive_type(surface)!=Mesh.PRIMITIVE_TRIANGLES: continue
			var indices:int = node.mesh.surface_get_array_index_len(surface)
			triangles += (indices if indices>0 else node.mesh.surface_get_array_len(surface))/3
		mesh_costs.append({"path":str(main.get_path_to(node)),"surfaces":node.mesh.get_surface_count(),"base_triangles":triangles})
	mesh_costs.sort_custom(func(a,b): return a.base_triangles>b.base_triangles)
	report["largest_visible_base_meshes"] = mesh_costs.slice(0,16)
	var folder := ProjectSettings.globalize_path("res://../audits/evidence/quality-execution-20261006/performance/")
	DirAccess.make_dir_recursive_absolute(folder)
	var file := FileAccess.open(folder+"opening-desktop.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print(JSON.stringify(report))
	main.queue_free()
	await process_frame
	for path in ["user://opening_frame_budget_review.json","user://opening_frame_budget_review.cfg"]:
		for suffix in ["",".bak",".tmp"]:
			if FileAccess.file_exists(path+suffix): DirAccess.remove_absolute(path+suffix)
	quit(0)

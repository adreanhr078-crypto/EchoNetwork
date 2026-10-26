extends "res://tests/post_contract_journey_review.gd"

## Diagnostic on an earned, PID-isolated profile. Frame intervals include CPU,
## presentation and scheduling; they are not GPU timestamps or device acceptance.
var _profile_tier := "high"
var _profile_samples: Array[Dictionary] = []

func _review_melee_camera() -> bool:
	var art_views_only:=OS.get_cmdline_user_args().has("--art-views-only")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--quality="):
			_profile_tier = argument.trim_prefix("--quality=")
	if not _check(_profile_tier in ["low", "medium", "high", "ultra"], "Unsupported diagnostic tier"):
		return false
	main.set_visual_quality(_profile_tier)
	main.set_reduced_motion(false)
	if art_views_only:main.hud.hide()
	var budget_service_shadows:=OS.get_cmdline_user_args().has("--budget-service-shadows")
	if budget_service_shadows:
		# Controlled diagnostic only: retain tier/post-FX/render scale, focal
		# surgical shadow, Zero and source normal maps for the comparison.
		var service_lighting:Node=room.get_node("ServiceLighting")
		for light in service_lighting.get_children():
			if light is OmniLight3D:light.shadow_enabled=false
	var freeze_reflection:=OS.get_cmdline_user_args().has("--freeze-reflection")
	if freeze_reflection:
		var reflection_owner:Node=main.find_child("MemoryReflectionSpace",true,false)
		reflection_owner.set_process(false)
		reflection_owner.reflection_view.render_target_update_mode=SubViewport.UPDATE_DISABLED
	var no_cladding_shadows:=OS.get_cmdline_user_args().has("--no-cladding-shadows")
	if no_cladding_shadows:
		# One variable only: opaque native hull/frame and all selected-tier
		# lights/post-FX remain unchanged. Decorative panels still receive light.
		var perimeter:Node=room.find_child("MeasuredTripoClinicalPerimeter",true,false)
		for draw in perimeter.find_children("*","MultiMeshInstance3D",true,false):
			draw.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var initial_progress := JSON.stringify(campaign.progress)
	var camera := Camera3D.new()
	camera.fov = 65
	room.add_child(camera)
	camera.environment = player.player_camera.environment
	camera.make_current()
	var views := [
		["entry", Vector3(0, 2.2, -2), Vector3(0, 2, -23)],
		["reverse", Vector3(0, 3, -36), Vector3(0, 2, -14)],
		["lateral", Vector3(-13.8, 3.5, -15), Vector3(2, 2.5, -22)],
		["theater", Vector3(3.2, 3.2, -16), Vector3(0, 2.1, -20)]
	]
	for view in views:
		camera.position = view[1]
		camera.look_at(room.to_global(view[2]))
		for tick in 45:
			await process_frame
		if not art_views_only and view[0] in ["entry", "theater"]:
			await _measure_interval(view[0])
		await _capture("profile-" + view[0])
	camera.queue_free()
	player.player_camera.make_current()
	for tick in 10:
		await process_frame
	# Reuse actual public-input walking and collision, with no fixture teleport.
	var started := Time.get_ticks_usec()
	if not art_views_only:
		if not await _walk_local(Vector3(0, 0, -28.8)):
			return false
		_profile_samples.append({"name": "native-walk-to-theater", "duration_ms": (Time.get_ticks_usec() - started) / 1000.0,
			"scope": "Public movement/collision elapsed time; not a frame percentile"})
		await _measure_interval("gameplay-camera")
		await _capture("profile-gameplay")
	if not _check(initial_progress == JSON.stringify(campaign.progress) and campaign.kinja.contacts == 0 and not room.wish_done,
		"Performance diagnostic changed earned progression"):
		return false
	var water := main.find_child("MemoryReflectionSpace", true, false)
	var cinema := main.find_child("IntactMemoryCinema", true, false)
	var inventory := _scene_inventory()
	var service := room.get_node("ServiceLighting")
	var service_shadows := 0
	for light in service.get_children():
		if light is OmniLight3D and light.shadow_enabled:
			service_shadows += 1
	var report := {
		"renderer": RenderingServer.get_current_rendering_method(),
		"adapter": RenderingServer.get_video_adapter_name(),
		"engine": Engine.get_version_info().string,
		"framebuffer": [root.size.x, root.size.y], "tier": _profile_tier,
		"render_scale": root.scaling_3d_scale, "msaa": root.msaa_3d,
		"audio_muted":main.audio_muted,
		"reduced_motion": main.reduced_motion,
		"reflection_frozen_for_diagnosis": freeze_reflection,
		"service_shadows_budgeted_for_diagnosis":budget_service_shadows,
		"decorative_cladding_shadows_disabled_for_diagnosis":no_cladding_shadows,
		"water_active": is_instance_valid(water) and water.active,
		"video_players": cinema.players.size() if is_instance_valid(cinema) else 0,
		"service_shadow_count": service_shadows, "focal_shadow": room._surgical_light.shadow_enabled,
		"samples": _profile_samples, "scene_inventory": inventory,
		"checks": checks, "source_hashes": {},
		"scope": "Two fixed views and a real walked gameplay camera in the earned lab. 180 consecutive presented-frame intervals after warmup per view; no GPU timing, full chapter, fun or other-device acceptance."
	}
	if art_views_only:
		report.scope="Four fixed rendered lab views, existing earned profile and no progression mutation. No frame timing, public route or final art acceptance."
	for path in ["res://tests/lab_performance_review.gd", "res://scripts/environment/clinical_lab_architecture.gd",
		"res://scripts/environment/memory_reflection_space.gd", "res://scripts/environment/lab_memory_cinema.gd",
		"res://engine_visuals/HyperAnimeWorldManager.gd", "res://assets/environments/lab_clinical_cp45/clinical_wall_p2_4k.glb","res://assets/environments/lab_clinical_cp45/clinical_service_frame_clean.glb","res://scripts/environment/clinical_modular_perimeter.gd","res://assets/environments/lab_clinical_cp45/clinical_scanner_p2_4k.glb",
		"res://shaders/clinical_architecture_surface.gdshader","res://shaders/clinical_porcelain_floor.gdshader","res://scripts/player/echo_skin_identifier.gd"]:
		report.source_hashes[path] = FileAccess.get_sha256(path)
	var output := FileAccess.open(folder + ("art-views.json" if art_views_only else "performance.json"), FileAccess.WRITE)
	if not _check(output != null, "Cannot save measured lab performance"):
		return false
	output.store_string(JSON.stringify(report, "\t"))
	output.close()
	print("LAB_PERFORMANCE ", JSON.stringify({"tier": _profile_tier, "samples": _profile_samples}))
	return true

func _scene_inventory() -> Dictionary:
	var groups := {}
	var textures := {}
	var materials := {}
	for node in main.find_children("*", "GeometryInstance3D", true, false):
		if not (node is MeshInstance3D or node is MultiMeshInstance3D):continue
		var mesh:Mesh=node.mesh if node is MeshInstance3D else (node.multimesh.mesh if node.multimesh else null)
		var owner: Node = node
		while owner.get_parent() != main and owner.get_parent() != null:
			owner = owner.get_parent()
		var key := String(owner.name)
		if not groups.has(key):
			groups[key] = {"meshes": 0, "visible_meshes": 0, "visible_surfaces": 0,"multimesh_batches":0,"multimesh_instances":0}
		groups[key].meshes += 1
		if node is MultiMeshInstance3D and node.multimesh:
			groups[key].multimesh_batches+=1
			groups[key].multimesh_instances+=node.multimesh.instance_count
		if node.is_visible_in_tree():
			groups[key].visible_meshes += 1
			groups[key].visible_surfaces += mesh.get_surface_count() if mesh else 0
		if not mesh:
			continue
		for surface in mesh.get_surface_count():
			var material: Material = node.get_active_material(surface) if node is MeshInstance3D else (node.material_override if node.material_override else mesh.surface_get_material(surface))
			if material == null or materials.has(material.get_instance_id()):
				continue
			materials[material.get_instance_id()] = true
			if material is ShaderMaterial and material.shader:
				for uniform in material.shader.get_shader_uniform_list():
					if uniform.type != TYPE_OBJECT:
						continue
					var resource = material.get_shader_parameter(uniform.name)
					if resource is Texture2D:
						var id: int = resource.get_rid().get_id()
						if not textures.has(id):
							textures[id] = {"path": resource.resource_path, "width": resource.get_width(),
								"height": resource.get_height(), "first_owner": String(node.get_path())}
	var rows: Array = textures.values()
	rows.sort_custom(func(a, b): return a.width * a.height > b.width * b.height)
	return {"roots": groups, "unique_active_materials": materials.size(), "unique_shader_textures": rows.size(),
		"largest_shader_textures": rows.slice(0, 24), "scope": "Scene graph references, including hidden roots; not per-texture VRAM attribution."}

func _measure_interval(label: String) -> void:
	var values: Array[float] = []
	var previous := Time.get_ticks_usec()
	for tick in 180:
		await process_frame
		var now := Time.get_ticks_usec()
		values.append((now - previous) / 1000.0)
		previous = now
	values.sort()
	_profile_samples.append({"name": label, "frames": values.size(),
		"p50_ms": values[89], "p95_ms": values[170], "p99_ms": values[178], "max_ms": values.back(),
		"texture_bytes": int(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)),
		"buffer_bytes": int(Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED)),
		"video_bytes": int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)),
		"draw_calls": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))})

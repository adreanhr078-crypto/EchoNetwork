extends "res://tests/post_contract_journey_review.gd"

## Read-only triangle probe of the actually rendered earned laboratory.
func _review_melee_camera() -> bool:
	main.set_visual_quality("low")
	if OS.get_cmdline_user_args().has("--quality=high"):
		main.set_visual_quality("high")
	main.set_reduced_motion(false)
	main.hud.hide()
	var progress_before := JSON.stringify(campaign.progress)
	var camera := Camera3D.new()
	camera.fov = 65
	room.add_child(camera)
	camera.environment = player.player_camera.environment
	camera.position = Vector3(3.2, 3.2, -16)
	camera.look_at(room.to_global(Vector3(0, 2.1, -20)))
	var reverse_header:=OS.get_cmdline_user_args().has("--reverse-header")
	if reverse_header:
		camera.position=Vector3(0,3,-36)
		camera.look_at(room.to_global(Vector3(0,2,-14)))
	camera.make_current()
	for tick in 45:
		await process_frame
	await _capture("surface-reference")
	var probes: Array = []
	var pixels:Array=[Vector2(640,255),Vector2(640,280),Vector2(640,310)] if reverse_header else [Vector2(1000,175),Vector2(1000,205),Vector2(1000,245)]
	for pixel in pixels:
		# Camera projection uses stretched viewport coordinates, while the
		# reference PNG uses physical framebuffer pixels.
		var viewport_pixel: Vector2 = pixel * root.get_visible_rect().size / Vector2(root.size)
		var origin := camera.project_ray_origin(viewport_pixel)
		var direction := camera.project_ray_normal(viewport_pixel)
		var hits: Array = []
		for node in room.find_children("*", "MeshInstance3D", true, false):
			if not node.is_visible_in_tree() or not node.mesh or node.skin:
				continue
			var inverse: Transform3D = node.global_transform.affine_inverse()
			var local_origin: Vector3 = inverse * origin
			var local_direction: Vector3 = (inverse * (origin + direction) - local_origin).normalized()
			if not node.get_aabb().intersects_ray(local_origin, local_direction):
				continue
			for surface in node.mesh.get_surface_count():
				var arrays: Array = node.mesh.surface_get_arrays(surface)
				if arrays.is_empty():
					continue
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
				var count: int = vertices.size() if indices.is_empty() else indices.size()
				var nearest := INF
				var hit_world := Vector3.ZERO
				for index in range(0, count, 3):
					var a: int = index if indices.is_empty() else indices[index]
					var b: int = index + 1 if indices.is_empty() else indices[index + 1]
					var c: int = index + 2 if indices.is_empty() else indices[index + 2]
					var hit = Geometry3D.ray_intersects_triangle(local_origin, local_direction, vertices[a], vertices[b], vertices[c])
					if hit == null:
						continue
					var world_hit: Vector3 = node.global_transform * hit
					var distance := origin.distance_to(world_hit)
					if distance < nearest:
						nearest = distance
						hit_world = world_hit
				if nearest == INF:
					continue
				var material: Material = node.get_active_material(surface)
				var details := {"class": material.get_class() if material else "none"}
				if material is ShaderMaterial:
					details.shader = material.shader.resource_path
					for uniform in material.shader.get_shader_uniform_list():
						if uniform.name in ["base_color", "clean_clinical_coating", "has_color_map", "has_ao_map", "metalness"]:
							details[uniform.name] = str(material.get_shader_parameter(uniform.name))
				hits.append({"node": String(node.get_path()), "surface": surface, "distance": nearest,
					"room_hit": str(room.to_local(hit_world)), "material": details})
		hits.sort_custom(func(a, b): return a.distance < b.distance)
		probes.append({"pixel": str(pixel), "hits": hits.slice(0, 4)})
	if not _check(JSON.stringify(campaign.progress) == progress_before, "Read-only surface probe changed progress"):
		return false
	var output := FileAccess.open(folder + "surface-probe.json", FileAccess.WRITE)
	output.store_string(JSON.stringify({"renderer": RenderingServer.get_current_rendering_method(),
		"framebuffer": str(root.size), "viewport": str(root.get_visible_rect().size),
		"probes": probes, "checks": checks}, "\t"))
	output.close()
	print("LAB_SURFACE_PROBE_COMPLETE")
	return true

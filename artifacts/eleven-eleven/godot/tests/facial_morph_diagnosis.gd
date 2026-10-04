extends SceneTree

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	var avatar = load("res://assets/characters/echo_opening_uniform_v13.glb").instantiate()
	var body := avatar.find_child("EchoOpeningUniformBody", true, false) as MeshInstance3D
	var report := {"glb_sha256": FileAccess.get_sha256("res://assets/characters/echo_opening_uniform_v13.glb"), "surface_count": body.mesh.get_surface_count(), "shapes": []}
	for surface in body.mesh.get_surface_count():
		var arrays := body.mesh.surface_get_arrays(surface)
		var base: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var targets := body.mesh.surface_get_blend_shape_arrays(surface)
		for shape in targets.size():
			var positions: PackedVector3Array = targets[shape][Mesh.ARRAY_VERTEX]
			var affected := []
			var bounds := AABB()
			var largest := 0.0
			for vertex in base.size():
				var difference := positions[vertex] - base[vertex] if body.mesh.blend_shape_mode == Mesh.BLEND_SHAPE_MODE_NORMALIZED else positions[vertex]
				if difference.length() > 0.00001:
					bounds = AABB(base[vertex], Vector3.ZERO) if affected.is_empty() else bounds.expand(base[vertex])
					affected.append(vertex)
					largest = maxf(largest, difference.length())
			report.shapes.append({"surface": surface, "name": body.mesh.get_blend_shape_name(shape), "affected_vertices": affected.size(), "largest_delta_model_m": largest, "affected_bounds_model": str(bounds), "runtime_scale": 1.81})
	var folder := ProjectSettings.globalize_path("res://../audits/evidence/character-shading-20261002/facial/")
	var file := FileAccess.open(folder + "morph-diagnosis.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	avatar.free()
	print(JSON.stringify(report))
	quit(0)

extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var player = load("res://scenes/player/echo_player.tscn").instantiate()
	root.add_child(player)
	await process_frame
	player.finish_opening_recovery()
	for i in range(3): await process_frame
	player.set_physics_process(false)
	player.position = Vector3.ZERO # No floor in this isolated rig fixture; cancel gravity drift.
	player.visual_root.rotation = Vector3(0, PI * 0.5, 0) # Match the recovery start, not airborne idle lean.
	var body: MeshInstance3D = player.find_child("EchoOpeningUniformBody", true, false)
	var skeleton: Skeleton3D = player.find_child("Skeleton3D", true, false)
	var arrays := body.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var influences := bones.size() / vertices.size()

	player.animation_player.play("preset_wakeup", 0.0)
	player.animation_player.pause()
	player.opening_recovery_active = true
	for sample in range(137):
		var phase := sample / 136.0
		player.animation_player.seek(player.animation_player.current_animation_length * phase, true)
		player.animation_player.advance(0)
		# paused animation deliberately uses the baked contact profile here;
		# the independent check below skins the actual surface with Godot poses.
		player.visual_root.position.y = load("res://scripts/player/opening_wake_contacts.gd").offset(phase)
		skeleton.force_update_all_bone_transforms()
		var transforms: Array[Transform3D] = []
		for bind in range(body.skin.get_bind_count()):
			var bone := body.skin.get_bind_bone(bind)
			if bone < 0: bone = skeleton.find_bone(body.skin.get_bind_name(bind))
			transforms.append(skeleton.get_bone_global_pose(bone) * body.skin.get_bind_pose(bind))
		var minimum := INF
		for vertex in range(vertices.size()):
			var skinned := Vector3.ZERO
			for influence in range(influences):
				var index := vertex * influences + influence
				if weights[index] > 0:
					skinned += (transforms[bones[index]] * vertices[vertex]) * weights[index]
			minimum = minf(minimum, (skeleton.global_transform * skinned).y)
		if sample % 34 == 0: print("WAKE CONTACT phase=", phase, " actual_surface_min_y=", minimum)
		if absf(minimum) > 0.03:
			push_error("deformed wake surface floats or sinks through floor: phase=%s minimum=%s" % [phase, minimum])
			quit(1)
			return
	player.queue_free()
	await process_frame
	print("PASS wake contacts: independent Godot skin evaluation at 137 different phases within 3cm of floor")
	quit(0)

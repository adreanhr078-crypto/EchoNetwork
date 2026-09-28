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
	var offsets: Array[float] = []
	for sample in range(481):
		var phase := sample / 480.0
		player.animation_player.seek(player.animation_player.current_animation_length * phase, true)
		player.animation_player.advance(0)
		# Measure uncorrected imported poses; runtime uses this baked contact curve.
		player.visual_root.position.y = 0.0
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
		offsets.append(snappedf(-minimum, 0.00001))
	player.queue_free()
	await process_frame
	var profile := FileAccess.open("res://scripts/player/opening_wake_contacts.gd", FileAccess.WRITE)
	profile.store_string("# Generated from Godot's imported/skinned V13 mesh by tools/bake_opening_wake_contacts.gd.\n# Source SHA256: %s; scale 1.81; 481 normalized samples.\nextends RefCounted\n\nconst OFFSETS = %s\n\nstatic func offset(phase: float) -> float:\n\tvar sample := clampf(phase, 0.0, 1.0) * (OFFSETS.size() - 1)\n\tvar lower := int(floor(sample))\n\treturn lerpf(OFFSETS[lower], OFFSETS[mini(lower + 1, OFFSETS.size() - 1)], sample - lower)\n" % [FileAccess.get_sha256("res://assets/characters/echo_opening_uniform_v13.glb"), str(offsets)])
	profile.close()
	print("BAKED runtime wake contact samples=", offsets.size())
	quit(0)

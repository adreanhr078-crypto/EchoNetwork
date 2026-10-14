extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	for cancel_before_deferred in [true, false]:
		var main = load("res://scenes/opening_native_room.tscn").instantiate()
		main.native_checkpoint_path = "user://native_visual_smoke.json"
		main.native_preferences_path = "user://native_visual_smoke.cfg"
		root.add_child(main)
		if not cancel_before_deferred:
			for i in range(3): await process_frame
		main.player.finish_opening_recovery()
		for i in range(6): await physics_frame
		if not _check(not main.player.opening_recovery_active and is_zero_approx(main.player.visual_root.position.y), "skipped wake lowered the idle model below the floor"): return
		if not _check(not main.player.animation_player.current_animation.to_lower().contains("wake"), "deferred wake restarted after skip/restore"): return
		var shell = main.get_node("Sector11OpeningShell")
		if not _check(shell.opening_only and shell.has_node("SouthContainmentWall_Body/Collider") and shell.has_node("Gate1_Bulkhead_West_Body/Collider"), "native opening lacks authored containment"): return
		if not _check(shell.find_children("Corridor1*", "", true, false).is_empty() and shell.find_children("Kinga*", "", true, false).is_empty(), "opening built later architecture"): return
		var ceiling = shell.get_node("CeilingShell/Surface")
		if not _check(is_equal_approx(ceiling.mesh.size.z,shell.OPENING_LENGTH) and is_equal_approx(shell.get_node("CeilingShell").position.z,shell.OPENING_CENTER_Z), "opening roof overlaps the upper maintenance camera"): return
		for beam in shell.find_children("CeilingCrossBeam*", "MeshInstance3D", true, false) + shell.find_children("ServiceTruss*", "MeshInstance3D", true, false):
			if not _check(beam.position.z >= -18, "opening beam intrudes into maintenance"): return
		print("STRUCTURE meshes=", shell.find_children("*", "MeshInstance3D", true, false).size())
		var env: Environment = main.get_node("WorldEnvironment").environment
		if not _check(env.tonemap_exposure < 1.0 and env.glow_intensity < 0.3 and not env.ssr_enabled and not env.volumetric_fog_enabled and main.post_processor.current_sky_mat == null, "overworld presentation overwrote quiet opening"): return
		var floor_material: ShaderMaterial = main.get_node("Sector11Facility/Room1_CryoChamber/CatwalkFloor").get_active_material(0)
		if not _check(floor_material != null and floor_material.shader != null, "opening floor lost its authored material"): return
		if floor_material.shader.resource_path == "res://shaders/opening_deck.gdshader":
			if not _check(is_zero_approx(float(floor_material.get_shader_parameter("reaction"))), "opening deck flashes without an evidence interaction"): return
		else:
			var pulse_speed = floor_material.get_shader_parameter("emergency_pulse_speed")
			if not _check(pulse_speed != null and is_zero_approx(float(pulse_speed)), "opening floor lacks a verifiable quiet shader contract"): return
		var body = main.player.find_child("EchoV31BodyAndCoat", true, false)
		if not _check(body != null and main.player.get_node("ModelRoot/EchoOpeningUniform").get_meta("owner_adopted_echo_v31",false), "visual review must inspect the actual adopted V31 body"): return
		var material: ShaderMaterial = body.get_active_material(0)
		if not _check(material.get_shader_parameter("albedo_texture") != null, "actual V31 lost its authored albedo atlas"): return
		var outline: Material = material.next_pass
		var skinned_hull: bool = outline is StandardMaterial3D and outline.grow
		if outline is ShaderMaterial and outline.shader:
			var code: String = outline.shader.code
			skinned_hull = outline.shader.resource_path == "res://shaders/anime_outline.gdshader" and code.contains("VERTEX += NORMAL") and not code.contains("POSITION")
		if not _check(skinned_hull, "outline bypasses hardware skinning or lost its bounded normal extrusion"): return
		main.queue_free()
		await process_frame
		for path in ["user://native_visual_smoke.json", "user://native_visual_smoke.json.bak", "user://native_visual_smoke.cfg"]:
			if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	print("PASS native opening visuals: both wake cancellation timings, idle grounding, containment, bounded architecture, quiet presentation and textured skinned outline")
	quit(0)

func _check(condition: bool, message: String) -> bool:
	if not condition:
		push_error(message)
		quit(1)
	return condition

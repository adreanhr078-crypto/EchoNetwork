extends SceneTree

func _init() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(640, 640)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)

	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.12, 0.16, 0.22)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.75, 0.85)
	env.ambient_light_energy = 1.2
	world_env.environment = env
	vp.add_child(world_env)

	var dir_light := DirectionalLight3D.new()
	dir_light.position = Vector3(1, 4, 3)
	vp.add_child(dir_light)
	dir_light.look_at_from_position(Vector3(1, 4, 3), Vector3(0, 1, 0))

	var player_scene = load("res://scenes/player/echo_player.tscn")
	var player = player_scene.instantiate()
	vp.add_child(player)
	player.position = Vector3.ZERO
	if player.has_method("finish_opening_recovery"):
		player.finish_opening_recovery()

	# Unsheath weapon so Katana is in hand
	if player.has_method("unsheath_weapon"):
		player.unsheath_weapon()

	# Play idle or combat stance
	if player.has_method("play_anim"):
		player.play_anim("IDLE", 0.0)

	var cam := Camera3D.new()
	cam.current = true
	vp.add_child(cam)
	cam.look_at_from_position(Vector3(0, 1.2, 2.4), Vector3(0, 1.0, 0))

	# Configure anime toon materials with native StandardMaterial3D inverted hull outline
	var mesh_inst = player.find_child("EchoOpeningUniformBody", true, false) as MeshInstance3D
	if mesh_inst and mesh_inst.mesh:
		for i in range(mesh_inst.mesh.get_surface_count()):
			var src = mesh_inst.get_active_material(i)
			if src is StandardMaterial3D:
				var toon_mat = src.duplicate(true) as StandardMaterial3D
				toon_mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
				toon_mat.specular_mode = BaseMaterial3D.SPECULAR_TOON
				toon_mat.rim_enabled = true
				toon_mat.rim = 0.5
				toon_mat.rim_tint = 0.5
				toon_mat.metallic = 0.0
				toon_mat.roughness = 0.65

				var outline_mat = StandardMaterial3D.new()
				outline_mat.cull_mode = BaseMaterial3D.CULL_FRONT
				outline_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				outline_mat.albedo_color = Color(0.04, 0.05, 0.08, 1.0)
				outline_mat.grow = true
				outline_mat.grow_amount = 0.003
				toon_mat.next_pass = outline_mat

				mesh_inst.set_surface_override_material(i, toon_mat)

	for frame in range(12):
		await process_frame

	var tex = vp.get_texture()
	if tex:
		var img = tex.get_image()
		if img:
			var path = "C:/Users/yasmo/.gemini/antigravity/brain/1e43e74f-96d2-4240-8c06-cdf56025df12/debug_echo_standing.png"
			img.save_png(path)
			print("SUCCESS saved standing image to: ", path)

	quit(0)

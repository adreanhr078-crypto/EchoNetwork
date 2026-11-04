extends SceneTree

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	root.size = Vector2i(960,720)
	root.content_scale_size = root.size
	var folder := ProjectSettings.globalize_path("res://../audits/evidence/experience-rebuild-20261103/character-back")
	DirAccess.make_dir_recursive_absolute(folder)
	var world := Node3D.new()
	root.add_child(world)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(.15,.18,.22)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = .8
	world.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40,-130,0)
	world.add_child(sun)
	var player = load("res://scenes/player/echo_player.tscn").instantiate()
	world.add_child(player)
	player.finish_opening_recovery()
	player.set_physics_process(false)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(0,1.2,3.2)
	camera.look_at(Vector3(0,1.0,0))
	camera.fov = 38
	camera.make_current()
	for i in 6: await process_frame
	player.visual_root.rotation = Vector3(0,PI,0)
	for pair in [["IDLE",0.0],["IDLE",.5],["WALK",.5],["RUN",.5],["preset_jump",.5]]:
		player.play_anim(pair[0],0)
		var clip: Animation = player.animation_player.get_animation(pair[0])
		player.animation_player.speed_scale = 0
		player.animation_player.seek(clip.length * pair[1],true)
		for i in 3: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(folder.path_join(pair[0]+"-"+str(pair[1])+".png"))
	var avatar: Node = player.get_node("ModelRoot/EchoOpeningUniform")
	preload("res://scripts/combat/shader_applicator.gd").apply_cel_shader(avatar,preload("res://shaders/anime_cel.gdshader"),Color.WHITE,Color(.75,.8,.86,1),Color(.42,.45,.58,1),3.2,.18,preload("res://shaders/anime_outline.gdshader"),.85,.12)
	for mode in ["cel", "cel-no-outline"]:
		if mode == "cel-no-outline":
			for mesh in avatar.find_children("*","MeshInstance3D",true,false):
				for index in mesh.mesh.get_surface_count(): mesh.get_active_material(index).next_pass = null
		for pair in [["IDLE",.5],["WALK",.5],["RUN",.5]]:
			player.play_anim(pair[0],0)
			var clip: Animation = player.animation_player.get_animation(pair[0])
			player.animation_player.speed_scale = 0
			player.animation_player.seek(clip.length * pair[1],true)
			for i in 3: await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(folder.path_join(mode+"-"+pair[0]+".png"))
	world.queue_free()
	for i in 3: await process_frame
	quit()

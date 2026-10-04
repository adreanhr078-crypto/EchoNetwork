extends SceneTree

const OUTPUT := "res://../audits/evidence/hospital-route-20261001/security-art/"

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1280,720)
	root.content_scale_size = root.size
	var room = load("res://scenes/environment/security_checkpoint_room.tscn").instantiate()
	root.add_child(room)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.025,0.04,0.06)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.55,0.65,0.75)
	environment.environment.ambient_light_energy = 0.35
	room.add_child(environment)
	var player: EchoPlayer = load("res://scenes/player/echo_player.tscn").instantiate()
	player.position = Vector3(-2.8,0.1,-2)
	root.add_child(player)
	player.finish_opening_recovery()
	room.player = player
	room.set_audio_muted(true)
	for i in range(15): await physics_frame
	player.control_locked = true
	player.play_anim("IDLE",0)
	player.animation_player.seek(0,true)
	player.animation_player.pause()
	player.suspend_gameplay_camera()
	room.set_physics_process(false)
	var camera := Camera3D.new()
	camera.fov = 62
	room.add_child(camera)
	camera.current = true
	var folder := ProjectSettings.globalize_path(OUTPUT)
	DirAccess.make_dir_recursive_absolute(folder)
	var views := [
		{"id":"entry","camera":Vector3(-2.9,1.85,0.3),"target":Vector3(0,1.3,-11)},
		{"id":"service-path","camera":Vector3(1.9,3.5,-1.6),"target":Vector3(3.5,2.4,-10)},
		{"id":"cover-latch","camera":Vector3(2.8,1.9,-11),"target":Vector3(-1.1,1.1,-16)}]
	for view in views:
		camera.position = view.camera
		camera.look_at(view.target)
		for i in range(5): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(folder+view.id+".png")
	print("CAPTURED local security candidate entry/service/cover views; route/art acceptance remains separate")
	player.queue_free()
	room.queue_free()
	await process_frame
	quit(0)

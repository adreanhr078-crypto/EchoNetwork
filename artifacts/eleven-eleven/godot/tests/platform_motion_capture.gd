extends SceneTree

## Rendered review of the actual reusable deck and Echo, under a rotated room.
## This is an isolated physics fixture, not a new story room or phone benchmark.
var trace := []

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	root.size = Vector2i(960,540)
	root.content_scale_size = Vector2i(960,540)
	var folder := ProjectSettings.globalize_path("res://../audits/evidence/third-person-foundation-20261001/implementation/render/platform-vault-60-final/")
	DirAccess.make_dir_recursive_absolute(folder)
	var world := Node3D.new()
	root.add_child(world)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.035,0.05,0.08)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.5,0.6,0.8)
	environment.environment.ambient_light_energy = 0.6
	world.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45,-30,0)
	light.light_energy = 1.4
	light.shadow_enabled = true
	world.add_child(light)
	var floor := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(16,0.2,16)
	collider.shape = box
	floor.add_child(collider)
	var mesh := MeshInstance3D.new()
	var cube := BoxMesh.new()
	cube.size = box.size
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.16,0.2,0.25)
	cube.material = material
	mesh.mesh = cube
	floor.add_child(mesh)
	floor.position.y = -0.2
	world.add_child(floor)
	var room := Node3D.new()
	room.rotation.y = PI/4
	world.add_child(room)
	var lift = load("res://scenes/environment/traversal_platform.tscn").instantiate()
	lift.position.y = 1
	lift.travel = Vector3(1.5,1,0)
	lift.running = false
	room.add_child(lift)
	# The contrasting deck marks make relative foot drift visible in the clip.
	for x in [-0.95,0.95]:
		var stripe := MeshInstance3D.new()
		var strip := BoxMesh.new()
		strip.size = Vector3(0.06,0.01,2)
		var cyan := StandardMaterial3D.new()
		cyan.albedo_color = Color(0.1,0.8,0.9)
		strip.material = cyan
		stripe.mesh = strip
		stripe.position = Vector3(x,0.105,0)
		lift.add_child(stripe)
	var player: EchoPlayer = load("res://scenes/player/echo_player.tscn").instantiate()
	player.position = Vector3(0,1.2,0)
	world.add_child(player)
	player.finish_opening_recovery()
	var neutral_clip := player.current_anim
	player.set_gameplay_orbit(Vector3(-0.15,0.5,0))
	for i in range(20): await physics_frame
	if not player.is_on_floor(): push_error("platform render fixture not grounded"); quit(1); return
	if player.current_anim != neutral_clip: push_error("pre-contract rider did not retain neutral idle"); quit(1); return
	var anchor: Vector3 = lift.to_local(player.global_position)
	var max_drift := 0.0
	lift.running = true
	for frame in range(390):
		if frame == 120: player.request_jump()
		if frame == 240: lift.running = false
		if frame == 270: lift.running = true
		await process_frame
		await RenderingServer.frame_post_draw
		if frame < 120:
			max_drift = maxf(max_drift,lift.to_local(player.global_position).distance_to(anchor))
		var picture := root.get_texture().get_image()
		picture.save_png(folder+"frame-%05d.png" % frame)
		trace.append({"frame":frame,"grounded":player.is_on_floor(),"clip":player.current_anim,"combat_available":player.combat_available,"platform":[lift.global_position.x,lift.global_position.y,lift.global_position.z],"player":[player.global_position.x,player.global_position.y,player.global_position.z],"camera":[player.player_camera.global_position.x,player.player_camera.global_position.y,player.player_camera.global_position.z]})
	if max_drift > 0.02 or not player.is_on_floor(): push_error("rotated platform drift or jump reboard failed"); quit(1); return
	if player.current_anim != neutral_clip: push_error("grounded rider retained falling pose after jump"); quit(1); return
	# A blocker in WORLD space must stop a deck travelling on its parent's axes.
	var blocker := StaticBody3D.new()
	var blocker_shape := CollisionShape3D.new()
	var obstacle := BoxShape3D.new()
	obstacle.size = Vector3(0.3,4,0.3)
	blocker_shape.shape = obstacle
	blocker.add_child(blocker_shape)
	lift._origin = lift.position
	lift._distance = 0
	lift._direction = 1
	lift._wait = 0
	lift.travel = Vector3(3,0,0)
	blocker.position = room.to_global(lift.position+Vector3(2,0,0))
	world.add_child(blocker)
	for i in range(180):
		await physics_frame
		if lift.blocked: break
	if not lift.blocked: push_error("rotated parent world obstruction ignored"); quit(1); return
	lift.running = false
	# Reuse the isolated floor/blocker for the real contextual Jump -> Vault path.
	# Entry is staged; transition, animation selection and landing are gameplay.
	obstacle.size = Vector3(2,0.7,0.3)
	blocker.position = Vector3(4,0.25,-0.65)
	blocker.add_to_group("vaultable")
	var obstacle_mesh := MeshInstance3D.new()
	var obstacle_box := BoxMesh.new()
	obstacle_box.size = obstacle.size
	obstacle_box.material = material
	obstacle_mesh.mesh = obstacle_box
	blocker.add_child(obstacle_mesh)
	player.position = Vector3(4,-0.04,0)
	player.velocity = Vector3.ZERO
	player.surface_traversal_enabled = true
	player.surface_motor.reset(player)
	player.set_gameplay_orbit(Vector3(-0.15,0,0))
	for i in range(35): await physics_frame
	player.set_mobile_input_vector(Vector2(0,-0.6),true)
	player.request_jump()
	var saw_vault := false
	for frame in range(90):
		await process_frame
		await RenderingServer.frame_post_draw
		saw_vault = saw_vault or player.surface_motor._transition_kind == "vault"
		if saw_vault and player.surface_motor._mantle_points.is_empty(): player.set_mobile_input_vector(Vector2.ZERO,true)
		root.get_texture().get_image().save_png(folder+"frame-%05d.png" % (390+frame))
		trace.append({"frame":390+frame,"phase":"context_vault","grounded":player.is_on_floor(),"clip":player.current_anim,"transition":player.surface_motor._transition_kind,"player":[player.global_position.x,player.global_position.y,player.global_position.z],"camera":[player.player_camera.global_position.x,player.player_camera.global_position.y,player.player_camera.global_position.z]})
	if not saw_vault or not player.is_on_floor() or player.position.z > -1.2: push_error("contextual Jump did not vault to safe ground"); quit(1); return
	var file := FileAccess.open(folder+"trace.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"fixed_step_render":60,"phone_verified":false,"rotated_parent":true,"max_ride_drift_m":max_drift,"jump_reboard":true,"stop_resume":true,"world_obstruction_stop":true,"context_vault":true,"frames":trace},"\t"))
	file.close()
	print("PASS rendered rotated platform ride/jump/stop/resume; max_drift_m=",max_drift,"; world obstruction stopped; contextual Jump/Vault landed")
	world.queue_free()
	await process_frame
	quit(0)

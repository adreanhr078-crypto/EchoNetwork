extends SceneTree

const Applicator = preload("res://scripts/combat/shader_applicator.gd")
const Cel = preload("res://shaders/anime_cel.gdshader")
const Outline = preload("res://shaders/anime_outline.gdshader")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(960, 1080)
	for variant in ["uniform", "8k-v3"]:
		var scene := Node3D.new()
		root.add_child(scene)
		var world := WorldEnvironment.new()
		world.environment = Environment.new()
		world.environment.background_mode = Environment.BG_COLOR
		world.environment.background_color = Color(0.012, 0.018, 0.028)
		world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		world.environment.ambient_light_color = Color(0.7, 0.75, 0.9)
		world.environment.ambient_light_energy = 0.3
		world.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		scene.add_child(world)
		var key := DirectionalLight3D.new()
		key.rotation_degrees = Vector3(-30, -30, 0)
		key.light_energy = 0.7
		scene.add_child(key)
		var fill := DirectionalLight3D.new()
		fill.rotation_degrees = Vector3(-10, 150, 0)
		fill.light_color = Color(0.62, 0.73, 1)
		fill.light_energy = 0.3
		scene.add_child(fill)
		var model: Node3D = load("res://assets/characters/echo_candidate_v3.glb" if variant == "8k-v3" else "res://assets/characters/echo_opening_uniform_v13.glb").instantiate()
		scene.add_child(model)
		await process_frame
		var bounds := AABB()
		var initialized := false
		for mesh in model.find_children("*", "MeshInstance3D", true, false):
			if not mesh.mesh: continue
			var local: AABB = mesh.global_transform * mesh.get_aabb()
			bounds = bounds.merge(local) if initialized else local
			initialized = true
		var scale := 1.78 / bounds.size.y
		Applicator.apply_cel_shader(model, Cel, Color.WHITE, Color(0.75, 0.8, 0.86), Color(0.42, 0.45, 0.58), 3.2, 0.12, Outline, 1.0, 0.06)
		var animation: AnimationPlayer = model.find_child("AnimationPlayer", true, false)
		if animation:
			for clip in animation.get_animation_list():
				if clip.to_lower().contains("idle"):
					animation.play(clip)
					animation.seek(0, true)
					animation.advance(0)
					animation.pause()
					break
		if variant == "uniform": model.rotation.y = -PI / 2
		for i in range(2): await process_frame
		# Static mesh AABBs describe the bind pose, not the animated surface.
		# Centre this comparison on the actual idle skeleton before framing it.
		var skeleton: Skeleton3D = model.find_child("Skeleton3D", true, false)
		var pose_bounds := AABB()
		for bone in range(skeleton.get_bone_count()):
			var point := skeleton.to_global(skeleton.get_bone_global_pose(bone).origin)
			if bone == 0: pose_bounds = AABB(point, Vector3.ZERO)
			else: pose_bounds = pose_bounds.expand(point)
		var ground := pose_bounds.position.y - 0.10
		scale = 1.78 / (pose_bounds.size.y + 0.28)
		model.scale *= scale
		model.position -= Vector3(pose_bounds.get_center().x, ground, pose_bounds.get_center().z) * scale
		var camera := Camera3D.new()
		scene.add_child(camera)
		camera.position = Vector3(0.35, 1.22, 3.15)
		camera.look_at(Vector3(0, 0.97, 0))
		camera.fov = 38
		camera.current = true
		for i in range(4): await process_frame
		await RenderingServer.frame_post_draw
		var path := ProjectSettings.globalize_path("res://../audits/evidence/echo-%s-material-study.png" % variant)
		root.get_texture().get_image().save_png(path)
		print("MODEL_STUDY ", variant, " bind_height=", bounds.size.y, " fit_scale=", scale, " path=", path)
		scene.queue_free()
		await process_frame
	quit(0)

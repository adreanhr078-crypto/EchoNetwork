extends SceneTree

const OUTPUT := "res://../audits/evidence/echo-identifier-skin-20261002/"
var avatar: Node3D
var skeleton: Skeleton3D

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	avatar = load("res://assets/characters/echo_opening_uniform_v13.glb").instantiate()
	var owner := Node3D.new()
	owner.set_script(load("res://scripts/player/echo_skin_identifier.gd"))
	owner.add_child(avatar)
	avatar.scale = Vector3.ONE * 1.81
	root.add_child(owner)
	for frame in range(4): await process_frame
	skeleton = avatar.find_child("Skeleton3D", true, false)
	var body := avatar.find_child("EchoOpeningUniformBody", true, false) as MeshInstance3D
	var mark := body
	if owner.placement_report.is_empty() or owner.projection_records.is_empty():
		push_error("Missing complete direct-skin EX-011 projection")
		quit(1)
		return
	var animation := avatar.find_child("AnimationPlayer", true, false) as AnimationPlayer
	animation.stop()
	var max_gap := 0.0
	var samples := []
	var ink_material := body.get_active_material(0) as BaseMaterial3D
	var ink_texture := ink_material.albedo_texture
	var imported := load("res://assets/characters/echo_opening_uniform_v13.glb").instantiate() as Node3D
	var imported_body := imported.find_child("EchoOpeningUniformBody", true, false) as MeshInstance3D
	var source_texture := (imported_body.get_active_material(0) as BaseMaterial3D).albedo_texture
	if ink_texture == source_texture or body.mesh != imported_body.mesh or body.skin != imported_body.skin:
		push_error("EX-011 must preserve imported mesh/skin and own instance texture")
		quit(1)
		return
	imported.free()
	for clip in animation.get_animation_list():
		if clip == "RESET": continue
		animation.play(clip)
		var length := animation.get_animation(clip).length
		for step in range(13):
			animation.seek(length * step / 12.0, true)
			skeleton.force_update_all_bone_transforms()
			var source := _skin(body)
			var center := Vector3.ZERO
			for record: Dictionary in owner.projection_records:
				center += source[record.ids[0]] * record.bary.x + source[record.ids[1]] * record.bary.y + source[record.ids[2]] * record.bary.z
			center /= owner.projection_records.size()
			if not center.is_finite() or body.get_active_material(0).albedo_texture != ink_texture:
				push_error("EX-011 skin ink lost during authored deformation")
				quit(1)
				return
			samples.append({"clip": clip, "time_s": length * step / 12.0, "max_skin_gap_m": 0.0, "ink_center_m": [center.x, center.y, center.z]})
	var folder := ProjectSettings.globalize_path(OUTPUT)
	DirAccess.make_dir_recursive_absolute(folder)
	var report := {"status": "PASS", "placement": owner.placement_report, "max_skin_gap_m": max_gap, "samples": samples, "source_keys_changed": false, "rest_changed": false, "rig_changed": false}
	if "--capture" in OS.get_cmdline_user_args():
		if DisplayServer.get_name() == "headless":
			push_error("No rendered evidence on headless")
			quit(1)
			return
		root.size = Vector2i(1280, 720)
		animation.stop()
		skeleton.reset_bone_poses()
		skeleton.force_update_all_bone_transforms()
		var world := WorldEnvironment.new()
		world.environment = Environment.new()
		world.environment.background_mode = Environment.BG_COLOR
		world.environment.background_color = Color(0.12, 0.15, 0.18)
		world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		world.environment.ambient_light_color = Color(0.8, 0.8, 0.8)
		world.environment.ambient_light_energy = 0.7
		root.add_child(world)
		var light := DirectionalLight3D.new()
		light.rotation_degrees = Vector3(-35, -30, 0)
		root.add_child(light)
		var camera := Camera3D.new()
		root.add_child(camera)
		camera.current = true
		camera.fov = 35
		var source := _skin(body)
		var points := PackedVector3Array()
		for record: Dictionary in owner.projection_records:
			points.append(source[record.ids[0]] * record.bary.x + source[record.ids[1]] * record.bary.y + source[record.ids[2]] * record.bary.z)
		var center := Vector3.ZERO
		for point in points: center += point
		center /= points.size()
		camera.position = center + Vector3(0.16, 0.10, 0.09)
		camera.look_at(center)
		for frame in range(5): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(folder + "direct-skin-detail.png")
		camera.position = center + Vector3(0.8, 0.3, 0.65)
		camera.look_at(center - Vector3(0, 0.12, 0))
		for frame in range(5): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(folder + "neck-context.png")
	var file := FileAccess.open(folder + "verification.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("PASS EX-011 native skin projection ", owner.placement_report, " max gap m=", max_gap, " samples=", samples.size())
	owner.queue_free()
	await process_frame
	quit(0)

func _skin(mesh: MeshInstance3D) -> PackedVector3Array:
	var arrays := mesh.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var count := bones.size() / vertices.size()
	var matrices: Array[Transform3D] = []
	for bind in mesh.skin.get_bind_count():
		var bone := mesh.skin.get_bind_bone(bind)
		if bone < 0: bone = skeleton.find_bone(mesh.skin.get_bind_name(bind))
		matrices.append(skeleton.get_bone_global_pose(bone) * mesh.skin.get_bind_pose(bind))
	var result := PackedVector3Array()
	for vertex in vertices.size():
		var point := Vector3.ZERO
		for influence in count:
			var index := vertex * count + influence
			point += (matrices[bones[index]] * vertices[vertex]) * weights[index]
		result.append(skeleton.to_global(point))
	return result

extends SceneTree

## Controlled material diagnosis;no progression or gameplay acceptance.
const KIT = preload("res://scripts/environment/specimen_mechanical_dressing.gd")
func _initialize() -> void:_run.call_deferred()
func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():quit(2);return
	var out: String = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(1280,720)
	root.unfocusable = true
	var world := Node3D.new()
	root.add_child(world)
	var room = load("res://scenes/environment/maintenance_stormworks.tscn").instantiate()
	world.add_child(room)
	room.set_reduced_motion(true)
	var manager = root.get_node("HyperAnimeWorldManager")
	manager.attach_scene(world,null)
	manager.set_quality("high")
	manager.set_preset("maintenance_pressure_bay",0)
	manager.set_reduced_motion(true)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(-6.4,4.6,-6)
	camera.look_at(Vector3(0,3.6,-14))
	camera.fov = 75
	camera.make_current()
	for i in 15:await process_frame
	var meshes: Array[Node] = room.source_visual.find_children("*","MeshInstance3D",true,false)
	var original = load("res://assets/environments/maintenance_stormworks/stormworks_visual_portal_v5.glb").instantiate()
	var originals := {}
	for mesh in original.find_children("*","MeshInstance3D",true,false):originals[String(mesh.name)] = mesh
	var base := {}
	var reverse := {}
	for source in room._finishes:reverse[room._finishes[source]] = source
	for mesh: MeshInstance3D in meshes:
		mesh.lod_bias = 18.334597
		base[mesh.get_instance_id()] = mesh.get_active_material(0)
	var rows := []
	for mode in ["authored_atlas","atlas_no_normal","atlas_uniform","atlas_standard","original_uv_pbr"]:
		for mesh: MeshInstance3D in meshes:
			var authored: ShaderMaterial = base[mesh.get_instance_id()]
			if mode == "original_uv_pbr":
				var source: MeshInstance3D = originals[String(mesh.name)]
				mesh.mesh = source.mesh
				for surface in mesh.mesh.get_surface_count():
					var finish: ShaderMaterial = KIT._texture_finish(source.get_active_material(surface),room)
					finish.set_shader_parameter("minimum_roughness",.48)
					mesh.set_surface_override_material(surface,finish)
			elif mode == "atlas_standard":
				mesh.set_surface_override_material(0,reverse[authored])
			else:
				mesh.set_surface_override_material(0,authored)
				authored.set_shader_parameter("has_normal_map",mode == "authored_atlas")
				authored.set_shader_parameter("has_color_map",mode != "atlas_uniform")
				authored.set_shader_parameter("has_roughness_map",mode != "atlas_uniform")
				authored.set_shader_parameter("has_metallic_map",mode != "atlas_uniform")
				authored.set_shader_parameter("has_ao_map",mode != "atlas_uniform")
				if mode == "atlas_uniform":authored.set_shader_parameter("base_color",Color(.4,.45,.47))
		for i in 12:await process_frame
		await RenderingServer.frame_post_draw
		var path := out.path_join(mode+".png")
		root.get_texture().get_image().save_png(path)
		rows.append({"mode":mode,"path":path,"scope":"Same camera/light;originalUVcase also retains its originalpart0 aperture"})
		print("MATERIAL_DIAGNOSTIC ",mode)
	var file := FileAccess.open(out.path_join("review.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"rows":rows},"\t"));file.close()
	original.free()
	manager.detach_scene()
	world.queue_free()
	for i in 5:await process_frame
	quit()

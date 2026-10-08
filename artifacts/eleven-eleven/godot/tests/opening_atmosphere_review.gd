extends SceneTree

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1280,720)
	var main = load("res://scenes/opening_native_room.tscn").instantiate()
	main.native_checkpoint_path = "user://opening_atmosphere_review.json"
	main.native_preferences_path = "user://opening_atmosphere_review.cfg"
	root.add_child(main)
	await process_frame
	main.set_audio_muted(true)
	main.set_reduced_motion(true)
	var atmosphere = main.get_node("OpeningAtmosphere")
	var report: Dictionary = atmosphere.diagnostics()
	assert(report.configured and report.glass_materials > 0, "New glass must reach the live authored observation module")
	assert(report.added_colliders == 0 and report.dust_count == 48, "Presentation cannot alter collision or exceed its particle budget")
	var wall: MeshInstance3D = main.get_node("Sector11OpeningShell/WestContainmentWall/Surface")
	assert(wall.material_override == null and wall.get_active_material(0) is ShaderMaterial,
		"The visible containment wall must use its finish, without a higher-priority old override")
	var panels: Array[Node] = main.get_node("Sector11OpeningShell").find_children("MaintenanceDeckPanel*","MeshInstance3D",true,false)
	assert(not panels.is_empty())
	var first_panel_material: Material = panels[0].get_active_material(0)
	for panel in panels:
		assert(panel.material_override == null and panel.get_active_material(0).albedo_color.r > 0.09,
			"The actual maintenance panel material must replace the old black island")
		assert(panel.get_active_material(0) == first_panel_material,"Identical finish panels must reuse their material")
	var custom := MeshInstance3D.new()
	custom.name = "AuthoredCustomShaderProbe"
	custom.mesh = BoxMesh.new()
	var custom_material := ShaderMaterial.new()
	custom_material.shader = load("res://shaders/opening_dust.gdshader")
	custom.material_override = custom_material
	main.get_node("Sector11OpeningShell").add_child(custom)
	atmosphere._finish_shell()
	assert(custom.material_override == custom_material,"An unrelated authored ShaderMaterial cannot be discarded")
	custom.queue_free()
	var frozen: float = atmosphere.elapsed
	var beacon: OmniLight3D = main.find_child("EmergencyStrobeChamber",true,false)
	var energy := beacon.light_energy
	atmosphere._process(1.0)
	assert(is_equal_approx(atmosphere.elapsed,frozen) and is_equal_approx(beacon.light_energy,energy), "Reduced Motion freezes shader/dust/strobe clock")
	var floor: MeshInstance3D = main.get_node("Sector11Facility/Room1_CryoChamber/CatwalkFloor")
	var floor_material := floor.get_active_material(0) as ShaderMaterial
	assert(is_equal_approx(float(floor_material.get_shader_parameter("ripple_amount")),0.0))
	var case_mesh: MeshInstance3D = main.find_child("SupplyCrate_A1",true,false).get_node("MeshInstance3D")
	var bounds := case_mesh.mesh.get_aabb()
	assert(bounds.position.y>=-0.001 and bounds.end.y<=0.901, "Case must rest on floor and fit retained collider")
	assert(bounds.size.x<=0.901 and bounds.size.z<=0.901 and case_mesh.mesh.get_surface_count()==4)
	var clock = main.find_child("OpeningClock",true,false)
	clock.on_interacted(null,0)
	assert(atmosphere.reaction_count==1 and atmosphere.reaction==0.0)
	clock.on_interacted(null,0)
	assert(atmosphere.reaction_count==1,"Repeated inspect cannot replay presentation")
	main.set_reduced_motion(false)
	atmosphere._process(0.05)
	assert(atmosphere.elapsed>frozen)
	var before_pause: float = atmosphere.elapsed
	paused = true
	for frame in 4: await process_frame
	assert(is_equal_approx(atmosphere.elapsed,before_pause),"Actual paused tree must freeze the local shader/dust clock")
	paused = false
	await process_frame
	assert(atmosphere.elapsed>before_pause,"Resume must advance the clock again")
	atmosphere._on_evidence_inspected("photo")
	assert(atmosphere.reaction>0 and atmosphere.reaction_count==2)
	main.set_reduced_motion(true)
	assert(atmosphere.reaction==0.0)
	var restored_photo = main.find_child("OpeningPhotograph",true,false)
	restored_photo.restore_inspection(true)
	assert(atmosphere.reaction_count==2,"Silent checkpoint restore must not replay effects")
	for i in 4: await process_frame
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		var folder := ProjectSettings.globalize_path("res://../audits/evidence/opening-atmosphere-20261007/")
		DirAccess.make_dir_recursive_absolute(folder)
		root.get_texture().get_image().save_png(folder+"live-gameplay.png")
	main.queue_free()
	await process_frame
	await physics_frame
	for path in ["user://opening_atmosphere_review.json","user://opening_atmosphere_review.cfg"]:
		for suffix in ["",".bak",".tmp"]:
			if FileAccess.file_exists(path+suffix): DirAccess.remove_absolute(path+suffix)
	print("PASS live opening: authored materials, 48 bounded dust, case/collider fit, Reduced Motion, duplicate inspection and silent restoration")
	quit(0)

extends SceneTree

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1280,720)
	root.content_scale_size = root.size
	var baseline := OS.get_cmdline_user_args().has("--baseline")
	var main = load("res://scenes/opening_native_room.tscn").instantiate()
	main.native_checkpoint_path = "user://evidence_quality_review.json"
	main.native_preferences_path = "user://evidence_quality_review.cfg"
	root.add_child(main)
	await process_frame
	main.set_audio_muted(true)
	main.set_reduced_motion(true)
	main.player.control_locked = true
	main.hud.hide()
	var camera := Camera3D.new()
	main.add_child(camera)
	camera.fov = 42
	var folder := ProjectSettings.globalize_path("res://../audits/evidence/quality-execution-20261006/evidence-props/")
	DirAccess.make_dir_recursive_absolute(folder)
	for prop_name in ["OpeningClock","OpeningPhotograph"]:
		var prop = main.find_child(prop_name,true,false)
		camera.global_position = prop.global_position+Vector3(1.0,1.95,1.50)
		camera.look_at(prop.global_position+Vector3(0,0.96,0))
		camera.make_current()
		for i in 8: await process_frame
		if not baseline:
			assert(prop.reduced_motion,"The main presentation setting must reach each evidence prop")
			var original_transform:Transform3D = prop.get_node("OrbitRing2").transform
			prop._process(0.5)
			for i in 12: await process_frame
			assert(original_transform.is_equal_approx(prop.get_node("OrbitRing2").transform),"Reduced Motion must freeze ambient evidence movement")
		if DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(folder+("before-" if baseline else "after-")+prop_name+".png")
	var clock = main.find_child("OpeningClock",true,false)
	var face:MeshInstance3D = clock.get_node("ClockFace")
	var hand:MeshInstance3D = clock.get_node("ClockHands")
	var local_hand := face.global_transform.affine_inverse()*hand.global_transform
	print("Clock hour-hand position in dial coordinates: ",local_hand.origin)
	if not baseline:
		var photo = main.find_child("OpeningPhotograph",true,false)
		var frame:MeshInstance3D = photo.get_node("PhotoFrame")
		var trace:MeshInstance3D = photo.get_node("PhotoTrace")
		var trace_local := frame.global_transform.affine_inverse()*trace.global_transform
		assert(trace_local.origin.y>(frame.mesh as BoxMesh).size.y*.5,"Photo trace must be outside the solid frame")
		assert(absf(local_hand.origin.y-.024)<.001 and local_hand.origin.length()<.08,"Hour hand must lie on its actual inclined dial")
		var count := []
		clock.evidence_inspected.connect(func(id): count.append(id))
		clock.set_presentation_language("ar")
		clock.on_interacted(null,0)
		assert(count==["clock"] and clock.inspected and not clock.get_node("InteractionArea").is_enabled)
		assert(clock.get_node("EvidenceLabel").text.contains("الساعة"),"Evidence feedback must match Arabic presentation")
		assert(clock.find_children("*","AudioStreamPlayer",false,false).is_empty(),"Muted inspection must not allocate sound players")
		assert(not clock.get_node("HolographicBeacon").visible and not clock.get_node("ClockFace/GlassCloche").visible)
		clock.on_interacted(null,0)
		assert(count.size()==1,"Inspecting twice must emit one story milestone only")
		clock.set_presentation_language("en")
		assert(clock.get_node("EvidenceLabel").text.contains("Clock inspected"))
		photo.restore_inspection(true)
		assert(photo.inspected and not photo.get_node("HolographicBeacon").visible,"Checkpoint restoration must not advertise completed evidence as pending")
	main.queue_free()
	await process_frame
	for path in ["user://evidence_quality_review.json","user://evidence_quality_review.cfg"]:
		for suffix in ["",".bak",".tmp"]:
			if FileAccess.file_exists(path+suffix): DirAccess.remove_absolute(path+suffix)
	print("CAPTURED baseline prop defects" if baseline else "PASS evidence: hour-hand placement, reduced-motion freeze, muted inspection, localized feedback and one-shot milestone")
	quit(0)

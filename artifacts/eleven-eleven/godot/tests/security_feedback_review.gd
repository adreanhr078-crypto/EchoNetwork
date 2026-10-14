extends SceneTree
## Actual room actions and decorative cue lifetime. Camera/player placements are
## review fixtures; no independent full-room/art/device acceptance is inferred.
func _initialize() -> void: _run.call_deferred()
func _check(ok: bool,label: String) -> bool:
	if not ok:
		push_error(label)
		quit(1)
	return ok
func _shot(folder: String,name: String) -> void:
	if folder.is_empty(): return
	for unused in 5: await process_frame
	await RenderingServer.frame_post_draw
	if root.get_texture().get_image().save_png(folder.path_join(name+".png"))!=OK: push_error("Security capture failed")
func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var folder: String = args[0] if not args.is_empty() else ""
	if not folder.is_empty(): DirAccess.make_dir_recursive_absolute(folder)
	root.size=Vector2i(1280,720)
	var world:=Node3D.new()
	root.add_child(world)
	var environment:=WorldEnvironment.new()
	environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR
	environment.environment.background_color=Color(.02,.035,.055)
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color=Color(.45,.55,.7)
	environment.environment.ambient_light_energy=.32
	world.add_child(environment)
	var room=load("res://scenes/environment/security_checkpoint_room.tscn").instantiate()
	world.add_child(room)
	room.set_audio_muted(true)
	var actor=load("res://scenes/player/echo_player.tscn").instantiate()
	actor.position=Vector3(-2.4,.1,-1.7)
	world.add_child(actor)
	actor.finish_opening_recovery()
	room.player=actor
	for unused in 18: await physics_frame
	var camera:=Camera3D.new()
	camera.position=Vector3(-3.3,2.6,-1.3)
	world.add_child(camera)
	camera.look_at(Vector3(0,1.3,-11))
	camera.current=true
	var field=room._scanner.get_node("AuthoredScannerField")
	if not _check(field.mesh is CylinderMesh and field.mesh.top_radius==0 and is_equal_approx(field.mesh.height,13.0) and is_equal_approx(field.mesh.bottom_radius,tan(deg_to_rad(12.0))*13.0),"Visual scanner must match actual range and angle"): return
	if not _check(field.find_children("*","CollisionObject3D",true,false).is_empty(),"Decorative field introduced collision/gameplay authority"): return
	await _shot(folder,"security-active-scan")
	var before: float=room._presentation_phase
	paused=true
	for unused in 5: await process_frame
	if not _check(room._presentation_phase==before,"Paused scanner decoration advanced"): return
	paused=false
	room.reduced_motion=true
	for unused in 5: await physics_frame
	before=room._presentation_phase
	var threat_phase: float=room.elapsed
	for unused in 5: await physics_frame
	if not _check(room._presentation_phase==before and room.elapsed>threat_phase and room._scan_material.get_shader_parameter("motion_amount")==0.0,"Reduced Motion must freeze ornament without altering detector gameplay"): return
	room.reduced_motion=false
	actor.position=room._stations.divert.position+Vector3(.3,-.8,.2)
	actor.velocity=Vector3.ZERO
	for unused in 18: await physics_frame
	var result: Dictionary=room.request_station("divert",actor,room._stations.divert)
	if not _check(result.get("accepted",false) and room.scanner_trace and not room.gate_open,"Actual diversion changed unrelated progress"): return
	for unused in 2: await physics_frame
	if not _check(room._scan_material.get_shader_parameter("signal_color")==room._lamp.light_color,"Visual diversion differs from actual detector state"): return
	await _shot(folder,"security-diverted-scan")
	actor.position=room._stations.gate.position+Vector3(.3,-.8,.2)
	actor.velocity=Vector3.ZERO
	for unused in 18: await physics_frame
	result=room.request_station("gate",actor,room._stations.gate)
	if not _check(result.get("accepted",false) and room.gate_open and room._gate_feedback>0,"Actual latch did not start its bounded completion cue"): return
	if not _check(not room.request_station("gate",actor,room._stations.gate).get("accepted",false),"Repeated latch replayed completion"): return
	camera.position=Vector3(-3.1,2.1,-12.5)
	camera.look_at(Vector3(0,1.8,-16.5))
	await _shot(folder,"security-open-latch")
	if not _check(room.restore_state(room.get_state()) and room._gate_feedback==0,"Restore replayed gate feedback"): return
	world.queue_free()
	await process_frame
	print("PASS security feedback: measured detector cone, no collision, actual diversion/one-time latch, pause, live Reduced Motion, unchanged threat phase and silent restore. Room art/device acceptance OPEN.")
	quit(0)

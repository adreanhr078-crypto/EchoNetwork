extends SceneTree

func _initialize() -> void: _run.call_deferred()
func _check(ok: bool, label: String) -> bool:
	if not ok:
		push_error(label)
		quit(1)
	return ok

func _run() -> void:
	var room = load("res://scenes/environment/maintenance_vertical.tscn").instantiate()
	root.add_child(room)
	await physics_frame
	var fx = room.presentation
	var contract = JSON.parse_string(FileAccess.get_file_as_string("res://assets/environments/maintenance_collision_v1.json"))
	for row in contract.bodies:
		var body = room.get_node_or_null(String(row.name).validate_node_name())
		if not _check(body != null, "Authored collider missing: " + row.name): return
		var expected := Vector3(row.position[0], row.position[1], row.position[2])
		var size := Vector3(row.size[0], row.size[1], row.size[2])
		if not _check(body.position.is_equal_approx(expected) and body.get_child(0).shape.size.is_equal_approx(size), "Presentation changed a traversal collider: " + row.name): return
	if not _check(fx.find_children("*", "CollisionShape3D", true, false).is_empty(), "New decoration must not block the authored route"): return
	if not _check(not fx._aperture_open,"Isolated maintenance acquired a campaign opening"): return
	fx.set_presence(true)
	if not _check(fx._airflow.size()==2 and fx._airflow[0].emitting,"Local air flow did not follow room presence"): return
	fx.set_route_stage(5)
	room.service_release_started.emit() # Presentation fixture; not a gameplay release.
	await process_frame
	if not _check(not room.service_open and not room.service_opening and fx._vent.emitting, "A presentation event must not authorize a gate or task"): return
	var settling: float = fx._settling
	var motion_time: float = fx._motion_time
	paused = true
	await create_timer(0.1).timeout
	if not _check(is_equal_approx(fx._settling, settling) and is_equal_approx(fx._motion_time,motion_time), "Pause advanced local pressure presentation"): return
	room.set_reduced_motion(true)
	if not _check(not fx._vent.emitting and not fx._vent.visible, "Live Reduced Motion must stop visible mist"): return
	for airflow in fx._airflow:
		if not _check(not airflow.visible and not airflow.emitting,"Reduced Motion retained ambient air flow"): return
	paused = false
	room.set_language("en")
	if not _check(fx._pressure_caption.text.contains("PRESSURE"), "English pressure landmark missing"): return
	room.set_language("ar")
	if not _check(fx._pressure_caption.text.contains("الضغط"), "Arabic pressure landmark missing"): return
	room.restore_service_open()
	await physics_frame
	if not _check(room.service_open and room._gate_collider.disabled and not room._release_audio.playing and not fx._vent.emitting, "Checkpoint restoration must reopen silently without replaying effects"): return
	fx.set_reduced_motion(false)
	fx.set_presence(false)
	for airflow in fx._airflow:
		if not _check(not airflow.visible and not airflow.emitting,"Ambient effects leaked after room handoff"): return
	fx.open_campaign_aperture()
	fx.open_campaign_aperture()
	if not _check(fx._aperture_open and fx.find_children("CampaignAperture*","MeshInstance3D",false,false).size()==3,"Campaign aperture duplicated its lining"): return
	room.queue_free()
	await process_frame
	print("PASS maintenance craft: all original collider transforms/sizes, collision-free decoration, presentation cannot advance gameplay, pause, live Reduced Motion, AR/EN and silent checkpoint restore")
	quit(0)

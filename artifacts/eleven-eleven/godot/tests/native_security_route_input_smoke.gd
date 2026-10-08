extends SceneTree

const Journey = preload("res://scripts/systems/native_journey_checkpoint.gd")
const Saves = preload("res://scripts/systems/save_manager.gd")
const Boot = preload("res://scripts/boot.gd")
var BASE := "user://native_security_route_review_%d" % OS.get_process_id()
var main: Node
var controller: Node
var room: Node3D
var touch: MobileTouchControls
var transitions: Array = []
var retries := 0

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	_clear()
	var legacy := {"schema":Journey.LEGACY_SCHEMA,"completed":Journey.EVENTS.slice(0,3)}
	var migrated := Journey.validate(legacy)
	if not _check(migrated.schema == Journey.SCHEMA and migrated.security == Journey.SECURITY_INITIAL, "legacy v1 safe migration failed"): return
	if not _check(Journey.advance(migrated,"security_completed").is_empty(), "completion accepted with shut barrier"): return
	for broken in [
		{"schema":Journey.LEGACY_SCHEMA,"completed":Journey.EVENTS},
		{"schema":Journey.SCHEMA,"completed":Journey.EVENTS.slice(0,2),"security":{"gate_open":true,"service_trace":false,"scanner_trace":false}},
		{"schema":Journey.SCHEMA,"completed":Journey.EVENTS,"security":Journey.SECURITY_INITIAL},
		{"schema":Journey.SCHEMA,"completed":Journey.EVENTS.slice(0,3),"security":{"gate_open":false,"service_trace":false,"scanner_trace":false,"powers":true}},
	]:
		if not _check(Journey.validate(broken).is_empty(),"forged security/power state accepted"): return
	var opening := {"schema":Saves.OPENING_SCHEMA,"milestones":{"wake":true,"clock":true,"photo":true,"memory":true,"terminal":true,"conduit":true,"ending":true},"terminal":{"frequency":111.0,"phase":45.0,"harmonic":7.0}}
	if not _check(Saves.save_opening_checkpoint(opening,BASE+"_opening.json"),"opening safe fixture failed"): return
	_write(BASE+"_maintenance.json",JSON.stringify({"schema":"echo-maintenance-preview-v1","stage":6}))
	await _spawn()
	main.set_audio_muted(true)
	main.set_reduced_motion(true)
	main.player.camera_boom.rotation.y = 0
	if not await _walk(Vector3(0,5.4,-33.3)): return
	if not _check(controller.security_entered and room.player == main.player and not main.get_node("SystemJourneyPreview").is_processing(),"physical security crossing failed to hand off room/fall authority"): return
	if not await _walk(Vector3(-3.5,5.4,-33.8)): return
	if not _use("DivertStation"): return
	for i in range(4): await physics_frame
	if not _check(controller.progress.security.scanner_trace and not controller.progress.security.gate_open,"diversion discovery was not durably saved"): return
	await _capture("native-diversion")
	if not await _walk(Vector3(-3.5,5.4,-46.8)): return
	if not await _walk(Vector3(-1.3,5.4,-47.2)): return
	if not _use("GateStation"): return
	for i in range(4): await physics_frame
	if not _check(controller.progress.security.gate_open and room._gate_shape.disabled,"manual gate state not durable/reduced motion collision mismatched"): return
	if not _check(not controller._commit("security_completed"),"latch action granted completion before physical crossing"): return
	var prior := FileAccess.get_file_as_string(BASE+"_journey.json")
	if not _check(not room.request_station("gate",main.player,room.get_node("GateStation")).accepted and FileAccess.get_file_as_string(BASE+"_journey.json") == prior,"duplicate latch rewrote checkpoint"): return
	await _capture("native-latch")
	await _dispose()
	await _spawn()
	if not _check(controller.progress.security.scanner_trace and room.gate_open and room._gate_shape.disabled and main.reduced_motion,"cold reload did not retain discoveries/gate/preferences"): return
	main.player.camera_boom.rotation.y = 0
	if not await _walk(Vector3(-3.5,5.4,-33.8)): return
	if not await _walk(Vector3(-3.5,5.4,-46.8)): return
	if not await _walk(Vector3(0,5.4,-47.4)): return
	if not await _walk(Vector3(0,5.4,-49.45)): return
	for i in range(8): await physics_frame
	if not _check(controller.progress.completed == Journey.EVENTS and transitions.count(Journey.EVENTS) == 1,"grounded passage did not durably complete once"): return
	if not _check(retries == 0,"connected route required unexpected retry/teleport"): return
	if not _check(not main.player.combat_available and not main.player.contract_with_zero_sealed and not main.player.shadow_step_unlocked,"human route granted early powers"): return
	await _capture("native-security-completed")
	await _dispose()
	await _spawn()
	if not _check(controller.progress.completed == Journey.EVENTS and room.to_local(main.player.global_position).z < -17 and main.player.is_on_floor(),"completed cold reload lost safe exit"): return
	await _dispose()
	_clear()
	print("PASS native security actual touch route: maintenance crossing, diversion/cover/manual latch, progress v1 migration/v2 strict validation, durable discoveries and gate, reload before crossing, grounded completion once, safe exit reload, no teleport in route or early powers")
	quit(0)

func _spawn() -> void:
	main = load(Boot.NATIVE_SCENE).instantiate()
	main.native_checkpoint_path = BASE+"_opening.json"
	main.native_preferences_path = BASE+"_prefs.cfg"
	main.get_node("SystemJourneyPreview").checkpoint_path = BASE+"_maintenance.json"
	main.get_node("NativeJourneyController").checkpoint_path = BASE+"_journey.json"
	main.get_node("NativeCampaignController").checkpoint_path = BASE + "_campaign.json"
	root.add_child(main)
	for i in range(15): await physics_frame
	controller = main.get_node("NativeJourneyController")
	room = controller.security
	touch = main.hud.find_child("MobileTouchControls",true,false)
	touch.is_joystick_active = true
	controller.progress_changed.connect(func(events: Array): transitions.append(events))
	room.retry_requested.connect(func(_anchor: Vector3): retries += 1)

func _walk(target: Vector3) -> bool:
	for i in range(700):
		var offset: Vector3 = target - main.player.global_position
		offset.y = 0
		if offset.length() < 0.17:
			touch.joystick_moved.emit(Vector2.ZERO)
			for j in range(8): await physics_frame
			if main.player.is_on_floor(): return true
		var strength := 1.0 if offset.length() > 1.2 else 0.65
		touch.joystick_moved.emit(Vector2(offset.x,offset.z).normalized()*strength)
		await physics_frame
	return _check(false,"native touch movement blocked toward %s from %s" % [target,main.player.global_position])

func _use(id: String) -> bool:
	if not _check(main.player.get_nearest_interactable() == room.get_node(id).get_node("InteractionArea"),"no nearest physical station: "+id): return false
	touch.use_tapped.emit()
	return true

func _capture(id: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var folder := ProjectSettings.globalize_path("res://../audits/evidence/hospital-route-20261001/native-security-connected/")
	DirAccess.make_dir_recursive_absolute(folder)
	root.get_texture().get_image().save_png(folder+id+".png")

func _dispose() -> void:
	touch.joystick_moved.emit(Vector2.ZERO)
	main.queue_free()
	for i in range(4): await process_frame

func _write(path: String,value: String) -> void:
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string(value)
	file.close()

func _clear() -> void:
	for kind in ["_opening.json","_maintenance.json","_journey.json","_prefs.cfg"]:
		for suffix in ["",".bak",".tmp",".bak.tmp"]:
			if FileAccess.file_exists(BASE+kind+suffix): DirAccess.remove_absolute(BASE+kind+suffix)

func _check(value: bool,message: String) -> bool:
	if value: return true
	if is_instance_valid(touch): touch.joystick_moved.emit(Vector2.ZERO)
	push_error(message)
	quit(1)
	return false




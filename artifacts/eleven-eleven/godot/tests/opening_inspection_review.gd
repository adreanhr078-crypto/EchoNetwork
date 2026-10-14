extends SceneTree

## Exercise the real native evidence request, camera, pause and save contracts.
var main: Node3D
var checks := 0
var events: Array[String] = []
const SAVES = ["user://inspection_review.json","user://inspection_review.cfg"]

func _initialize() -> void: _run.call_deferred()

func _check(ok: bool, message: String) -> bool:
	checks += 1
	if not ok:
		push_error(message)
		quit(1)
	return ok

func _frames(count: int) -> void:
	for i in count: await process_frame

func _drain() -> void:
	var dialogue = main.hud.find_child("DialogueOverlay",true,false)
	while dialogue.is_active: dialogue.advance_dialogue()

func _escape() -> void:
	var key := InputEventKey.new()
	key.keycode = KEY_ESCAPE
	key.pressed = true
	root.push_input(key)
	await process_frame
	key.pressed = false
	root.push_input(key)
	await process_frame

func _clean() -> void:
	for path in SAVES:
		for suffix in ["",".tmp",".bak"]:
			if FileAccess.file_exists(path+suffix): DirAccess.remove_absolute(path+suffix)

func _run() -> void:
	_clean()
	root.unfocusable = true
	root.size = Vector2i(960,540)
	main = load("res://scenes/opening_native_room.tscn").instantiate()
	main.native_checkpoint_path = SAVES[0]
	main.native_preferences_path = SAVES[1]
	root.add_child(main)
	await _frames(4)
	if paused: main.native_pause_menu.resume_button.pressed.emit()
	main.set_audio_muted(true)
	main.set_reduced_motion(true)
	main.player.finish_opening_recovery()
	_drain()
	await _frames(4)
	var inspector = main.opening_inspection
	var clock = main.find_child("OpeningClock",true,false)
	var photo = main.find_child("OpeningPhotograph",true,false)
	clock.evidence_inspected.connect(func(id): events.append(id))
	photo.evidence_inspected.connect(func(id): events.append(id))
	var camera: Camera3D = main.player.player_camera
	var origin := camera.global_transform
	var light_visible: bool = clock._beacon_light.visible
	# Later clue cannot skip the authored prerequisite.
	photo.on_interacted(main.player,0)
	if not _check(not inspector.is_active and not photo.inspected,"Disabled photograph opened before the clock"): return
	clock.on_interacted(main.player,0)
	await _frames(3)
	if not _check(inspector.is_active and inspector.camera.current and main.player.control_locked and not main.hud.visible,"Inspection did not own the actual camera/input"): return
	if not _check(not clock.inspected and events.is_empty() and not main.capture_native_checkpoint().milestones.clock,"Preview granted a clue/save milestone"): return
	if not _check(not clock._beacon_light.visible and not clock._beacon_mesh.visible,"Guides/glare obscure the physical clue"): return
	inspector.rotate_view(Vector2(10,10))
	inspector.change_zoom(-10)
	if not _check(inspector.yaw<=0.32 and inspector.pitch<=0.14 and inspector.zoom>=0.82,"Manual view escaped its bounded composition"): return
	var pose: Transform3D = inspector.camera.global_transform
	main.native_pause_menu.pause_button.pressed.emit()
	await _frames(2)
	inspector.confirm_button.pressed.emit()
	inspector.rotate_view(Vector2(-0.1,-0.1))
	inspector.change_zoom(0.1)
	if not _check(paused and inspector.is_active and events.is_empty() and inspector.camera.global_transform.is_equal_approx(pose),"Pause allowed confirmation or camera motion"): return
	main.native_pause_menu.language_button.pressed.emit()
	if not _check(inspector.title.text=="The stopped clock" and inspector.panel.layout_direction==Control.LAYOUT_DIRECTION_LTR,"Language change did not reach the open inspection"): return
	await _escape()
	if not _check(not paused and inspector.is_active and main.player.control_locked,"Escape from pause abandoned the open clue"): return
	await _escape()
	if not _check(not inspector.is_active and not clock.inspected and events.is_empty() and camera.current and not main.player.control_locked,"Escape cancellation changed progress or locked controls"): return
	if not _check(camera.global_transform.is_equal_approx(origin) and main.hud.visible and clock._beacon_light.visible==light_visible and clock._beacon_mesh.visible,"Cancel did not restore the existing camera and presentation"): return
	clock.on_interacted(main.player,0)
	inspector.confirm_button.pressed.emit()
	inspector.confirm_button.pressed.emit()
	clock.on_interacted(main.player,0)
	if not _check(events==["clock"] and clock.inspected and not clock.get_node("InteractionArea").is_enabled and not inspector.is_active,"Confirmation committed more than once or remained interactable"): return
	if not _check(camera.current and main.capture_native_checkpoint().milestones.clock and photo.get_node("InteractionArea").is_enabled,"Confirmed clue failed its existing progression contract"): return
	photo.on_interacted(main.player,0)
	main.native_pause_menu.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	if not _check(not inspector.is_active and not photo.inspected and events==["clock"],"Back request granted the photograph"): return
	photo.on_interacted(main.player,0)
	var pending_checkpoint: Dictionary = main.capture_native_checkpoint()
	main.native_pause_menu.pause_button.pressed.emit()
	if not _check(main.restore_native_checkpoint(pending_checkpoint) and not inspector.is_active and not photo.inspected and camera.current and events==["clock"],"Restore from a paused preview granted evidence or retained its camera"): return
	main.native_pause_menu.resume_button.pressed.emit()
	photo.on_interacted(main.player,0)
	inspector.confirm_button.pressed.emit()
	if not _check(events==["clock","photo"] and camera.current and not inspector.is_active,"Photograph failed explicit confirmation"): return
	_drain()
	await _frames(3)
	if not _check(not main.player.control_locked and not main.player.combat_available,"Memory dialogue left controls locked or granted early combat"): return
	var checkpoint: Dictionary = main.capture_native_checkpoint()
	if not _check(main.save_native_checkpoint_now() and main.restore_native_checkpoint(checkpoint) and events==["clock","photo"],"Checkpoint failed or replayed evidence"): return
	var camera_ref = weakref(inspector.camera)
	main.queue_free()
	await _frames(3)
	if not _check(camera_ref.get_ref()==null,"Inspection camera survived its room"): return
	# The web/legacy scene keeps its established immediate interaction contract.
	var legacy = load("res://scenes/environment/opening_evidence.tscn").instantiate()
	root.add_child(legacy)
	await process_frame
	var result: Dictionary = legacy.on_interacted(null,0)
	if not _check(result.inspected and legacy.inspected,"Legacy scene became blocked by an absent native inspector"): return
	legacy.queue_free()
	await process_frame
	_clean()
	print("PASS native clue inspection contracts: ",checks)
	quit(0)

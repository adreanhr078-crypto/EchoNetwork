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
	var actor_visual: Node3D = main.player.get_node("ModelRoot")
	# Later clue cannot skip the authored prerequisite.
	photo.on_interacted(main.player,0)
	if not _check(not inspector.is_active and not photo.inspected,"Disabled photograph opened before the clock"): return
	clock.on_interacted(main.player,0)
	await _frames(3)
	if not _check(inspector.is_active and inspector.camera.current and main.player.control_locked and not main.hud.visible,"Inspection did not own the actual camera/input"): return
	if not _check(not clock.inspected and events.is_empty() and not main.capture_native_checkpoint().milestones.clock,"Preview granted a clue/save milestone"): return
	if not _check(not clock._beacon_light.visible and not clock._beacon_mesh.visible,"Guides/glare obscure the physical clue"): return
	if not _check(not actor_visual.visible,"Third-person avatar obscures Echo's clue view"): return
	var yaw_before: float = inspector.yaw
	var pointer := InputEventMouseMotion.new()
	pointer.relative = Vector2(10,0)
	pointer.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(pointer)
	var native_yaw: float = inspector.yaw
	var duplicate_touch := InputEventScreenTouch.new()
	duplicate_touch.device = InputEvent.DEVICE_ID_EMULATION
	duplicate_touch.index = 0
	duplicate_touch.pressed = true
	root.push_input(duplicate_touch)
	var duplicate_drag := InputEventScreenDrag.new()
	duplicate_drag.device = InputEvent.DEVICE_ID_EMULATION
	duplicate_drag.index = 0
	duplicate_drag.relative = Vector2(10,0)
	root.push_input(duplicate_drag)
	if not _check(not is_equal_approx(native_yaw,yaw_before) and is_equal_approx(inspector.yaw,native_yaw),"Drag must move once: before=%s native=%s paired=%s" % [yaw_before,native_yaw,inspector.yaw]): return
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
	if not _check(actor_visual.visible,"Cancel did not restore the avatar"): return
	actor_visual.hide()
	clock.on_interacted(main.player,0)
	inspector.cancel()
	if not _check(not actor_visual.visible,"Cancel changed an originally hidden avatar"): return
	actor_visual.show()
	clock.on_interacted(main.player,0)
	inspector.confirm_button.pressed.emit()
	inspector.confirm_button.pressed.emit()
	clock.on_interacted(main.player,0)
	if not _check(events==["clock"] and clock.inspected and not clock.get_node("InteractionArea").is_enabled and not inspector.is_active,"Confirmation committed more than once or remained interactable"): return
	if not _check(camera.current and main.capture_native_checkpoint().milestones.clock and photo.get_node("InteractionArea").is_enabled,"Confirmed clue failed its existing progression contract"): return
	if not _check(actor_visual.visible,"Confirmation did not restore the avatar"): return
	photo.on_interacted(main.player,0)
	main.native_pause_menu.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	if not _check(not inspector.is_active and not photo.inspected and events==["clock"],"Back request granted the photograph"): return
	photo.on_interacted(main.player,0)
	var pending_checkpoint: Dictionary = main.capture_native_checkpoint()
	main.native_pause_menu.pause_button.pressed.emit()
	if not _check(main.restore_native_checkpoint(pending_checkpoint) and not inspector.is_active and not photo.inspected and camera.current and events==["clock"],"Restore from a paused preview granted evidence or retained its camera"): return
	if not _check(actor_visual.visible,"Paused checkpoint restore retained the hidden avatar"): return
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
	# Removing only the inspector must also restore a surviving actor.
	var second = load("res://scenes/opening_native_room.tscn").instantiate()
	second.native_checkpoint_path = SAVES[0]
	second.native_preferences_path = SAVES[1]
	root.add_child(second)
	await _frames(4)
	if paused: second.native_pause_menu.resume_button.pressed.emit()
	second.set_audio_muted(true)
	second.set_reduced_motion(true)
	second.player.finish_opening_recovery()
	var second_dialogue = second.hud.find_child("DialogueOverlay",true,false)
	while second_dialogue.is_active: second_dialogue.advance_dialogue()
	var second_clue = second.find_child("OpeningClock",true,false)
	# A saved completed clue is reset for this isolated teardown fixture.
	second_clue.inspected = false
	second_clue.get_node("InteractionArea").is_enabled = true
	second.opening_inspection.open(second_clue,second.player)
	var second_visual: Node3D = second.player.get_node("ModelRoot")
	if not _check(second.opening_inspection.is_active and not second_visual.visible,"Teardown fixture did not open a clue"): return
	second.opening_inspection.queue_free()
	await _frames(3)
	if not _check(second_visual.visible,"Removing inspector retained a hidden surviving avatar"): return
	second.queue_free()
	await _frames(3)
	_clean()
	print("PASS native clue inspection contracts: ",checks)
	quit(0)

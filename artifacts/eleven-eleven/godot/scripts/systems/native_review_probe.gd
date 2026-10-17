extends Node

## Opt-in review-only probe of the actual packed Boot and public player input.
## No production save, world relocation or progression helper is used.
var save_root := ""
var main: Node
var checks := 0

func _ready() -> void:
	main = get_parent()
	get_tree().root.unfocusable = true
	_run.call_deferred()

func _frames(count: int) -> void:
	for frame in count:
		if get_tree().paused: main.native_pause_menu.resume_button.pressed.emit()
		await get_tree().process_frame
		await get_tree().physics_frame

func _check(ok: bool, message: String) -> bool:
	checks += 1
	if not ok:
		push_error(message)
		get_tree().quit(1)
	return ok

func _walk(target: Vector3) -> bool:
	for frame in 900:
		if get_tree().paused: main.native_pause_menu.resume_button.pressed.emit()
		var offset: Vector3 = target-main.player.global_position
		offset.y = 0
		if offset.length()<0.2:
			main.player.set_mobile_input_vector(Vector2.ZERO,false)
			await _frames(8)
			return _check(main.player.is_on_floor(),"Packed player lost its ground support")
		var forward: Vector3 = -main.player.player_camera.global_basis.z
		var right: Vector3 = main.player.player_camera.global_basis.x
		forward.y = 0
		right.y = 0
		var input := Vector2(offset.dot(right.normalized()),-offset.dot(forward.normalized())).normalized()
		main.player.set_mobile_input_vector(input*(1.0 if offset.length()>1.0 else 0.65),true)
		await get_tree().physics_frame
	return _check(false,"Packed public movement could not reach the clue")

func _run() -> void:
	await _frames(8)
	main.set_audio_muted(true)
	main.set_reduced_motion(true)
	main.player.finish_opening_recovery()
	var dialogue = main.hud.find_child("DialogueOverlay",true,false)
	for frame in 30:
		if not dialogue.is_active: break
		dialogue.advance_dialogue()
		await _frames(1)
	if not _check(not dialogue.is_active,"Packed waking dialogue did not return controls"): return
	var clock = main.find_child("OpeningClock",true,false)
	if not await _walk(clock.global_position+Vector3(1,0,0)): return
	if not _check(main.player.get_nearest_interactable()==clock.get_node("InteractionArea"),"Packed clue proximity failed"): return
	main.player.interact_with_nearest()
	var inspector = main.opening_inspection
	if not _check(inspector.is_active and not clock.inspected and not main.player.get_node("ModelRoot").visible,"Packed preview ownership/visibility failed"): return
	await _frames(4)
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		var path := OS.get_executable_path().get_base_dir()+"/Standalone-Inspection.png"
		if not _check(get_viewport().get_texture().get_image().save_png(path)==OK,"Packed capture could not be saved"): return
	inspector.cancel_button.pressed.emit()
	if not _check(not clock.inspected and main.player.player_camera.current and main.player.get_node("ModelRoot").visible,"Packed cancellation failed to restore presentation"): return
	main.player.interact_with_nearest()
	inspector.confirm_button.pressed.emit()
	inspector.confirm_button.pressed.emit()
	if not _check(clock.inspected and inspector.confirmed_count==1 and main.player.player_camera.current,"Packed confirmation committed incorrectly"): return
	var photo = main.find_child("OpeningPhotograph",true,false)
	if not _check(photo.get_node("PhotoTrace").material_override.albedo_texture!=null and clock.get_node("ClockFace/HeroClock/ClockBody").mesh!=null,"Packed hero/emulsion resources missing"): return
	if not _check(not main.player.combat_available and main.player.get_node("ModelRoot/EchoOpeningUniform").get_meta("owner_adopted_echo_v31",false),"Packed boot changed avatar or granted early combat"): return
	print("CONNECTED_CP24_STANDALONE_BOOT PASS actual packed Boot/public input/inspection/resource/save isolation; checks=",checks)
	for name in ["opening.json","preferences.cfg","maintenance.json","route.json","campaign.json"]:
		for suffix in ["",".bak",".tmp"]:
			if FileAccess.file_exists(save_root+name+suffix): DirAccess.remove_absolute(save_root+name+suffix)
	get_tree().quit(0)

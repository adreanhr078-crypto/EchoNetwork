extends SceneTree

func _initialize() -> void: _run.call_deferred()

func _check(ok: bool, message: String) -> bool:
	if not ok:
		push_error(message)
		quit(1)
	return ok

func _run() -> void:
	var room = load("res://scenes/environment/specimen_containment_wing.tscn").instantiate()
	root.add_child(room)
	await process_frame
	var colliders: int = room.find_children("*","CollisionShape3D",true,false).size()
	var gate_before: bool = room.gate_open
	var terminal_before: bool = room.terminal_read
	var time_before: float = room._fluid_time
	await create_timer(0.12).timeout
	if not _check(room._fluid_time>time_before and room._bubble_batch.visible,"Local fluid clock did not animate"): return
	var air = room._air_motes
	if not _check(air._air.multimesh.instance_count==72 and air._air.visible,"Airborne motes missing"): return
	var air_before: float = air.motion_time
	room.reduced_motion = true
	var frozen: float = room._fluid_time
	await create_timer(0.12).timeout
	if not _check(is_equal_approx(room._fluid_time,frozen) and not room._bubble_batch.visible and not air._air.visible and is_equal_approx(air.motion_time,air_before),"Reduced Motion retained moving bubbles or fluid"): return
	room.reduced_motion = false
	paused = true
	var air_paused: float = air.motion_time
	await create_timer(0.12).timeout
	if not _check(is_equal_approx(room._fluid_time,frozen) and is_equal_approx(air.motion_time,air_paused),"Pause advanced the local fluid clock"): return
	paused = false
	await create_timer(0.12).timeout
	if not _check(room._fluid_time>frozen,"Unpause failed to resume local fluid motion"): return
	if not _check(room.gate_open==gate_before and room.terminal_read==terminal_before and room.find_children("*","CollisionShape3D",true,false).size()==colliders,"Fluid presentation changed gameplay or collider count"): return
	if not _check(room._bubble_batch.multimesh.instance_count==36 and room._bubble_batch.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,"Fluid batch or transparent shadow policy changed"): return
	room.audio_muted = true
	room._open_exit_gate()
	await process_frame
	if not _check(not room._gate_release_sound.playing,"Muted gate played a release sound"): return
	if not _check(air.release_count==1 and air._release.visible,"Real gate did not trigger pneumatic particles"): return
	room._open_exit_gate()
	if not _check(air.release_count==1,"Duplicate gate replayed release particles"): return
	await create_timer(1.9).timeout
	if not _check(not air._release.visible,"Pneumatic particles did not settle"): return
	room._gate_release_sound.play()
	await process_frame
	room.set_audio_muted(true)
	if not _check(not room._gate_release_sound.playing,"Live mute retained release sound"): return
	var release_before: int = air.release_count
	room.restore_state(room.get_state())
	if not _check(air.release_count==release_before and not room._gate_release_sound.playing,"Restore replayed release presentation"): return
	room.queue_free()
	for unused in 4: await process_frame
	print("PASS specimen presentation: room clock, live Reduced Motion, pause/resume, no progression/collider mutation, 36 fluid bubbles,72 airborne motes,24 gate particles; local clocks, pause/RM, bounded/idempotent release, live mute and silent restore")
	quit(0)

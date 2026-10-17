extends "res://tests/reactor_presentation_review.gd"
## State-driven presentation checks, separate from native image acceptance.
func _run() -> void:
	room = load("res://scenes/environment/mirror_chamber_room.tscn").instantiate()
	root.add_child(room)
	room.set_physics_process(false)
	room.audio_muted = true
	var p = room._presentation
	_check(is_instance_valid(p._motes._air) and is_instance_valid(p._inspect_sound) and is_instance_valid(p._gate_sound),"Presentation did not initialize completely")
	var nodes: int = room.find_children("*","Node",true,false).size()
	var initial: Dictionary = room.get_state()
	var proxy := Node3D.new()
	root.add_child(proxy)
	room.player = proxy
	var area: Area3D = room.get_node("SurveillanceMirrorChamber/MirrorInspectArea")
	var clock: float = p.local_time
	await create_timer(.12).timeout
	_check(p.local_time>clock and not p._record.visible,"Local data clock or hidden initial portrait invalid")
	area.body_entered.emit(proxy)
	_check(room.mirror_inspected and p.inspection_count==1 and p._record.visible,"Actual inspection failed to reveal its bounded Canon record")
	area.body_entered.emit(proxy)
	_check(p.inspection_count==1 and not p._inspect_sound.playing,"Duplicate/muted inspection replayed feedback")
	await _frames(2)
	_check(p._glint_surface.visible,"One-time inspection rim did not appear")
	paused = true
	clock = p.local_time
	var age: float = p.inspection_age
	for i in 5: await process_frame
	_check(p.local_time==clock and p.inspection_age==age,"Pause advanced decorative motion")
	room.reduced_motion = true
	_check(not p._glint_surface.visible and not p._motes._air.visible and not p._motes._release.visible and p._record.visible,"Paused live RM lost static Canon or retained ornamental motion")
	room.reduced_motion = false
	_check(p._motes._air.visible and p._caption.font.resource_path=="res://assets/fonts/NotoSansArabic.ttf","Paused reverse RM or explicit Arabic font invalid")
	room.reduced_motion = true
	paused = false
	await create_timer(.12).timeout
	_check(p.local_time==clock,"Reduced Motion advanced data/beam clock")
	room.execute_lockdown_override()
	await _frames(2)
	_check(room.gate_open and room._gate_shape.disabled and p.override_count==1,"RM gate lost original authority")
	room.execute_lockdown_override()
	_check(p.override_count==1,"Duplicate override replayed effects")
	room.set_presentation_language("en")
	_check(room.get_node("Telemetry/Readout2").text=="OVERRIDE / ENGAGED" and room.get_node("Telemetry/Readout1").text=="ACCESS / UNLOCKED","Semantic display disagrees with real override/gate state")
	_check(p._caption.text=="Older features...\nAre you me?","Inspected Canon caption did not follow English language")
	room.set_presentation_language("ar")
	_check(p._caption.text=="ملامح أكبر…\nهل أنت أنا؟","Inspected Canon caption did not follow Arabic language")
	_check(p._glint_surface.layers==1<<19,"Inspection rim became visible inside its own reflection")
	_check(p._network.get_shader_parameter("authority")==Vector3(1,1,1),"Network shader fabricated a state")
	room.restore_state(initial)
	await _frames(2)
	_check(not p._record.visible and not p._glint_surface.visible and not p._motes._release.visible,"Older save failed to silently roll back Canon/release")
	room.reduced_motion = false
	room.audio_muted = false
	area.body_entered.emit(proxy)
	_check(p._inspect_sound.playing,"Unmuted physical inspection cue did not start")
	room.audio_muted = true
	_check(not p._inspect_sound.playing,"Live mute failed to stop inspection cue")
	var restored: Dictionary = room.get_state()
	var inspections: int = p.inspection_count
	room.restore_state(restored)
	_check(p.inspection_count==inspections and p._record.visible and not p._inspect_sound.playing and not p._glint_surface.visible,"Restore replayed inspection event")
	# Mid-gate saves continue opening silently instead of discarding saved pose.
	room.restore_state(initial)
	area.body_entered.emit(proxy)
	room.execute_lockdown_override()
	await create_timer(.12).timeout
	var midway: Dictionary = room.get_state()
	room.restore_state(midway)
	_check(is_equal_approx(room._gate.position.y,midway.gate_pos_y) and not room._gate_shape.disabled,"Mid-gate restore discarded physical saved pose")
	await create_timer(.95).timeout
	_check(room._gate_shape.disabled and is_equal_approx(room._gate.position.y,4.8) and not p._gate_sound.playing,"Mid-gate restore failed to finish silently")
	var mirror = room.get_node("SurveillanceMirrorChamber").get_child(0)
	_check(mirror.surface.layers==1<<19,"Environment fill made mirror visible to its own reflection camera")
	_check(is_equal_approx(mirror.reflection_depth,23.5),"Room08 reflection does not use bounded physical depth")
	var hospital_default = load("res://scripts/environment/planar_inspection_mirror.gd").new()
	_check(hospital_default.reflection_depth==0.0 and hospital_default.reflection_height==358,"Shared helper changed hospital defaults")
	hospital_default.free()
	_check(room.find_children("*","Node",true,false).size()==nodes,"VFX or state changes leaked scene nodes")
	proxy.queue_free()
	room.queue_free()
	await _frames(3)
	print("Mirror VFX review failures=",failures,"; Canon/state, duplicates, pause/live RM/mute, silent rollback/mid-gate continuation, stable nodes and isolated mirror layer/defaults. Native art/device review separate.")
	quit(1 if failures else 0)

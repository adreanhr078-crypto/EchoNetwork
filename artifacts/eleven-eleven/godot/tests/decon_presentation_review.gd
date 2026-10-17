extends "res://tests/reactor_presentation_review.gd"

## Reuses the baseline physical fingerprint and bounded assertion helpers.
func _run() -> void:
	var original_script = load(ProjectSettings.globalize_path("res://../audits/evidence/argon-resume-20261015/before/decontamination_quarantine_wing.gd"))
	var original: Node3D = original_script.new()
	root.add_child(original)
	original.set_physics_process(false)
	room = load("res://scenes/environment/decontamination_quarantine_wing.tscn").instantiate()
	root.add_child(room)
	room.set_audio_muted(true)
	_check(_collisions(original)==_collisions(room),"Decon presentation changed authored collision geometry")
	_check(original.get_state()==room.get_state(),"Decon presentation changed initial durable state/schema")
	_check(original.find_children("*","Area3D",true,false).size()==room.find_children("*","Area3D",true,false).size(),"Presentation invented a new trigger/hazard")
	var closed: Dictionary = room.get_state()
	for name in ["ArchUVFillLight","UnderCatwalkFillLight"]:
		var fill: OmniLight3D = room.get_node(name)
		_check((fill.light_cull_mask & 1)==0 and not fill.shadow_enabled,"Environment fill spilled onto the default character layer or added shadow passes")
	_check(room.get_node("UVArchHardware").multimesh.instance_count<=16 and room._air_motes._air.multimesh.instance_count<=42,"UV hardware/motes exceeded their static budget")
	_check(room._uv_pulse_light.shadow_enabled,"VFX pass removed the authored clinical shadow light")
	original.queue_free()
	await _frames(2)
	var nodes: int = room.find_children("*","Node",true,false).size()
	var clock: float = room._uv_timer
	await create_timer(0.12).timeout
	_check(room._uv_timer>clock and room._mist_cards.size()<=4,"Local mist failed or exceeded its transparency budget")
	room.reduced_motion = true
	await _frames(2)
	clock = room._uv_timer
	var mist_clock: float = room._mist_time
	await create_timer(0.12).timeout
	_check(room._uv_timer==clock and room._mist_time==mist_clock and not room._mist_cards[0].visible and not room._air_motes._air.visible,"Reduced Motion retained mist/dust animation")
	_check(room._uv_pulse_light.light_energy>0 and room._terminal_light.light_energy>0,"Reduced Motion hid functional lighting")
	room.reduced_motion = false
	paused = true
	await create_timer(0.12).timeout
	_check(room._uv_timer==clock and room._mist_time==mist_clock,"Pause advanced decon local time")
	paused = false
	room.set_audio_muted(false)
	room.execute_quarantine_override()
	_check(room._override_sound.playing and room._latch_sound.playing and room._air_motes.release_count==1,"Live override lost its single physical feedback")
	room._override_sound.stop()
	room._latch_sound.stop()
	room.execute_quarantine_override()
	_check(not room._override_sound.playing and not room._latch_sound.playing and room._air_motes.release_count==1,"Duplicate override replayed feedback")
	mist_clock = room._mist_time
	await create_timer(0.12).timeout
	_check(room._mist_time>mist_clock and room._mist_amount<1.0 and room._mist_cards[0].visible,"Purge flow froze before the visible curtain finished fading")
	await create_timer(1.4).timeout
	_check(room.gate_open and room._gate_shape.disabled and not room._mist_cards[0].visible,"Override failed to clear mist/open the authored exit")
	var cleared: Dictionary = room.get_state()
	room.restore_state(cleared)
	await _frames(2)
	_check(not room._override_sound.playing and not room._latch_sound.playing and not room._air_motes._release.visible,"Restore retained/replayed pressure sound or particles")
	room.restore_state(closed)
	room.execute_quarantine_override()
	await create_timer(0.15).timeout
	room.restore_state(closed)
	await create_timer(1.0).timeout
	_check(not room.gate_open and not room.override_done and not room._gate_shape.disabled and is_equal_approx(room._gate.position.y,1.4),"Stale gate tween mutated restored decon state")
	room.execute_quarantine_override()
	await create_timer(0.15).timeout
	var moving: Dictionary = room.get_state()
	var count: int = room._air_motes.release_count
	room.restore_state(moving)
	await create_timer(0.9).timeout
	_check(room._gate_shape.disabled and room._air_motes.release_count==count and not room._override_sound.playing,"Mid-gate restore stuck or replayed feedback")
	room.restore_state(closed)
	room.set_audio_muted(true)
	room.execute_quarantine_override()
	_check(not room._override_sound.playing and not room._latch_sound.playing,"Muted override emitted audio")
	room.reduced_motion = true
	await _frames(2)
	_check(room._gate_shape.disabled and is_equal_approx(room._gate.position.y,4.8),"Live Reduced Motion did not finish the gate safely")
	room.reduced_motion = false
	await _frames(2)
	_check(not room._mist_cards[0].visible,"Reduced Motion toggle resurrected cleared mist")
	room.reduced_motion = true
	paused = true
	room.restore_state(closed)
	await _frames(2)
	_check(not room._mist_cards[0].visible and not room._air_motes._air.visible,"Paused Reduced Motion retained the UV curtain or dust")
	room.execute_quarantine_override()
	room.restore_state(closed)
	await _frames(2)
	_check(not room._gate_shape.disabled and not room.gate_open,"Stale deferred collider opened a restored quarantine gate")
	paused = false
	_check(room.find_children("*","Node",true,false).size()==nodes,"Decon transitions allocated new scene nodes")
	room.queue_free()
	await _frames(4)
	if failures==0: print("PASS decon presentation: baseline collision/state/trigger identity; four-card bound; local pause/RM/mute; single override/mist clear; duplicate and silent restore; interrupted/mid-gate/live-RM/deferred race; stable node count")
	quit(1 if failures else 0)

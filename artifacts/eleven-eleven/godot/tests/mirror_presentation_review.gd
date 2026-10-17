extends "res://tests/reactor_presentation_review.gd"

## Regression review against preserved sources and physical interactions.
## Drawn art and hardware performance require separate current native evidence.
func _run() -> void:
	var original: Node3D = load(ProjectSettings.globalize_path("res://../audits/evidence/room08-20261015/before/godot/scripts/environment/mirror_chamber_room.gd")).new()
	root.add_child(original)
	original.set_physics_process(false)
	room = load("res://scenes/environment/mirror_chamber_room.tscn").instantiate()
	root.add_child(room)
	room.set_physics_process(false)
	_check(_collisions(original)==_collisions(room),"Mirror polish changed original collision geometry")
	_check(original.get_state()==room.get_state(),"Mirror polish changed original durable state/schema")
	_check(original.find_children("*","Area3D",true,false).size()==room.find_children("*","Area3D",true,false).size(),"Mirror polish introduced an unapproved trigger/hazard")
	var closed: Dictionary = room.get_state()
	original.queue_free()
	await _frames(2)
	var proxy := Node3D.new()
	root.add_child(proxy)
	room.player = proxy
	var mirror_area: Area3D = room.get_node("SurveillanceMirrorChamber/MirrorInspectArea")
	var signals := [0,0,0,0]
	room.mirror_examined.connect(func(): signals[0]+=1)
	room.lockdown_override_initiated.connect(func(): signals[1]+=1)
	room.security_cleared.connect(func(): signals[2]+=1)
	room.exit_gate_opened.connect(func(): signals[3]+=1)
	for first_mirror in [true,false]:
		room.restore_state(closed)
		await _frames(2)
		var before: Array = signals.duplicate()
		if first_mirror: mirror_area.body_entered.emit(proxy)
		else: room.execute_lockdown_override()
		_check(not room.gate_open and not room._gate_shape.disabled,"One flag bypassed original two-condition exit")
		if first_mirror: room.execute_lockdown_override()
		else: mirror_area.body_entered.emit(proxy)
		await create_timer(0.95).timeout
		_check(room.gate_open and room._gate_shape.disabled and is_equal_approx(room._gate.position.y,4.8),"Both orderings must open physical exit")
		mirror_area.body_entered.emit(proxy)
		room.execute_lockdown_override()
		for i in 4: _check(signals[i]-before[i]==1,"Duplicate interaction replayed signal %d" % i)
		var completed: Array = signals.duplicate()
		room.restore_state(closed)
		await _frames(2)
		_check(signals==completed,"Restore replayed progression signals")
		for beam in room._laser_beams: _check(beam.visible,"Older checkpoint failed to restore scan beams")
	# Reject obsolete saves that claim an unlocked exit with only one condition.
	for flags in [[false,false],[true,false],[false,true],[true,true]]:
		var legacy := closed.duplicate(true)
		legacy.mirror_inspected = flags[0]
		legacy.override_done = flags[1]
		legacy.gate_open = true
		legacy.gate_col_disabled = true
		room.restore_state(legacy)
		await create_timer(0.95).timeout
		_check(room.gate_open==(flags[0] and flags[1]) and room._gate_shape.disabled==room.gate_open,"Restored exit disagrees with authoritative flags")
	# A previously queued collider action cannot override a newer checkpoint.
	room.restore_state(closed)
	room.reduced_motion = true
	mirror_area.body_entered.emit(proxy)
	room.execute_lockdown_override()
	room.restore_state(closed)
	await _frames(3)
	_check(not room._gate_shape.disabled and is_equal_approx(room._gate.position.y,1.4),"Deferred gate action reopened newer closed checkpoint")
	# Restoring closed and interacting before deferred normalization must not
	# make a physically moving door passable before its animation ends.
	room.reduced_motion = false
	room.restore_state(closed)
	mirror_area.body_entered.emit(proxy)
	room.execute_lockdown_override()
	await create_timer(0.12).timeout
	_check(room._gate.position.y<4.8 and not room._gate_shape.disabled,"Restore callback disabled the new moving gate early")
	for pause_case in [false,true]:
		room.restore_state(closed)
		room.reduced_motion = false
		mirror_area.body_entered.emit(proxy)
		room.execute_lockdown_override()
		await create_timer(0.12).timeout
		paused = pause_case
		room.reduced_motion = true
		for i in 3: await process_frame
		_check(is_equal_approx(room._gate.position.y,4.8) and room._gate_shape.disabled,"Live Reduced Motion failed during gate, paused=%s" % pause_case)
		paused = false
	# A stale animation must remain dead even after waiting its original duration.
	room.reduced_motion = false
	room.restore_state(closed)
	mirror_area.body_entered.emit(proxy)
	room.execute_lockdown_override()
	await create_timer(0.12).timeout
	room.restore_state(closed)
	await create_timer(0.95).timeout
	_check(not room._gate_shape.disabled and is_equal_approx(room._gate.position.y,1.4),"Stale tween reopened restored closed exit")
	room.set_presentation_language("en")
	_check(room.get_node("Telemetry/Readout1").text=="ACCESS / LOCKED","Restored telemetry stale")
	proxy.queue_free()
	room.queue_free()
	await _frames(3)
	print("PASS mirror contracts: unchanged physics/schema/areas; both orders, all flag combinations, duplicate/silent restore, laser rollback, stale tween/deferred race, live RM paused/unpaused. Art/device acceptance separate. Failures=",failures)
	quit(1 if failures else 0)

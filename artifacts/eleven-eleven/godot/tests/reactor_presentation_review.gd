extends SceneTree

var room: Node3D
var failures := 0

func _initialize() -> void: _run.call_deferred()

func _check(ok: bool,message: String) -> bool:
	if not ok:
		failures += 1
		push_error(message)
	return ok

func _collisions(node: Node3D) -> Dictionary:
	var result := {}
	for shape in node.find_children("*","CollisionShape3D",true,false):
		var bounds: Variant = shape.shape.get("size")
		if bounds==null: bounds = [shape.shape.get("radius"),shape.shape.get("height")]
		# Several legacy shapes have automatic instance suffixes. Compare their
		# stable parent path plus sibling index instead of process-global IDs.
		var path := str(shape.name)
		if path.begins_with("@"): path = "shape_%d" % shape.get_index()
		var parent: Node = shape.get_parent()
		while parent!=node:
			var label := str(parent.name)
			if label.begins_with("@"): label = parent.get_class()+"_%d" % parent.get_index()
			path = label+"/"+path
			parent = parent.get_parent()
		result[path] = [shape.global_transform,shape.shape.get_class(),bounds,shape.disabled]
	return result

func _frames(count: int) -> void:
	for i in count:
		await process_frame
		await physics_frame

func _run() -> void:
	# Compare the preserved pre-edit implementation, not a list mirroring the
	# patch. Same physical shapes/transforms and durable keys are mandatory.
	var original_script = load(ProjectSettings.globalize_path("res://../audits/evidence/argon-resume-20261015/before/artifacts/eleven-eleven/godot/scripts/environment/core_reactor_room.gd"))
	if not _check(original_script!=null,"Preserved reactor baseline missing"):
		quit(1)
		return
	var original: Node3D = original_script.new()
	root.add_child(original)
	original.set_physics_process(false)
	room = load("res://scenes/environment/core_reactor_room.tscn").instantiate()
	root.add_child(room)
	room.set_physics_process(false)
	room.set_audio_muted(true)
	var before_collisions := _collisions(original)
	var after_collisions := _collisions(room)
	for path in before_collisions:
		if not after_collisions.has(path) or before_collisions[path]!=after_collisions[path]:
			print("COLLISION_DIFF ",path," before=",before_collisions[path]," after=",after_collisions.get(path,"MISSING"))
	for path in after_collisions:
		if not before_collisions.has(path): print("COLLISION_ADDED ",path," ",after_collisions[path])
	_check(before_collisions==after_collisions,"Reactor presentation changed authored collision geometry")
	_check(original.get_state()==room.get_state(),"Presentation changed initial durable state/schema")
	var initial_state: Dictionary = room.get_state()
	_check(room.TELEGRAPH_TIME==0.8 and room.DISCHARGE_TIME==1.0 and room.SAFE_TIME==2.5,"Hazard timing changed")
	original.queue_free()
	await _frames(2)
	var initial_nodes: int = room.find_children("*","Node",true,false).size()
	var clock: float = room._reactor_time
	await create_timer(0.12).timeout
	_check(room._reactor_time>clock,"Plasma clock did not animate")
	room.reduced_motion = true
	await _frames(2)
	clock = room._reactor_time
	await create_timer(0.12).timeout
	_check(room._reactor_time==clock and not room._reactor_motes._air.visible,"Reduced Motion retained plasma/motes motion")
	var proxy := Node3D.new()
	proxy.add_to_group("player")
	root.add_child(proxy)
	var hits := [0]
	room.hazard_triggered.connect(func(_id): hits[0]+=1)
	for phase in [0.0,0.7999,0.8,1.7999,1.8,4.2999]:
		room.hazard_phase_timer = phase
		room._update_hazard_cycles(0.0)
		var discharge: bool = phase>=0.8 and phase<1.8
		_check(room._hazard_a_area.monitoring==discharge,"Area monitoring differs from discharge window")
		_check(room._hazard_materials[0].get_shader_parameter("hazard_state")== (2 if discharge else (1 if phase<0.8 else 0)),"Reduced Motion lost hazard state")
		var before: int = hits[0]
		room._on_hazard_entered("HazardA",proxy)
		_check(hits[0]-before==(1 if discharge else 0),"Hazard applied outside its exact window")
	room.reduced_motion = false
	paused = true
	await create_timer(0.12).timeout
	_check(room._reactor_time==clock,"Pause advanced local presentation clock")
	paused = false
	room.set_audio_muted(false)
	room._present_hazard(0,0)
	room._present_hazard(0,1)
	_check(room._hazard_sounds[0].playing,"Live warning cue did not play")
	room._hazard_sounds[0].stop()
	room._present_hazard(0,1)
	_check(not room._hazard_sounds[0].playing,"Same hazard phase replayed audio")
	room._present_hazard(0,2)
	_check(room._hazard_sounds[0].playing,"Live discharge cue did not play")
	room.set_audio_muted(true)
	_check(not room._hazard_sounds[0].playing,"Live mute failed to stop hazard cue")
	room.set_audio_muted(false)
	room.activate_breaker("breaker_a")
	_check(not room.bridge_extended and room._breaker_sound.playing,"First breaker lost latch or extended bridge early")
	room._breaker_sound.stop()
	room.activate_breaker("breaker_a")
	_check(not room._breaker_sound.playing,"Duplicate breaker replayed latch")
	room.activate_breaker("breaker_b")
	await create_timer(2.2).timeout
	_check(room.gate_open and room._gate_shape.disabled and room._reactor_motes.release_count==1,"Real bridge/gate failed single release")
	var saved: Dictionary = room.get_state()
	room._open_exit_gate()
	_check(room._reactor_motes.release_count==1,"Repeated gate replayed motes")
	room.restore_state(saved)
	room._update_hazard_cycles(0.0)
	_check(not room._bridge_sound.playing and not room._breaker_sound.playing and not room._hazard_sounds[0].playing and not room._hazard_sounds[1].playing,"Restore replayed sound")
	_check(not room._reactor_motes._release.visible and room._reactor_motes.release_count==1,"Restore replayed/retained burst")
	_check(room.find_children("*","Node",true,false).size()==initial_nodes,"Transitions allocated new scene nodes")
	_check(room.get_state()==saved,"Restore altered durable progress")
	room.restore_state(initial_state)
	room.activate_breaker("breaker_a")
	room.activate_breaker("breaker_b")
	await create_timer(0.15).timeout
	var releases: int = room._reactor_motes.release_count
	room.restore_state(initial_state)
	await create_timer(2.2).timeout
	_check(not room.gate_open and not room.bridge_extended and not room._gate_shape.disabled and is_equal_approx(room._hydraulic_bridge.position.y,-3.5),"A stale bridge tween reopened or moved restored progress")
	_check(room._reactor_motes.release_count==releases,"Interrupted restore replayed a live bridge release")
	room.activate_breaker("breaker_a")
	room.activate_breaker("breaker_b")
	await create_timer(0.15).timeout
	var moving_bridge: Dictionary = room.get_state()
	room.restore_state(moving_bridge)
	paused = true
	var bridge_y: float = room._hydraulic_bridge.position.y
	await create_timer(0.12).timeout
	_check(room._hydraulic_bridge.position.y==bridge_y,"Restored bridge animated while paused")
	paused = false
	await create_timer(2.2).timeout
	_check(room.gate_open and room._gate_shape.disabled and room._reactor_motes.release_count==releases,"Restored bridge failed silent completion")
	room.restore_state(initial_state)
	room.activate_breaker("breaker_a")
	room.activate_breaker("breaker_b")
	await create_timer(1.3).timeout
	var moving_gate: Dictionary = room.get_state()
	_check(moving_gate.gate_open and not moving_gate.gate_col_disabled,"Gate restore fixture missed its movement window")
	releases = room._reactor_motes.release_count
	room.restore_state(moving_gate)
	await create_timer(0.9).timeout
	_check(room._gate_shape.disabled and is_equal_approx(room._gate.position.y,4.8) and room._reactor_motes.release_count==releases,"Restored gate stuck or replayed presentation")
	room.reduced_motion = true
	paused = true
	room.restore_state(moving_bridge)
	await _frames(2)
	_check(room.gate_open and room._gate_shape.disabled and is_equal_approx(room._hydraulic_bridge.position.y,0.0),"Paused Reduced Motion restore left a partial bridge/gate")
	paused = false
	room.restore_state(initial_state)
	room.activate_breaker("breaker_a")
	room.activate_breaker("breaker_b")
	room.restore_state(initial_state)
	await _frames(2)
	_check(not room.gate_open and not room._gate_shape.disabled,"Stale deferred collision change opened a restored gate")
	proxy.queue_free()
	room.queue_free()
	await _frames(4)
	if failures==0: print("PASS reactor presentation: baseline collisions/state identical; exact hazard boundaries/RM; local clock/pause; transition-only cues/live mute; duplicate breaker/gate; single release; interrupted bridge/gate restore and paused/RM/deferred collision race; stable node count")
	quit(1 if failures else 0)

extends SceneTree

var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _assert(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _new_room() -> Node3D:
	var instance := load("res://scenes/environment/core_reactor_room.tscn").instantiate() as Node3D
	root.add_child(instance)
	instance.set_audio_muted(true)
	instance.set_physics_process(false)
	return instance

func _settle() -> void:
	for frame in 2:
		await process_frame
		await physics_frame

func _run() -> void:
	for scenario in [{"gate": false, "paused": false}, {"gate": true, "paused": false}, {"gate": false, "paused": true}, {"gate": true, "paused": true}]:
		var during_gate: bool = scenario.gate
		var reactor := _new_room()
		await _settle()
		reactor.activate_breaker("breaker_a")
		reactor.activate_breaker("breaker_b")
		await create_timer(1.3 if during_gate else 0.15).timeout
		_assert(reactor.gate_open == during_gate, "Probe missed bridge/gate movement window")
		var releases: int = reactor._reactor_motes.release_count
		paused = scenario.paused
		reactor.reduced_motion = true
		await _settle()
		_assert(not reactor._reactor_motes._air.visible and not reactor._reactor_motes._release.visible, "Live Reduced Motion left frozen particles visible")
		_assert(reactor._hazard_materials[0].get_shader_parameter("motion_amount") == 0.0, "Paused Reduced Motion failed to update hazard material")
		print("LIVE_RM stage=", "gate" if during_gate else "bridge", " paused=", paused, " bridge_y=", reactor._hydraulic_bridge.position.y, " gate_y=", reactor._gate.position.y, " collider_disabled=", reactor._gate_shape.disabled)
		_assert(is_equal_approx(reactor._hydraulic_bridge.position.y, 0.0) and is_equal_approx(reactor._gate.position.y, 4.8) and reactor._gate_shape.disabled, "Live Reduced Motion left a partial reactor bridge/gate")
		_assert(not reactor._bridge_sound.playing and reactor._reactor_motes.release_count == releases, "Live Reduced Motion replayed bridge presentation")
		paused = false
		await create_timer(0.15).timeout
		_assert(is_equal_approx(reactor._gate.position.y, 4.8), "Cancelled old motion overwrote live Reduced Motion")
		reactor.queue_free()
		await _settle()
	if failures == 0: print("PASS live Reduced Motion during paused/unpaused reactor bridge and gate; immediate safe geometry and silent completion")
	quit(1 if failures else 0)

extends SceneTree

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	var room = load("res://scenes/environment/security_checkpoint_room.tscn").instantiate()
	root.add_child(room)
	var player: EchoPlayer = load("res://scenes/player/echo_player.tscn").instantiate()
	player.position = Vector3(-2.6,0.1,-1.4)
	root.add_child(player)
	player.finish_opening_recovery()
	player.surface_traversal_enabled = true
	room.player = player
	room.set_audio_muted(true)
	for i in range(12): await physics_frame
	if not _check(player.is_on_floor() and absf(player.position.y) < 0.15, "room entry has no reliable grounded landing"): return
	if not _check(room.get_node("ServiceClimb").is_in_group("climbable"), "service branch is not an authored climb face"): return
	var station: Node3D = room.get_node("DivertStation")
	if not _check(room.request_station("divert",player,station).accepted, "physical diversion station is unreachable from safe entry"): return
	if not _check(room.diversion_remaining == 8 and room.scanner_trace and not room.gate_open, "diversion incorrectly opens route gate"): return
	if not _check(not room.request_station("gate",player,room.get_node("GateStation")).accepted, "gate opens from across room"): return
	room.diversion_remaining = 0
	room.elapsed = 0
	room._scanner.rotation.y = PI
	# Scanner uses an actual physics ray; cover must occlude human torso.
	player.position = Vector3(0,0.1,-10)
	player.velocity = Vector3.ZERO
	for i in range(3): await physics_frame
	room._scanner.rotation.y = PI
	if not _check(room._scanner_sees(player), "uncovered central route is invisible to scanner"): return
	player.position = Vector3(-1.9,0.1,-10.0)
	for i in range(3): await physics_frame
	room._scanner.look_at(player.global_position+Vector3.UP*0.95)
	if not _check(not room._scanner_sees(player), "authored cover fails to block surveillance ray"): return
	var safe_state: Dictionary = room.get_state()
	if not _check(not room.restore_state({"gate_open":true,"service_trace":false,"scanner_trace":false,"powers":true}) and room.get_state() == safe_state, "unvalidated state mutates gate"): return
	player.position = Vector3(-1.3,0.1,-15.2)
	for i in range(5): await physics_frame
	room.reduced_motion = true
	if not _check(room.request_station("gate",player,room.get_node("GateStation")).accepted, "manual exit latch failed"): return
	await physics_frame
	await process_frame
	if not _check(room.gate_open and room._gate_shape.disabled and is_equal_approx(room._gate.position.y,4.3), "gate presentation/collision disagrees after reduced-motion action"): return
	if not _check(not room.request_station("gate",player,room.get_node("GateStation")).accepted, "duplicate latch replay accepted"): return
	var state: Dictionary = room.get_state()
	if not _check(room.restore_state(state) and room.get_state() == state, "validated local checkpoint does not restore room"): return
	if not _check(not player.combat_available and not player.contract_with_zero_sealed, "human stealth room granted early power"): return
	print("PASS security room: grounded entry, physical diversion/latch, physics cover occlusion, validated restoration, duplicate guard and no early powers")
	player.queue_free()
	room.queue_free()
	for i in range(4):
		await process_frame
		await physics_frame
	await create_timer(0.1).timeout
	quit(0)

func _check(condition: bool,message: String) -> bool:
	if not condition:
		push_error(message)
		quit(1)
	return condition

extends SceneTree
## Regression probes for presentation crossing checkpoint/accessibility boundaries.
var failures := 0
func _initialize() -> void: _run.call_deferred()
func check(ok: bool,label: String) -> void:
	if ok: print("PASS ",label)
	else:
		failures += 1
		push_error(label)
func frames(n: int) -> void:
	for i in n: await process_frame
func _run() -> void:
	for file in ["specimen_containment_wing","memory_archive_wing"]:
		var room = load("res://scenes/environment/"+file+".tscn").instantiate()
		root.add_child(room)
		room.set_audio_muted(true)
		await frames(3)
		var closed: Dictionary = room.get_state()
		room._open_exit_gate()
		await create_timer(0.12).timeout
		room.restore_state(closed)
		await create_timer(1.0).timeout
		check(not room.gate_open and not room._gate_shape.disabled and is_equal_approx(room._gate.position.y,room._gate_closed_y),file+": closed restore defeats stale tween")
		room.restore_state(closed)
		room._open_exit_gate()
		await create_timer(0.12).timeout
		paused = true
		var clock: float = room._air_motes.motion_time
		room.reduced_motion = true
		await frames(3)
		check(room.gate_open and room._gate_shape.disabled and is_equal_approx(room._gate.position.y,room._gate_open_y),file+": paused live Reduced Motion finishes gate")
		check(not room._air_motes._air.visible and not room._air_motes._release.visible and room._air_motes.motion_time==clock,file+": paused Reduced Motion hides/fixes decoration")
		room.restore_state(closed)
		await frames(3)
		check(not room.gate_open and not room._gate_shape.disabled,file+": same-frame restore defeats deferred collider")
		paused = false
		if file=="memory_archive_wing":
			room.reduced_motion = false
			room._collect_shard("shard_shizuka")
			await frames(3)
			room.restore_state(closed)
			await frames(3)
			var shard: Area3D = room._shard_nodes.shard_shizuka
			check(shard.visible and not shard.get_node("CollisionShape3D").disabled and room.collected_shards.is_empty(),"archive: closed checkpoint restores uncollected shard visual and collider")
			check(not room._memory_sound.playing and not room._air_motes._release.visible,"archive: restore stops old presentation without replay")
		room.queue_free()
		await frames(3)
	print("ROOM_RESTORE_FAILURES ",failures)
	quit(1 if failures else 0)

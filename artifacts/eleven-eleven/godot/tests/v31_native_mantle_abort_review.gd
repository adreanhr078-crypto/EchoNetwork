extends SceneTree

var checks := 0
var completions := 0

func _initialize() -> void: _run.call_deferred()

func _check(ok: bool, message: String) -> bool:
	checks += 1
	if not ok:
		paused = false
		push_error(message)
		quit(1)
	return ok

func _steps(count: int) -> void:
	for frame in count: await physics_frame

func _wall(world: Node3D) -> StaticBody3D:
	var wall := StaticBody3D.new()
	wall.position = Vector3(0, 1.7, -1.4)
	wall.add_to_group("climbable")
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2, 3.4, 2)
	collision.shape = shape
	wall.add_child(collision)
	world.add_child(wall)
	return wall

func _run() -> void:
	AudioServer.set_bus_mute(0, true)
	for phase in [0, 1]:
		for unload in [false, true]:
			var world := Node3D.new()
			root.add_child(world)
			var wall := _wall(world)
			var actor: EchoPlayer = load("res://scenes/player/echo_player.tscn").instantiate()
			actor.position = Vector3(0, 1.9, 0.025)
			world.add_child(actor)
			actor.finish_opening_recovery()
			actor.surface_traversal_enabled = true
			actor.set_physics_process(false)
			actor.surface_motor.mantle_completed.connect(func(): completions += 1)
			await _steps(3)
			if not _check(not actor.surface_motor._begin_mantle(actor), "Mantle started without a hanging support state"): return
			actor.velocity = Vector3.DOWN
			actor.surface_motor.tick(actor, 1.0 / 60.0, Vector2(0, -1), false, false)
			if not _check(actor.surface_motor.hanging and actor.surface_motor._begin_mantle(actor), "Abort fixture could not catch/start the qualified mantle"): return
			actor.set_physics_process(true)
			for frame in 110:
				await _steps(1)
				if actor.surface_motor._native_phase == phase and actor.surface_motor._mantle_elapsed > (0.3 if phase == 0 else 1.3): break
			if not _check(actor.surface_motor.native_mantle_active and actor.surface_motor._native_phase == phase, "Abort fixture missed the intended native phase"): return
			actor.reduced_motion = true
			var before_clock: float = actor.surface_motor._mantle_elapsed
			await _steps(3)
			if not _check(actor.surface_motor._mantle_elapsed > before_clock and actor.surface_motor.native_mantle_active, "Reduced Motion skipped or stalled native traversal"): return
			var paused_clock: float = actor.surface_motor._mantle_elapsed
			var paused_position := actor.global_position
			paused = true
			for unused in 8: await process_frame
			paused = false
			if not _check(actor.surface_motor._mantle_elapsed == paused_clock and actor.global_position == paused_position, "Paused abort fixture advanced native state"): return
			actor.set_physics_process(false)
			if unload:
				wall.free()
				_wall(world)
				await _steps(2)
			actor.surface_motor.tick(actor, 1.0 / 60.0, Vector2.ZERO, false, not unload)
			if not _check(not actor.surface_motor.native_mantle_active and not actor.traversal.is_climbing() and actor.surface_motor._mantle_points.is_empty() and actor.velocity.y < 0 and actor.animation_player.speed_scale == 1.0, "Abort retained native ownership, inherited replacement support or failed to release into gravity"): return
			if not _check(completions == 0 and not actor.contract_with_zero_sealed and not actor.combat_available, "Aborted mantle emitted completion or granted a power"): return
			var skeleton := actor.find_child("Skeleton3D", true, false) as Skeleton3D
			var hips := skeleton.find_bone("Hips")
			var previous_hips := skeleton.to_global(skeleton.get_bone_global_pose(hips).origin)
			var maximum_step := 0.0
			var recovery_samples: Array = []
			actor.set_physics_process(true)
			for frame in 10:
				await _steps(1)
				var current_hips := skeleton.to_global(skeleton.get_bone_global_pose(hips).origin)
				maximum_step = maxf(maximum_step, current_hips.distance_to(previous_hips))
				recovery_samples.append({"frame": frame, "hips": current_hips, "capsule": actor.global_position, "clip": actor.animation_player.current_animation, "source_clock": actor.animation_player.current_animation_position, "return_clock": actor.get_node("ModelRoot/EchoOpeningUniform")._native_return_remaining, "model_origin": actor.get_node("ModelRoot/EchoOpeningUniform").position})
				previous_hips = current_hips
			if maximum_step >= 0.12: print("ABORT_RECOVERY_DIAGNOSIS ", JSON.stringify(recovery_samples))
			if not _check(maximum_step < 0.12 and completions == 0, "Abort handoff visibly snapped the hips or emitted delayed completion: " + str(maximum_step) + " phase=" + str(phase) + " unload=" + str(unload)): return
			world.queue_free()
			await _steps(3)
	print("NATIVE_MANTLE_ABORT PASS checks=", checks, " four cases: drop/unload at pull-up/standing, pause/RM/no false completion")
	quit(0)

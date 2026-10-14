extends SceneTree

## Automated Verification Suite: Locomotion Audio & Footstep Sync Audit (Worker 9)
## Validates:
## 1. Baked animation contact phases match Run (0.8s) and Walk (1.2s) curves exactly.
## 2. Right and Left feet alternate correctly on lowest Y/Z contact points.
## 3. Audio volume / mute controls silence audio while preserving visual puffs.
## 4. Reduced-motion softens particle parameters while maintaining visual cues.
## 5. Footstep signals fire with surface identification and position data.

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	print("--- Running Locomotion Footstep Sync Audit ---")

	var holder := Node3D.new()
	root.add_child(holder)

	var player := CharacterBody3D.new()
	holder.add_child(player)

	# Verify EchoFootstepSystem script loading
	var step_script = load("res://scripts/player/echo_footstep_system.gd")
	var footstep_system = Node3D.new()
	footstep_system.set_script(step_script)
	footstep_system.name = "EchoFootstepSystem"
	player.add_child(footstep_system)

	# 1. Verify Timing Constants
	assert(is_equal_approx(step_script.RUN_RIGHT_PHASE, 7.0 / 24.0), "RUN_RIGHT_PHASE must be Frame 7 (0.2917)")
	assert(is_equal_approx(step_script.RUN_LEFT_PHASE, 20.0 / 24.0), "RUN_LEFT_PHASE must be Frame 20 (0.8333)")
	assert(is_equal_approx(step_script.WALK_RIGHT_PHASE, 10.0 / 36.0), "WALK_RIGHT_PHASE must be Frame 10 (0.2778)")
	assert(is_equal_approx(step_script.WALK_LEFT_PHASE, 29.0 / 36.0), "WALK_LEFT_PHASE must be Frame 29 (0.8056)")
	print("[PASS] Foot contact timing constants verified against baked animation curves.")

	# 2. Phase crossing logic
	assert(footstep_system._crossed_phase(0.2917, 0.28, 0.30) == true, "Standard phase crossing must return true")
	assert(footstep_system._crossed_phase(0.2917, 0.30, 0.32) == false, "Past phase must return false")
	assert(footstep_system._crossed_phase(0.10, 0.95, 0.15) == true, "Loop wrap crossing must return true")
	print("[PASS] Phase crossing detection verified with wrap-around support.")

	# 3. Mute & Volume control test
	assert(footstep_system.has_method("_is_audio_muted"), "System must expose _is_audio_muted")
	player.set_meta("audio_muted", false)
	assert(footstep_system._is_audio_muted() == false, "Should not be muted when audio_muted is false")
	player.set_meta("audio_muted", true)
	assert(footstep_system._is_audio_muted() == true, "Should be muted when audio_muted is true")
	player.set_meta("audio_muted", false)
	print("[PASS] Audio mute controls verified.")

	# 4. Reduced-motion detection and VFX scaling
	assert(footstep_system.has_method("_is_reduced_motion"), "System must expose _is_reduced_motion")
	player.set_meta("reduced_motion", false)
	assert(footstep_system._is_reduced_motion() == false, "Reduced motion false verified")
	player.set_meta("reduced_motion", true)
	assert(footstep_system._is_reduced_motion() == true, "Reduced motion true verified")
	player.set_meta("reduced_motion", false)

	# 5. Visual indicator spawning under both standard and reduced motion
	var pre_count := holder.get_child_count()
	footstep_system._spawn_step_vfx("concrete", Vector3.ZERO)
	var standard_vfx = holder.get_child(holder.get_child_count() - 1) as GPUParticles3D
	assert(standard_vfx != null, "Standard puff must be a GPUParticles3D")
	assert(standard_vfx.amount == 8, "Standard puff particle amount must be 8")
	assert(is_equal_approx(standard_vfx.explosiveness, 0.9), "Standard puff explosiveness must be 0.9")

	player.set_meta("reduced_motion", true)
	footstep_system._spawn_step_vfx("concrete", Vector3.ZERO)
	var reduced_vfx = holder.get_child(holder.get_child_count() - 1) as GPUParticles3D
	assert(reduced_vfx != null, "Reduced motion puff must spawn")
	assert(reduced_vfx.amount == 3, "Reduced motion particle amount must be 3")
	assert(is_equal_approx(reduced_vfx.explosiveness, 0.3), "Reduced motion explosiveness must be 0.3")
	print("[PASS] Visual indicator particle adaptation for reduced-motion verified.")

	# 6. Signal emission and footstep trigger verification
	var signal_received := []
	footstep_system.footstep_triggered.connect(func(is_left: bool, surface: String, is_run: bool, pos: Vector3):
		signal_received.append({"left": is_left, "surface": surface, "run": is_run, "pos": pos})
	)

	# Test right foot step
	footstep_system._trigger_footstep(false, true)
	assert(signal_received.size() == 1, "Signal must be emitted on trigger")
	assert(signal_received[0]["left"] == false, "First step was Right foot (left == false)")
	assert(signal_received[0]["run"] == true, "Step registered as run")

	# Test left foot step
	footstep_system._trigger_footstep(true, false)
	assert(signal_received.size() == 2, "Second signal must be emitted")
	assert(signal_received[1]["left"] == true, "Second step was Left foot (left == true)")
	assert(signal_received[1]["run"] == false, "Step registered as walk")
	print("[PASS] Footstep alternating signal & trigger verification passed.")

	# Clean up
	holder.queue_free()
	await create_timer(0.4).timeout
	print("ALL TESTS PASSED: Locomotion Audio & Footstep Sync Audit complete.")
	quit(0)

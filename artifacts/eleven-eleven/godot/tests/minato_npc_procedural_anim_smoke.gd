extends SceneTree

const MinatoNPC = preload("res://scripts/characters/minato_npc.gd")

func _init() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	print("--- [MINATO NPC PROCEDURAL ANIMATION TEST] ---")

	# 1. Instantiate minato_npc.tscn
	var npc_scene = load("res://scenes/characters/minato_npc.tscn")
	assert(npc_scene != null, "minato_npc.tscn must exist and load cleanly")
	var npc: MinatoNPC = npc_scene.instantiate() as MinatoNPC
	assert(npc != null, "minato_npc.tscn must instantiate as MinatoNPC")
	root.add_child(npc)
	await process_frame
	await process_frame

	print("[1/6] minato_npc.tscn instantiated cleanly in SceneTree.")
	assert(npc.body_mesh != null, "BodyMesh must be resolved")
	assert(npc.head_mesh != null, "HeadMesh must be resolved")
	assert(npc.interactable != null, "InteractableComponent must be resolved")
	assert(is_equal_approx(npc._body_base_pos.y, 0.85), "BodyMesh base Y must be 0.85")
	assert(is_equal_approx(npc._head_base_pos.y, 1.55), "HeadMesh base Y must be 1.55")

	# 2. Verify procedural idle animation (breathing & weight shifting)
	var initial_body_y = npc.body_mesh.position.y
	var initial_sway_z = npc.body_mesh.rotation.z
	var y_changed := false
	var z_changed := false

	for frame in range(40):
		await process_frame
		if absf(npc.body_mesh.position.y - initial_body_y) > 0.001:
			y_changed = true
		if absf(npc.body_mesh.rotation.z - initial_sway_z) > 0.001:
			z_changed = true

	assert(y_changed, "Procedural idle breathing must produce gentle Y bobbing")
	assert(z_changed, "Procedural idle must produce gentle Z rotation weight shifting")
	assert(absf(npc.body_mesh.position.y - 0.85) <= 0.03, "Breathing Y bob must remain subtle and bounded")
	assert(absf(npc.body_mesh.rotation.z) <= 0.06, "Sway Z rotation must remain subtle and bounded")
	print("[2/6] Procedural idle animation verified: gentle breathing Y bob & weight shift sway.")

	# 3. Verify look-at tracking within 3.5m
	var mock_echo := Node3D.new()
	mock_echo.name = "EchoPlayer"
	mock_echo.add_to_group("player")
	mock_echo.position = Vector3(2.0, 0.0, 0.0) # 2.0m away (< 3.5m)
	root.add_child(mock_echo)

	for frame in range(25):
		await process_frame

	assert(npc.is_tracking_player, "NPC must detect Echo within 3.5m and track")
	assert(absf(npc.rotation.y) > 0.05, "NPC body must rotate toward Echo approaching within 3.5m")

	# Move Echo away (> 3.5m)
	mock_echo.position = Vector3(10.0, 0.0, 10.0)
	for frame in range(35):
		await process_frame

	assert(not npc.is_tracking_player, "NPC must stop tracking when Echo leaves 3.5m radius")
	print("[3/6] Look-at tracking verified: tracks Echo within 3.5m, returns to rest when Echo leaves.")

	# 4. Verify interactive gestures (nodding & welcoming lean)
	var talk_result = npc.talk_to_player(mock_echo)
	assert(talk_result.has("dialogue"), "talk_to_player must return dialogue")
	assert(npc.is_gesturing, "Interacting with NPC must trigger interactive gesture")
	assert(npc.gesture_timer > 0.0, "Gesture timer must be active")

	# Progress frames through gesture
	var peak_head_pitch := 0.0
	for frame in range(20):
		await process_frame
		if npc.head_mesh.rotation.x > peak_head_pitch:
			peak_head_pitch = npc.head_mesh.rotation.x

	assert(peak_head_pitch > 0.02, "Gesture must animate head pitch (nodding/leaning)")

	# Wait for gesture completion
	for frame in range(60):
		await process_frame
	assert(not npc.is_gesturing, "Gesture must complete and return to idle smoothly")

	# Test explicit welcoming lean and nod
	npc.play_welcoming_lean()
	assert(npc.current_gesture == MinatoNPC.GestureType.WELCOMING_LEAN, "Welcoming lean activates")
	assert(npc.is_gesturing, "Welcoming lean is active")
	for frame in range(60):
		await process_frame

	npc.play_nod()
	assert(npc.current_gesture == MinatoNPC.GestureType.NOD, "Nod activates")
	assert(npc.is_gesturing, "Nod is active")
	for frame in range(60):
		await process_frame

	print("[4/6] Interactive gestures verified: nodding and welcoming lean play and ease out.")

	# 5. Verify reduced_motion compliance
	npc.set_reduced_motion(true)
	assert(npc.is_reduced_motion(), "Reduced motion setting recognized")
	await process_frame
	await process_frame

	assert(is_equal_approx(npc.body_mesh.position.y, 0.85), "Reduced motion must eliminate breathing bob")
	assert(is_equal_approx(npc.body_mesh.rotation.z, 0.0), "Reduced motion must eliminate weight shift sway")

	# Check that interactive gesture respects reduced motion
	npc.play_interactive_gesture()
	assert(not npc.is_gesturing, "Reduced motion must suppress exaggerated procedural gestures")
	print("[5/6] Reduced motion compliance verified: breathing bob, sway, and gestures disabled.")

	# 6. Verify existing quest/dialogue triggers and familiarity progression
	npc.set_reduced_motion(false)
	var test_fresh_npc := MinatoNPC.new()
	test_fresh_npc.npc_id = "NPC_TEST_VERIFY"
	test_fresh_npc.display_name = "Verification Citizen"
	test_fresh_npc.dialogue_lines = ["Hello!", "Good morning!", "Nice weather!"]

	assert(test_fresh_npc.familiarity_tier == MinatoNPC.FamiliarityTier.STRANGER, "Starts as stranger")
	var t1 = test_fresh_npc.talk_to_player()
	assert(t1["talk_count"] == 1, "Talk counter incremented")
	assert(test_fresh_npc.familiarity_tier == MinatoNPC.FamiliarityTier.ACQUAINTANCE, "Advances to ACQUAINTANCE")

	for i in range(2):
		test_fresh_npc.talk_to_player()
	assert(test_fresh_npc.familiarity_tier == MinatoNPC.FamiliarityTier.REGULAR, "Advances to REGULAR at 3 talks")

	for i in range(3):
		test_fresh_npc.talk_to_player()
	assert(test_fresh_npc.familiarity_tier == MinatoNPC.FamiliarityTier.FAMILIAR, "Advances to FAMILIAR at 6 talks")

	var sched = test_fresh_npc.get_schedule_info()
	assert(sched["npc_id"] == "NPC_TEST_VERIFY", "Schedule info preserved")
	print("[6/6] Dialogue triggers, familiarity progression, and schedule metadata preserved.")

	print("\nALL MINATO NPC PROCEDURAL ANIMATION TESTS PASSED.")
	quit(0)

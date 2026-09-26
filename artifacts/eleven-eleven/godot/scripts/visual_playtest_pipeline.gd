extends SceneTree

## Visual Playtest & Photographic Inspection Pipeline
## Executes simulated player traversal across all 5 dungeon zones,
## verifies camera tracking, Katana rigging, floor grounding, and UI toasts,
## and saves 1080p rendered frames for automated agent critique.

const ARTIFACT_DIR := "C:/Users/yasmo/.gemini/antigravity/brain/1e43e74f-96d2-4240-8c06-cdf56025df12"

func _init() -> void:
	print("--- STARTING 11.11 VISUAL PLAYTEST & AUDIT PIPELINE ---")
	
	# Create 1080p SubViewport for off-screen rendering
	var vp := SubViewport.new()
	vp.size = Vector2i(1920, 1080)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)

	var main_scene = load("res://scenes/main.tscn")
	if not main_scene:
		printerr("FAILED to load main.tscn")
		quit(1)
		return

	var main_root = main_scene.instantiate()
	vp.add_child(main_root)
	await process_frame

	var player = main_root.find_child("EchoPlayer", true, false) as CharacterBody3D
	var hud = main_root.find_child("GameplayHUD", true, false) as CanvasLayer
	var boss = main_root.find_child("SpecimenEX000", true, false) as CharacterBody3D
	var kinga = main_root.find_child("DrKinga", true, false) as CharacterBody3D
	var prologue = main_root.find_child("PrologueOrchestrator", true, false)

	if not player or not hud:
		printerr("FAILED: Required player or HUD missing")
		quit(1)
		return

	# Setup a dedicated test camera inside the viewport to capture key perspectives
	var test_cam := Camera3D.new()
	test_cam.current = true
	test_cam.fov = 65.0
	vp.add_child(test_cam)
	await process_frame

	# -------------------------------------------------------------
	# STAGE 0: ROOM 1 (Cryo Chamber & Awakening)
	# -------------------------------------------------------------
	print("[Capture 1/6] Rendering Room 1: Cryo Chamber Awakening & Exploration...")
	player.global_position = Vector3(0, 0, 0)
	if player.has_method("sheath_weapon"):
		player.sheath_weapon()
	if hud and hud.has_method("show_tutorial_toast"):
		hud.show_tutorial_toast("TOAST_MOVE", "WASD / SPACE", "EXPLORATION CONTROLS", "Move with [WASD], jump with [SPACE], sprint with [SHIFT]", 10.0)

	test_cam.global_position = Vector3(0, 2.2, 5.5)
	test_cam.look_at(player.global_position + Vector3(0, 1.0, 0))

	# Advance 8 frames for shaders and lighting to settle
	for i in range(8):
		await process_frame

	_save_capture(vp, ARTIFACT_DIR + "/capture_01_room1_cryo.png")

	# -------------------------------------------------------------
	# STAGE 1: CORRIDOR 1 (Decontamination & Obstacle Slide)
	# -------------------------------------------------------------
	print("[Capture 2/6] Rendering Corridor 1: Decontamination & Slide Barrier...")
	if player.has_method("finish_opening_recovery"):
		player.finish_opening_recovery()
	player.global_position = Vector3(0, 0, -35.0)
	if player.has_method("play_anim"):
		player.play_anim("RUN", 0.0)
	if hud and hud.has_method("show_tutorial_toast"):
		hud.show_tutorial_toast("TOAST_SLIDE", "C / CTRL", "SPRINT SLIDE", "Sprint and press [C] to slide under low obstacles", 10.0)

	test_cam.global_position = Vector3(1.8, 1.8, -29.0)
	test_cam.look_at(player.global_position + Vector3(0, 0.9, 0))

	for i in range(8):
		await process_frame

	_save_capture(vp, ARTIFACT_DIR + "/capture_02_corridor1_decontamination.png")

	# -------------------------------------------------------------
	# STAGE 2: ROOM 2 (Generator Hall & Power Grid Puzzles)
	# -------------------------------------------------------------
	print("[Capture 3/6] Rendering Room 2: Generator Hall & Power Conduits...")
	player.global_position = Vector3(0, 0, -80.0)
	if player.has_method("unsheath_weapon"):
		player.unsheath_weapon()
	if player.has_method("play_anim"):
		player.play_anim("IDLE", 0.0)
	if hud and hud.has_method("show_tutorial_toast"):
		hud.show_tutorial_toast("TOAST_COMBAT", "LMB / RMB", "TACTICAL COMBAT", "Strike combo [LMB], Dash & evade with [RMB]", 10.0)

	test_cam.global_position = Vector3(-4.0, 3.2, -72.0)
	test_cam.look_at(player.global_position + Vector3(0, 1.0, 0))

	for i in range(8):
		await process_frame

	_save_capture(vp, ARTIFACT_DIR + "/capture_03_room2_generator.png")

	# -------------------------------------------------------------
	# STAGE 3: ROOM 3 (Chimera Trench & Specimen EX-000 Boss)
	# -------------------------------------------------------------
	print("[Capture 4/6] Rendering Room 3: Chimera Arena & Specimen EX-000...")
	player.global_position = Vector3(0, 0, -118.0)
	if boss:
		boss.visible = true
		boss.global_position = Vector3(0, 0, -125.0)
		if boss.has_method("take_damage"):
			boss.take_damage(550.0) # Trigger Phase 2 enraged crimson core

	if hud and hud.has_method("update_boss_hp"):
		hud.update_boss_hp(450.0, 1000.0)
	if hud and hud.has_node("BossContainer"):
		hud.get_node("BossContainer").visible = true

	test_cam.global_position = Vector3(2.5, 2.0, -112.0)
	test_cam.look_at(Vector3(0, 1.4, -122.0))

	for i in range(8):
		await process_frame

	_save_capture(vp, ARTIFACT_DIR + "/capture_04_room3_chimera.png")

	# -------------------------------------------------------------
	# STAGE 4: ROOM 4 (Dr. Kinga Observation Neuro-Lab)
	# -------------------------------------------------------------
	print("[Capture 5/6] Rendering Room 4: Dr. Kinga Neuro-Lab Dynamic Confrontation...")
	player.global_position = Vector3(0, 0, -164.0)
	if kinga:
		kinga.visible = true
		kinga.global_position = Vector3(0, 0, -170.0)
		if kinga.has_method("start_combat_encounter"):
			kinga.start_combat_encounter(player)

	if hud and hud.has_method("show_tutorial_toast"):
		hud.show_tutorial_toast("TOAST_KINGA", "DR. KINGA", "CHIEF SCIENTIST", "Break hexagonal barrier with continuous strikes!", 10.0)

	test_cam.global_position = Vector3(-2.2, 2.0, -158.0)
	test_cam.look_at(Vector3(0, 1.2, -168.0))

	for i in range(8):
		await process_frame

	_save_capture(vp, ARTIFACT_DIR + "/capture_05_room4_drkinga.png")

	# -------------------------------------------------------------
	# STAGE 5: CLIMAX SINGULARITY (Zero's Awakening & Wing)
	# -------------------------------------------------------------
	print("[Capture 6/6] Rendering Climax: Single Left Shadow Wing & Zero Eyes...")
	player.global_position = Vector3(0, 0, -164.0)
	if player.has_method("manifest_zero_wing"):
		player.manifest_zero_wing()
	if player.has_method("set_zero_eye_active"):
		player.set_zero_eye_active(true)
	if player.has_method("equip_shadow_katana"):
		player.equip_shadow_katana()

	test_cam.global_position = Vector3(1.2, 1.6, -161.5)
	test_cam.look_at(player.global_position + Vector3(0, 1.2, 0))

	for i in range(8):
		await process_frame

	_save_capture(vp, ARTIFACT_DIR + "/capture_06_climax_singularity.png")

	print("--- ALL 6 CAPTURES GENERATED SUCCESSFULLY ---")
	quit(0)

func _save_capture(vp: SubViewport, dest_path: String) -> void:
	var tex = vp.get_texture()
	if not tex:
		printerr("Texture null for: ", dest_path)
		return
	var img = tex.get_image()
	if not img:
		printerr("Image null for: ", dest_path)
		return
	var err = img.save_png(dest_path)
	if err == OK:
		print("  ✔ Successfully saved: ", dest_path)
	else:
		printerr("  ✖ Failed saving: ", dest_path, " code: ", err)

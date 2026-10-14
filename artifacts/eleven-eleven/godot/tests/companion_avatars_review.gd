extends SceneTree

const ShizukaCompanion = preload("res://scripts/characters/shizuka_companion.gd")
const YukiCompanion = preload("res://scripts/characters/yuki_companion.gd")
const MinatoHighSchool = preload("res://scripts/environment/minato_high_school.gd")

class MockPlayer extends CharacterBody3D:
	signal hp_changed(current: float, max_val: float)
	var hp: float = 100.0
	var sanity: float = 30.0
	var glitch_meter: float = 80.0
	var reality_glitch: float = 80.0
	var needs = null

class MockEnemy extends CharacterBody3D:
	var hp: float = 200.0
	var frost_slow_applied: bool = false
	func take_damage(amount: float) -> void:
		hp = maxf(0.0, hp - amount)
	func apply_frost_slow(multiplier: float, duration: float) -> void:
		frost_slow_applied = true

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	print("=================================================================")
	print("--- AAA COMPANION VISUAL AVATAR & PROCEDURAL IDLE REVIEW ---")
	print("=================================================================")

	var root_node := Node3D.new()
	root_node.name = "TestWorld"
	root.add_child(root_node)

	# Mock Echo / Player Node
	var echo_player := MockPlayer.new()
	echo_player.name = "EchoPlayer"
	echo_player.add_to_group("player")
	echo_player.position = Vector3(0, 0, 0)
	root_node.add_child(echo_player)

	# -------------------------------------------------------------
	# 1. SHIZUKA COMPANION VERIFICATION
	# -------------------------------------------------------------
	print("[1/4] Testing Shizuka Visual Avatar & Architecture...")
	var shizuka := ShizukaCompanion.new()
	shizuka.name = "Shizuka"
	root_node.add_child(shizuka)

	# Verify avatar hierarchy exists
	var shizuka_avatar: Node = shizuka.find_child("ShizukaAvatarMesh", true, false)
	assert(shizuka_avatar != null, "Shizuka must have ShizukaAvatarMesh root")
	assert(shizuka_avatar.find_child("BodyRoot", true, false) != null, "BodyRoot must exist")
	assert(shizuka_avatar.find_child("BreathingPivot", true, false) != null, "BreathingPivot must exist")
	assert(shizuka_avatar.find_child("HeadPivot", true, false) != null, "HeadPivot must exist")
	assert(shizuka_avatar.find_child("BentoBoxProp", true, false) != null, "BentoBoxProp must exist")

	# Verify Shizuka accessories & distinct styling
	var apron_bib = shizuka_avatar.find_child("ApronBib", true, false)
	var chest_ribbon = shizuka_avatar.find_child("ChestRibbonKnot", true, false)
	var hairpin = shizuka_avatar.find_child("HairpinMesh", true, false)
	var hair_ribbon = shizuka_avatar.find_child("CrimsonHairRibbon", true, false)
	var bento_base = shizuka_avatar.find_child("BentoBase", true, false)
	var furoshiki = shizuka_avatar.find_child("FuroshikiKnot", true, false)
	var chopsticks = shizuka_avatar.find_child("ChopstickCase", true, false)

	assert(apron_bib != null, "Shizuka must have apron bib accent")
	assert(chest_ribbon != null, "Shizuka must have crimson chest ribbon")
	assert(hairpin != null, "Shizuka must have warm peach hairpin")
	assert(hair_ribbon != null, "Shizuka must have crimson hair ribbon")
	assert(bento_base != null, "Shizuka must have bento box prop base")
	assert(furoshiki != null, "Shizuka must have furoshiki knot")
	assert(chopsticks != null, "Shizuka must have chopstick case")
	print("  -> Shizuka anime humanoid hierarchy & warm accessories verified.")

	# -------------------------------------------------------------
	# 2. YUKI COMPANION VERIFICATION
	# -------------------------------------------------------------
	print("[2/4] Testing Yuki Visual Avatar & Architecture...")
	var yuki := YukiCompanion.new()
	yuki.name = "Yuki"
	root_node.add_child(yuki)

	# Verify avatar hierarchy exists
	var yuki_avatar: Node = yuki.find_child("YukiAvatarMesh", true, false)
	assert(yuki_avatar != null, "Yuki must have YukiAvatarMesh root")
	assert(yuki_avatar.find_child("BodyRoot", true, false) != null, "BodyRoot must exist")
	assert(yuki_avatar.find_child("BreathingPivot", true, false) != null, "BreathingPivot must exist")
	assert(yuki_avatar.find_child("HeadPivot", true, false) != null, "HeadPivot must exist")

	# Verify Yuki accessories & distinct cool-tone styling
	var scarf_wrap = yuki_avatar.find_child("ScarfNeckWrap", true, false)
	var scarf_knot = yuki_avatar.find_child("ScarfKnot", true, false)
	var scarf_tail_pivot = yuki_avatar.find_child("ScarfTailPivot", true, false)
	var scarf_lower = yuki_avatar.find_child("ScarfTailLower", true, false)
	var frost_barrette = yuki_avatar.find_child("FrostBarrette", true, false)
	var cryo_holster = yuki_avatar.find_child("CryoHolster", true, false)
	var cryo_core = yuki_avatar.find_child("CryoCoreMesh", true, false)
	var lapel = yuki_avatar.find_child("LapelLeft", true, false)

	assert(scarf_wrap != null, "Yuki must have ice-blue scarf neck wrap")
	assert(scarf_knot != null, "Yuki must have scarf knot")
	assert(scarf_tail_pivot != null, "Yuki must have scarf tail pivot")
	assert(scarf_lower != null, "Yuki must have lavender scarf tail lower drape")
	assert(frost_barrette != null, "Yuki must have frost crystal barrette")
	assert(cryo_holster != null, "Yuki must have tactical cryo holster")
	assert(cryo_core != null, "Yuki must have luminescent cyan cryo core")
	assert(lapel != null, "Yuki must have navy blazer lapel")
	print("  -> Yuki anime humanoid hierarchy & cool-tone scarf/cryo accessories verified.")

	# -------------------------------------------------------------
	# 3. PROCEDURAL IDLE ANIMATION & ECHO HEAD TRACKING
	# -------------------------------------------------------------
	print("[3/4] Testing Procedural Idle Animation & Head Tracking...")

	var shizuka_breathing: Node3D = shizuka_avatar.find_child("BreathingPivot", true, false)
	var shizuka_head: Node3D = shizuka_avatar.find_child("HeadPivot", true, false)
	var shizuka_bento: Node3D = shizuka_avatar.find_child("BentoBoxProp", true, false)

	var yuki_breathing: Node3D = yuki_avatar.find_child("BreathingPivot", true, false)
	var yuki_head: Node3D = yuki_avatar.find_child("HeadPivot", true, false)
	var yuki_scarf_tail: Node3D = yuki_avatar.find_child("ScarfTailPivot", true, false)

	# Initial positions before simulation
	var shizuka_b_init_y = shizuka_breathing.position.y
	var yuki_b_init_y = yuki_breathing.position.y

	# Place Echo nearby in front of companions
	shizuka.global_position = Vector3(0, 0, 0)
	yuki.global_position = Vector3(2.0, 0, 0)
	# Position Echo 2 meters in front and slightly to the side (-Z is forward)
	echo_player.global_position = Vector3(0.5, 0, -2.0)

	# Simulate 30 frames (delta = 0.05s => 1.5s simulated time)
	for frame in range(30):
		shizuka._process(0.05)
		yuki._process(0.05)

	# 3a. Breathing bob verification: position oscillating and bento moving
	print("  Shizuka breathing pivot Y: ", shizuka_breathing.position.y, " (delta: ", absf(shizuka_breathing.position.y - shizuka_b_init_y), ")")
	print("  Yuki breathing pivot Y: ", yuki_breathing.position.y, " (delta: ", absf(yuki_breathing.position.y - yuki_b_init_y), ")")
	assert(shizuka_bento.position.y != 0.10 or absf(shizuka_breathing.position.y - shizuka_b_init_y) > 0.0001, "Breathing bob must update positions")
	assert(absf(yuki_scarf_tail.rotation.z) > 0.0001, "Scarf tail must procedurally sway")

	# 3b. Head tracking towards nearby Echo
	print("  Shizuka head rotation: yaw=", rad_to_deg(shizuka_head.rotation.y), " deg, pitch=", rad_to_deg(shizuka_head.rotation.x), " deg, roll=", rad_to_deg(shizuka_head.rotation.z), " deg")
	print("  Yuki head rotation: yaw=", rad_to_deg(yuki_head.rotation.y), " deg, pitch=", rad_to_deg(yuki_head.rotation.x), " deg")
	assert(absf(shizuka_head.rotation.y) > 0.02, "Shizuka head must rotate towards nearby Echo")
	assert(absf(yuki_head.rotation.y) > 0.02, "Yuki head must rotate towards nearby Echo")
	assert(absf(shizuka_head.rotation.z) > 0.001, "Shizuka must exhibit empathetic head tilt roll")

	# 3c. Move Echo far away (> 6 meters) and simulate return to forward rest pose
	echo_player.global_position = Vector3(0, 0, 20.0) # behind and far
	for frame in range(60): # 3.0s simulated return
		shizuka._process(0.05)
		yuki._process(0.05)

	print("  After Echo moves away:")
	print("    Shizuka head yaw: ", rad_to_deg(shizuka_head.rotation.y), " deg")
	print("    Yuki head yaw: ", rad_to_deg(yuki_head.rotation.y), " deg")
	assert(absf(shizuka_head.rotation.y) < deg_to_rad(10.0), "Shizuka head must return towards forward neutral")
	assert(absf(yuki_head.rotation.y) < deg_to_rad(10.0), "Yuki head must return towards forward neutral")
	print("  -> Procedural breathing bob, scarf sway, and Echo head tracking verified.")

	# -------------------------------------------------------------
	# 4. COMPANION GAMEPLAY LOGIC & AI PRESERVATION
	# -------------------------------------------------------------
	print("[4/4] Testing Companion Dialogue, State Machine & Action Systems...")

	# 4a. Shizuka State Machine
	shizuka.sit_at_desk()
	assert(shizuka.current_state == ShizukaCompanion.State.CLASSROOM_IDLE, "Shizuka must be in CLASSROOM_IDLE")
	assert(shizuka.position.distance_to(ShizukaCompanion.DESK_POSITION) < 0.01, "Shizuka must be at authored desk")

	shizuka.go_to_rooftop_lunch()
	assert(shizuka.current_state == ShizukaCompanion.State.ROOFTOP_LUNCH, "Shizuka must transition to ROOFTOP_LUNCH")

	var follow_res := shizuka.start_following(echo_player)
	assert(follow_res["success"] == true and shizuka.current_state == ShizukaCompanion.State.FOLLOWING_PLAYER, "Shizuka follow must succeed")
	var stop_res := shizuka.stop_following()
	assert(stop_res["success"] == true and shizuka.current_state == ShizukaCompanion.State.CLASSROOM_IDLE, "Shizuka stop follow must succeed")

	# 4b. Shizuka Bento Sharing & Trauma Counseling
	var bento_res := shizuka.share_homemade_bento(echo_player)
	assert(bento_res["success"] == true, "Bento sharing must succeed")
	assert(bento_res["meal"] == "Shizuka's Special Tamagoyaki & Karaage Bento", "Meal name must match")
	assert(echo_player.hp == 150.0, "Player HP should heal +50 from bento")

	var counsel_res := shizuka.provide_trauma_counseling(echo_player)
	assert(counsel_res["success"] == true, "Trauma counseling must succeed")
	assert(echo_player.sanity == 70.0, "Sanity should restore +40")
	assert(echo_player.reality_glitch == 30.0, "Reality glitch should suppress -50")

	var talk_shizuka := shizuka.talk()
	assert(talk_shizuka["character"] == "Shizuka" and talk_shizuka["dialogue"].length() > 0, "Shizuka talk must return dialogue")

	var chat_shizuka := shizuka.chat_freeform("How was your lunch, Shizuka?")
	assert(chat_shizuka.has("text"), "Shizuka freeform chat must produce response")

	# 4c. Yuki State Machine & Combat Assist
	yuki.sit_at_desk()
	assert(yuki.current_state == YukiCompanion.State.CLASSROOM_IDLE, "Yuki must be in CLASSROOM_IDLE")
	assert(yuki.position.distance_to(YukiCompanion.DESK_POSITION) < 0.01, "Yuki must be at authored desk")

	var yuki_follow := yuki.start_following(echo_player)
	assert(yuki_follow["success"] == true and yuki.current_state == YukiCompanion.State.FOLLOWING_PLAYER, "Yuki follow must succeed")
	var yuki_stop := yuki.stop_following()
	assert(yuki_stop["success"] == true and yuki.current_state == YukiCompanion.State.CLASSROOM_IDLE, "Yuki stop follow must succeed")

	# Target dummy for combat assist
	var dummy := MockEnemy.new()
	dummy.name = "DummyEnemy"
	root_node.add_child(dummy)

	var assist_res := yuki.execute_combat_assist(dummy)
	assert(assist_res["success"] == true, "Combat assist must succeed")
	assert(assist_res["skill_name"] == "Glacial Severance", "Skill name must be Glacial Severance")
	assert(assist_res["element"] == "CYAN_CRYO", "Element must be CYAN_CRYO")
	assert(dummy.hp == 115.0, "Target HP should reduce by 85 damage")
	assert(dummy.frost_slow_applied == true, "Frost slow should be applied to target")

	# Cooldown check
	var assist_cd := yuki.execute_combat_assist(dummy)
	assert(assist_cd["success"] == false, "Combat assist should be on cooldown")

	var talk_yuki := yuki.talk()
	assert(talk_yuki["character"] == "Yuki Tachibana" and talk_yuki["dialogue"].length() > 0, "Yuki talk must return dialogue")

	var chat_yuki := yuki.chat_freeform("Report on sector status.")
	assert(chat_yuki.has("text"), "Yuki freeform chat must produce response")

	print("  -> All gameplay logic, follow AI, and dialogue systems verified 100% operational.")

	# -------------------------------------------------------------
	# 5. MINATO HIGH SCHOOL COMPANION INTEGRATION
	# -------------------------------------------------------------
	print("[5/5] Testing MinatoHighSchool Scene Integration...")
	var school := MinatoHighSchool.new()
	school.name = "MinatoHighSchool"
	root_node.add_child(school)

	var school_yuki = school.get_yuki_companion()
	var school_shizuka = school.get_shizuka_companion()
	assert(school_yuki != null, "School must provide Yuki")
	assert(school_shizuka != null, "School must provide Shizuka")
	assert(school_yuki.find_child("YukiAvatarMesh", true, false) != null, "School Yuki must have avatar mesh")
	assert(school_shizuka.find_child("ShizukaAvatarMesh", true, false) != null, "School Shizuka must have avatar mesh")
	assert(school_yuki.current_state == YukiCompanion.State.CLASSROOM_IDLE, "School Yuki must be in CLASSROOM_IDLE")
	assert(school_shizuka.current_state == ShizukaCompanion.State.CLASSROOM_IDLE, "School Shizuka must be in CLASSROOM_IDLE")
	print("  -> MinatoHighSchool companions instantiated and avatar meshes verified.")

	# Wait for queued audio stream players to flush cleanly
	root_node.queue_free()
	await process_frame

	print("=================================================================")
	print("PASS: ALL COMPANION AVATAR & BEHAVIOR TESTS COMPLETED SUCCESSFULLY!")
	print("=================================================================")
	quit(0)

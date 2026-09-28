class_name PrologueOrchestrator
extends Node

const ProceduralCinematicAudio = preload("res://scripts/audio/procedural_cinematic_audio.gd")

## 11.11 Master Prologue Orchestrator
## Seamlessly choreographs the definitive 5-zone Genshin-tier dungeon progression:
## Stage 0: Room 1 Cryo Chamber (Exploration, Crates, Conduit A & Sector Terminal Hack)
## Stage 1: Corridor 1 Decontamination (Obstacle Slide, Security Droid Duel, Vault 1 Chest)
## Stage 2: Room 2 Generator Hall (Conduits B & C Overload, Security Patrol, Vault 2 Chest)
## Stage 3: Room 3 Chimera Trench (Aberrant Specimen EX-000 2-Phase Boss Battle)
## Stage 4: Room 4 Observation Neuro-Lab (Dynamic Cybernetic Dr. Kinga Duel, Shields & Lasers)
## Stage 5: Climax Singularity (Overload -> Ocean Abyss & Zero Covenant -> Solo Leveling Glitch -> Reality)

signal prologue_step_changed(step_name: String)
signal prologue_completed()

enum Step {
	STAGE_0_AWAKENING,
	STAGE_1_DECONTAMINATION,
	STAGE_2_GENERATOR_HALL,
	STAGE_3_CHIMERA_TRENCH,
	STAGE_4_KINGA_NEURO_LAB,
	STAGE_5_ZERO_CLIMAX,
	KINGA_TORTURE_QTE,
	OCEAN_ABYSS_CONTRACT,
	HYSTERICAL_AWAKENING,
	SUBJECT_010_DUEL,
	SOLO_LEVELING_GLITCH_CHOICE,
	NOCTURNAL_HOSPITAL_WAKE,
	FREE_EXPLORATION
}

var current_step: Step = Step.STAGE_0_AWAKENING

var main_root: Node3D = null
var player: EchoPlayer = null
var hud: GameplayHUD = null
var boss: Node3D = null
var kinga_actor: DrKinga = null

# Conduits & Puzzle state
var conduit_a_energized: bool = false
var conduit_b_energized: bool = false
var conduit_c_energized: bool = false
var wake_terminal_solved: bool = false
var room_gate_open: bool = false
var gate_reveal_seen: bool = false
var clock_inspected: bool = false
var photo_inspected: bool = false
var opening_memory_recovered: bool = false

# Traversal & Combat triggers
var corridor_droid_defeated: bool = false
var slide_toast_shown: bool = false
var specimen_encounter_triggered: bool = false
var kinga_encounter_triggered: bool = false
var struggle_presses: int = 0
const REQUIRED_STRUGGLES: int = 4

func set_zone_active(zone_name: String, active: bool) -> void:
	if not main_root:
		return
	var zone = main_root.find_child(zone_name, true, false)
	if zone:
		zone.visible = active
		zone.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED

func initialize(root_node: Node3D, player_node: EchoPlayer, hud_node: GameplayHUD) -> void:
	main_root = root_node
	player = player_node
	hud = hud_node

	if main_root:
		boss = main_root.find_child("SpecimenEX000", true, false) as Node3D
		kinga_actor = main_root.find_child("DrKinga", true, false) as DrKinga

	_setup_dungeon_listeners()
	# Main starts the first objective only after Echo's recovery has finished.

func _setup_dungeon_listeners() -> void:
	if not main_root:
		return

	# 1. Listen for Power Conduits
	var photograph = main_root.find_child("OpeningPhotograph", true, false)
	if photograph and photograph.has_node("InteractionArea"):
		photograph.get_node("InteractionArea").is_enabled = false
	var terminal = main_root.find_child("SectorTerminal", true, false)
	if terminal and terminal.has_node("InteractionArea"):
		terminal.get_node("InteractionArea").is_enabled = false
	var wake_conduit = main_root.find_child("EnergyPowerConduit_A", true, false)
	if wake_conduit and wake_conduit.has_node("InteractionArea"):
		wake_conduit.is_locked = true
		wake_conduit.get_node("InteractionArea").is_enabled = false
	for conduit in main_root.find_children("*", "EnergyPowerConduit", true, false):
		if conduit and conduit.has_signal("conduit_energized"):
			conduit.conduit_energized.connect(_on_conduit_energized)

	# 2. Listen for Security Droids
	for droid in main_root.find_children("*", "Sector11SecurityDroid", true, false):
		if droid and droid.has_signal("droid_defeated"):
			droid.droid_defeated.connect(_on_security_droid_defeated)

	# 3. Listen for Boss Defeat
	if boss and boss.has_signal("boss_defeated"):
		boss.boss_defeated.connect(_on_specimen_defeated)

	# 4. Listen for Kinga Defeat
	if kinga_actor and kinga_actor.has_signal("kinga_defeated"):
		kinga_actor.kinga_defeated.connect(_on_kinga_defeated)

func start_prologue(play_wake_cue: bool = true) -> void:
	current_step = Step.STAGE_0_AWAKENING
	emit_signal("prologue_step_changed", "STAGE_0_AWAKENING")
	if play_wake_cue:
		_play_wake_signal()

	# Compartmentalize: Isolate Room 1; dormantly hide and disable future zones
	set_zone_active("Corridor1_Decontamination", false)
	set_zone_active("SideChamber1_PowerVault", false)
	set_zone_active("Room2_GeneratorHall", false)
	set_zone_active("SideChamber2_DissectionLab", false)
	set_zone_active("Room3_ChimeraTrench", false)
	set_zone_active("Room4_KingaNeuroLab", false)

	if player:
		player.set_combat_available(false)
		if player.has_method("sheath_weapon"):
			player.sheath_weapon()

	if hud:
		if hud.has_method("show_tutorial_toast"):
			var touch_ui = hud.find_child("MobileTouchControls", true, false)
			var touch_mode: bool = touch_ui != null and touch_ui.visible
			hud.show_tutorial_toast(
				"TOAST_MOVE",
				"TOUCH" if touch_mode else "WASD / E",
				"التحرك والتفاعل",
				"حرّك Echo بالمقبض، ثم افحص الساعة المتوقفة." if touch_mode else "تحرك نحو الساعة المتوقفة واضغط E لفحصها.",
				6.0
			)
		if hud.has_method("set_directive"):
			hud.set_directive(
				"SECTOR 11 // أثر الاستيقاظ 0/4",
				"افحص الساعة المتوقفة، ثم اتبع الأثر الشخصي في الغرفة."
			)
	_update_room_markers()

func _play_wake_signal() -> void:
	var capsule := main_root.find_child("Sector11Capsule", true, false) as Node3D if main_root else null
	if not capsule:
		return
	var cue := AudioStreamPlayer3D.new()
	cue.name = "WakeSignalCue"
	cue.volume_db = -18.0
	cue.max_distance = 9.0
	capsule.add_child(cue)
	cue.stream = ProceduralCinematicAudio.create_heart_monitor_beep()
	cue.finished.connect(cue.queue_free)
	cue.play()

func _physics_process(_delta: float) -> void:
	if not player or not is_inside_tree():
		return

	var pz: float = player.global_position.z
	if current_step == Step.STAGE_0_AWAKENING and room_gate_open and not gate_reveal_seen and pz <= -14.5:
		gate_reveal_seen = true
		if main_root and main_root.has_method("report_opening_milestone"):
			main_root.report_opening_milestone("chapter_boundary_seen")
		if main_root and main_root.has_method("play_opening_boundary_memory"):
			main_root.play_opening_boundary_memory()
		if hud and hud.has_method("show_tutorial_toast"):
			hud.show_tutorial_toast("TOAST_CHAPTER_END", "11.11", "نهاية الافتتاح", "خلف العتبة أثر لم تُكشف هويته بعد. يتبع...", 7.0)

	# Stage 0 -> 1: Threshold crossing at Gate 1 (pz <= -18.5)
	# The approved opening ends at Gate 1. Later stages stay dormant until a new phase is accepted.

	# Stage 1: Slide barrier tutorial trigger
	if current_step == Step.STAGE_1_DECONTAMINATION and not slide_toast_shown:
		if pz <= -24.0:
			slide_toast_shown = true
			if hud and hud.has_method("show_tutorial_toast"):
				hud.show_tutorial_toast(
					"TOAST_SLIDE",
					"C / CTRL",
					"SPRINT SLIDE",
					"Sprint and press [C] to slide under low obstacles",
					6.0
				)

	# Stage 3: Chimera boss encounter trigger
	elif current_step == Step.STAGE_3_CHIMERA_TRENCH and not specimen_encounter_triggered:
		if pz <= -102.0:
			specimen_encounter_triggered = true
			_trigger_specimen_boss_battle()

	# Stage 4: Dr. Kinga confrontation trigger
	elif current_step == Step.STAGE_4_KINGA_NEURO_LAB and not kinga_encounter_triggered:
		if pz <= -148.0:
			kinga_encounter_triggered = true
			_trigger_kinga_combat_battle()

func _on_conduit_energized(conduit_node: Node) -> void:
	var cid: String = conduit_node.get("conduit_id") if conduit_node else ""

	if cid == "conduit_a":
		conduit_a_energized = true
		if main_root and main_root.has_method("report_opening_milestone"):
			main_root.report_opening_milestone("conduit_energized")
		_check_room_gate()
		_update_room_markers()

	elif cid == "conduit_b":
		conduit_b_energized = true
		_check_generator_hall_completion()

	elif cid == "conduit_c":
		conduit_c_energized = true
		_check_generator_hall_completion()

func on_terminal_puzzle_solved(terminal_node: Node) -> void:
	if terminal_node == null or terminal_node.name != "SectorTerminal":
		return
	wake_terminal_solved = true
	_check_room_gate()
	_update_room_markers()

func on_opening_evidence_inspected(evidence_id: String) -> void:
	if evidence_id == "clock" and not clock_inspected:
		clock_inspected = true
		var photograph = main_root.find_child("OpeningPhotograph", true, false)
		if photograph and photograph.has_node("InteractionArea"):
			photograph.get_node("InteractionArea").is_enabled = true
	elif evidence_id == "photo" and clock_inspected and not photo_inspected:
		photo_inspected = true
	_update_room_markers()

func on_opening_memory_recovered() -> void:
	if not clock_inspected or not photo_inspected or opening_memory_recovered:
		return
	opening_memory_recovered = true
	for target_name in ["SectorTerminal", "EnergyPowerConduit_A"]:
		var target = main_root.find_child(target_name, true, false)
		if target and target.has_node("InteractionArea"):
			if target_name == "EnergyPowerConduit_A":
				target.is_locked = false
			target.get_node("InteractionArea").is_enabled = true
	if hud and hud.has_method("set_directive"):
		hud.set_directive("SECTOR 11 // طريق الخروج 2/4", "استعدت أثر الصوت. فعّل المحطة وموصل الطاقة لفتح البوابة.")
	_update_room_markers()

func _check_room_gate() -> void:
	if current_step == Step.STAGE_0_AWAKENING and opening_memory_recovered and wake_terminal_solved and conduit_a_energized and not room_gate_open:
		if main_root and main_root.has_method("report_opening_milestone"):
			main_root.report_opening_milestone("puzzle_solved")
		_open_primary_blast_gate()
	elif hud and current_step == Step.STAGE_0_AWAKENING and opening_memory_recovered and not room_gate_open and hud.has_method("set_directive"):
		if wake_terminal_solved:
			hud.set_directive("SECTOR 11 // طريق الخروج 3/4", "اتبع علامة موصل الطاقة، واقترب منه لإعادة تشغيل البوابة.")
		elif conduit_a_energized:
			hud.set_directive("SECTOR 11 // طريق الخروج 3/4", "الطاقة عادت. اتبع علامة المحطة لاستعادة أثر الاستيقاظ.")

func _update_room_markers() -> void:
	if not hud or not main_root:
		return
	if hud.has_method("remove_compass_marker"):
		hud.remove_compass_marker("opening_clock")
		hud.remove_compass_marker("opening_photo")
		hud.remove_compass_marker("wake_terminal")
		hud.remove_compass_marker("power_conduit")
		hud.remove_compass_marker("room_gate")
	if not hud.has_method("add_compass_marker"):
		return
	var target_name := ""
	var marker_id := ""
	var label := ""
	if not clock_inspected:
		target_name = "OpeningClock"
		marker_id = "opening_clock"
		label = "11:11"
	elif not photo_inspected:
		target_name = "OpeningPhotograph"
		marker_id = "opening_photo"
		label = "الأثر الشخصي"
	elif not opening_memory_recovered:
		return
	elif room_gate_open:
		target_name = "PrimaryBlastGate"
		marker_id = "room_gate"
		label = "البوابة"
	elif not wake_terminal_solved and not conduit_a_energized:
		target_name = "SectorTerminal"
		marker_id = "wake_terminal"
		label = "المحطة"
	elif not wake_terminal_solved:
		target_name = "SectorTerminal"
		marker_id = "wake_terminal"
		label = "المحطة"
	else:
		target_name = "EnergyPowerConduit_A"
		marker_id = "power_conduit"
		label = "موصل الطاقة"
	var target := main_root.find_child(target_name, true, false) as Node3D
	if target:
		hud.add_compass_marker(marker_id, target.global_position, label)

func _open_primary_blast_gate() -> void:
	room_gate_open = true
	if main_root and main_root.has_method("report_opening_milestone"):
		main_root.report_opening_milestone("door_unlocked")
		main_root.report_opening_milestone("gate_revealed")
	var gate1 = main_root.find_child("PrimaryBlastGate", true, false) if main_root else null
	if gate1:
		gate1.keep_collision_when_open = true
	# Show a narrow view beyond the threshold without activating later gameplay.
	var corridor = main_root.find_child("Corridor1_Decontamination", true, false) if main_root else null
	if corridor:
		corridor.visible = true
		corridor.process_mode = Node.PROCESS_MODE_DISABLED
	var breach = main_root.find_child("BlastGateBreachCinematic", true, false) if main_root else null
	if breach and player and gate1 and not main_root.get("reduced_motion"):
		breach.play(player, gate1)
	elif gate1 and gate1.has_method("open_gate"):
		gate1.unlock_gate()
		gate1.open_gate()

	if hud:
		if hud.has_method("show_tutorial_toast"):
			hud.show_tutorial_toast(
				"TOAST_GATE1",
				"SIGNAL RESTORED",
				"البوابة الرئيسية",
				"انفتحت البوابة. ما وراءها ينتظر في الفصل التالي.",
				5.0
			)
		if hud.has_method("set_directive"):
			hud.set_directive(
				"SECTOR 11 // طريق الخروج 2/2",
				"اقترب من البوابة، وانظر إلى اللمحة التي كشفتها في الجانب الآخر."
			)

func _on_security_droid_defeated(droid_node: Node) -> void:
	if current_step == Step.STAGE_1_DECONTAMINATION:
		corridor_droid_defeated = true
		# Unlock Substation Power Gate (Gate 2 at z = -60)
		var gate2 = main_root.find_child("SubstationPowerGate", true, false) if main_root else null
		if gate2 and gate2.has_method("open_gate"):
			gate2.unlock_gate()
			gate2.open_gate()

		# Reveal & activate Stage 2 (Generator Hall)
		set_zone_active("Room2_GeneratorHall", true)
		set_zone_active("SideChamber2_DissectionLab", true)
		for droid in main_root.find_children("*", "Sector11SecurityDroid", true, false):
			if droid.get_parent() and "Room2" in droid.get_parent().name:
				droid.visible = true
				droid.process_mode = Node.PROCESS_MODE_INHERIT

		current_step = Step.STAGE_2_GENERATOR_HALL
		emit_signal("prologue_step_changed", "STAGE_2_GENERATOR_HALL")

		if hud:
			if hud.has_method("show_tutorial_toast"):
				hud.show_tutorial_toast(
					"TOAST_GATE2",
					"ACCESS GRANTED",
					"SUBSTATION POWER GATE",
					"Gate opened. Enter Generator Hall and energize Conduits B & C.",
					5.0
				)
			if hud.has_method("set_directive"):
				hud.set_directive(
					"SECTOR 11 // GENERATOR HALL",
					"اضرب موصلي الطاقة B و C لشحن شبكة الطاقة وفتح بوابة الحجر الصحي."
				)

func _check_generator_hall_completion() -> void:
	if conduit_b_energized and conduit_c_energized:
		# Unlock Quarantine Gate (Gate 3 at z = -100)
		var gate3 = main_root.find_child("QuarantineGate", true, false) if main_root else null
		if gate3 and gate3.has_method("open_gate"):
			gate3.unlock_gate()
			gate3.open_gate()

		# Reveal & activate Stage 3 (Chimera Arena)
		set_zone_active("Room3_ChimeraTrench", true)

		current_step = Step.STAGE_3_CHIMERA_TRENCH
		emit_signal("prologue_step_changed", "STAGE_3_CHIMERA_TRENCH")

		if hud:
			if hud.has_method("show_tutorial_toast"):
				hud.show_tutorial_toast(
					"TOAST_GATE3",
					"CRITICAL OVERRIDE",
					"QUARANTINE GATE",
					"Quarantine breach detected. Approaching Specimen EX-000 Trench.",
					5.0
				)
			if hud.has_method("set_directive"):
				hud.set_directive(
					"SECTOR 11 // QUARANTINE TRENCH",
					"تحذير: مؤشرات حيوية عدائية من الدرجة S في الأمام! استعد للمعركة."
				)

func _trigger_specimen_boss_battle() -> void:
	if main_root and main_root.has_method("activate_specimen_encounter"):
		main_root.activate_specimen_encounter()
	elif main_root and main_root.has_method("_set_specimen_encounter_active"):
		main_root.call("_set_specimen_encounter_active", true)

	if player and player.has_method("unsheath_weapon"):
		player.unsheath_weapon()

	if hud and hud.has_method("show_tutorial_toast"):
		hud.show_tutorial_toast(
			"TOAST_BOSS",
			"LMB / RMB / C",
			"CHIMERA SPECIMEN EX-000",
			"Strike combo [LMB], Evade slam shockwaves with [RMB / SPACE]",
			6.0
		)

func _on_specimen_defeated() -> void:
	# Unlock Executive Airlock (Gate 4 at z = -145)
	var gate4 = main_root.find_child("ExecutiveAirlock", true, false) if main_root else null
	if gate4 and gate4.has_method("open_gate"):
		gate4.unlock_gate()
		gate4.open_gate()

	# Reveal & activate Stage 4 (Dr. Kinga Neuro-Lab)
	set_zone_active("Room4_KingaNeuroLab", true)
	if kinga_actor:
		kinga_actor.visible = true
		kinga_actor.process_mode = Node.PROCESS_MODE_INHERIT

	if player and player.has_method("unlock_shadow_step"):
		player.unlock_shadow_step()

	current_step = Step.STAGE_4_KINGA_NEURO_LAB
	emit_signal("prologue_step_changed", "STAGE_4_KINGA_NEURO_LAB")

	if hud:
		if hud.has_method("show_tutorial_toast"):
			hud.show_tutorial_toast(
				"TOAST_SHADOW_STEP",
				"SHIFT / RMB",
				"SKILL UNLOCKED: SHADOW STEP",
				"Press [SHIFT/RMB] to instantly blink through space",
				6.0
			)
		if hud.has_method("set_directive"):
			hud.set_directive(
				"SECTOR 11 // EXECUTIVE NEURO-LAB",
				"تم القضاء على العينة EX-000. البوابة التنفيذية مفتوحة — ادخل مختبر كينجا."
			)

func _trigger_kinga_combat_battle() -> void:
	if not kinga_actor:
		kinga_actor = main_root.find_child("DrKinga", true, false) as DrKinga if main_root else null

	if kinga_actor and kinga_actor.has_method("start_combat_encounter"):
		kinga_actor.start_combat_encounter(player)

	if hud:
		if hud.has_method("show_tutorial_toast"):
			hud.show_tutorial_toast(
				"TOAST_KINGA",
				"DR. KINGA",
				"CHIEF ARCHITECT",
				"Break his hexagonal barrier with continuous strikes!",
				5.0
			)
		if hud.has_method("set_directive"):
			hud.set_directive(
				"SECTOR 11 // DR. KINGA CONFRONTATION",
				"واجه رئيس المشروع د. كينجا! اكسر درعه السداسي وتفادَ أشعة الليزر."
			)

func _on_kinga_defeated() -> void:
	current_step = Step.STAGE_5_ZERO_CLIMAX
	emit_signal("prologue_step_changed", "STAGE_5_ZERO_CLIMAX")

	if hud and hud.has_method("set_directive"):
		hud.set_directive(
			"SECTOR 11 // FACILITY NEURAL OVERLOAD",
			"كينجا ينهار رعباً ويفعل التفجير العصبي الذاتي! الوعي يتلاشى..."
		)

	var tree = get_tree() if is_inside_tree() else null
	if tree:
		tree.create_timer(2.0).timeout.connect(_transition_to_ocean_abyss)
	else:
		_transition_to_ocean_abyss()

func _transition_to_ocean_abyss() -> void:
	current_step = Step.OCEAN_ABYSS_CONTRACT
	emit_signal("prologue_step_changed", "OCEAN_ABYSS_CONTRACT")

	if hud and hud.has_method("set_directive"):
		hud.set_directive(
			"CRITICAL // HEART FLATLINE",
			"انطفاء المؤشرات الحيوية لـ EX-011... السقوط في قاع المحيط المظلم."
		)

	var tree = get_tree() if is_inside_tree() else null
	if tree:
		tree.create_timer(2.2).timeout.connect(_forge_zero_contract)
	else:
		_forge_zero_contract()

func _forge_zero_contract() -> void:
	if hud and hud.has_method("set_directive"):
		hud.set_directive(
			"ABYSS // ZERO'S COVENANT",
			"«هل تريد الانتقام؟ سأمنحك القوة... لكن الثمن هو إنسانيتك!» — غرس الكاتانا في القلب."
		)

	var tree = get_tree() if is_inside_tree() else null
	if tree:
		tree.create_timer(3.5).timeout.connect(_transition_to_hysterical_awakening)
	else:
		_transition_to_hysterical_awakening()

func _transition_to_hysterical_awakening() -> void:
	current_step = Step.HYSTERICAL_AWAKENING
	emit_signal("prologue_step_changed", "HYSTERICAL_AWAKENING")

	if player:
		player.set_combat_available(true)
		player.set_zero_eye_active(true)
		player.manifest_zero_wing()
		if player.has_method("play_anim"):
			player.play_anim("LAUGH", 0.1)

	if hud and hud.has_method("set_directive"):
		hud.set_directive(
			"ZERO'S AWAKENING // HYSTERICAL LAUGH",
			"إيكو يضحك بهيستيرية ويكسر القيود! كينجا يزحف رعباً: «مستحيل! جسد بشري لا يتحمل هذا!»"
		)

	var tree = get_tree() if is_inside_tree() else null
	if tree:
		tree.create_timer(3.0).timeout.connect(trigger_solo_leveling_glitch)
	else:
		trigger_solo_leveling_glitch()

func trigger_solo_leveling_glitch() -> void:
	current_step = Step.SOLO_LEVELING_GLITCH_CHOICE
	emit_signal("prologue_step_changed", "SOLO_LEVELING_GLITCH_CHOICE")

	Engine.time_scale = 0.05

	if hud:
		var sys_win = hud.find_child("SystemWindow", true, false)
		if sys_win and sys_win.has_method("show_solo_leveling_glitch_prompt"):
			sys_win.show_solo_leveling_glitch_prompt(Callable(self, "_on_glitch_choice_made"))
		else:
			_on_glitch_choice_made("ACCEPT_SINGULARITY")
	else:
		_on_glitch_choice_made("ACCEPT_SINGULARITY")

func _on_glitch_choice_made(_choice_id: String) -> void:
	Engine.time_scale = 1.0

	if hud and hud.has_method("set_directive"):
		hud.set_directive(
			"SYSTEM // SINGULARITY ACCEPTED",
			"تسري خطوط البيانات الحمراء في عروق إيكو... انقطاع الوعي!"
		)

	var tree = get_tree() if is_inside_tree() else null
	if tree:
		tree.create_timer(1.8).timeout.connect(_transition_to_nocturnal_hospital)
	else:
		_transition_to_nocturnal_hospital()

func _transition_to_nocturnal_hospital() -> void:
	current_step = Step.NOCTURNAL_HOSPITAL_WAKE
	emit_signal("prologue_step_changed", "NOCTURNAL_HOSPITAL_WAKE")

	if hud and hud.has_method("set_directive"):
		hud.set_directive(
			"NOCTURNAL WARD // MINATO HOSPITAL [02:14 AM]",
			"مستشفى مهجور مظلم... صوت نبضات القلب وأمطار الليل على زجاج النافذة."
		)

	emit_signal("prologue_completed")

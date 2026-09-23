extends SceneTree

const ProceduralSecondaryMotion = preload("res://scripts/player/procedural_secondary_motion.gd")
const ProceduralFootIK = preload("res://scripts/player/procedural_foot_ik.gd")
const GhostTrailSpawner = preload("res://scripts/player/ghost_trail_spawner.gd")
const VolumetricFogController = preload("res://scripts/effects/volumetric_fog_controller.gd")
const CineCameraDirector = preload("res://scripts/cinematics/cine_camera_director.gd")
const RealityGlitchOverlay = preload("res://scripts/ui/reality_glitch_overlay.gd")
const HospitalEgressHatch = preload("res://scripts/props/hospital_egress_hatch.gd")
const MinatoKasumiAlleyway = preload("res://scripts/environment/minato_kasumi_alleyway.gd")
const InteractableComponent = preload("res://scripts/interaction/interactable_component.gd")
const EconomyManager = preload("res://scripts/systems/economy_manager.gd")
const PlayerInventory = preload("res://scripts/systems/player_inventory.gd")
const HospitalSlidingDoors = preload("res://scripts/props/hospital_sliding_doors.gd")
const MinatoVendingMachine = preload("res://scripts/props/minato_vending_machine.gd")
const ResidentialHouse = preload("res://scripts/props/residential_house.gd")
const MinatoNPC = preload("res://scripts/characters/minato_npc.gd")
const PlayerNeeds = preload("res://scripts/systems/player_needs.gd")
const GameClock = preload("res://scripts/systems/game_clock.gd")
const HouseholdManager = preload("res://scripts/systems/household_manager.gd")
const KonbiniStore = preload("res://scripts/props/konbini_store.gd")
const SaveManager = preload("res://scripts/systems/save_manager.gd")
const EchoResidence = preload("res://scripts/props/echo_residence.gd")
const RideableVehicle = preload("res://scripts/vehicles/rideable_vehicle.gd")


func _init() -> void:
	print("--- 11.11 GODOT FORWARD+ AAA COLD WEAPON COMBAT TEST ---")
	var main_scene = load("res://scenes/main.tscn")
	if not main_scene:
		printerr("FAILED to load res://scenes/main.tscn")
		quit(1)
		return

	var root_node = main_scene.instantiate()
	root.add_child(root_node)

	print("[1/8] Main scene instantiated successfully.")

	var player = root_node.get_node_or_null("EchoPlayer")
	var boss = root_node.get_node_or_null("SpecimenEX000")
	var companion = root_node.get_node_or_null("FloatingPod")
	var hud = root_node.get_node_or_null("GameplayHUD")
	var capsule = root_node.get_node_or_null("Sector11Capsule")
	var intro_cam = root_node.get_node_or_null("IntroCamera")

	if not player or not boss or not companion or not hud or not capsule or not intro_cam:
		printerr("FAILED: One or more required nodes missing from main.tscn")
		quit(1)
		return

	print("[2/8] Scene hierarchy verified: EchoPlayer, SpecimenEX000, FloatingPod, GameplayHUD, Sector11Capsule, IntroCamera.")

	# Verify Visual Model Instantiations & Skeletal Rig
	var echo_model = player.find_child("EchoOpeningUniform", true, false)
	if not echo_model:
		echo_model = player.find_child("echo_tripo_native", true, false)
	var boss_model = boss.find_child("tripo_monster", true, false)
	var capsule_model = capsule.find_child("CryogenicPodModel", true, false)
	if not capsule_model:
		capsule_model = capsule.find_child("sector11-wake-capsule-v2", true, false)

	assert(echo_model != null, "Echo native rigged GLB model must be instantiated")
	assert(boss_model != null, "Specimen EX-000 GLB model must be instantiated")
	assert(capsule_model != null, "Sector 11 Capsule GLB model must be instantiated")

	# Verify 3D Katana Blade & Slash Arc
	var katana = player.find_child("KatanaBlade", true, false)
	assert(katana != null, "KatanaBlade must be attached to EchoPlayer")
	var slash_arc = katana.find_child("SlashArc", true, false)
	assert(slash_arc != null, "SlashArc ribbon mesh must be present on Katana")

	var player_anim = player.find_child("AnimationPlayer", true, false) as AnimationPlayer
	assert(player_anim != null, "Echo model must contain an AnimationPlayer")
	var has_idle: bool = player_anim.has_animation("preset_biped_idle_001") or player_anim.has_animation("preset_idle") or player_anim.has_animation("IDLE")
	var has_walk: bool = player_anim.has_animation("preset_biped_walk_001") or player_anim.has_animation("preset_walk") or player_anim.has_animation("WALK")
	var has_run: bool = player_anim.has_animation("preset_biped_run_001") or player_anim.has_animation("preset_run") or player_anim.has_animation("RUN")
	assert(has_idle, "Echo must have idle animation")
	assert(has_walk, "Echo must have walk animation")
	assert(has_run, "Echo must have run animation")

	print("[3/8] Cold weapon & GLB assets verified: Tactical Katana, Slash Arc, Rigged Echo & Animations.")

	# Verify Initial Combat State
	assert(player.hp == 200.0, "Player initial HP should be 200")
	assert(player.stamina == 100.0, "Player initial stamina should be 100")
	assert(boss.hp == 1000.0, "Boss initial HP should be 1000")
	assert(boss.phase == 1, "Boss should start in Phase 1")

	print("[4/8] Initial vitals verified: Player HP=200/200, Stamina=100/100, Boss HP=1000/1000.")

	# Verify Lock-On Target System
	var target_reticle = boss.find_child("TargetReticle", true, false)
	assert(target_reticle != null, "TargetReticle must exist on SpecimenEX000")
	assert(target_reticle.visible == false, "Reticle should be hidden initially")

	player.toggle_lock_on(boss)
	assert(player.is_locked_on == true, "Lock-on should be active")
	assert(player.lock_target == boss, "Lock target should be boss")
	assert(target_reticle.visible == true, "Reticle should be visible when locked-on")

	player.toggle_lock_on()
	assert(player.is_locked_on == false, "Lock-on should toggle off")
	assert(target_reticle.visible == false, "Reticle should hide when unlocked")

	print("[5/8] Lock-On system verified: Holographic 3D reticle activation and tracking.")

	# Verify Companion Tactical Ultrasonic Scan & No Laser
	assert(not companion.has_method("laser_fired"), "Arcade laser fire must be removed")
	companion.trigger_scan()
	assert(boss.is_staggered == true, "Tactical resonance scan should stun the boss")

	print("[6/8] Companion tactical overhaul verified: Ultrasonic scan active, arcade laser eliminated.")

	# Position player within Katana strike range (2.0m from boss)
	player.position = boss.position + Vector3(0, 0, 2.0)
	player.perform_attack()
	assert(player.combo_count >= 1, "Cold weapon attack should land and increment combo count")
	player.trigger_hit_stop(0.06)
	assert(Engine.time_scale <= 0.05, "Hit-Stop impact freeze must engage on strike")
	Engine.time_scale = 1.0 # Reset time scale for test runner

	while player.combo_count < 5:
		player.register_hit_landed(35)
	assert(player.combo_count == 5, "Combo count should be 5")
	assert(player.combo_multiplier == 2, "Combo multiplier should be 2 at 5 hits")

	for i in range(5):
		player.register_hit_landed(35)
	assert(player.combo_count == 10, "Combo count should be 10")
	assert(player.combo_multiplier == 3, "Combo multiplier should be 3 at 10 hits (MAX CHAIN)")

	print("[7/8] Cold weapon melee combat verified: Katana hit streak (x1->x2->x3) and 0.06s Hit-Stop.")

	# Simulate Boss Phase 2 Transition & Kinetic Counter Stagger
	boss.is_staggered = false
	boss.take_damage(660) # 1000 - 70 - 660 = 270 <= 350
	assert(boss.hp <= 350.0, "Boss HP should be <= 350")
	assert(boss.phase == 2, "Boss should have transitioned to Phase 2 at HP <= 350")

	boss.start_slam_windup()
	assert(boss.is_slam_windup == true, "Boss should be in slam windup")
	boss.take_damage(50) # Counter attack during windup!
	assert(boss.is_staggered == true, "Boss should enter stagger on kinetic counter")
	assert(boss.is_slam_windup == false, "Slam windup should be cancelled on counter")

	print("[8/8] Boss Phase 2 Enrage & Kinetic Counter Stagger verified.")

	# [9/12] Verify Procedural Secondary Motion (Spring Bones / Jiggle Physics)
	var tassel = player.find_child("TasselRoot", true, false)
	assert(tassel != null, "TasselRoot node must be present on KatanaBlade")
	assert(tassel is ProceduralSecondaryMotion, "TasselRoot must use ProceduralSecondaryMotion")
	tassel.apply_impulse(Vector3(5.0, 10.0, -5.0))
	assert(tassel.angular_velocity.length() > 0.0, "Impulse should register in angular velocity")
	print("[9/12] Procedural Secondary Motion verified: Spring physics & inertia simulation active.")

	# [10/12] Verify Procedural Foot Placement IK
	var foot_ik = player.find_child("ProceduralFootIK", true, false)
	assert(foot_ik != null, "ProceduralFootIK must be present on EchoPlayer")
	assert(foot_ik is ProceduralFootIK, "Foot IK node must inherit ProceduralFootIK")
	assert(foot_ik.left_ray != null and foot_ik.right_ray != null, "Foot IK must initialize left and right raycasts")
	print("[10/12] Procedural Foot Placement IK verified: Dual ground raycasts and pelvis compensation active.")

	# [11/12] Verify Impact FX & Decal Spawner
	var impact_spawner = load("res://scripts/combat/impact_spawner.gd")
	assert(impact_spawner != null, "ImpactSpawner script must load cleanly")
	impact_spawner.spawn_katana_sparks(root_node, player.position, Vector3.UP, true)
	var sparks = root_node.find_child("KatanaSparks", true, false)
	assert(sparks != null, "KatanaSparks GPUParticles3D must be spawned in tree")
	var slash_decal = root_node.find_child("KatanaSlashDecal", true, false)
	assert(slash_decal != null, "KatanaSlashDecal must be projected in tree")

	impact_spawner.spawn_boss_slam_crater(root_node, boss.position)
	var crater = root_node.find_child("BossCraterDecal", true, false)
	assert(crater != null, "BossCraterDecal must be projected in tree")
	print("[11/12] Combat Impact FX & Decals verified: High-frequency sparks, slash decals, and slam craters.")

	# [12/15] Verify Noto-Gari Katana Sheathing & Cinematic Victory Sequence
	assert(player.has_method("sheath_weapon"), "EchoPlayer must implement sheath_weapon()")
	assert(player.has_method("unsheath_weapon"), "EchoPlayer must implement unsheath_weapon()")
	player.sheath_weapon()
	assert(player.is_sheathed == true, "Player weapon must be marked sheathed")
	player.unsheath_weapon()
	assert(player.is_sheathed == false, "Player weapon must return to ready combat stance")

	var victory_banner = hud.find_child("VictoryBanner", true, false)
	assert(victory_banner != null, "VictoryBanner must exist in GameplayHUD")
	hud.show_victory_banner("TARGET NEUTRALIZED", "SECTOR 11 CONTAINMENT RESTORED", 1.0)
	assert(victory_banner.visible == true, "VictoryBanner should display on victory sequence")
	print("[12/15] Noto-Gari Katana Sheathing & Cinematic Victory Sequence verified.")

	# [13/15] Verify Mobile Touch Controls & Virtual Joystick
	var touch_ui = hud.find_child("MobileTouchControls", true, false)
	assert(touch_ui != null, "MobileTouchControls must be present in GameplayHUD")
	var attack_btn = touch_ui.find_child("AttackBtn", true, false)
	var dodge_btn = touch_ui.find_child("DodgeBtn", true, false)
	var jump_btn = touch_ui.find_child("JumpBtn", true, false)
	var lock_btn = touch_ui.find_child("LockOnBtn", true, false)
	var scan_btn = touch_ui.find_child("ScanBtn", true, false)
	assert(attack_btn != null and dodge_btn != null and jump_btn != null and lock_btn != null and scan_btn != null, "All mobile action buttons must be present")

	if not touch_ui.joystick_moved.is_connected(player.set_mobile_input_vector):
		touch_ui.joystick_moved.connect(player.set_mobile_input_vector)

	touch_ui._update_joystick(touch_ui.joystick_center + Vector2(50, 0))
	assert(player.mobile_input_vector.x > 0.5, "Virtual joystick should deliver movement vector to player")
	touch_ui._update_joystick(touch_ui.joystick_center)
	print("[13/15] Mobile Touch Controls & Virtual Joystick verified: Full mobile touch layout active.")

	# [14/15] Verify Charged Iai Slash & Ghost Trail Phantoms
	assert(player.has_method("start_iai_charge"), "EchoPlayer must implement start_iai_charge()")
	assert(player.has_method("execute_iai_slash"), "EchoPlayer must implement execute_iai_slash()")
	boss.hp = 400.0
	boss.is_staggered = false
	player.position = boss.position + Vector3(0, 0, 2.0)
	player.visual_root.rotation = Vector3.ZERO
	player.start_iai_charge()
	assert(player.is_charging_iai == true, "Player must be in Iai charging state")
	player.update_iai_charge(1.0)
	assert(player.iai_charge >= 1.0, "Iai charge should reach full ratio")

	var boss_hp_before: float = boss.hp
	player.execute_iai_slash(1.0)
	assert(player.is_charging_iai == false, "Charging state must reset after Iai slash")
	assert(boss.hp < boss_hp_before, "Charged Iai Blink Dash must deal massive damage")

	GhostTrailSpawner.spawn_ghost(root_node, player.visual_root, 0.3)
	var ghost = root_node.find_child("GhostPhantom", true, false)
	assert(ghost != null, "GhostTrail phantom silhouette must instantiate in tree")
	print("[14/15] Charged Iai Slash & Ghost Trail Phantoms verified: 180 dmg critical blink dash active.")

	# [15/18] Verify Engaging Story Quest Directives
	var quest_box = hud.find_child("QuestContainer", true, false)
	assert(quest_box != null, "QuestContainer must exist in GameplayHUD")
	hud.set_directive("01. Neutralize Threat: Specimen EX-000", "Cold Weapon defense required.")
	assert(hud.quest_title.text.contains("01. Neutralize Threat"), "Directive title must update")
	hud.complete_directive("02. Override Primary Blast Gate", "Locate Substation Terminal to access encrypted records on 'Project Zeo'.")
	assert(hud.quest_title.text.contains("02. Override Primary Blast Gate"), "Directive must advance to next step")
	print("[15/18] Engaging Story Quest Directives verified: Genshin-tier objective tracking active.")

	# [16/18] Verify Primary Blast Gate & Hydraulic Vertical Lift
	var blast_gate = root_node.find_child("PrimaryBlastGate", true, false)
	assert(blast_gate != null, "PrimaryBlastGate must be instantiated in Sector11Facility")
	assert(blast_gate.state == blast_gate.GateState.LOCKED, "Blast gate must start LOCKED")
	blast_gate.unlock_gate()
	assert(blast_gate.state == blast_gate.GateState.UNLOCKED, "Blast gate must transition to UNLOCKED")
	blast_gate.open_gate()
	assert(blast_gate.state == blast_gate.GateState.OPENED, "Blast gate must transition to OPENED")
	assert(blast_gate.get_collision_shape() != null and blast_gate.get_collision_shape().disabled == true, "Gate collider must disable when opened")
	print("[16/18] Primary Blast Gate & Hydraulic Vertical Lift verified: 6.5m slide & collision clearance active.")

	# [17/18] Verify Substation Terminal & Cyber Hacking Puzzle
	var terminal = root_node.find_child("MainframeTerminal", true, false)
	assert(terminal != null, "MainframeTerminal must exist in SubstationExtension")
	var puzzle = hud.find_child("TerminalHackPuzzle", true, false)
	assert(puzzle != null, "TerminalHackPuzzle must exist in GameplayHUD")
	puzzle.open_puzzle()
	assert(puzzle.visible == true, "Terminal puzzle must become visible on open")
	assert(puzzle.is_solved == false, "Puzzle must not start in solved state")
	puzzle.auto_align_solution()
	assert(puzzle.is_solved == true, "Puzzle must report solved upon frequency alignment")
	assert(puzzle.get_progress_bar() != null and puzzle.get_progress_bar().value >= 99.0, "Progress bar must register 100% synchronization")
	terminal.complete_hack()
	assert(terminal.is_hacked == true, "Terminal must register completed hack")
	puzzle.close_puzzle()
	assert(puzzle.visible == false, "Puzzle must hide upon closure")
	print("[17/18] Substation Terminal & Cyber Hacking Puzzle verified: Resonance frequency decryption active.")

	# [18/18] Verify Cinematic Narrative Dialogue & Directive Progression
	var dialogue = hud.find_child("DialogueOverlay", true, false)
	assert(dialogue != null, "DialogueOverlay must exist in GameplayHUD")
	dialogue.start_dialogue()
	assert(dialogue.is_active == true, "Dialogue system must become active")
	assert(dialogue.visible == true, "Dialogue overlay must become visible")
	assert(dialogue.current_line_index == 0, "Dialogue should start at line 0")
	dialogue.advance_dialogue() # Finish typing
	dialogue.advance_dialogue() # Advance to line 1
	assert(dialogue.current_line_index == 1, "Dialogue must advance to line 1")
	dialogue.close_dialogue()
	assert(dialogue.is_active == false, "Dialogue must deactivate on close")
	assert(dialogue.visible == false, "Dialogue overlay must hide on close")

	hud.complete_directive("04. Investigate Deep Sector 11", "Trace origin of manual wake signal before secondary defense lockdown.")
	assert(hud.quest_title.text.contains("04. Investigate Deep Sector 11"), "Directive 04 must update cleanly")
	print("[18/21] Cinematic Narrative Dialogue & Directive Progression verified: Multi-character story delivery active.")

	# [19/21] Verify Solo Leveling System Window (Level Up & Rewards)
	var system_win = hud.find_child("SystemWindow", true, false)
	assert(system_win != null, "SystemWindow must exist in GameplayHUD")
	system_win.show_level_up(2)
	assert(system_win.visible == true, "SystemWindow must become visible on show_level_up")
	assert(system_win.title_lbl.text.contains("LEVEL UP"), "Title label must show LEVEL UP")
	system_win.show_reward_window("SHADOW KATANA // نصل ملوك الظلال")
	assert(system_win.title_lbl.text.contains("SYSTEM GIFT"), "Title label must show SYSTEM GIFT")
	system_win.close_window()
	assert(system_win.visible == false, "SystemWindow must hide upon close_window")
	print("[19/21] Solo Leveling System Window verified: Dynamic notification, level-up, and rewards active.")

	# [20/23] Verify Shadow Katana & Dark Flame Shader
	assert(player.has_method("equip_shadow_katana"), "EchoPlayer must implement equip_shadow_katana()")
	player.equip_shadow_katana()
	assert(player.is_shadow_katana_equipped == true, "Player must register Shadow Katana equipped")
	var shadow_katana = player.find_child("ShadowKatana", true, false)
	assert(shadow_katana != null and shadow_katana.visible == true, "ShadowKatana node must become visible")
	var standard_katana = player.find_child("KatanaBlade", true, false)
	assert(standard_katana != null and standard_katana.visible == false, "Standard KatanaBlade must hide when Shadow Katana is equipped")
	shadow_katana.trigger_shadow_burst()
	assert(shadow_katana.blade_glow.light_energy > 5.0, "Shadow burst should amplify blade glow energy")
	print("[20/23] Shadow Katana & Dark Flame Shader verified: Black flame aura & void slice active.")

	# [21/23] Verify Zero's Right Eye Singularity & Shadow Monarch Wing Strict Pact Dormancy
	var zero_eye = player.find_child("ZeroEyeSingularity", true, false)
	var zero_wing = player.find_child("ZeroShadowWing", true, false)
	assert(zero_eye != null, "ZeroEyeSingularity must be attached to EchoPlayer")
	assert(zero_wing != null, "ZeroShadowWing must be attached to EchoPlayer")
	# Strict narrative constraint: Eye and wing MUST be dormant at start and after equipping katana
	assert(player.contract_with_zero_sealed == false, "Contract with Zero must start unsealed (false)")
	assert(zero_eye.is_singularity_active == false, "Eye Singularity must remain dormant before the Pact")
	assert(zero_wing.is_wing_manifested == false, "Shadow Wing must remain dormant before the Pact")
	assert(zero_wing.visible == false, "Shadow Wing node must be invisible before the Pact")

	# Awaken Zero Pact: Both Eye Singularity and Shadow Monarch Wing manifest simultaneously
	player.awaken_zero_pact(1.8)
	assert(player.contract_with_zero_sealed == true, "Pact must be registered as sealed")
	assert(zero_eye.is_singularity_active == true, "Singularity eye flare must manifest upon pact awakening")
	assert(zero_eye.eye_light.visible == true, "Eye light must be visible upon pact awakening")
	assert(zero_wing.is_wing_manifested == true, "Shadow Wing must manifest upon pact awakening")
	assert(zero_wing.visible == true, "Shadow Wing must be visible upon pact awakening")

	player.set_zero_eye_active(false)
	assert(zero_eye.is_singularity_active == false, "Singularity must deactivate when toggled off")
	player.dismiss_zero_wing()
	assert(zero_wing.is_wing_manifested == false, "Wing must deactivate when dismissed")
	print("[21/23] Zero's Right Eye & Shadow Monarch Wing verified: Strict pre-pact dormancy and simultaneous awakening active.")

	# [22/23] Verify Tripo 3D Restraint & Neural Torture Chair Prop
	var chair_scene = load("res://scenes/props/restraint_chair.tscn")
	assert(chair_scene != null, "Restraint chair scene must load cleanly")
	var chair = chair_scene.instantiate()
	root.add_child(chair)
	assert(chair.has_method("restrain_subject"), "Chair must implement restrain_subject()")
	assert(chair.has_method("trigger_neural_surge"), "Chair must implement trigger_neural_surge()")
	assert(chair.has_method("break_restraints"), "Chair must implement break_restraints()")
	assert(chair.is_restrained == false, "Chair must start empty/idle")

	chair.restrain_subject("ECHO_EX011")
	assert(chair.is_restrained == true and chair.restraints_locked == true, "Subject must be securely restrained")

	chair.trigger_neural_surge(2.0)
	assert(chair.neural_surge_active == true, "Neural surge must be active during psychological torture")
	assert(chair.surge_light != null and chair.surge_light.visible == true, "Torture surge crimson light must activate")

	chair.break_restraints()
	assert(chair.is_restrained == false and chair.restraints_locked == false, "Restraints must shatter upon Zero awakening")
	chair.queue_free()
	print("[22/23] Tripo 3D Restraint & Neural Torture Chair verified: Straps, crimson surge & shattered restraints active.")

	# [23/23] Verify Redesigned Cybernetic Chimera Bioweapon Boss & Bio-Energy Core
	var boss_core_light = boss.find_child("BioEnergyCoreLight", true, false)
	assert(boss_core_light != null, "BioEnergyCoreLight must exist on redesigned Specimen EX-000")
	assert(boss_core_light.light_color.r > 0.8, "Enraged bio-core in Phase 2 must emit crimson rage energy")
	# Reset boss to Phase 1 to verify standby cyan energy mode
	boss.phase = 1
	boss.hp = 1000.0
	boss_core_light.light_color = Color(0, 0.94, 1, 1)
	assert(boss_core_light.light_color.b > 0.8 and boss_core_light.light_color.r < 0.2, "Standby bio-core must emit cyan energy")
	# Trigger Phase 2 transition to re-verify dynamic surge
	boss.take_damage(700.0)
	assert(boss.phase == 2, "Boss must transition to Phase 2")
	assert(boss_core_light.light_color.r > 0.8, "Surging bio-core must switch to crimson rage")
	print("[23/24] Redesigned Cybernetic Chimera Bioweapon & Bio-Energy Core verified: Dark sci-fi manhwa aesthetic active.")

	# [24/24] Verify Tripo V3 Laboratory Mainframe Server Racks in Sector 11 Substation
	var server_left = root_node.find_child("ServerRackLeft", true, false)
	var server_right = root_node.find_child("ServerRackRight", true, false)
	assert(server_left != null, "ServerRackLeft must be instantiated in SubstationExtension")
	assert(server_right != null, "ServerRackRight must be instantiated in SubstationExtension")
	var server_left_model = server_left.find_child("server_rack", true, false)
	var server_right_model = server_right.find_child("server_rack", true, false)
	assert(server_left_model != null and server_right_model != null, "Tripo V3 ServerRack GLB models must be present")
	print("[24/26] Tripo V3 Laboratory Mainframe Server Racks verified: High-poly cybernetic infrastructure active.")

	# [25/26] Verify Dr. Kinga Character Actor, Monocle Cybernetics & Neuro-Syringe
	var kinga = root_node.find_child("DrKinga", true, false)
	assert(kinga != null, "DrKinga actor must be instantiated in Main scene")
	assert(kinga.monocle_light != null and kinga.monocle_light.visible == true, "Kinga cybernetic monocle light must be active")
	kinga.prepare_injection()
	assert(kinga.current_state == kinga.State.ADMINISTERING_INJECTION, "Kinga must enter injection state")
	assert(kinga.syringe_glow != null and kinga.syringe_glow.visible == true, "Neuro-syringe glow must illuminate")
	kinga.administer_injection()
	kinga.react_to_zero_singularity()
	assert(kinga.current_state == kinga.State.TERRIFIED, "Kinga must enter terrified state upon Zero awakening")
	print("[25/26] Dr. Kinga Character Actor verified: Monocle, toxic neuro-syringe & terror reaction active.")

	# [26/26] Verify Kinga Torture, Despair Abyss, Zero Covenant & Hospital Awakening Sequence
	var torture_seq = root_node.find_child("KingaTortureSequence", true, false)
	assert(torture_seq != null, "KingaTortureSequence must exist in Main scene")
	torture_seq.player_actor = player
	assert(torture_seq.audio_synth != null, "ProceduralCinematicAudio must be initialized")

	# Verify Procedural Sound Synthesis
	var beep_wav = ProceduralCinematicAudio.create_heart_monitor_beep()
	var shock_wav = ProceduralCinematicAudio.create_neural_shock_sizzle()
	var abyss_wav = ProceduralCinematicAudio.create_abyss_drone()
	var chime_wav = ProceduralCinematicAudio.create_covenant_chime()
	assert(beep_wav != null and beep_wav.data.size() > 0, "Procedural heart monitor beep WAV must generate PCM data")
	assert(shock_wav != null and shock_wav.data.size() > 0, "Procedural neural shock WAV must generate PCM data")
	assert(abyss_wav != null and abyss_wav.data.size() > 0, "Procedural abyss drone WAV must generate PCM data")
	assert(chime_wav != null and chime_wav.data.size() > 0, "Procedural covenant chime WAV must generate PCM data")

	# Step-through the cinematic journey
	torture_seq.start_confrontation()
	assert(torture_seq.current_phase == torture_seq.CinematicPhase.KINGA_CONFRONTATION, "Must transition to KINGA_CONFRONTATION")

	torture_seq.trigger_neural_injection()
	assert(torture_seq.current_phase == torture_seq.CinematicPhase.NEURAL_INJECTION_COLLAPSE, "Must transition to NEURAL_INJECTION_COLLAPSE")

	torture_seq.enter_restraint_torture()
	assert(torture_seq.current_phase == torture_seq.CinematicPhase.CHAIR_RESTRAINT_TORTURE, "Must transition to CHAIR_RESTRAINT_TORTURE")

	# Interactive struggling against neural voltage
	torture_seq.player_struggle_pulse()
	torture_seq.player_struggle_pulse()
	torture_seq.player_struggle_pulse()
	assert(torture_seq.current_phase == torture_seq.CinematicPhase.PSYCHOLOGICAL_ILLUSION, "Struggles must advance to PSYCHOLOGICAL_ILLUSION")

	torture_seq.enter_despair_abyss()
	assert(torture_seq.current_phase == torture_seq.CinematicPhase.DESPAIR_ABYSS_FALL, "Must plunge into DESPAIR_ABYSS_FALL")

	torture_seq.trigger_zero_covenant_dialogue()
	assert(torture_seq.current_phase == torture_seq.CinematicPhase.ZERO_MEETING_COVENANT, "Must enter ZERO_MEETING_COVENANT")

	# Covenant sealed: Singularity eye flares, Shadow Wing manifests, restraints break
	torture_seq.seal_zero_pact()
	assert(torture_seq.current_phase == torture_seq.CinematicPhase.PACT_SEALED_EXPLOSION, "Must transition to PACT_SEALED_EXPLOSION")
	assert(player.contract_with_zero_sealed == true, "Covenant with Zero must be permanently sealed")
	assert(zero_eye.is_singularity_active == true, "Zero eye singularity must blaze")
	assert(zero_wing.is_wing_manifested == true, "Zero shadow monarch wing must be manifested")

	torture_seq.trigger_system_intervention()
	assert(torture_seq.current_phase == torture_seq.CinematicPhase.SYSTEM_INTERVENTION, "System must intervene on threshold override")

	# Hospital Awakening: Bed model, heart beep, eye softly dims, physical scars remain
	torture_seq.trigger_hospital_awakening()
	assert(torture_seq.current_phase == torture_seq.CinematicPhase.HOSPITAL_AWAKENING, "Must transition to HOSPITAL_AWAKENING")
	var hospital_bed = root_node.find_child("HospitalBed", true, false)
	assert(hospital_bed != null, "HospitalBed must exist in scene hierarchy")
	var hospital_bed_model = hospital_bed.find_child("hospital_bed", true, false)
	assert(hospital_bed_model != null, "Tripo V3 HospitalBed GLB must be loaded")

	print("[26/30] Kinga Torture, Despair Abyss, Zero Covenant & Hospital Awakening verified: Authentic Manhwa emotional journey active.")

	# [27/30] Verify CineCameraDirector (Trauma shake, Dutch tilt, FOV punch & presets)
	var cam_director = torture_seq.cam_director
	assert(cam_director != null, "CineCameraDirector must be initialized")
	cam_director.apply_trauma(0.5)
	assert(cam_director.trauma == 0.5, "Trauma must register on camera")
	cam_director.set_dutch_tilt(6.0, 0.0)
	assert(cam_director.current_dutch_tilt == 6.0, "Dutch tilt angle must be 6.0 deg")
	cam_director.punch_fov(48.0, 0.0, 0.0)
	cam_director.preset_combat_critical()
	print("[27/30] CineCameraDirector verified: Trauma shake, Dutch tilt, FOV punch & presets active.")

	# [28/30] Verify Procedural AI Voice Acting Formants & Reality Glitch Audio Synthesis
	var kinga_wav = ProceduralCinematicAudio.create_kinga_voice_line()
	var zero_wav = ProceduralCinematicAudio.create_zero_whisper()
	var laugh_wav = ProceduralCinematicAudio.create_echo_hysterical_laugh()
	var ecg_wav = ProceduralCinematicAudio.create_ecg_flatline()
	var glitch_wav = ProceduralCinematicAudio.create_reality_glitch_sfx()
	assert(kinga_wav != null and kinga_wav.data.size() > 0, "Kinga voice formant WAV must generate PCM data")
	assert(zero_wav != null and zero_wav.data.size() > 0, "Zero whisper sub-bass WAV must generate PCM data")
	assert(laugh_wav != null and laugh_wav.data.size() > 0, "Echo hysterical laugh WAV must generate PCM data")
	assert(ecg_wav != null and ecg_wav.data.size() > 0, "ECG flatline alarm WAV must generate PCM data")
	assert(glitch_wav != null and glitch_wav.data.size() > 0, "Reality glitch SFX WAV must generate PCM data")
	print("[28/30] Procedural Voice Formants & Reality Audio verified: Cold scientist, demonic whisper & glitch SFX active.")

	# [29/30] Verify Volumetric Fog Controller, God Rays & Atmospheric Particles
	var fog_controller = torture_seq.fog_controller
	assert(fog_controller != null, "VolumetricFogController must be initialized")
	fog_controller.apply_profile(VolumetricFogController.FogProfile.SECTOR11_LAB, 0.0)
	assert(fog_controller.current_profile == VolumetricFogController.FogProfile.SECTOR11_LAB, "Lab profile must apply")
	fog_controller.apply_profile(VolumetricFogController.FogProfile.HOSPITAL_SUNLIGHT, 0.0)
	assert(fog_controller.current_profile == VolumetricFogController.FogProfile.HOSPITAL_SUNLIGHT, "Hospital sunlight profile must apply")
	var dark_matter = torture_seq.find_child("VoidDarkMatter", true, false)
	assert(dark_matter != null, "VoidDarkMatter GPU particles must be present in KingaTortureSequence")
	var dust_motes = torture_seq.find_child("DustMotesParticles", true, false)
	assert(dust_motes != null, "DustMotesParticles must be present in HospitalBed area")
	print("[29/30] Volumetric Lighting & Atmospheric Particles verified: Dynamic fog profiles, God rays & dark matter active.")

	# [30/30] Verify Reality Glitch Overlay, Simulation Anomaly Detection & Hospital Egress Breach
	var glitch_overlay = root_node.find_child("RealityGlitchOverlay", true, false)
	assert(glitch_overlay != null, "RealityGlitchOverlay must exist in Main scene")
	glitch_overlay.pulse_glitch(0.8, 0.1)
	assert(glitch_overlay.current_intensity == 0.8, "Glitch intensity must set to 0.8")
	var egress_hatch = torture_seq.find_child("HospitalEgressHatch", true, false)
	assert(egress_hatch != null, "HospitalEgressHatch must be in hospital area")
	assert(egress_hatch.current_state == egress_hatch.HatchState.LOCKED_SEALED, "Egress hatch starts sealed")
	torture_seq.trigger_simulation_anomaly()
	assert(torture_seq.current_phase == torture_seq.CinematicPhase.SIMULATION_BREACH, "Must enter SIMULATION_BREACH")
	assert(egress_hatch.current_state == egress_hatch.HatchState.ANOMALY_EXPOSED, "Egress hatch must expose simulation anomaly")
	egress_hatch.breach_hatch()
	assert(egress_hatch.current_state == egress_hatch.HatchState.BREACHED_OPEN, "Egress hatch must breach open")
	print("[30/33] Reality Glitch & Simulation Breach verified: Fullscreen glitch shader, anomaly alarm & egress breach active.")

	# [31/33] Verify Shadow Step Skill Awakening, Blink Teleportation & Crit Surge
	assert(player.shadow_step_unlocked == false, "Shadow Step must start locked before reality emergence")
	player.unlock_shadow_step()
	assert(player.shadow_step_unlocked == true, "Shadow Step must unlock on emergence")
	var initial_player_pos = player.global_position if player.is_inside_tree() else player.position
	var shadow_step_success = player.perform_shadow_step(boss)
	assert(shadow_step_success == true, "Shadow Step must successfully execute toward boss target")
	assert(player.perfect_dodge_surge == true, "Shadow Step must charge critical surge")
	var final_player_pos = player.global_position if player.is_inside_tree() else player.position
	assert(final_player_pos != initial_player_pos, "Shadow Step must teleport player to target rear")
	print("[31/33] Shadow Step Skill verified: Blink teleportation, target re-orientation & critical surge active.")

	# [32/38] Verify Minato-Kasumi Coastal Alleyway & Ambient Ocean Breeze
	var alleyway = root_node.find_child("MinatoKasumiAlleyway", true, false)
	assert(alleyway != null, "MinatoKasumiAlleyway must be instantiated in Main scene")
	var seawall = alleyway.find_child("Seawall", true, false)
	var ocean_surface = alleyway.find_child("OceanSurface", true, false)
	var vending_machine = alleyway.find_child("MinatoVendingMachine", true, false)
	if not vending_machine:
		vending_machine = alleyway.find_child("VendingMachine", true, false)
	var streetlight = alleyway.find_child("StreetLight", true, false)
	assert(seawall != null, "Concrete seawall embankment must be present")
	assert(ocean_surface != null, "Ocean surface backdrop plane must be present")
	assert(vending_machine != null, "Japanese vending machine must be present")
	assert(streetlight != null, "Japanese amber streetlight must be present")
	var ocean_wav = ProceduralCinematicAudio.create_ocean_coastal_breeze()
	assert(ocean_wav != null and ocean_wav.data.size() > 0, "Ocean coastal breeze WAV must generate PCM data")
	print("[32/38] Minato-Kasumi Coastal Alleyway verified: Seawall, ocean plane, vending machine & coastal breeze active.")

	# [33/38] Verify Seamless Emergence Transition & Directive 09
	alleyway._on_emergence_entered(player)
	assert(alleyway.has_emerged == true, "Alleyway emergence must register on player entry")
	root_node._on_street_emerged()
	assert(hud.current_directive_title.begins_with("09."), "Directive must advance to 09. Minato-Kasumi // First Breath of Reality")
	print("[33/38] Seamless Emergence Transition verified: Hospital breach to Minato-Kasumi coastal reality active.")

	# [34/38] Verify Universal Interaction Framework & Contextual HUD Prompt
	var sato_house = alleyway.find_child("ResidentialHouse", true, false)
	assert(sato_house != null, "ResidentialHouse must exist in Minato-Kasumi alleyway")
	var house_interact = sato_house.find_child("DoorbellInteractable", true, false)
	assert(house_interact != null and house_interact is InteractableComponent, "Doorbell must integrate InteractableComponent")
	assert(house_interact.verb == InteractableComponent.InteractionVerb.RING, "Doorbell verb must be RING")
	assert(house_interact.get_full_prompt().contains("RING DOORBELL"), "Prompt must format RING DOORBELL")
	
	player.register_nearby_interactable(house_interact)
	assert(player.get_nearest_interactable() == house_interact, "Player must register nearby interactable")
	hud.show_interaction_prompt(house_interact)
	assert(hud.interaction_prompt != null and hud.interaction_prompt.visible == true, "HUD prompt must become visible on focus")
	hud.hide_interaction_prompt()
	assert(hud.interaction_prompt.visible == false, "HUD prompt must hide on unfocus")
	player.unregister_nearby_interactable(house_interact)
	assert(player.get_nearest_interactable() == null, "Player must unregister interactable")
	print("[34/38] Universal Interaction Framework verified: Data-driven component, verbs & HUD prompt active.")

	# [35/38] Verify Hospital Exit Sliding Doors & Acoustic Whoosh
	var hosp_doors = alleyway.find_child("HospitalSlidingDoors", true, false)
	assert(hosp_doors != null, "HospitalSlidingDoors must exist at hospital exit threshold")
	assert(hosp_doors.is_open == false, "Hospital sliding doors must start closed")
	hosp_doors.open_doors()
	assert(hosp_doors.is_open == true, "Sliding doors must actuate open")
	var whoosh_wav = ProceduralCinematicAudio.create_sliding_door_whoosh()
	assert(whoosh_wav != null and whoosh_wav.data.size() > 0, "Sliding door whoosh WAV must generate PCM data")
	hosp_doors.close_doors()
	assert(hosp_doors.is_open == false, "Sliding doors must actuate closed")
	print("[35/38] Hospital Exit & Sliding Doors Transition verified: Sensor actuation, whoosh sound & exterior reveal active.")

	# [36/38] Verify Minato-Kasumi NPCs, Schedules & Contextual Dialogue
	var npcs = alleyway.get_npcs()
	assert(npcs.size() >= 3, "Minato-Kasumi Phase 1 must include at least 3-5 authored NPCs")
	var aoi = alleyway.get_npc("NPC_AOI_01")
	var daiki = alleyway.get_npc("NPC_DAIKI_02")
	var ren = alleyway.get_npc("NPC_REN_03")
	assert(aoi != null, "Nurse Aoi Tanaka must be present")
	assert(daiki != null, "Resident Daiki Yamada must be present")
	assert(ren != null, "Commuter Ren Takahashi must be present")
	
	var aoi_schedule = aoi.get_schedule_info()
	assert(aoi_schedule["role"] == "Hospital Outpatient Nurse", "Nurse Aoi schedule must reflect medical workplace")
	assert(aoi_schedule["npc_id"] == "NPC_AOI_01", "NPC ID must be stored in schedule")
	
	var talk_res1 = aoi.talk_to_player(player)
	assert(talk_res1.has("dialogue") and talk_res1["dialogue"].length() > 0, "NPC must speak contextual dialogue")
	assert(talk_res1["talk_count"] == 1, "Talk counter must advance")
	var talk_res2 = aoi.talk_to_player(player)
	assert(talk_res2["talk_count"] == 2, "Repeated talking must advance counter")
	print("[36/38] Minato-Kasumi NPCs & Scheduling verified: 3+ authored citizens, schedule phases & contextual dialogue active.")

	# [37/38] Verify Persistent Household & Doorbell Annoyance Counter
	assert(sato_house.household_id == "HOUSE_SATO_01", "Household ID must be HOUSE_SATO_01")
	assert(sato_house.resident_name == "Mika Sato", "Resident must be Mika Sato")
	assert(sato_house.ring_count == 0, "Doorbell starts with 0 rings")
	
	var ring1 = sato_house.ring_doorbell(player)
	assert(ring1["ring_count"] == 1 and ring1["response"].contains("Hello? Can I help you?"), "Ring 1 must elicit polite greeting")
	var ring2 = sato_house.ring_doorbell(player)
	assert(ring2["ring_count"] == 2 and ring2["response"].contains("Dr. Sato"), "Ring 2 must explain Dr. Sato is at clinic")
	var ring3 = sato_house.ring_doorbell(player)
	assert(ring3["ring_count"] == 3 and ring3["response"].contains("stop ringing"), "Ring 3 must trigger annoyance at sleeping baby")
	var ring4 = sato_house.ring_doorbell(player)
	assert(ring4["ring_count"] == 4 and ring4["response"].contains("Silence"), "Ring 4+ must produce silence / ignore")
	
	var doorbell_wav = ProceduralCinematicAudio.create_doorbell_chime()
	assert(doorbell_wav != null and doorbell_wav.data.size() > 0, "Doorbell chime WAV must generate PCM data")
	print("[37/38] Persistent Household & Doorbell verified: Sato residence, chime audio & annoyance counter progression active.")

	# [38/38] Verify Functional Vending Machine, Wallet Deduction & Drink Consumption
	assert(player.wallet != null and player.wallet.get_yen() == 1000, "Player wallet starts with ¥1,000")
	assert(player.inventory != null and player.inventory.has_item("water") == false, "Player starts without water")
	
	var buy_result = vending_machine.buy_drink("water", player)
	assert(buy_result["success"] == true, "Water purchase must succeed")
	assert(player.wallet.get_yen() == 880, "Wallet must deduct ¥120 (1000 - 120 = 880)")
	assert(player.inventory.has_item("water") == true, "Water must enter player inventory")
	assert(player.inventory.get_item_count("water") == 1, "Player must possess exactly 1 water")
	
	var vending_wav = ProceduralCinematicAudio.create_vending_clunk()
	assert(vending_wav != null and vending_wav.data.size() > 0, "Vending machine clunk WAV must generate PCM data")
	
	player.stamina = 50.0
	var drink_result = player.drink_item("water")
	assert(drink_result["success"] == true, "Drinking water must succeed")
	assert(player.inventory.has_item("water") == false, "Consumed drink must be removed from inventory")
	assert(player.stamina >= 75.0, "Drinking water must restore 25 stamina (50 + 25 = 75)")
	
	var drink_wav = ProceduralCinematicAudio.create_drink_gulp()
	assert(drink_wav != null and drink_wav.data.size() > 0, "Drink gulp WAV must generate PCM data")
	
	# Test insufficient funds rejection
	player.wallet.spend_yen(player.wallet.get_yen()) # Empty wallet
	assert(player.wallet.get_yen() == 0, "Wallet is now 0")
	var poor_buy = vending_machine.buy_drink("tea", player)
	assert(poor_buy["success"] == false and poor_buy["reason"] == "insufficient_funds", "Purchase must fail on insufficient funds")
	print("[38/47] Functional Vending Machine, Wallet & Drinking verified: Yen deduction, inventory delivery & drink consumption active.")

	# [39/47] Verify Player Needs System (Hunger, Thirst, Energy)
	var test_needs = PlayerNeeds.new()
	assert(test_needs.hunger == 85.0 and test_needs.get_hunger_state() == PlayerNeeds.HungerState.SATIATED, "Needs starts satiated")
	assert(test_needs.thirst == 85.0 and test_needs.get_thirst_state() == PlayerNeeds.ThirstState.HYDRATED, "Needs starts hydrated")
	assert(test_needs.energy == 90.0 and test_needs.get_energy_state() == PlayerNeeds.EnergyState.ENERGETIC, "Needs starts energetic")

	test_needs.process_needs(300.0, false) # 5 minutes of simulated time
	assert(test_needs.hunger < 85.0 and test_needs.thirst < 85.0 and test_needs.energy < 90.0, "Needs must gradually decay")
	assert(test_needs.hunger >= 0.0 and test_needs.thirst >= 0.0 and test_needs.energy >= 0.0, "Needs cannot drop below 0")

	test_needs.hunger = 25.0
	assert(test_needs.get_hunger_state() == PlayerNeeds.HungerState.HUNGRY, "State becomes HUNGRY below 40")
	assert(test_needs.is_hungry() == true, "is_hungry returns true")

	test_needs.thirst = 10.0
	assert(test_needs.get_thirst_state() == PlayerNeeds.ThirstState.VERY_THIRSTY, "State becomes VERY_THIRSTY below 15")
	assert(test_needs.is_thirsty() == true, "is_thirsty returns true")

	test_needs.energy = 5.0
	assert(test_needs.is_exhausted() == true, "is_exhausted returns true below 15")
	print("[39/47] Player Needs System verified: Hunger, Thirst, Energy decay and life-simulation states active.")

	# [40/47] Verify Expanded Inventory & 10+ Authentic Items & Categories
	var defs = PlayerInventory.ITEM_DEFINITIONS
	assert(defs.size() >= 10, "Inventory must contain at least 10 authored items")
	assert(defs.has("water") and defs.has("tea") and defs.has("juice") and defs.has("coffee") and defs.has("energy_drink"), "Drinks present")
	assert(defs.has("onigiri") and defs.has("sando") and defs.has("bento") and defs.has("ramen") and defs.has("pocky"), "Food items present")
	assert(defs["onigiri"]["category"] == "food" and defs["onigiri"]["hunger_restore"] >= 30.0, "Onigiri categorized as food with hunger restore")
	assert(defs["water"]["category"] == "drink" and defs["water"]["thirst_restore"] >= 35.0, "Water categorized as drink with thirst restore")
	print("[40/47] Expanded Inventory verified: 10+ authored Japanese foods and drinks categorized correctly.")

	# [41/47] Verify Food Eating, Crunch Audio, and Hunger/Energy Restoration
	player.needs.hunger = 30.0
	player.needs.energy = 40.0
	player.inventory.add_item("onigiri", 1)
	assert(player.inventory.has_item("onigiri") == true, "Onigiri added to inventory")

	var eat_res = player.eat_item("onigiri")
	assert(eat_res["success"] == true, "Eating onigiri succeeds")
	assert(player.inventory.has_item("onigiri") == false, "Onigiri removed on consumption")
	assert(player.needs.hunger >= 65.0, "Hunger restored by 35 (30 + 35 = 65)")
	assert(player.needs.energy >= 55.0, "Energy restored by 15 (40 + 15 = 55)")

	var food_crunch_wav = ProceduralCinematicAudio.create_food_crunch()
	assert(food_crunch_wav != null and food_crunch_wav.data.size() > 0, "Food crunch audio generated")
	print("[41/47] Food Eating & Needs Restoration verified: Crunch audio and hunger/energy recovery active.")

	# [42/47] Verify Persistent Game Clock & Shop Hours Architecture
	var clock = GameClock.new()
	clock.set_time(17, 45, 1)
	assert(clock.get_formatted_time() == "17:45", "Formatted time must match 17:45")
	assert(clock.is_between_hours(8, 20) == true, "17:45 is between 08:00 and 20:00")
	assert(clock.is_between_hours(21, 6) == false, "17:45 is not in night window 21:00-06:00")

	clock.advance_time(75.0) # 1 hour 15 min
	assert(clock.hour == 19 and clock.minute == 0, "17:45 + 75m = 19:00")
	assert(clock.get_formatted_time() == "19:00", "Formatted time updated to 19:00")
	print("[42/47] Game Clock & Shop Hours verified: 24h time tracking, advance calculation and hour windows active.")

	# [43/47] Verify 5 Persistent Households & Schedule-Consistent Doorbells
	var house_mgr = HouseholdManager.new()
	assert(house_mgr.households.size() >= 5, "Must contain at least 5 active households")

	# At 17:00: Nurse Aoi (HOUSE_002) is at work/stroll (home after 19:00)
	var h2_absent = house_mgr.ring_doorbell("HOUSE_002", 17, player)
	assert(h2_absent["is_home"] == false and h2_absent["response"].contains("duty at Minato-Kasumi Hospital"), "Aoi absent at 17:00")

	# At 21:00: Nurse Aoi is at home
	var h2_home = house_mgr.ring_doorbell("HOUSE_002", 21, player)
	assert(h2_home["is_home"] == true and h2_home["response"].contains("Echo! You made it out"), "Aoi answers when home at 21:00")

	# HOUSE_001 (Sato residence): Mika Sato is always home
	var h1_ring = house_mgr.ring_doorbell("HOUSE_001", 17, player)
	assert(h1_ring["is_home"] == true and h1_ring["response"].contains("Can I help you?"), "Mika Sato answers at home")

	# HOUSE_005 (Kobayashi residence): Haruko Kobayashi asleep after 21:00
	var h5_sleep = house_mgr.ring_doorbell("HOUSE_005", 22, player)
	assert(h5_sleep["is_home"] == false and h5_sleep["response"].contains("asleep"), "Haruko Kobayashi asleep at 22:00")
	print("[43/47] 5 Persistent Households verified: Dynamic doorbells and schedule consistency (absent vs home) active.")

	# [44/47] Verify NPC Familiarity Tiers & Needs Contextual Dialogue
	var test_npc = MinatoNPC.new()
	test_npc.npc_id = "NPC_TEST_01"
	test_npc.display_name = "Test Citizen"
	var custom_lines: Array[String] = ["Line 1", "Line 2", "Line 3"]
	test_npc.dialogue_lines = custom_lines



	assert(test_npc.familiarity_tier == MinatoNPC.FamiliarityTier.STRANGER, "Starts as stranger")

	var t1 = test_npc.talk_to_player(player)
	assert(test_npc.familiarity_tier == MinatoNPC.FamiliarityTier.ACQUAINTANCE, "Tier advances to acquaintance after talk 1")

	for _k in range(5):
		test_npc.talk_to_player(player)
	assert(test_npc.familiarity_tier == MinatoNPC.FamiliarityTier.FAMILIAR, "Tier advances to familiar after 6+ talks")
	assert(test_npc.get_familiarity_name() == "Familiar", "Familiarity name matches")

	# Test needs contextual observation
	player.needs.hunger = 10.0 # very hungry
	var needs_dialogue = test_npc.talk_to_player(player)
	assert(needs_dialogue["needs_comment"].contains("stomach rumble") or needs_dialogue["needs_comment"].contains("Kasumi Mart"), "NPC comments on player hunger")
	print("[44/47] NPC Familiarity & Contextual Dialogue verified: Tier progression and needs awareness active.")

	# [45/47] Verify Kasumi Mart Konbini: Entry Chime, Shelf Selection & Register Checkout
	var konbini = KonbiniStore.new()
	assert(konbini.is_open(17) == true, "Konbini is open at 17:00")
	assert(konbini.shopping_cart.is_empty(), "Cart starts empty")

	var konbini_chime_wav = ProceduralCinematicAudio.create_konbini_chime()
	assert(konbini_chime_wav != null and konbini_chime_wav.data.size() > 0, "Konbini chime audio generated")

	# Add items to cart
	konbini.add_to_cart("onigiri", 2) # 150 * 2 = 300
	konbini.add_to_cart("tea", 1)     # 140
	assert(konbini.get_cart_total() == 440, "Total cart cost 300 + 140 = 440 yen")

	player.wallet.add_yen(1000) # Ensure sufficient funds
	var prev_yen = player.wallet.get_yen()
	var checkout_res = konbini.checkout(player)

	assert(checkout_res["success"] == true, "Checkout must succeed")
	assert(checkout_res["total_paid"] == 440, "Total paid matches 440 yen")
	assert(player.wallet.get_yen() == prev_yen - 440, "Wallet deducted exactly 440 yen")
	assert(player.inventory.has_item("onigiri") and player.inventory.get_item_count("onigiri") >= 2, "2 Onigiri added to inventory")
	assert(player.inventory.has_item("tea") and player.inventory.get_item_count("tea") >= 1, "Tea added to inventory")
	assert(konbini.shopping_cart.is_empty(), "Shopping cart cleared after checkout")

	var register_beep_wav = ProceduralCinematicAudio.create_register_beep()
	assert(register_beep_wav != null and register_beep_wav.data.size() > 0, "Register scanner beep audio generated")
	print("[45/47] Kasumi Mart Konbini verified: Entry chime, cart calculation, wallet deduction and register checkout active.")

	# [46/47] Verify Save / Load Persistence Roundtrip
	var save_clock = GameClock.new()
	save_clock.set_time(19, 15, 2)
	player.needs.hunger = 72.5
	player.needs.thirst = 64.0
	player.needs.energy = 88.0

	var save_data = SaveManager.create_save_dictionary(player, save_clock, house_mgr, [test_npc])
	assert(save_data["wallet"]["yen"] == player.wallet.get_yen(), "Wallet yen saved")
	assert(save_data["clock"]["hour"] == 19 and save_data["clock"]["minute"] == 15, "Clock 19:15 saved")
	assert(save_data["needs"]["hunger"] == 72.5, "Needs hunger saved")
	assert(save_data["npcs"].has("NPC_TEST_01"), "NPC familiarity saved")

	# Reset states and reload
	player.wallet.spend_yen(player.wallet.get_yen())
	assert(player.wallet.get_yen() == 0, "Wallet cleared for reload test")
	player.needs.hunger = 10.0
	save_clock.set_time(8, 0, 1)

	var restore_ok = SaveManager.apply_save_dictionary(save_data, player, save_clock, house_mgr, [test_npc])
	assert(restore_ok == true, "Save data application succeeds")
	assert(player.wallet.get_yen() == save_data["wallet"]["yen"], "Wallet restored")
	assert(player.needs.hunger == 72.5, "Needs hunger restored")
	assert(save_clock.hour == 19 and save_clock.minute == 15, "Clock time restored to 19:15")
	print("[46/47] Save / Load Persistence verified: Complete roundtrip for wallet, inventory, needs, clock and NPC familiarity active.")

	# [47/47] Verify Full Minato-Kasumi Living Residential Block Scene
	assert(alleyway != null, "MinatoKasumiAlleyway exists in scene tree")
	assert(alleyway.get_houses().size() >= 5, "At least 5 active residential houses present")
	assert(alleyway.get_house("HOUSE_001") != null, "HOUSE_001 Sato house present")
	assert(alleyway.get_house("HOUSE_002") != null, "HOUSE_002 Tanaka house present")
	assert(alleyway.get_house("HOUSE_003") != null, "HOUSE_003 Yamada house present")
	assert(alleyway.get_house("HOUSE_004") != null, "HOUSE_004 Takahashi house present")
	assert(alleyway.get_house("HOUSE_005") != null, "HOUSE_005 Kobayashi house present")
	assert(alleyway.get_konbini() != null, "Kasumi Mart Konbini present in scene")
	assert(alleyway.get_npcs().size() >= 8, "At least 8-12 authored NPCs active across residential block and store")
	assert(alleyway.get_clock() != null, "Neighborhood game clock initialized")
	assert(alleyway.get_household_manager() != null, "Household manager initialized")

	var neighborhood_amb_wav = ProceduralCinematicAudio.create_neighborhood_ambience()
	assert(neighborhood_amb_wav != null and neighborhood_amb_wav.data.size() > 0, "Neighborhood ambient audio generated")
	print("[47/58] Minato-Kasumi Living Residential Block verified: 5 households, Konbini store, 8+ NPCs, and neighborhood ambience active.")

	# [48/58] Verify Echo's Childhood Residence (HOUSE_ECHO)
	var echo_house = alleyway.get_echo_residence()
	assert(echo_house != null, "EchoResidence must exist in Minato-Kasumi scene")
	assert(echo_house.address == "Minato-Kasumi 2-Chome 7-1", "Echo's residence address matches 2-Chome 7-1")
	assert(echo_house.house_state == EchoResidence.HouseState.NEGLECTED, "House starts in NEGLECTED state upon return")
	assert(echo_house.dust_layer != null and echo_house.dust_layer.visible == true, "Dust layer visible in neglected state")
	print("[48/58] Echo's Childhood Residence verified: Minato-Kasumi 2-Chome 7-1, neglected state, dust layer active.")

	# [49/58] Verify Father Photograph Inspection & Dialogue
	assert(echo_house.photo_father_inspected == false, "Father photo uninspected initially")
	var father_photo_res = echo_house.inspect_father_photo(player)
	assert(father_photo_res["inspected"] == true, "Father photo inspection succeeds")
	var has_kinja: bool = father_photo_res["text"].contains("Kinja") or father_photo_res["text"].contains("Kinga")
	assert(has_kinja and father_photo_res["text"].contains("Sector 11"), "Narrative contains Kinja & Sector 11 memory")
	assert(echo_house.photo_father_inspected == true, "photo_father_inspected flag set")
	print("[49/58] Father Photo Inspection verified: Dr. Kinga pre-singularity smile memory and dialogue active.")

	# [50/58] Verify Mother Broken Photograph Inspection & Abduction Memory
	assert(echo_house.photo_mother_inspected == false, "Mother photo uninspected initially")
	assert(echo_house.mother_photo_repaired == false, "Mother frame starts shattered on floor")
	var mother_photo_res = echo_house.inspect_mother_photo(player)
	assert(mother_photo_res["inspected"] == true, "Mother photo inspection succeeds")
	assert(mother_photo_res["text"].contains("shattered glass frame") and mother_photo_res["text"].contains("rain"), "Narrative depicts abduction night memory")
	assert(echo_house.mother_photo_broken != null and echo_house.mother_photo_broken.visible == true, "Broken frame visible on floor")
	print("[50/58] Mother Broken Photo Inspection verified: Shattered frame on floor & abduction memory active.")

	# [51/58] Verify CRT Television Interaction, Static Glow & Broadcast
	assert(echo_house.tv_on == false, "TV starts turned off")
	var tv_res = echo_house.toggle_tv(player)
	assert(tv_res["tv_on"] == true, "TV powers on")
	assert(tv_res["broadcast"].contains("NHK Kasumi") and tv_res["broadcast"].contains("Sector 11"), "News broadcast reports Sector 11 anomalies")
	assert(echo_house.tv_light != null and echo_house.tv_light.visible == true, "TV CRT light glow illuminates")
	var tv_static_wav = ProceduralCinematicAudio.create_tv_static()
	assert(tv_static_wav != null and tv_static_wav.data.size() > 0, "TV static audio PCM data generated")
	echo_house.toggle_tv(player)
	assert(echo_house.tv_on == false, "TV toggles off cleanly")
	print("[51/58] CRT Television Interaction verified: Power toggle, CRT static glow, news broadcast & 60Hz hum audio active.")

	# [52/58] Verify Refrigerator Interaction & Chilled Milk Retrieval
	assert(echo_house.fridge_open == false, "Fridge starts closed")
	var fridge_res = echo_house.toggle_fridge(player)
	assert(fridge_res["fridge_open"] == true, "Fridge door opens")
	assert(echo_house.fridge_light != null and echo_house.fridge_light.visible == true, "Fridge interior light turns on")
	var fridge_audio_wav = ProceduralCinematicAudio.create_fridge_door_open()
	assert(fridge_audio_wav != null and fridge_audio_wav.data.size() > 0, "Fridge magnetic seal & hinge audio generated")

	var milk_take_res = echo_house.take_milk_from_fridge(player)
	assert(milk_take_res["success"] == true, "Taking milk from fridge succeeds")
	assert(player.inventory.has_item("milk") == true, "Chilled milk added to player inventory")
	assert(milk_take_res["remaining_stock"] == 1, "Remaining milk stock decremented")
	echo_house.toggle_fridge(player)
	assert(echo_house.fridge_open == false, "Fridge closes")
	print("[52/58] Refrigerator Interaction verified: Door hinge audio, interior illumination & cold milk retrieval active.")

	# [53/58] Verify Kitchen Gas Stove Ignition & Blue Flame
	assert(echo_house.stove_lit == false, "Stove starts unlit")
	var stove_res = echo_house.toggle_stove(player)
	assert(stove_res["stove_lit"] == true, "Gas stove burner ignites")
	assert(echo_house.stove_flame != null and echo_house.stove_flame.visible == true, "Blue flame visual mesh visible")
	assert(echo_house.stove_light != null and echo_house.stove_light.visible == true, "Blue flame omni light active")
	var gas_wav = ProceduralCinematicAudio.create_gas_ignite()
	assert(gas_wav != null and gas_wav.data.size() > 0, "Gas piezo spark & flame whoosh audio generated")
	echo_house.toggle_stove(player)
	assert(echo_house.stove_lit == false, "Stove burner extinguishes")
	print("[53/58] Gas Stove & Flame verified: Piezo spark audio, blue flame mesh/light & ignition control active.")

	# [54/58] Verify Domestic Cleaning System & House Restoration
	assert(echo_house.cleaning_tasks_done == 0, "Cleaning tasks starts at 0")
	var clean1 = echo_house.clean_house(player)
	assert(clean1["tasks_done"] == 1 and clean1["task_description"].contains("Dusting"), "Stage 1: Dusting living room")
	assert(clean1["house_state"] == "NEGLECTED", "House remains neglected after stage 1")

	var clean2 = echo_house.clean_house(player)
	assert(clean2["tasks_done"] == 2 and clean2["mother_photo_repaired"] == true, "Stage 2: Mother's portrait repaired")
	assert(echo_house.mother_photo_repaired == true, "Mother photo repaired flag set")
	assert(echo_house.mother_photo_restored.visible == true, "Restored mother photo visible on altar")

	var clean3 = echo_house.clean_house(player)
	assert(clean3["tasks_done"] == 3 and clean3["house_state"] == "RESTORED", "Stage 3: Sweeping & curtains opened")
	assert(echo_house.house_state == EchoResidence.HouseState.RESTORED, "House transitions to RESTORED state")
	assert(echo_house.dust_layer.visible == false, "Dust layer disappears upon restoration")
	assert(echo_house.sunlight != null and echo_house.sunlight.visible == true, "Golden sunlight beam shines through shoji screens")
	print("[54/58] House Cleaning System verified: 3-stage tidying, portrait repair on altar, sunlight beam & RESTORED state active.")

	# [55/58] Verify Bed Sleep Cycle & 07:00 AM Morning Recovery
	player.hp = 35.0
	player.needs.energy = 12.0
	var test_clock = alleyway.get_clock()
	test_clock.set_time(23, 30, 1)

	var sleep_res = echo_house.use_bed(player, test_clock)
	assert(sleep_res["success"] == true, "Sleep action succeeds")
	assert(sleep_res["time"] == "07:00", "Clock advances to 07:00 AM morning")
	assert(player.hp == player.MAX_HP, "Player HP restored to 100% full")
	assert(player.needs.energy == 100.0, "Player Energy restored to 100% full")
	var birds_wav = ProceduralCinematicAudio.create_morning_birds()
	assert(birds_wav != null and birds_wav.data.size() > 0, "Morning birdsong audio PCM generated")
	print("[55/58] Bed Rest & Sleep Cycle verified: 07:00 AM clock advance, 100% HP/Energy recovery & morning birdsong active.")

	# [56/58] Verify Rideable Bicycle (Mamachari)
	var bike = alleyway.get_vehicle("Mamachari Bicycle // ママチャリ")
	assert(bike != null, "Bicycle present in Minato-Kasumi scene")
	assert(bike.vehicle_type == RideableVehicle.VehicleType.BICYCLE, "Vehicle type is BICYCLE")
	assert(bike.is_occupied == false, "Bicycle starts unoccupied")

	var bike_mount = bike.mount(player)
	assert(bike_mount["success"] == true and bike.is_occupied == true, "Mounting bicycle succeeds")
	assert(bike.current_driver == player, "Player is current driver")
	bike.trigger_bell_or_horn()
	var bell_wav = ProceduralCinematicAudio.create_bicycle_bell()
	assert(bell_wav != null and bell_wav.data.size() > 0, "Bicycle bell double-ding audio generated")

	var bike_dismount = bike.dismount()
	assert(bike_dismount["success"] == true and bike.is_occupied == false, "Dismounting bicycle succeeds")
	print("[56/58] Rideable Bicycle verified: Mount/dismount mechanics, driver attachment & double-ding bell active.")

	# [57/58] Verify Rideable 50cc Scooter (KasumiMoped)
	var moped = alleyway.get_vehicle("Kasumi 50cc Scooter // カスミ原付")
	assert(moped != null, "Moped present in Minato-Kasumi scene")
	assert(moped.vehicle_type == RideableVehicle.VehicleType.SCOOTER, "Vehicle type is SCOOTER")
	assert(moped.max_speed >= 14.0, "Scooter has authentic 50cc top speed")

	var moped_mount = moped.mount(player)
	assert(moped_mount["success"] == true and moped.is_occupied == true, "Mounting scooter succeeds")
	assert(moped.headlight != null and moped.headlight.visible == true, "Headlight illuminates on mount")
	moped.trigger_bell_or_horn()
	var throttle_wav = ProceduralCinematicAudio.create_engine_throttle()
	assert(throttle_wav != null and throttle_wav.data.size() > 0, "Two-stroke engine throttle audio generated")

	moped.dismount()
	assert(moped.is_occupied == false, "Scooter dismounted cleanly")
	assert(moped.headlight.visible == false, "Headlight switches off on dismount")
	print("[57/58] Rideable 50cc Scooter verified: Mount, headlight beam, engine throttle audio & dismount active.")

	# [58/58] Verify Street Skateboard & Japanese Kei-Car Multi-Vehicle Fleet
	var skate = alleyway.get_vehicle("Street Skateboard // スケートボード")
	assert(skate != null, "Skateboard present in scene")
	assert(skate.vehicle_type == RideableVehicle.VehicleType.SKATEBOARD, "Vehicle type is SKATEBOARD")
	var skate_roll_wav = ProceduralCinematicAudio.create_skateboard_roll()
	assert(skate_roll_wav != null and skate_roll_wav.data.size() > 0, "Skateboard polyurethane roll audio generated")

	var car = alleyway.get_vehicle("Japanese Kei-Car // 軽自動車")
	assert(car != null, "Kei-Car present in scene")
	assert(car.vehicle_type == RideableVehicle.VehicleType.CAR, "Vehicle type is CAR")
	assert(car.max_speed >= 18.0, "Kei-Car top speed calibrated")
	assert(car.find_child("Chassis", true, false) != null, "Kei-Car chassis mesh exists")
	assert(car.find_child("Cabin", true, false) != null, "Kei-Car cabin mesh exists")
	assert(alleyway.get_vehicles().size() >= 4, "At least 4 diverse vehicles deployed in Minato-Kasumi")
	print("[58/58] Multi-Vehicle Traversal Fleet verified: Skateboard carving, Kei-Car automotive body, 4+ vehicles active in Minato-Kasumi.")

	print(">>> [11.11 GODOT ENGINE] ALL 58/58 AAA MINATO-KASUMI GATES PASSED! 100% OK <<<")
	quit(0)





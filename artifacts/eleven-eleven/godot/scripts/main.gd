extends Node3D

const ShaderApplicator = preload("res://scripts/combat/shader_applicator.gd")
const CelShader = preload("res://shaders/anime_cel.gdshader")
const OutlineShader = preload("res://shaders/anime_outline.gdshader")
const GameClockScript = preload("res://scripts/systems/game_clock.gd")
const WeatherSystemScript = preload("res://scripts/systems/weather_system.gd")
const WorldStreamerScript = preload("res://scripts/systems/world_streamer.gd")
const CinematicPostProcessorScript = preload("res://scripts/effects/cinematic_post_processor.gd")
const PrologueOrchestratorScript = preload("res://scripts/cinematics/prologue_orchestrator.gd")

@onready var player: CharacterBody3D = $EchoPlayer if has_node("EchoPlayer") else null
@onready var boss: CharacterBody3D = $SpecimenEX000 if has_node("SpecimenEX000") else null
@onready var companion: Node3D = $FloatingPod if has_node("FloatingPod") else null
@onready var hud: CanvasLayer = $GameplayHUD if has_node("GameplayHUD") else null
@onready var intro_camera: Camera3D = $IntroCamera if has_node("IntroCamera") else null
@onready var opening_cinematic: Node = $OpeningAwakeningCinematic if has_node("OpeningAwakeningCinematic") else null

var weather_system: WeatherSystemScript = null
var world_streamer: WorldStreamerScript = null
var post_processor: Node = null
var game_clock = GameClockScript.new()
var is_intro_playing: bool = false
var _active_hack_terminal: Node = null

func _ready() -> void:
	post_processor = CinematicPostProcessorScript.new()
	post_processor.name = "CinematicPostProcessor"
	add_child(post_processor)

	# Initialize Master Prologue Sequence
	_set_specimen_encounter_active(false)
	if hud and hud.has_node("BossContainer"):
		hud.get_node("BossContainer").visible = false

	var prologue := PrologueOrchestratorScript.new()
	prologue.name = "PrologueOrchestrator"
	add_child(prologue)
	prologue.initialize(self, player, hud)

	# 1. Connect Player Signals to HUD
	if player and hud:
		if hud.has_method("set_player"):
			hud.set_player(player)
		if player.has_signal("hp_changed"):
			player.hp_changed.connect(hud.update_player_hp)
		if player.has_signal("stamina_changed"):
			player.stamina_changed.connect(hud.update_player_stamina)
		if player.has_signal("combo_changed"):
			player.combo_changed.connect(hud.update_combo)
		if player.has_signal("nearby_interactable_changed"):
			player.nearby_interactable_changed.connect(func(target: Node):
				if player.get("opening_recovery_active"):
					return
				if target:
					hud.show_interaction_prompt(target)
				else:
					hud.hide_interaction_prompt()
			)
		if player.has_signal("opening_recovery_completed"):
			player.opening_recovery_completed.connect(_on_opening_recovery_completed)

	# 2. Connect Boss Signals to HUD
	if boss and hud:
		if boss.has_signal("hp_changed"):
			boss.hp_changed.connect(hud.update_boss_hp)
		if boss.has_signal("phase_changed"):
			boss.phase_changed.connect(func(phase: int): hud.set_phase2(phase == 2))
		if boss.has_signal("stagger_changed"):
			boss.stagger_changed.connect(hud.set_stagger)
		if boss.has_signal("slam_warning"):
			boss.slam_warning.connect(hud.set_slam_warning)
		if boss.has_signal("boss_defeated"):
			boss.boss_defeated.connect(trigger_victory_sequence)

	# 3. Setup Companion Targets
	if companion and player:
		companion.set("follow_target", player)

	# 4. Setup Boss Target
	if boss and player:
		boss.set("target_player", player)

	# 5. Setup Mobile Touch Controls to Player & Companion
	if hud and player:
		var touch_ui = hud.find_child("MobileTouchControls", true, false)
		if touch_ui:
			touch_ui.joystick_moved.connect(func(v: Vector2):
				player.set("mobile_input_vector", v)
			)
			touch_ui.attack_tapped.connect(player.perform_attack)
			touch_ui.iai_charge_started.connect(player.start_iai_charge)
			touch_ui.iai_charge_released.connect(player.execute_iai_slash)
			touch_ui.dodge_tapped.connect(player.start_dodge)
			touch_ui.jump_tapped.connect(player.perform_jump)
			if touch_ui.has_signal("use_tapped"):
				touch_ui.use_tapped.connect(player.interact_with_nearest)
			touch_ui.lock_on_tapped.connect(player.toggle_lock_on)
			if companion and companion.has_method("trigger_scan"):
				touch_ui.scan_tapped.connect(companion.trigger_scan)

	# 6. Initialize HUD State
	if hud and player:
		hud.update_player_hp(player.get("hp"), player.get("MAX_HP"))
		hud.update_player_stamina(player.get("stamina"), player.get("MAX_STAMINA"))
		if boss:
			hud.set_phase2(false)
			hud.set_stagger(false)
			hud.set_slam_warning(false)

	# 7. Apply Anime Cel Shader Aesthetics
	apply_stylized_shaders()
	_setup_substation_events()

	# 8. Boss content remains staged until the story earns the encounter.

	# 9. Initialize AAA WeatherSystem (street-only, clock-driven)
	weather_system = WeatherSystemScript.new()
	weather_system.name = "WeatherSystem"
	add_child(weather_system)
	weather_system.connect_to_clock(game_clock)
	# Start inactive; WorldStreamer activates it when street zone is loaded
	weather_system.set_street_zone_active(false)

	# 10. Initialize AAA WorldStreamer (preloads both zones on boot)
	world_streamer = WorldStreamerScript.new()
	world_streamer.name = "WorldStreamer"
	var existing_alleyway = find_child("MinatoKasumiAlleyway", true, false)
	if existing_alleyway:
		world_streamer.set_existing_zone(WorldStreamerScript.Zone.MINATO_KASUMI_STREET, existing_alleyway)
		existing_alleyway.visible = false
	add_child(world_streamer)
	if player:
		world_streamer.set_player(player)
	if player and player.has_node("SpatialVoiceManager"):
		world_streamer.set_voice_manager(player.get_node("SpatialVoiceManager"))
	world_streamer.set_weather_system(weather_system)

	# 11. Start game clock running
	set_process(true)
	if player and opening_cinematic and player.get("opening_recovery_active"):
		opening_cinematic.play(player)

func _on_opening_recovery_completed() -> void:
	if opening_cinematic and opening_cinematic.has_method("finish"):
		opening_cinematic.finish()
	if hud and hud.has_method("set_directive"):
		hud.set_directive("01. Find a way out of Sector 11", "Recovery is unstable. Follow the signal and find a route out.")
	if hud and hud.has_method("start_dialogue"):
		hud.start_dialogue([
			{"speaker": "ECHO", "speaker_color": Color(0.72, 0.82, 1.0, 1.0), "text": "Where... is this?"},
			{"speaker": "FLOATING POD", "speaker_color": Color(0.0, 0.78, 0.92, 1.0), "text": "Neural link stable. I will interpret System prompts and flag anything you cannot yet identify. Find the nearby signal terminal."}
		])
	if player:
		player.emit_signal("nearby_interactable_changed", player.call("get_nearest_interactable"))

func apply_stylized_shaders() -> void:
	# Echo Player: Anime Toon Cel Shading + Ink Outlines (Preserves rich PBR uniform textures)
	if player and player.has_node("ModelRoot"):
		var model_root := player.get_node("ModelRoot")
		ShaderApplicator.apply_outline(model_root, OutlineShader, 1.25)

	# Boss Monster: Threat Anime Toon Cel Shading + Menacing Dark Outlines
	if boss and boss.has_node("ModelRoot"):
		var boss_root := boss.get_node("ModelRoot")
		ShaderApplicator.apply_outline(boss_root, OutlineShader, 1.45)

func play_boss_intro() -> void:
	if not intro_camera or not player:
		return

	var player_cam: Camera3D = player.find_child("Camera3D", true, false) as Camera3D
	if not player_cam:
		return

	is_intro_playing = true
	intro_camera.current = true

	if hud and hud.has_method("show_boss_intro"):
		hud.show_boss_intro("ABERRANT SPECIMEN EX-000", "SECTOR 11 CONTAINMENT BREACH // THREAT LEVEL: S", 3.0)

	var tween := create_tween()
	tween.tween_property(intro_camera, "position", Vector3(1.6, 2.2, -4.2), 2.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(func():
		player_cam.current = true
		intro_camera.current = false
		is_intro_playing = false
	)

func activate_specimen_encounter() -> void:
	if not boss:
		return
	_set_specimen_encounter_active(true)
	if player and player.has_method("set_combat_available"):
		player.set_combat_available(true)
	if player:
		boss.set("target_player", player)
	if companion:
		companion.set("aim_target", boss)
	if hud:
		hud.update_boss_hp(boss.get("hp"), boss.get("MAX_HP"))
		hud.set_directive("SURVIVE THE CONTAINMENT BREACH", "The route is sealed. Defend yourself and find another exit.")
	play_boss_intro()

func _set_specimen_encounter_active(active: bool) -> void:
	if not boss:
		return
	boss.visible = active
	boss.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	for collision in boss.find_children("*", "CollisionShape3D", true, false):
		collision.set_deferred("disabled", not active)

var is_victory_playing: bool = false

func trigger_victory_sequence() -> void:
	if is_victory_playing:
		return
	is_victory_playing = true

	# Slow motion impact moment
	Engine.time_scale = 0.2

	# Low-angle dramatic victory camera
	if intro_camera and player:
		intro_camera.current = true
		var player_pos: Vector3 = player.global_position if is_inside_tree() else player.position
		intro_camera.position = player_pos + Vector3(1.8, 0.7, 2.2)
		intro_camera.look_at(player_pos + Vector3(0, 0.95, 0))

	# Player performs Katana sheathing
	if player and player.has_method("sheath_weapon"):
		player.sheath_weapon()
		if player.has_signal("weapon_sheathed"):
			player.weapon_sheathed.connect(_on_victory_sheathed, CONNECT_ONE_SHOT)
	else:
		_on_victory_sheathed()

func _on_victory_sheathed() -> void:
	Engine.time_scale = 1.0
	var player_cam: Camera3D = player.find_child("Camera3D", true, false) as Camera3D if player else null
	if player_cam:
		player_cam.current = true
	if intro_camera:
		intro_camera.current = false

	if hud and hud.has_method("show_victory_banner"):
		hud.show_victory_banner("TARGET NEUTRALIZED", "SECTOR 11 CONTAINMENT RESTORED // SPECIMEN DISSOLVED", 4.0)
	if hud and hud.has_method("complete_directive"):
		hud.complete_directive("02. Override Primary Blast Gate", "Locate Substation Terminal to access encrypted records on 'Project Zeo'.")

	# Trigger Solo Leveling Glitch Reality Stop Prompt
	var prologue = find_child("PrologueOrchestrator", true, false)
	if prologue and prologue.has_method("trigger_solo_leveling_glitch"):
		prologue.trigger_solo_leveling_glitch()

	# Unlock and open Primary Blast Gate
	var blast_gate = find_child("PrimaryBlastGate", true, false)
	if blast_gate and blast_gate.has_method("open_gate"):
		blast_gate.unlock_gate()
		blast_gate.open_gate()

	_setup_substation_events()

func _setup_substation_events() -> void:
	var wake_terminal = find_child("SectorTerminal", true, false)
	var terminal = find_child("MainframeTerminal", true, false)
	var puzzle = hud.find_child("TerminalHackPuzzle", true, false) if hud else null
	var dialogue = hud.find_child("DialogueOverlay", true, false) if hud else null

	if wake_terminal and wake_terminal.has_signal("terminal_accessed"):
		var wake_callback = _on_terminal_accessed.bind(wake_terminal)
		if not wake_terminal.terminal_accessed.is_connected(wake_callback):
			wake_terminal.terminal_accessed.connect(wake_callback)
	if terminal and terminal.has_signal("terminal_accessed"):
		var archive_callback = _on_terminal_accessed.bind(terminal)
		if not terminal.terminal_accessed.is_connected(archive_callback):
			terminal.terminal_accessed.connect(archive_callback)

	if puzzle and not puzzle.puzzle_completed.is_connected(_on_terminal_puzzle_solved):
		puzzle.puzzle_completed.connect(_on_terminal_puzzle_solved)

	if dialogue:
		if not dialogue.dialogue_completed.is_connected(_on_dialogue_finished):
			dialogue.dialogue_completed.connect(_on_dialogue_finished)

func _on_terminal_accessed(terminal: Node) -> void:
	_active_hack_terminal = terminal
	var puzzle = hud.find_child("TerminalHackPuzzle", true, false) if hud else null
	if puzzle and puzzle.has_method("open_puzzle"):
		puzzle.open_puzzle()

func _on_terminal_puzzle_solved(lore_data: Dictionary) -> void:
	var terminal: Node = _active_hack_terminal
	if not terminal:
		return
	if terminal and terminal.has_method("complete_hack"):
		terminal.complete_hack()
	if terminal.name == "SectorTerminal":
		var prologue = find_child("PrologueOrchestrator", true, false)
		if prologue and prologue.has_method("on_terminal_puzzle_solved"):
			prologue.on_terminal_puzzle_solved(terminal)
		var gate = find_child("PrimaryBlastGate", true, false)
		var breach_cine = find_child("BlastGateBreachCinematic", true, false)
		if breach_cine and player and gate:
			breach_cine.play(player, gate)
		elif gate:
			gate.unlock_gate()
			gate.open_gate()
		if hud and hud.has_method("complete_directive"):
			hud.complete_directive("02. Cross the blast gate", "The signal continues through the open passage. Find its source.")
		_active_hack_terminal = null
		return

	if hud and hud.has_method("complete_directive"):
		hud.complete_directive("03. Recover the signal record", "The archive is damaged. Review the fragments before moving deeper.")

	# Keep early story text focused on the wake signal and the escape route.
	if hud and hud.has_method("start_dialogue"):
		hud.start_dialogue([
			{"speaker": "ECHO", "speaker_color": Color(0.0, 0.94, 1.0, 1.0), "text": "This record is broken. I don't remember coming here."},
			{"speaker": "FLOATING POD", "speaker_color": Color(1.0, 0.75, 0.2, 1.0), "text": "The wake signal continues deeper into Sector 11. The exit route is still unverified."}
		])
	_active_hack_terminal = null

func _on_dialogue_finished() -> void:
	if hud and hud.has_method("complete_directive"):
		hud.complete_directive("Continue deeper into Sector 11", "The signal leads onward. Stay alert; the System is still withholding information.")

func trigger_kinga_encounter() -> void:
	if hud and hud.has_method("complete_directive"):
		hud.complete_directive("05. Confront Dr. Kinja", "Infiltrate clandestine neuro-laboratory and face the architect of Project Zeo.")
	var torture_seq = find_child("KingaTortureSequence", true, false)
	if torture_seq:
		if not torture_seq.hospital_awakening_completed.is_connected(_on_hospital_awakening_completed):
			torture_seq.hospital_awakening_completed.connect(_on_hospital_awakening_completed)
		if not torture_seq.simulation_anomaly_exposed.is_connected(_on_simulation_anomaly_exposed):
			torture_seq.simulation_anomaly_exposed.connect(_on_simulation_anomaly_exposed)
		if not torture_seq.hospital_escaped.is_connected(_on_hospital_escaped):
			torture_seq.hospital_escaped.connect(_on_hospital_escaped)
		if torture_seq.has_method("start_confrontation"):
			torture_seq.start_confrontation()

func _on_hospital_awakening_completed() -> void:
	if hud and hud.has_method("complete_directive"):
		hud.complete_directive("06. Reality Reclaimed // Awakening", "Awakened in medical quarantine. Physical scars remain; Zero's latent power resides within.")

func _on_simulation_anomaly_exposed() -> void:
	if hud and hud.has_method("complete_directive"):
		hud.complete_directive("07. Break Containment // Simulation Glitch", "Hospital quarantine is a simulated decoy. Breach the maintenance egress hatch before memory purge.")

func _on_hospital_escaped() -> void:
	if hud and hud.has_method("complete_directive"):
		hud.complete_directive("08. Emergence into Reality // Threshold Shattered", "Breached quarantine simulation into real world. System status: HOSTILE OVERRIDE.")
	if hud and hud.has_method("show_level_up"):
		hud.show_level_up(3)
	
	var alleyway = find_child("MinatoKasumiAlleyway", true, false)
	if alleyway and not alleyway.street_emerged.is_connected(_on_street_emerged):
		alleyway.street_emerged.connect(_on_street_emerged)

func _on_street_emerged() -> void:
	if not hud:
		hud = find_child("GameplayHUD", true, false)
	if hud and hud.has_method("complete_directive"):
		hud.complete_directive("09. Minato-Kasumi // First Breath of Reality", "Breathe the cold salty sea air. Explore the Japanese coastal alleyway toward Yuki's residence.")
	if hud and hud.has_method("show_system_reward"):
		hud.show_system_reward("TITLE: ONE WHO PIERCED THE VEIL", "Skill [SHADOW STEP] Awakened. Reality Reclaimed.")
	
	_setup_street_interactions()

func _setup_street_interactions() -> void:
	var alleyway = find_child("MinatoKasumiAlleyway", true, false)
	if not alleyway:
		return
	
	# Connect Sato household doorbell to HUD dialogue
	var sato = alleyway.find_child("ResidentialHouse", true, false)
	if sato and not sato.doorbell_rung.is_connected(_on_sato_doorbell_rung):
		sato.doorbell_rung.connect(_on_sato_doorbell_rung)
	
	# Connect NPCs to HUD dialogue
	if alleyway.has_method("get_npcs"):
		for npc in alleyway.get_npcs():
			if npc and not npc.spoke_with_player.is_connected(_on_npc_spoke):
				npc.spoke_with_player.connect(_on_npc_spoke)

func _on_sato_doorbell_rung(count: int, response_text: String) -> void:
	if hud and hud.has_method("start_dialogue"):
		hud.start_dialogue([
			{
				"speaker": "INTERCOM // MIKA SATO",
				"speaker_color": Color(1.0, 0.8, 0.4, 1.0),
				"text": response_text
			}
		])

func _on_npc_spoke(npc_id: String, dialogue_line: String) -> void:
	var alleyway = find_child("MinatoKasumiAlleyway", true, false)
	var npc = alleyway.get_npc(npc_id) if (alleyway and alleyway.has_method("get_npc")) else null
	var speaker_name = npc.display_name if npc else "CITIZEN"
	if hud and hud.has_method("start_dialogue"):
		hud.start_dialogue([
			{
				"speaker": speaker_name.to_upper(),
				"speaker_color": Color(0.3, 0.9, 0.6, 1.0),
				"text": dialogue_line
			}
		])

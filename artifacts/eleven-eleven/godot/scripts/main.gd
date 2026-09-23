extends Node3D

const ShaderApplicator = preload("res://scripts/combat/shader_applicator.gd")
const CelShader = preload("res://shaders/anime_cel.gdshader")
const OutlineShader = preload("res://shaders/anime_outline.gdshader")
const WeatherSystemScript = preload("res://scripts/systems/weather_system.gd")
const WorldStreamerScript = preload("res://scripts/systems/world_streamer.gd")

@onready var player: CharacterBody3D = $EchoPlayer if has_node("EchoPlayer") else null
@onready var boss: CharacterBody3D = $SpecimenEX000 if has_node("SpecimenEX000") else null
@onready var companion: Node3D = $FloatingPod if has_node("FloatingPod") else null
@onready var hud: CanvasLayer = $GameplayHUD if has_node("GameplayHUD") else null
@onready var intro_camera: Camera3D = $IntroCamera if has_node("IntroCamera") else null

var weather_system: WeatherSystemScript = null
var world_streamer: WorldStreamerScript = null
var game_clock: GameClock = GameClock.new()
var is_intro_playing: bool = false

func _ready() -> void:
	# 1. Connect Player Signals to HUD
	if player and hud:
		if player.has_signal("hp_changed"):
			player.hp_changed.connect(hud.update_player_hp)
		if player.has_signal("stamina_changed"):
			player.stamina_changed.connect(hud.update_player_stamina)
		if player.has_signal("combo_changed"):
			player.combo_changed.connect(hud.update_combo)

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
		if boss:
			companion.set("aim_target", boss)

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
			touch_ui.lock_on_tapped.connect(player.toggle_lock_on)
			if companion and companion.has_method("trigger_scan"):
				touch_ui.scan_tapped.connect(companion.trigger_scan)

	# 6. Initialize HUD State
	if hud and player and boss:
		hud.update_player_hp(player.get("hp"), player.get("MAX_HP"))
		hud.update_player_stamina(player.get("stamina"), player.get("MAX_STAMINA"))
		hud.update_boss_hp(boss.get("hp"), boss.get("MAX_HP"))
		hud.set_phase2(false)
		hud.set_stagger(false)
		hud.set_slam_warning(false)
		if hud.has_method("set_directive"):
			hud.set_directive("01. Neutralize Threat: Specimen EX-000", "Cold Weapon defense required. Eliminate biological threat.")

	# 7. Apply Anime Cel Shader Aesthetics
	apply_stylized_shaders()

	# 8. Play Boss Entrance Cinematic
	play_boss_intro()

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
	add_child(world_streamer)
	if player:
		world_streamer.set_player(player)
	if player and player.has_node("SpatialVoiceManager"):
		world_streamer.set_voice_manager(player.get_node("SpatialVoiceManager"))
	world_streamer.set_weather_system(weather_system)

	# 11. Start game clock running
	set_process(true)

func apply_stylized_shaders() -> void:
	# Echo Player: Signal Cyan anime rim + dark anime outlines
	if player and player.has_node("ModelRoot"):
		ShaderApplicator.apply_cel_shader(
			player.get_node("ModelRoot"),
			CelShader,
			Color(0.95, 0.95, 1.0, 1.0),
			Color(0.0, 0.94, 1.0, 1.0), # Signal Cyan Rim
			Color(0.25, 0.28, 0.38, 1.0),
			3.2,
			1.1,
			OutlineShader
		)

	# Boss Monster: Threat Crimson anime rim + menacing dark outlines
	if boss and boss.has_node("ModelRoot"):
		ShaderApplicator.apply_cel_shader(
			boss.get_node("ModelRoot"),
			CelShader,
			Color(0.85, 0.85, 0.9, 1.0),
			Color(1.0, 0.15, 0.25, 1.0), # Signal Crimson Rim
			Color(0.18, 0.08, 0.12, 1.0),
			2.5,
			1.4,
			OutlineShader
		)

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

	# Unlock and open Primary Blast Gate
	var blast_gate = find_child("PrimaryBlastGate", true, false)
	if blast_gate and blast_gate.has_method("open_gate"):
		blast_gate.unlock_gate()
		blast_gate.open_gate()

	_setup_substation_events()

func _setup_substation_events() -> void:
	var terminal = find_child("MainframeTerminal", true, false)
	var puzzle = hud.find_child("TerminalHackPuzzle", true, false) if hud else null
	var dialogue = hud.find_child("DialogueOverlay", true, false) if hud else null

	if terminal and puzzle:
		if not terminal.terminal_accessed.is_connected(puzzle.open_puzzle):
			terminal.terminal_accessed.connect(puzzle.open_puzzle)

		if not puzzle.puzzle_completed.is_connected(_on_terminal_puzzle_solved):
			puzzle.puzzle_completed.connect(_on_terminal_puzzle_solved)

	if dialogue:
		if not dialogue.dialogue_completed.is_connected(_on_dialogue_finished):
			dialogue.dialogue_completed.connect(_on_dialogue_finished)

func _on_terminal_puzzle_solved(lore_data: Dictionary) -> void:
	var terminal = find_child("MainframeTerminal", true, false)
	if terminal and terminal.has_method("complete_hack"):
		terminal.complete_hack()

	if hud and hud.has_method("complete_directive"):
		hud.complete_directive("03. Security Bypassed: Archive Unlocked", "Encrypted logs indicate wake signal originated from Central Core.")

	# Start dramatic narrative dialogue
	if hud and hud.has_method("start_dialogue"):
		hud.start_dialogue()

func _on_dialogue_finished() -> void:
	if hud and hud.has_method("complete_directive"):
		hud.complete_directive("04. Investigate Deep Sector 11", "Trace origin of manual wake signal before secondary defense lockdown.")

	# Solo Leveling System Event: Overclock Level Up & Shadow Katana Award
	if player and player.has_method("equip_shadow_katana"):
		player.equip_shadow_katana()
		player.set("MAX_HP", 250.0)
		player.hp = 250.0
		if hud and hud.has_method("update_player_hp"):
			hud.update_player_hp(250.0, 250.0)

	if hud and hud.has_method("show_level_up"):
		hud.show_level_up(2)

	# Directives advance to Kinga Encounter
	var timer = get_tree().create_timer(1.2) if is_inside_tree() else null
	if timer:
		timer.timeout.connect(trigger_kinga_encounter)

func trigger_kinga_encounter() -> void:
	if hud and hud.has_method("complete_directive"):
		hud.complete_directive("05. Confront Dr. Kinga", "Infiltrate clandestine neuro-laboratory and face the architect of Project Zeo.")
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




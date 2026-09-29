extends Node3D

const ShaderApplicator = preload("res://scripts/combat/shader_applicator.gd")
const CelShader = preload("res://shaders/anime_cel.gdshader")
const OutlineShader = preload("res://shaders/anime_outline.gdshader")
const GameClockScript = preload("res://scripts/systems/game_clock.gd")
const WeatherSystemScript = preload("res://scripts/systems/weather_system.gd")
const WorldStreamerScript = preload("res://scripts/systems/world_streamer.gd")
const CinematicPostProcessorScript = preload("res://scripts/effects/cinematic_post_processor.gd")
const PrologueOrchestratorScript = preload("res://scripts/cinematics/prologue_orchestrator.gd")
const SaveManagerScript = preload("res://scripts/systems/save_manager.gd")
const NativePauseMenuScript = preload("res://scripts/ui/native_pause_menu.gd")

@export var native_session_enabled := false
@export var maintenance_preview_enabled := false
var native_checkpoint_path := SaveManagerScript.OPENING_SAVE_PATH
var native_preferences_path := "user://presentation_v1.cfg"
var _restoring_native_session := false
var _checkpoint_queued := false
var presentation_language := "ar"
var native_pause_menu: Node = null

func opening_text(ar: String, en: String) -> String:
	return ar if presentation_language == "ar" else en

func opening_line(ar: String, en: String, guide: bool = false) -> Dictionary:
	return {"speaker_ar": "مرافق الإشارة" if guide else "إيكو", "speaker_en": "SIGNAL COMPANION" if guide else "ECHO", "text_ar": ar, "text_en": en, "speaker_color": Color(0.0, 0.78, 0.92) if guide else Color(0.72, 0.82, 1.0)}

func set_presentation_language(language: String) -> void:
	if language not in ["ar", "en"]:
		return
	presentation_language = language
	_save_native_preferences()
	refresh_opening_language()

func refresh_opening_language() -> void:
	if not hud:
		return
	if hud.quest_container:
		hud.quest_container.layout_direction = Control.LAYOUT_DIRECTION_RTL if presentation_language == "ar" else Control.LAYOUT_DIRECTION_LTR
		for label in [hud.quest_title, hud.quest_desc]:
			if label: label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if presentation_language == "ar" else HORIZONTAL_ALIGNMENT_LEFT
	for node_name in ["DialogueOverlay", "TerminalHackPuzzle", "InteractionPromptHUD"]:
		var surface = hud.find_child(node_name, true, false)
		if surface and surface.has_method("set_presentation_language"):
			surface.set_presentation_language(presentation_language)
	var touch_ui = hud.find_child("MobileTouchControls", true, false)
	if touch_ui: touch_ui.refresh_labels(presentation_language,audio_muted,reduced_motion)
	var prompt = hud.find_child("InteractionPromptHUD", true, false)
	if prompt:
		prompt.touch_mode = touch_ui != null and touch_ui._platform_touch_enabled
	for pair in [["OpeningClock", "الساعة المتوقفة", "Stopped clock"], ["OpeningPhotograph", "الأثر الشخصي", "Personal trace"], ["SectorTerminal", "محطة الإشارة", "Signal terminal"], ["EnergyPowerConduit_A", "موصل الطاقة", "Power conduit"]]:
		var target = find_child(pair[0], true, false)
		if target and target.has_node("InteractionArea"):
			target.get_node("InteractionArea").prompt_target_name = opening_text(pair[1], pair[2])
		if target and target.has_method("set_presentation_language"):
			target.set_presentation_language(presentation_language)
	var prologue = get_node_or_null("PrologueOrchestrator")
	if prologue and not player.opening_recovery_active:
		prologue.refresh_opening_objective()
	if prompt and prompt.visible and is_instance_valid(prompt.current_interactable):
		prompt.show_prompt(prompt.current_interactable)
	if native_pause_menu:
		native_pause_menu.refresh_labels()
	var journey := get_node_or_null("SystemJourneyPreview")
	if journey and journey.room:
		journey.refresh_objective()

func queue_native_checkpoint() -> void:
	if not native_session_enabled or OS.has_feature("web") or _restoring_native_session or _checkpoint_queued:
		return
	_checkpoint_queued = true
	_flush_native_checkpoint.call_deferred()

func capture_native_checkpoint() -> Dictionary:
	var prologue = get_node_or_null("PrologueOrchestrator")
	var puzzle = hud.find_child("TerminalHackPuzzle", true, false) if hud else null
	if not prologue or not player or not puzzle:
		return {}
	return {
		"schema": SaveManagerScript.OPENING_SCHEMA,
		"milestones": {
			"wake": not player.opening_recovery_active,
			"clock": prologue.clock_inspected,
			"photo": prologue.photo_inspected,
			"memory": prologue.opening_memory_recovered,
			"terminal": prologue.wake_terminal_solved,
			"conduit": prologue.conduit_a_energized,
			"ending": opening_web_handoff.reported_milestones.has("memory_scene_completed"),
		},
		"terminal": {"frequency": puzzle.freq_val, "phase": puzzle.phase_val, "harmonic": puzzle.harmonic_val},
	}

func _flush_native_checkpoint() -> void:
	_checkpoint_queued = false
	if not is_inside_tree() or not native_session_enabled or OS.has_feature("web") or _restoring_native_session:
		return
	if not save_native_checkpoint_now():
		push_warning("Local opening checkpoint could not be saved; prior checkpoint retained.")

func save_native_checkpoint_now() -> bool:
	if not is_inside_tree() or not native_session_enabled or OS.has_feature("web") or _restoring_native_session:
		return false
	return SaveManagerScript.save_opening_checkpoint(capture_native_checkpoint(), native_checkpoint_path)

func restore_native_checkpoint(raw: Dictionary) -> bool:
	if OS.has_feature("web"):
		return false
	var clean := SaveManagerScript.validate_opening_checkpoint(raw)
	var prologue = get_node_or_null("PrologueOrchestrator")
	if clean.is_empty() or not clean.milestones.wake or not prologue or not player:
		return false
	_restoring_native_session = true
	player.finish_opening_recovery()
	if opening_cinematic:
		opening_cinematic.finish()
	prologue.start_prologue(false)
	var state: Dictionary = clean.milestones
	prologue.clock_inspected = state.clock
	prologue.photo_inspected = state.photo
	prologue.opening_memory_recovered = state.memory
	prologue.wake_terminal_solved = state.terminal
	prologue.conduit_a_energized = state.conduit
	# Replay unfinished memory by allowing the photograph to be inspected again.
	for evidence_name in ["OpeningClock", "OpeningPhotograph"]:
		var evidence = find_child(evidence_name, true, false)
		var completed: bool = state.clock if evidence_name == "OpeningClock" else state.memory
		evidence.inspected = completed
		evidence.get_node("InteractionArea").is_enabled = not completed and (evidence_name == "OpeningClock" or state.clock)
	var terminal = find_child("SectorTerminal", true, false)
	terminal.is_hacked = state.terminal
	terminal._update_visuals()
	terminal.get_node("InteractionArea").is_enabled = state.memory and not state.terminal
	var conduit = find_child("EnergyPowerConduit_A", true, false)
	conduit.is_energized = state.conduit
	conduit.is_locked = not state.memory
	conduit._update_visuals()
	conduit.get_node("InteractionArea").is_enabled = state.memory and not state.conduit
	var puzzle = hud.find_child("TerminalHackPuzzle", true, false)
	puzzle.has_started = true
	puzzle.freq_val = clean.terminal.frequency
	puzzle.phase_val = clean.terminal.phase
	puzzle.harmonic_val = clean.terminal.harmonic
	puzzle.is_solved = state.terminal
	# Restore at an authored safe ground anchor, not arbitrary serialized transforms.
	player.global_position = Vector3(0, 0, 4)
	player.velocity = Vector3.ZERO
	player.control_locked = false
	player.set_combat_available(false)
	if state.memory:
		hud.set_directive("SECTOR 11 // طريق الخروج", "فعّل المحطة وموصل الطاقة لفتح البوابة.")
	elif state.clock:
		hud.set_directive("SECTOR 11 // الأثر الشخصي", "اتبع أثر الصورة لاستعادة الصوت.")
	# Reconstruct local telemetry without emitting server-visible completion events.
	opening_web_handoff.reported_milestones.clear()
	for pair in [[true, "wake_completed"], [true, "room_entered"], [state.clock, "clock_inspected"], [state.photo, "photo_inspected"], [state.memory, "memory_recovered"], [state.terminal, "terminal_aligned"], [state.conduit, "conduit_energized"]]:
		if pair[0]:
			opening_web_handoff.reported_milestones.append(pair[1])
	if state.terminal and state.conduit:
		# Opening the restored gate must not replay a camera sweep or sound.
		prologue.room_gate_open = true
		var gate = find_child("PrimaryBlastGate", true, false)
		gate.keep_collision_when_open = true
		gate.state = gate.GateState.OPENED
		gate.get_door_panel().position.y = gate.initial_door_y + gate.slide_distance
		gate._update_visual_state()
		var corridor = find_child("Corridor1_Decontamination", true, false)
		if corridor:
			corridor.visible = true
			corridor.process_mode = Node.PROCESS_MODE_DISABLED
		for event in ["puzzle_solved", "door_unlocked", "gate_revealed"]:
			opening_web_handoff.reported_milestones.append(event)
		hud.set_directive("SECTOR 11 // البوابة", "اقترب من البوابة لاستكمال أثر الاستيقاظ.")
	if state.ending:
		prologue.gate_reveal_seen = true
		opening_web_handoff.reported_milestones.append("chapter_boundary_seen")
		opening_web_handoff.reported_milestones.append("memory_scene_completed")
		hud.set_directive("SECTOR 11 // نهاية الافتتاح", "تم حفظ أثر الغرفة. الطريق التالي لم يُفتح بعد.")
	prologue._update_room_markers()
	_restoring_native_session = false
	refresh_opening_language()
	return true

func _save_native_preferences() -> void:
	if not native_session_enabled or OS.has_feature("web") or _restoring_native_session:
		return
	var preferences := ConfigFile.new()
	preferences.set_value("presentation", "muted", audio_muted)
	preferences.set_value("presentation", "reduced_motion", reduced_motion)
	preferences.set_value("presentation", "language", presentation_language)
	if preferences.save(native_preferences_path) != OK:
		push_warning("Presentation preferences could not be saved.")

func _load_native_preferences() -> void:
	var preferences := ConfigFile.new()
	if preferences.load(native_preferences_path) != OK:
		return
	_restoring_native_session = true
	var muted: Variant = preferences.get_value("presentation", "muted", false)
	var motion: Variant = preferences.get_value("presentation", "reduced_motion", false)
	var language: Variant = preferences.get_value("presentation", "language", "ar")
	if language is String and language in ["ar", "en"]:
		presentation_language = language
	if muted is bool:
		set_audio_muted(muted)
	if motion is bool:
		set_reduced_motion(motion)
	_restoring_native_session = false
	refresh_opening_language()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_WINDOW_FOCUS_OUT, NOTIFICATION_WM_CLOSE_REQUEST]:
		if player:
			player.mobile_input_vector = Vector2.ZERO
			player.mobile_sprint_active = false
		_flush_native_checkpoint()
		if what != NOTIFICATION_WM_CLOSE_REQUEST and native_pause_menu:
			native_pause_menu.set_session_paused(true)

@onready var player: CharacterBody3D = $EchoPlayer if has_node("EchoPlayer") else null
@onready var boss: CharacterBody3D = $SpecimenEX000 if has_node("SpecimenEX000") else null
@onready var companion: Node3D = $FloatingPod if has_node("FloatingPod") else null
@onready var hud: CanvasLayer = $GameplayHUD if has_node("GameplayHUD") else null
@onready var intro_camera: Camera3D = $IntroCamera if has_node("IntroCamera") else null
@onready var opening_cinematic: Node = $OpeningAwakeningCinematic if has_node("OpeningAwakeningCinematic") else null
@onready var opening_web_handoff: Node = $OpeningWebHandoff if has_node("OpeningWebHandoff") else null

var weather_system: WeatherSystemScript = null
var world_streamer: WorldStreamerScript = null
var post_processor: Node = null
var game_clock = GameClockScript.new()
var is_intro_playing: bool = false
var _active_hack_terminal: Node = null
var _pending_wake_terminal: Node = null
var _archive_dialogue_pending: bool = false
var _evidence_memory_pending: bool = false
var _boundary_memory_pending: bool = false
var audio_muted: bool = false
var reduced_motion: bool = false

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_M:
		set_audio_muted(not audio_muted)
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		set_reduced_motion(not reduced_motion)

func set_audio_muted(muted: bool) -> void:
	audio_muted = muted
	AudioServer.set_bus_mute(0, muted)
	_save_native_preferences()
	var touch_ui = hud.find_child("MobileTouchControls", true, false) if hud else null
	if touch_ui: touch_ui.refresh_labels(presentation_language,audio_muted,reduced_motion)
	if hud and hud.has_method("show_tutorial_toast"):
		hud.show_tutorial_toast("TOAST_AUDIO", "M", opening_text("الصوت مكتوم", "Sound muted") if muted else opening_text("الصوت يعمل", "Sound on"), opening_text("يمكن تغيير الصوت في أي وقت.", "Sound can be changed at any time."), 2.5)

func set_reduced_motion(enabled: bool) -> void:
	reduced_motion = enabled
	var touch_ui = hud.find_child("MobileTouchControls",true,false) if hud else null
	if touch_ui: touch_ui.refresh_labels(presentation_language,audio_muted,reduced_motion)
	var journey := get_node_or_null("SystemJourneyPreview")
	if journey and journey.room:
		journey.room.set_reduced_motion(enabled)
		if enabled and journey.service_cinematic: journey.service_cinematic.finish()
	if companion: companion.reduced_motion = enabled
	var terminal = find_child("SectorTerminal", true, false)
	if terminal and terminal.has_method("set_reduced_motion"):
		terminal.set_reduced_motion(enabled)
	var dialogue = hud.find_child("DialogueOverlay", true, false) if hud else null
	if dialogue:
		dialogue.reduced_motion = enabled
		if enabled and dialogue.is_active: dialogue.finish_typing()
	_save_native_preferences()
	if enabled:
		if opening_cinematic and opening_cinematic.has_method("finish"):
			opening_cinematic.finish()
		var breach = find_child("BlastGateBreachCinematic", true, false)
		if breach and breach.has_method("finish"):
			breach.finish()
	if hud and hud.has_method("show_tutorial_toast"):
		hud.show_tutorial_toast("TOAST_MOTION", "R", opening_text("حركة أقل", "Reduced motion") if enabled else opening_text("الحركة المعتادة", "Standard motion"), opening_text("يمكن تغيير حركة الكاميرا في أي وقت.", "Camera motion can be changed at any time."), 2.5)

func _on_nearby_interactable_changed(target: Node) -> void:
	if not is_instance_valid(player) or not is_instance_valid(hud) or is_queued_for_deletion() or player.opening_recovery_active: return
	if is_instance_valid(target): hud.show_interaction_prompt(target)
	else: hud.hide_interaction_prompt()

func _ready() -> void:
	audio_muted = AudioServer.is_bus_mute(0)
	var touch_ui_initial = hud.find_child("MobileTouchControls", true, false) if hud else null
	var mute_button_initial = touch_ui_initial.find_child("MuteBtn", true, false) as Button if touch_ui_initial else null
	if mute_button_initial:
		mute_button_initial.text = "MUTED" if audio_muted else "SOUND"
	post_processor = CinematicPostProcessorScript.new()
	post_processor.name = "CinematicPostProcessor"
	post_processor.bounded_opening = native_session_enabled
	add_child(post_processor)
	if native_session_enabled:
		_configure_native_opening_surfaces()

	# Initialize Master Prologue Sequence
	_set_specimen_encounter_active(false)
	if hud and hud.has_node("BossContainer"):
		hud.get_node("BossContainer").visible = false

	var prologue := PrologueOrchestratorScript.new()
	prologue.name = "PrologueOrchestrator"
	add_child(prologue)
	prologue.initialize(self, player, hud)
	if player and player.has_method("set_combat_available"):
		player.set_combat_available(false)

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
			player.nearby_interactable_changed.connect(_on_nearby_interactable_changed)
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
			player.touch_input_enabled = touch_ui._platform_touch_enabled
			touch_ui.joystick_moved.connect(func(v: Vector2):
				player.set("mobile_input_vector", Vector2.ZERO if player.control_locked else v)
			)
			touch_ui.attack_tapped.connect(player.perform_attack)
			touch_ui.iai_charge_started.connect(player.start_iai_charge)
			touch_ui.iai_charge_released.connect(player.execute_iai_slash)
			touch_ui.dodge_tapped.connect(player.request_dodge)
			touch_ui.jump_tapped.connect(player.request_jump)
			touch_ui.camera_swiped.connect(player.apply_camera_look)
			touch_ui.sprint_changed.connect(func(active: bool):
				player.mobile_sprint_active = active and not player.control_locked
			)
			if touch_ui.has_signal("use_tapped"):
				touch_ui.use_tapped.connect(player.interact_with_nearest)
			touch_ui.lock_on_tapped.connect(player.toggle_lock_on)
			touch_ui.mute_tapped.connect(func(): set_audio_muted(not audio_muted))
			touch_ui.motion_tapped.connect(func(): set_reduced_motion(not reduced_motion))
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
	refresh_opening_language()

	# 8. Boss content remains staged until the story earns the encounter.

	# The Web opening package contains only the first room. Future zones remain
	# native-only until their own authored export and story gate exist.
	if not OS.has_feature("web") and not native_session_enabled:
		weather_system = WeatherSystemScript.new()
		weather_system.name = "WeatherSystem"
		add_child(weather_system)
		weather_system.connect_to_clock(game_clock)
		weather_system.set_street_zone_active(false)
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
	if native_session_enabled and not OS.has_feature("web"):
		native_pause_menu = NativePauseMenuScript.new()
		native_pause_menu.name = "NativePauseMenu"
		add_child(native_pause_menu)
		_load_native_preferences()
		var checkpoint := SaveManagerScript.load_opening_checkpoint(native_checkpoint_path)
		if not checkpoint.is_empty() and checkpoint.milestones.wake:
			restore_native_checkpoint(checkpoint)
			return
	if player and opening_cinematic and player.get("opening_recovery_active") and not reduced_motion:
		opening_cinematic.play(player)

func _on_opening_recovery_completed() -> void:
	if _restoring_native_session:
		return
	report_opening_milestone("wake_completed")
	report_opening_milestone("room_entered")
	if opening_cinematic and opening_cinematic.has_method("finish"):
		opening_cinematic.finish()
	var prologue = find_child("PrologueOrchestrator", true, false)
	if prologue and prologue.has_method("start_prologue"):
		prologue.start_prologue()
	if hud and hud.has_method("start_dialogue"):
		hud.start_dialogue([
			opening_line("أين... أنا؟", "Where... is this?"),
			opening_line("الاتصال مستقر. سأساعدك على قراءة إشارات النظام. افحص الساعة المتوقفة أولاً.", "Link stable. I will help interpret System signals. Inspect the stopped clock first.", true)
		])
	if player:
		player.emit_signal("nearby_interactable_changed", player.call("get_nearest_interactable"))

func _configure_native_opening_surfaces() -> void:
	var terminal_fill := get_node_or_null("Sector11TerminalFocus") as OmniLight3D
	if terminal_fill:
		terminal_fill.position.z = 3.5
		terminal_fill.light_energy = 0.5
	var floor_mesh := get_node_or_null("Sector11Facility/Room1_CryoChamber/CatwalkFloor") as MeshInstance3D
	if floor_mesh:
		var source := floor_mesh.get_active_material(0) as ShaderMaterial
		if source:
			var floor_material := source.duplicate() as ShaderMaterial
			floor_material.set_shader_parameter("floor_color", Color(0.18, 0.21, 0.25))
			floor_material.set_shader_parameter("water_tint", Color(0.15, 0.17, 0.2))
			floor_material.set_shader_parameter("neon_reflection_color", Color(0.06, 0.1, 0.12))
			floor_material.set_shader_parameter("emergency_pulse_speed", 0.0)
			floor_material.set_shader_parameter("roughness", 0.58)
			floor_material.set_shader_parameter("metallic", 0.12)
			floor_material.set_shader_parameter("specular", 0.3)
			floor_mesh.set_surface_override_material(0, floor_material)
	if player:
		var face_fill := player.get_node_or_null("ModelRoot/EchoFaceFill") as OmniLight3D
		if face_fill: face_fill.light_energy = 0.35
		var shoulder_fill := player.get_node_or_null("ModelRoot/EchoShoulderFill") as OmniLight3D
		if shoulder_fill: shoulder_fill.light_energy = 0.18

func apply_stylized_shaders() -> void:
	# Keep Echo's authored texture values and a restrained neutral silhouette rim.
	if player and player.has_node("ModelRoot"):
		var model_root := player.get_node("ModelRoot")
		ShaderApplicator.apply_cel_shader(
			model_root,
			CelShader,
			Color(1.0, 1.0, 1.0, 1.0),
			Color(0.75, 0.8, 0.86, 1.0),
			Color(0.42, 0.45, 0.58, 1.0),
			3.2,
			0.18,
			OutlineShader,
			0.85,
			0.12
		)

	# Boss Monster: Threat Anime Toon Cel Shading + Crimson Abyss Rim + Dark Outlines
	if boss and boss.has_node("ModelRoot"):
		var boss_root := boss.get_node("ModelRoot")
		ShaderApplicator.apply_cel_shader(
			boss_root,
			CelShader,
			Color(0.9, 0.85, 0.95, 1.0),
			Color(1.0, 0.1, 0.25, 1.0),
			Color(0.2, 0.15, 0.3, 1.0),
			2.8,
			0.9,
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
		hud.complete_directive("03. Defeat Aberrant Specimen EX-000", "Proceed through Executive Airlock into Chief Scientist Dr. Kinga's Neuro-Lab.")

	_setup_substation_events()

func _setup_substation_events() -> void:
	for evidence_name in ["OpeningClock", "OpeningPhotograph"]:
		var evidence = find_child(evidence_name, true, false)
		if evidence and evidence.has_signal("evidence_inspected"):
			evidence.evidence_inspected.connect(_on_opening_evidence_inspected)
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
	if puzzle and not puzzle.puzzle_closed.is_connected(_on_terminal_puzzle_closed):
		puzzle.puzzle_closed.connect(_on_terminal_puzzle_closed)

	if dialogue:
		if not dialogue.dialogue_started.is_connected(_on_opening_dialogue_started):
			dialogue.dialogue_started.connect(_on_opening_dialogue_started)
		if not dialogue.dialogue_completed.is_connected(_on_dialogue_finished):
			dialogue.dialogue_completed.connect(_on_dialogue_finished)

func _on_terminal_accessed(terminal: Node) -> void:
	_active_hack_terminal = terminal
	var puzzle = hud.find_child("TerminalHackPuzzle", true, false) if hud else null
	if puzzle and hud.has_method("open_terminal_puzzle"):
		player.control_locked = true
		hud.open_terminal_puzzle()

func _on_terminal_puzzle_closed() -> void:
	queue_native_checkpoint()
	if player:
		player.control_locked = false
	if hud and hud.has_method("restore_touch_controls"):
		hud.restore_touch_controls()
	var dialogue = hud.find_child("DialogueOverlay", true, false) if hud else null
	if OS.get_name() not in ["Android", "iOS"] and not (dialogue and dialogue.visible):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if _pending_wake_terminal:
		var terminal: Node = _pending_wake_terminal
		_pending_wake_terminal = null
		var prologue = find_child("PrologueOrchestrator", true, false)
		if prologue and prologue.has_method("on_terminal_puzzle_solved"):
			report_opening_milestone("terminal_aligned")
			prologue.on_terminal_puzzle_solved(terminal)
	_active_hack_terminal = null

func report_opening_milestone(milestone_id: String) -> void:
	if opening_web_handoff:
		opening_web_handoff.report_milestone(milestone_id)
	queue_native_checkpoint()

func _on_opening_evidence_inspected(evidence_id: String) -> void:
	var prologue = find_child("PrologueOrchestrator", true, false)
	if prologue and prologue.has_method("on_opening_evidence_inspected"):
		prologue.on_opening_evidence_inspected(evidence_id)
	if evidence_id == "clock":
		report_opening_milestone("clock_inspected")
	elif evidence_id == "photo":
		report_opening_milestone("photo_inspected")
		_evidence_memory_pending = true
		if hud and hud.has_method("start_dialogue"):
			hud.start_dialogue([
			opening_line("11:11. عندما تخاف، عدّ إلى أحد عشر... أحدهم قال لي ذلك. لم أكن وحدي.", "11:11. When you're afraid, count to eleven... Someone said that to me. I wasn't alone.")
		])

func play_opening_boundary_memory() -> void:
	if _boundary_memory_pending or opening_web_handoff.reported_milestones.has("memory_scene_completed"):
		return
	_boundary_memory_pending = true
	var glitch = find_child("RealityGlitchOverlay", true, false)
	if glitch and not reduced_motion and glitch.has_method("pulse_glitch"):
		glitch.pulse_glitch(0.22, 0.28)
	if hud and hud.has_method("start_dialogue"):
		hud.start_dialogue([
			opening_line("تنتهي الإشارة عند هذا الباب. الصوت المرتبط بالصورة... لماذا يبدو مألوفاً؟", "The signal ends at this door. The voice in that photograph... why does it feel familiar?")
		])

func _on_terminal_puzzle_solved(lore_data: Dictionary) -> void:
	var terminal: Node = _active_hack_terminal
	if not terminal:
		return
	if terminal and terminal.has_method("complete_hack"):
		terminal.complete_hack()
	if terminal.name == "SectorTerminal":
		_pending_wake_terminal = terminal
		_active_hack_terminal = null
		return

	if hud and hud.has_method("complete_directive"):
		hud.complete_directive("03. Recover the signal record", "The archive is damaged. Review the fragments before moving deeper.")

	# Keep early story text focused on the wake signal and the escape route.
	if hud and hud.has_method("start_dialogue"):
		_archive_dialogue_pending = true
		hud.start_dialogue([
			{"speaker": "ECHO", "speaker_color": Color(0.0, 0.94, 1.0, 1.0), "text": "This record is broken. I don't remember coming here."},
			{"speaker": "FLOATING POD", "speaker_color": Color(1.0, 0.75, 0.2, 1.0), "text": "The wake signal continues deeper into Sector 11. The exit route is still unverified."}
		])
	_active_hack_terminal = null

func _on_opening_dialogue_started() -> void:
	for action in ["move_forward", "move_backward", "move_left", "move_right", "sprint", "jump", "interact", "attack_light"]:
		if InputMap.has_action(action): Input.action_release(action)
	if player:
		player.control_locked = true
		player.mobile_input_vector = Vector2.ZERO
		player.mobile_sprint_active = false
		player.velocity = Vector3.ZERO
	var touch_ui = hud.find_child("MobileTouchControls", true, false) if hud else null
	if touch_ui:
		touch_ui.reset_input()
		touch_ui.set_interaction_blocked(true)
	if hud: hud.hide_interaction_prompt()

func _on_dialogue_finished() -> void:
	for action in ["jump", "interact", "attack_light"]:
		if InputMap.has_action(action): Input.action_release(action)
	var puzzle = hud.find_child("TerminalHackPuzzle", true, false) if hud else null
	if player:
		player.control_locked = puzzle != null and puzzle.visible
		player._suppress_attack_until_release = true
	if not (puzzle and puzzle.visible):
		if hud: hud.restore_touch_controls()
		if player and not player.touch_input_enabled:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if _evidence_memory_pending:
		_evidence_memory_pending = false
		report_opening_milestone("memory_recovered")
		var prologue = find_child("PrologueOrchestrator", true, false)
		if prologue and prologue.has_method("on_opening_memory_recovered"):
			prologue.on_opening_memory_recovered()
	if _boundary_memory_pending:
		_boundary_memory_pending = false
		report_opening_milestone("memory_scene_completed")
		get_node("PrologueOrchestrator").refresh_opening_objective()
	if _archive_dialogue_pending and hud and hud.has_method("complete_directive"):
		_archive_dialogue_pending = false
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

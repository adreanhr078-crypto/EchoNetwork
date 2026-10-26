extends Node3D

const ShaderApplicator = preload("res://scripts/combat/shader_applicator.gd")
const CelShader = preload("res://engine_visuals/shaders/hyper_anime_uber.gdshader")
const OutlineShader = preload("res://shaders/anime_outline.gdshader")
const GameClockScript = preload("res://scripts/systems/game_clock.gd")
const WeatherSystemScript = preload("res://scripts/systems/weather_system.gd")
const WorldStreamerScript = preload("res://scripts/systems/world_streamer.gd")
const CinematicPostProcessorScript = preload("res://scripts/effects/cinematic_post_processor.gd")
const PrologueOrchestratorScript = preload("res://scripts/cinematics/prologue_orchestrator.gd")
const SaveManagerScript = preload("res://scripts/systems/save_manager.gd")
const NativePauseMenuScript = preload("res://scripts/ui/native_pause_menu.gd")
const OpeningInspectionScript = preload("res://scripts/cinematics/opening_inspection.gd")

@export var native_session_enabled := false
@export var maintenance_preview_enabled := false
@export var chapter_companion_enabled := false
var native_checkpoint_path := SaveManagerScript.OPENING_SAVE_PATH
var native_preferences_path := "user://presentation_v1.cfg"
var _restoring_native_session := false
var _checkpoint_queued := false
var _web_configuration_pending := false
var _web_configuration_accepted := false
var _opening_initialization_ready := false
var _web_process_mode_before: ProcessMode = Node.PROCESS_MODE_INHERIT
var presentation_language := "ar"
var opening_transfer_presented := false
var native_pause_menu: Node = null
var opening_inspection: Node = null

func _requires_web_configuration() -> bool:
	return OS.has_feature("web")

func _enter_tree() -> void:
	if _requires_web_configuration():
		# Hold this scene's input, animation and bound tweens before child ready.
		# Direct browser callbacks still configure it; the SceneTree is not paused.
		_web_configuration_pending = true
		_web_process_mode_before = process_mode
		process_mode = Node.PROCESS_MODE_DISABLED

func is_web_configuration_pending() -> bool:
	return _web_configuration_pending

func complete_web_configuration() -> void:
	if not _web_configuration_pending:
		return
	_web_configuration_accepted = true
	_release_web_configuration_gate()

func _release_web_configuration_gate() -> void:
	if not _web_configuration_pending or not _web_configuration_accepted or not _opening_initialization_ready:
		return
	_web_configuration_pending = false
	process_mode = _web_process_mode_before
	_start_opening_cinematic()

func _start_opening_cinematic() -> void:
	if opening_transfer_presented and player and player.get("opening_recovery_active"):
		# The played cover/transfer already introduced Echo. Begin his waking
		# dialogue directly rather than replaying the old orbit over the film.
		player.finish_opening_recovery.call_deferred()
		return
	if player and opening_cinematic and player.get("opening_recovery_active") and not reduced_motion:
		opening_cinematic.play(player)

func opening_text(ar: String, en: String) -> String:
	return ar if presentation_language == "ar" else en

func opening_line(ar: String, en: String, guide: bool = false) -> Dictionary:
	return {"speaker_ar": "مرافق الإشارة" if guide else "إيكو", "speaker_en": "SIGNAL COMPANION" if guide else "ECHO", "text_ar": ar, "text_en": en, "speaker_color": Color(0.0, 0.78, 0.92) if guide else Color(0.72, 0.82, 1.0)}

func set_presentation_language(language: String) -> void:
	if language not in ["ar", "en"]:
		return
	if language != presentation_language and hud and hud._tutorial_toast:
		# Timed hints were authored in the previous language; the refreshed
		# objective stays visible and subsequent hints use the new language.
		hud._tutorial_toast.dismiss_toast()
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
	for node_name in ["DialogueOverlay", "TerminalHackPuzzle", "InteractionPromptHUD", "SystemWindow"]:
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
	if opening_inspection:
		opening_inspection.refresh_labels()
	var journey := get_node_or_null("SystemJourneyPreview")
	if journey and journey.room:
		journey.refresh_objective()
	var campaign := get_node_or_null("NativeCampaignController")
	if campaign: campaign.sync_preferences()

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
	var opening_saved: bool=SaveManagerScript.save_opening_checkpoint(capture_native_checkpoint(), native_checkpoint_path)
	var campaign=get_node_or_null("NativeCampaignController")
	return (campaign.save_now() if campaign else true) and opening_saved

func restore_native_checkpoint(raw: Dictionary) -> bool:
	if OS.has_feature("web"):
		return false
	var clean := SaveManagerScript.validate_opening_checkpoint(raw)
	var prologue = get_node_or_null("PrologueOrchestrator")
	if clean.is_empty() or not clean.milestones.wake or not prologue or not player:
		return false
	_restoring_native_session = true
	if opening_inspection and opening_inspection.is_active:
		opening_inspection.interrupt()
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
		evidence.restore_inspection(completed)
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
	# Retain independently owned entry presentation flags and other settings.
	preferences.load(native_preferences_path)
	preferences.set_value("presentation", "muted", audio_muted)
	preferences.set_value("presentation", "reduced_motion", reduced_motion)
	preferences.set_value("presentation", "language", presentation_language)
	preferences.set_value("presentation", "visual_quality", visual_quality)
	preferences.set_value("controls", "settings", get_control_preferences())
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
	var quality: Variant=preferences.get_value("presentation","visual_quality","high")
	if quality is String and quality in ["low","medium","high","ultra"]: set_visual_quality(quality)
	var controls: Variant = preferences.get_value("controls", "settings", {})
	if controls is Dictionary: set_control_preferences(controls)
	_restoring_native_session = false
	refresh_opening_language()

func get_control_preferences() -> Dictionary:
	var touch = hud.find_child("MobileTouchControls", true, false) if hud else null
	var settings: Dictionary = touch.control_preferences() if touch else {}
	settings["mouse_sensitivity"] = player.mouse_look_sensitivity / 0.0022 if player else 1.0
	settings["touch_sensitivity"] = player.touch_look_sensitivity / 0.003 if player else 1.0
	return settings

func set_control_preferences(settings: Dictionary) -> void:
	var touch = hud.find_child("MobileTouchControls", true, false) if hud else null
	if not touch or not player: return
	touch.apply_control_preferences(settings)
	player.mouse_look_sensitivity = 0.0022 * touch._finite_setting(settings, "mouse_sensitivity", 1, 0.5, 2.0)
	player.touch_look_sensitivity = 0.003 * touch._finite_setting(settings, "touch_sensitivity", 1, 0.5, 2.0)
	_save_native_preferences()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_WINDOW_FOCUS_OUT, NOTIFICATION_WM_CLOSE_REQUEST]:
		if player:
			player.mobile_input_vector = Vector2.ZERO
			player.mobile_sprint_active = false
			player.clear_traversal_input()
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
var visual_quality := "high"

func _input(event: InputEvent) -> void:
	if not chapter_companion_enabled and event.is_action_pressed("companion_scan") and not event.is_echo():
		show_environment_help()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_I:
		if toggle_personal_system(): get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_M:
		set_audio_muted(not audio_muted)
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		set_reduced_motion(not reduced_motion)

func show_environment_help() -> void:
	if not player or not hud or get_tree().paused or player.control_locked or player.opening_recovery_active: return
	var campaign := get_node_or_null("NativeCampaignController")
	if campaign and campaign.active and campaign.current >= campaign.rooms.size(): return
	hud.show_tutorial_toast("ENVIRONMENT_HELP", "E", opening_text("قراءة المكان", "Read the room"), opening_text("اقترب من جهاز أو دليل، وانتظر علامة التفاعل. التفاصيل متاحة بالفحص؛ المساعدة لا تختار الإجابة.", "Approach a device or a trace and look for the interaction prompt. Inspect it for details; help never chooses an answer."), 5.0)

func toggle_personal_system() -> bool:
	if not player or not hud or get_tree().paused or player.control_locked or is_intro_playing: return false
	var window:Node=hud.find_child("SystemWindow",true,false)
	if not window:return false
	if window._status_view:
		window.close_window()
		return true
	if window.visible and window._modal:return false
	var bound:bool=player.contract_with_zero_sealed
	var campaign:=get_node_or_null("NativeCampaignController")
	if campaign and campaign.active:bound=bool(campaign.progress.flags.get("lab",{}).get("contract_done",false))
	return window.show_personal_status({"hp":player.hp,"max_hp":player.MAX_HP,"stamina":player.stamina,"max_stamina":player.MAX_STAMINA,"pact_confirmed":bound,"objective":hud.current_directive_title})

func set_audio_muted(muted: bool) -> void:
	audio_muted = muted
	AudioServer.set_bus_mute(0, muted)
	var campaign := get_node_or_null("NativeCampaignController")
	if campaign: campaign.sync_preferences()
	_save_native_preferences()
	var touch_ui = hud.find_child("MobileTouchControls", true, false) if hud else null
	if touch_ui: touch_ui.refresh_labels(presentation_language,audio_muted,reduced_motion)
	if hud and hud.has_method("show_tutorial_toast"):
		hud.show_tutorial_toast("TOAST_AUDIO", "M", opening_text("الصوت مكتوم", "Sound muted") if muted else opening_text("الصوت يعمل", "Sound on"), opening_text("يمكن تغيير الصوت في أي وقت.", "Sound can be changed at any time."), 2.5)

func set_reduced_motion(enabled: bool) -> void:
	get_node("/root/HyperAnimeWorldManager").set_reduced_motion(enabled)
	get_node("/root/KineticVFXOrchestrator").set_reduced_motion(enabled)
	if player and player.action_camera_rig: player.action_camera_rig.set_reduced_motion(enabled)
	reduced_motion = enabled
	var opening_atmosphere := get_node_or_null("OpeningAtmosphere")
	if opening_atmosphere: opening_atmosphere.set_reduced_motion(enabled)
	if player: player.reduced_camera_motion = enabled
	if hud: hud.tutorial_toast.set_reduced_motion(enabled)
	var system_popup = hud.find_child("SystemWindow", true, false) if hud else null
	if system_popup: system_popup.reduced_motion = enabled
	var terminal_puzzle = hud.find_child("TerminalHackPuzzle", true, false) if hud else null
	if terminal_puzzle: terminal_puzzle.reduced_motion = enabled
	var interaction_prompt = hud.find_child("InteractionPromptHUD", true, false) if hud else null
	if interaction_prompt: interaction_prompt.reduced_motion = enabled
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
	var opening_conduit = find_child("EnergyPowerConduit_A", true, false)
	if opening_conduit: opening_conduit.set_reduced_motion(enabled)
	for evidence_name in ["OpeningClock", "OpeningPhotograph"]:
		var evidence = find_child(evidence_name,true,false)
		if evidence and evidence.has_method("set_reduced_motion"):
			evidence.set_reduced_motion(enabled)
	var dialogue = hud.find_child("DialogueOverlay", true, false) if hud else null
	if dialogue:
		dialogue.reduced_motion = enabled
		if enabled and dialogue.is_active: dialogue.finish_typing()
	var campaign := get_node_or_null("NativeCampaignController")
	if campaign: campaign.sync_preferences()
	_save_native_preferences()
	if enabled:
		if opening_cinematic and opening_cinematic.has_method("finish"):
			opening_cinematic.finish()
		var breach = find_child("BlastGateBreachCinematic", true, false)
		if breach and breach.has_method("finish"):
			breach.finish()
		# Camera teardown must not release a still-pending explicit decision.
		if _system_modal_owned:
			_release_gameplay_modal_controls()
	if hud and hud.has_method("show_tutorial_toast"):
		hud.show_tutorial_toast("TOAST_MOTION", "R", opening_text("حركة أقل", "Reduced motion") if enabled else opening_text("الحركة المعتادة", "Standard motion"), opening_text("يمكن تغيير حركة الكاميرا في أي وقت.", "Camera motion can be changed at any time."), 2.5)

func _on_nearby_interactable_changed(target: Node) -> void:
	if not is_instance_valid(player) or not is_instance_valid(hud) or is_queued_for_deletion() or player.opening_recovery_active: return
	var touch = hud.find_child("MobileTouchControls", true, false)
	if player.control_locked:
		if touch: touch.set_interaction_available(false)
		hud.hide_interaction_prompt()
		return
	if touch: touch.set_interaction_available(is_instance_valid(target))
	if is_instance_valid(target): hud.show_interaction_prompt(target)
	else: hud.hide_interaction_prompt()

func _ready() -> void:
	_enable_hyper_visuals.call_deferred()
	# Debug-only, explicitly requested; no instrumentation runs in a normal session.
	var frame_capture_script = preload("res://scripts/diagnostics/player_frame_capture.gd")
	if frame_capture_script.requested():
		var frame_capture = frame_capture_script.new()
		frame_capture.name = "PlayerFrameCapture"
		add_child(frame_capture)
		if not frame_capture.start_capture(): push_warning("Optional frame capture could not start")
	audio_muted = AudioServer.is_bus_mute(0)
	var touch_ui_initial = hud.find_child("MobileTouchControls", true, false) if hud else null
	var mute_button_initial = touch_ui_initial.find_child("MuteBtn", true, false) as Button if touch_ui_initial else null
	if mute_button_initial:
		mute_button_initial.text = "MUTED" if audio_muted else "SOUND"
	post_processor = CinematicPostProcessorScript.new()
	post_processor.name = "CinematicPostProcessor"
	post_processor.bounded_opening = native_session_enabled or _requires_web_configuration()
	add_child(post_processor)
	if native_session_enabled or _requires_web_configuration():
		_configure_native_opening_surfaces()
		var opening_atmosphere := Node3D.new()
		opening_atmosphere.name = "OpeningAtmosphere"
		opening_atmosphere.set_script(preload("res://scripts/environment/opening_atmosphere.gd"))
		add_child(opening_atmosphere)
		opening_atmosphere.configure(self)

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

	# Reversible chapter policy. The legacy companion remains available to a
	# future authored mission, but owns no scan, target or light in this chapter.
	if companion:
		companion.set_chapter_enabled(chapter_companion_enabled)
		if chapter_companion_enabled and player: companion.follow_target = player

	# 4. Setup Boss Target
	if boss and player:
		boss.set("target_player", player)

	# 5. Setup Mobile Touch Controls to Player & Companion
	if hud and player:
		var touch_ui = hud.find_child("MobileTouchControls", true, false)
		if touch_ui:
			player.touch_input_enabled = touch_ui._platform_touch_enabled
			touch_ui.input_reset.connect(player.clear_traversal_input)
			touch_ui.joystick_moved.connect(func(v: Vector2):
				player.set_mobile_input_vector(Vector2.ZERO if player.control_locked else v, touch_ui.is_joystick_active and not player.control_locked)
			)
			touch_ui.attack_tapped.connect(player.perform_attack)
			touch_ui.iai_charge_started.connect(player.start_iai_charge)
			touch_ui.iai_charge_released.connect(player.execute_iai_slash)
			touch_ui.dodge_tapped.connect(player.request_dodge)
			touch_ui.jump_tapped.connect(player.request_jump)
			if touch_ui.has_signal("sprint_changed"):
				touch_ui.sprint_changed.connect(player.set_dash_held)
			touch_ui.camera_swiped.connect(player.apply_touch_camera_look)
			if touch_ui.has_signal("use_tapped"):
				touch_ui.use_tapped.connect(player.interact_with_nearest)
			touch_ui.lock_on_tapped.connect(player.toggle_lock_on)
			touch_ui.mute_tapped.connect(func(): set_audio_muted(not audio_muted))
			touch_ui.motion_tapped.connect(func(): set_reduced_motion(not reduced_motion))
			touch_ui.set_environment_help(not chapter_companion_enabled)
			if chapter_companion_enabled and companion and companion.has_method("trigger_scan"):
				touch_ui.scan_tapped.connect(companion.trigger_scan)
			else:
				touch_ui.scan_tapped.connect(show_environment_help)

	# 6. Initialize HUD State
	var system_window = hud.find_child("SystemWindow",true,false) if hud else null
	if system_window:
		system_window.system_window_opened.connect(_on_system_window_opened)
		system_window.system_window_closed.connect(_on_system_window_closed)
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
	if not _requires_web_configuration() and not native_session_enabled:
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
	_opening_initialization_ready = true
	if _web_configuration_pending:
		_release_web_configuration_gate()
	else:
		_start_opening_cinematic()

func _on_opening_recovery_completed() -> void:
	if _restoring_native_session:
		return
	report_opening_milestone("wake_completed")
	report_opening_milestone("room_entered")
	var clock_target:=find_child("OpeningClock",true,false) as Node3D
	if player and clock_target:
		player.face_world_direction(clock_target.global_position-player.global_position)
	if opening_cinematic and opening_cinematic.has_method("finish"):
		opening_cinematic.finish()
	var prologue = find_child("PrologueOrchestrator", true, false)
	if prologue and prologue.has_method("start_prologue"):
		prologue.start_prologue()
	if hud and hud.has_method("start_dialogue"):
		hud.start_dialogue([
			opening_line("أين... أنا؟", "Where... is this?"),
			opening_line("الساعة... توقفت. عليّ أن أفحصها.", "The clock... it stopped. I should look closer.")
		])
	if player:
		player.emit_signal("nearby_interactable_changed", player.call("get_nearest_interactable"))

func _configure_native_opening_surfaces() -> void:
	# A neutral medical key keeps material and face values readable; colored
	# practicals identify equipment rather than washing the entire room in neon.
	var key := get_node_or_null("Sector11KeyFill") as OmniLight3D
	if key:
		key.light_color = Color(0.75,0.80,0.85)
		key.light_energy = 1.35
	for light_name in ["Sector11NeonVioletRim","Sector11NeonCyanRim"]:
		var rim := get_node_or_null(light_name) as OmniLight3D
		if rim:
			rim.light_energy = 0.4
			rim.light_color = Color(0.52,0.43,0.68) if light_name == "Sector11NeonVioletRim" else Color(0.42,0.66,0.72)
	var terminal_fill := get_node_or_null("Sector11TerminalFocus") as OmniLight3D
	if terminal_fill:
		terminal_fill.position.z = 3.5
		terminal_fill.light_energy = 0.5
	var floor_mesh := get_node_or_null("Sector11Facility/Room1_CryoChamber/CatwalkFloor") as MeshInstance3D
	if floor_mesh:
		var source := floor_mesh.get_active_material(0) as ShaderMaterial
		if source:
			var floor_material := source.duplicate() as ShaderMaterial
			floor_material.set_shader_parameter("floor_color", Color(0.30, 0.34, 0.37))
			floor_material.set_shader_parameter("water_tint", Color(0.15, 0.17, 0.2))
			floor_material.set_shader_parameter("neon_reflection_color", Color(0.06, 0.1, 0.12))
			floor_material.set_shader_parameter("emergency_pulse_speed", 0.0)
			floor_material.set_shader_parameter("roughness", 0.58)
			floor_material.set_shader_parameter("metallic", 0.12)
			floor_material.set_shader_parameter("specular", 0.3)
			# The puddle branch overwrites dry roughness/specular. Bound that branch
			# too, so the real opening floor retains detail instead of light blobs.
			floor_material.set_shader_parameter("puddle_coverage", 0.44)
			floor_material.set_shader_parameter("wet_edge_width", 0.05)
			floor_material.set_shader_parameter("wet_darkening", 0.8)
			floor_material.set_shader_parameter("puddle_roughness", 0.09)
			floor_material.set_shader_parameter("puddle_specular", 0.55)
			floor_mesh.set_surface_override_material(0, floor_material)
	if player:
		var face_fill := player.get_node_or_null("ModelRoot/EchoFaceFill") as OmniLight3D
		if face_fill: face_fill.light_energy = clampf(face_fill.light_energy, 0.8, 1.4)
		var shoulder_fill := player.get_node_or_null("ModelRoot/EchoShoulderFill") as OmniLight3D
		if shoulder_fill: shoulder_fill.light_energy = clampf(shoulder_fill.light_energy, 0.8, 1.4)

func apply_stylized_shaders() -> void:
	# Keep Echo's authored texture values and a restrained neutral silhouette rim.
	if player and player.has_node("ModelRoot"):
		var model_root := player.get_node("ModelRoot")
		# The avatar owns cel shading. Wings, eyes and blades retain their own
		# authored materials; broad traversal erased their textures and effects.
		var avatar := model_root.get_node_or_null("EchoOpeningUniform")
		ShaderApplicator.apply_cel_shader(
			avatar,
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
		for mesh in avatar.find_children("*","MeshInstance3D",true,false):
			for surface in mesh.mesh.get_surface_count():
				var material: Material=mesh.get_active_material(surface)
				if material is ShaderMaterial and material.shader==CelShader:
					material.set_shader_parameter("skin_light_scale",0.26)
					material.set_shader_parameter("backlight_intensity",0.035)
					material.set_shader_parameter("diffuse_light_ceiling",1.65)
					material.set_shader_parameter("specular_light_ceiling",0.22)

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
	if companion and chapter_companion_enabled:
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
	if native_session_enabled and not opening_inspection:
		opening_inspection = CanvasLayer.new()
		opening_inspection.name = "OpeningInspection"
		opening_inspection.set_script(OpeningInspectionScript)
		add_child(opening_inspection)
		opening_inspection.configure(self)
	for evidence_name in ["OpeningClock", "OpeningPhotograph"]:
		var evidence = find_child(evidence_name, true, false)
		if evidence and evidence.has_signal("evidence_inspected"):
			evidence.evidence_inspected.connect(_on_opening_evidence_inspected)
		if opening_inspection and evidence and evidence.has_signal("inspection_requested"):
			if not evidence.inspection_requested.is_connected(opening_inspection.open):
				evidence.inspection_requested.connect(opening_inspection.open)
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
	_release_gameplay_modal_controls()
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
		player.clear_traversal_input()
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
	_release_gameplay_modal_controls()
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

var _system_modal_owned := false
func _on_system_window_opened(_kind: int) -> void:
	var window = hud.find_child("SystemWindow",true,false)
	var was_owned:=_system_modal_owned
	_system_modal_owned = window != null and window._modal
	if _system_modal_owned: _on_opening_dialogue_started()
	elif was_owned: _release_gameplay_modal_controls()

func _on_system_window_closed(_kind: int) -> void:
	if not _system_modal_owned: return
	_system_modal_owned = false
	_release_gameplay_modal_controls()

func _release_gameplay_modal_controls() -> void:
	var blocked := false
	if opening_inspection and opening_inspection.is_active: blocked = true
	var campaign:=get_node_or_null("NativeCampaignController")
	if campaign and campaign.is_hospital_input_blocked(): blocked=true
	for id in ["TerminalHackPuzzle","DialogueOverlay","SystemWindow"]:
		var overlay = hud.find_child(id,true,false) if hud else null
		if not overlay: continue
		var owns_input: bool = overlay.is_active if id == "DialogueOverlay" else (overlay.is_open if id == "TerminalHackPuzzle" else overlay.visible)
		if owns_input and (id != "SystemWindow" or overlay._modal): blocked = true
	for action in ["jump","interact","attack_light"]:
		if InputMap.has_action(action): Input.action_release(action)
	if player:
		player.control_locked = blocked
		player.clear_traversal_input()
		player._suppress_attack_until_release = true
	if not blocked:
		if hud: hud.restore_touch_controls()
		if player: _on_nearby_interactable_changed(player.get_nearest_interactable())
		if player and not player.touch_input_enabled: Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

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

func _enable_hyper_visuals() -> void:
	if not is_instance_valid(player): return
	player.enable_hyper_visuals()
	get_node("/root/HyperAnimeWorldManager").attach_scene(self,player)
	get_node("/root/KineticVFXOrchestrator").attach_player(self,player)
	get_node("/root/HyperAnimeWorldManager").set_quality(visual_quality)
	if not get_node_or_null("MemoryAtmosphereDirector"):
		var atmosphere=preload("res://engine_visuals/MemoryAtmosphereDirector.gd").new()
		atmosphere.name="MemoryAtmosphereDirector"
		add_child(atmosphere)
		atmosphere.configure(self)

func set_visual_quality(tier: String) -> bool:
	if tier not in ["low","medium","high","ultra"]: return false
	visual_quality=tier
	get_node("/root/HyperAnimeWorldManager").set_quality(tier)
	_save_native_preferences()
	if native_pause_menu: native_pause_menu.refresh_labels()
	return true

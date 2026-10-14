extends SceneTree

const Main = preload("res://scripts/main.gd")

class EmbeddedMain extends Main:
	# The only simulated boundary is the OS web-feature predicate. All scene,
	# player, animation, cinematic, configuration and localization logic is real.
	func _requires_web_configuration() -> bool:
		return true

class OutsideProbe extends Node:
	var frames := 0
	func _process(_delta: float) -> void:
		frames += 1

var checks := 0
var save_prefix := "user://web_gate_review_%d" % OS.get_process_id()

func _init() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> bool:
	checks += 1
	if not condition:
		push_error(message)
		quit(1)
	return condition

func _configuration(reduced := false) -> Dictionary:
	return {"source": "11-11-web", "type": "configure", "bridgeVersion": 1, "nonce": "input-gate-review", "coverVerified": true, "locale": "en", "muted": true, "reducedMotion": reduced}

func _audio_status(node: Node) -> Dictionary:
	var status := {"count": 0, "playing": []}
	for child in node.find_children("*", "", true, false):
		if child is AudioStreamPlayer or child is AudioStreamPlayer3D or child is AudioStreamPlayer2D:
			status.count += 1
			if child.playing: status.playing.append(str(child.get_path()))
	return status

func _run() -> void:
	var outside := OutsideProbe.new()
	root.add_child(outside)
	var web_scene: PackedScene = load("res://scenes/opening_web_room.tscn")
	var main = web_scene.instantiate()
	main.set_script(EmbeddedMain)
	root.add_child(main)
	var handoff = main.get_node("OpeningWebHandoff")
	var player = main.get_node("EchoPlayer")
	var cinematic = main.get_node("OpeningAwakeningCinematic")
	for i in 5: await process_frame
	if not _check(main.is_web_configuration_pending() and not main.can_process() and not player.can_process(), "Web scene accepted processing before configure"): return
	if not _check(not paused and outside.frames > 0, "Web gate paused unrelated SceneTree processing"): return
	if not _check(player.opening_recovery_active and not cinematic._is_playing and handoff.reported_milestones.is_empty(), "Wake cinematic or progress began before configure"): return
	if not _check(main.weather_system == null and main.world_streamer == null, "Simulated Web scene instantiated native-only weather/zone side effects"): return
	if not _check(main.post_processor.bounded_opening and not main.post_processor.is_volumetric_fog_active() and main.post_processor.world_env.environment.background_mode == Environment.BG_COLOR and not main.post_processor.world_env.environment.ssr_enabled, "Web opening applied the overworld sky or unsupported Forward+ effects"): return
	var audio_before := _audio_status(main)
	if not _check(audio_before.count > 0 and audio_before.playing.is_empty(), "Ready or deferred initialization played audio before configure"): return
	# Deferred player setup still runs in a disabled subtree: its clip starts at
	# phase zero. This check deliberately distinguishes boot work from progress.
	if not _check(player.animation_player.is_playing() and is_zero_approx(player.animation_player.current_animation_position), "Deferred wake setup was not measured at its held initial phase"): return
	var dialogue = main.hud.dialogue_overlay
	var prologue = main.get_node("PrologueOrchestrator")
	var clock_time := [main.game_clock.day, main.game_clock.hour, main.game_clock.minute, main.game_clock.second]
	var clip_position: float = player.animation_player.current_animation_position
	var player_position: Vector3 = player.position
	Input.action_press("ui_accept")
	Input.action_press("interact")
	Input.action_press("move_forward")
	var press := InputEventAction.new()
	press.action = "interact"
	press.pressed = true
	Input.parse_input_event(press)
	for i in 180: await physics_frame
	Input.action_release("ui_accept")
	Input.action_release("interact")
	Input.action_release("move_forward")
	if not _check(player.opening_recovery_active and handoff.reported_milestones.is_empty(), "Pending key input or elapsed frames advanced wake progress"): return
	if not _check(is_equal_approx(player.animation_player.current_animation_position, clip_position) and player.position.is_equal_approx(player_position), "Pending animation or movement advanced"): return
	var audio_after := _audio_status(main)
	if not _check(audio_after.playing.is_empty() and not dialogue.is_active and dialogue.current_line_index == -1 and not prologue.clock_inspected and not prologue.photo_inspected and not prologue.wake_terminal_solved and not prologue.room_gate_open, "Pending ready/deferred callbacks played audio or advanced authored opening state"): return
	if not _check([main.game_clock.day, main.game_clock.hour, main.game_clock.minute, main.game_clock.second] == clock_time, "Pending opening game clock advanced"): return
	print("Pending side effects: %d audio players silent; deferred wake clip initialized at phase zero; dialogue/puzzle/gate/clock unchanged" % audio_after.count)
	for field in [{"coverVerified": false}, {"nonce": ""}, {"source": "foreign"}, {"bridgeVersion": 2}, {"locale": "fr"}, {"muted": "true"}, {"reducedMotion": 1}]:
		var rejected = _configuration()
		rejected.merge(field, true)
		handoff._apply_configuration(rejected)
		if not _check(main.is_web_configuration_pending() and handoff._session_nonce.is_empty(), "Rejected initialization configured or released pending gameplay"): return
	var missing = _configuration()
	missing.erase("locale")
	handoff._apply_configuration(missing)
	if not _check(main.is_web_configuration_pending(), "Incomplete preference handshake released gameplay"): return
	handoff._apply_configuration(_configuration())
	if not _check(not main.is_web_configuration_pending() and main.can_process() and player.can_process(), "Valid direct configure callback could not release the disabled scene"): return
	if not _check(main.presentation_language == "en" and main.audio_muted and not main.reduced_motion and cinematic._is_playing, "Preferences did not precede initial cinematic"): return
	var tween_id: int = cinematic._camera_tween.get_instance_id()
	handoff._apply_configuration(_configuration())
	if not _check(cinematic._camera_tween.get_instance_id() == tween_id, "Repeated configure restarted the wake cinematic"): return
	for i in 20: await physics_frame
	if not _check(player.animation_player.current_animation_position > clip_position, "Accepted handshake did not resume wake animation"): return
	handoff._apply_configuration(_configuration(true))
	if not _check(not cinematic._is_playing and not player.opening_recovery_active and player.control_locked, "Reduced Motion did not hand wake ownership to the real dialogue"): return
	handoff._apply_configuration(_configuration(true))
	if not _check(player.control_locked, "Reconfiguration released active dialogue ownership"): return
	for i in 3: await process_frame
	dialogue.reduced_motion = false
	dialogue.close_dialogue()
	if not _check(dialogue.visible and not dialogue.is_active and not player.control_locked, "Cosmetic dialogue departure kept the actual player locked"): return
	if not _check(dialogue.continue_button.disabled and dialogue.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Departing dialogue retained GUI input ownership"): return
	var puzzle = main.hud.find_child("TerminalHackPuzzle", true, false)
	puzzle.open_puzzle()
	dialogue.start_dialogue([{"speaker":"ECHO", "text":"Modal ownership review."}])
	dialogue.close_dialogue()
	if not _check(player.control_locked, "Dialogue completion unlocked a still-open terminal modal"): return
	puzzle.close_puzzle()
	main._release_gameplay_modal_controls()
	if not _check(not player.control_locked, "Closing the remaining modal failed to restore control"): return
	puzzle.open_puzzle()
	dialogue.start_dialogue([{"speaker":"ECHO", "text":"Dialogue retains ownership."}])
	puzzle.close_puzzle()
	if not _check(player.control_locked and dialogue.is_active, "Terminal departure released an active dialogue modal"): return
	dialogue.close_dialogue()
	if not _check(not player.control_locked, "The last dialogue failed to restore control after terminal departure"): return
	main.queue_free()
	for i in 3: await process_frame
	# Accepting configure between parent enter_tree and ready must defer release.
	var early = web_scene.instantiate()
	early.set_script(EmbeddedMain)
	var early_held := false
	early.tree_entered.connect(func():
		early.get_node("OpeningWebHandoff")._apply_configuration(_configuration(true))
		early.set_meta("held_before_ready", early.is_web_configuration_pending() and not early.can_process())
	)
	root.add_child(early)
	early_held = early.get_meta("held_before_ready", false)
	if not _check(early_held and not early.is_web_configuration_pending() and early.can_process(), "Early configure released before ready or failed to release afterward"): return
	if not _check(early.presentation_language == "en" and early.reduced_motion and not early.opening_cinematic._is_playing, "Early preferences were lost or Reduced Motion cinematic started"): return
	early.player.finish_opening_recovery()
	for i in 3: await process_frame
	early.queue_free()
	for i in 3: await process_frame
	var native_scene: PackedScene = load("res://scenes/opening_native_room.tscn")
	var native = native_scene.instantiate()
	native.native_checkpoint_path = save_prefix + ".json"
	native.native_preferences_path = save_prefix + ".cfg"
	root.add_child(native)
	for i in 5: await process_frame
	if not _check(not native.is_web_configuration_pending() and native.can_process() and native.opening_cinematic._is_playing, "Native initialization now requires a web handshake"): return
	var native_clip_position: float = native.player.animation_player.current_animation_position
	for i in 20: await physics_frame
	if not _check(native.player.animation_player.current_animation_position > native_clip_position, "Native wake animation no longer advances normally"): return
	native.opening_cinematic.finish()
	for i in 3: await process_frame
	native.queue_free()
	outside.queue_free()
	for i in 3: await process_frame
	for name in [".json", ".cfg"]:
		for suffix in ["", ".bak", ".tmp", ".bak.tmp"]:
			if FileAccess.file_exists(save_prefix + name + suffix): DirAccess.remove_absolute(save_prefix + name + suffix)
	print("PASS opening web input gate: %d checks; real pending wake/input freeze, rejected/incomplete configure, prefs-before-release, idempotence, dialogue ownership, early-ready ordering, native unaffected; OS web predicate simulated" % checks)
	quit(0)

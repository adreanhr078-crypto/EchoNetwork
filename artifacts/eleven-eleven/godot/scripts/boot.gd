extends Node

const NATIVE_SCENE := "res://scenes/native_journey.tscn"
var _preferences := ConfigFile.new()
var _preferences_path := "user://presentation_v1.cfg"
var _language := "ar"
var _reduced_motion := false
var _title_review := false
var _handoff_started := false

func _ready() -> void:
	# The browser shell already owns title, played cover and transfer. The
	# embedded room starts behind its existing web configuration handshake.
	if OS.has_feature("web"):
		_launch_game.call_deferred()
		return
	# Official export templates intentionally ignore external --script/path
	# overrides. Review sessions use normal user arguments and packed resources.
	if not OS.has_feature("web") and "--review-cp24" in OS.get_cmdline_user_args():
		_launch_review.call_deferred()
		return
	var title := preload("res://scripts/ui/title_entry.gd").new()
	_title_review = OS.is_debug_build() and "--review-title" in OS.get_cmdline_user_args()
	_preferences_path = "user://title_review_%d/preferences.cfg" % OS.get_process_id() if _title_review else "user://presentation_v1.cfg"
	if _title_review: DirAccess.make_dir_recursive_absolute(_preferences_path.get_base_dir())
	var preferences_loaded := _preferences.load(_preferences_path) == OK
	if not preferences_loaded: preferences_loaded = _preferences.load(_preferences_path + ".bak") == OK
	if preferences_loaded:
		var saved_language: Variant = _preferences.get_value("presentation", "language", "ar")
		var saved_motion: Variant = _preferences.get_value("presentation", "reduced_motion", false)
		var saved_mute: Variant = _preferences.get_value("presentation", "muted", false)
		title.language = saved_language if saved_language is String and saved_language in ["ar","en"] else "ar"
		title.reduced_motion = saved_motion if saved_motion is bool else false
		if saved_mute is bool: AudioServer.set_bus_mute(0,saved_mute)
	add_child(title)
	title.start_requested.connect(func():
		_language = title.language
		_reduced_motion = title.reduced_motion
		_preferences.set_value("presentation", "language", _language)
		_preferences.set_value("presentation", "reduced_motion", _reduced_motion)
		_save_entry_preferences()
		title.queue_free()
		if _title_review: _begin_local_entry.call_deferred()
		else: _launch_game.call_deferred()
	)

func _launch_game() -> void:
	var entry_origin: String=ProjectSettings.get_setting("network/native_entry_origin","")
	# Developer-only local transport review; never changes the deployed origin.
	if OS.is_debug_build():
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--entry-origin="): entry_origin=arg.trim_prefix("--entry-origin=")
	if not OS.has_feature("web") and not entry_origin.is_empty():
		var gate:=preload("res://scripts/systems/native_entry_gate.gd").new()
		gate.origin=entry_origin
		gate.language=_language
		add_child(gate)
		gate.entry_confirmed.connect(func(_receipt: String):
			gate.queue_free()
			_show_opening_film(Rect2(), false)
		)
		return
	if not OS.has_feature("web") and not "--maintenance-preview" in OS.get_cmdline_user_args():
		_begin_local_entry()
		return
	var scene_path := NATIVE_SCENE
	if OS.has_feature("web"):
		scene_path = "res://scenes/opening_web_room.tscn"
	elif "--maintenance-preview" in OS.get_cmdline_user_args():
		# Explicit maintenance-only review preserves its existing boundary.
		scene_path = "res://scenes/system_journey_preview.tscn"
	get_tree().call_deferred("change_scene_to_file", scene_path)

func _begin_local_entry() -> void:
	# These are presentation preferences, never an account entitlement.
	# A validated existing local chapter save resumes without replaying the cover.
	var saved := {} if _title_review else preload("res://scripts/systems/save_manager.gd").load_opening_checkpoint()
	if not saved.is_empty() and saved.milestones.wake:
		_enter_chapter()
		return
	if _preferences.get_value("entry", "cover_completed", false):
		_show_opening_film(Rect2(), false)
		return
	var cover := preload("res://scripts/ui/cover_recovery.gd").new()
	cover.language = _language
	cover.reduced_motion = _reduced_motion
	add_child(cover)
	cover.restored.connect(func(rect: Rect2):
		_language = cover.language
		_preferences.set_value("presentation", "language", _language)
		_preferences.set_value("entry", "cover_completed", true)
		_save_entry_preferences()
		cover.queue_free()
		_show_opening_film(rect, true)
	, CONNECT_ONE_SHOT)

func _show_opening_film(rect: Rect2, fracture: bool) -> void:
	if _preferences.get_value("entry", "film_seen", false):
		_enter_chapter()
		return
	var film := preload("res://scripts/ui/school_lab_opening.gd").new()
	# Keep media preloading in the presenter. Native4.8-dev7 leaks zero-count
	# RefCounted objects when this script-heavy scene is loaded on a worker
	# (isolated threaded42 vs synchronous0). Load it beneath the completed
	# sensory-cut curtain on the main thread instead.
	film.language = _language
	film.reduced_motion = _reduced_motion
	film.audio_muted = AudioServer.is_bus_mute(0)
	var saved_entry: Variant = _preferences.get_value("entry", "opening_state", {})
	var clean_entry: Dictionary = film.validate_state(saved_entry)
	if not clean_entry.is_empty(): film.entry_state = clean_entry
	film.board_rect = rect
	film.show_fracture = fracture
	film.entry_checkpoint_changed.connect(func(state: Dictionary, language: String, motion: bool, muted: bool):
		_language=language
		_reduced_motion=motion
		_preferences.set_value("entry","opening_state",state)
		_preferences.set_value("presentation","language",language)
		_preferences.set_value("presentation","reduced_motion",motion)
		_preferences.set_value("presentation","muted",muted)
		_save_entry_preferences()
		AudioServer.set_bus_mute(0,muted)
	)
	film.finished.connect(func():
		_preferences.set_value("entry", "film_seen", true)
		_save_entry_preferences()
		film.queue_free()
		_enter_chapter()
	, CONNECT_ONE_SHOT)
	add_child(film)

func _save_entry_preferences() -> bool:
	var temporary := _preferences_path + ".tmp"
	if _preferences.save(temporary) != OK:
		push_warning("Entry checkpoint write failed; previous checkpoint retained.")
		return false
	var previous := ConfigFile.new()
	if previous.load(_preferences_path) == OK:
		if DirAccess.copy_absolute(_preferences_path, _preferences_path + ".bak") != OK: return false
	if DirAccess.rename_absolute(temporary, _preferences_path) != OK:
		push_warning("Entry checkpoint replacement failed; previous checkpoint retained.")
		return false
	return true

func _enter_chapter() -> void:
	if _handoff_started: return
	_handoff_started = true
	if _title_review: _launch_review.call_deferred()
	else: _launch_native.call_deferred()

func _take_native_scene() -> PackedScene:
	# Every entry path must consume the preload it requested. A synchronous
	# load alone leaves the threaded request holding scene resources at exit.
	var status:=ResourceLoader.load_threaded_get_status(NATIVE_SCENE)
	if status in [ResourceLoader.THREAD_LOAD_IN_PROGRESS,ResourceLoader.THREAD_LOAD_LOADED]:
		return ResourceLoader.load_threaded_get(NATIVE_SCENE) as PackedScene
	return load(NATIVE_SCENE) as PackedScene

func _launch_native() -> void:
	var native_scene:=_take_native_scene()
	var main = native_scene.instantiate()
	main.opening_transfer_presented = true
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	queue_free()

func _launch_review() -> void:
	var smoke := "--review-smoke" in OS.get_cmdline_user_args()
	var save_root := "user://chapter_cp24_smoke_%d/" % OS.get_process_id() if smoke else "user://chapter_cp24_review/"
	if _title_review: save_root = _preferences_path.get_base_dir() + "/"
	DirAccess.make_dir_recursive_absolute(save_root)
	var main = _take_native_scene().instantiate()
	main.native_checkpoint_path = save_root+"opening.json"
	main.native_preferences_path = save_root+"preferences.cfg"
	if _title_review:
		main.native_preferences_path = _preferences_path
		main.opening_transfer_presented = true
	main.get_node("SystemJourneyPreview").checkpoint_path = save_root+"maintenance.json"
	main.get_node("NativeJourneyController").checkpoint_path = save_root+"route.json"
	main.get_node("NativeCampaignController").checkpoint_path = save_root+"campaign.json"
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	if smoke:
		var probe := preload("res://scripts/systems/native_review_probe.gd").new()
		probe.save_root = save_root
		main.add_child(probe)
	queue_free()

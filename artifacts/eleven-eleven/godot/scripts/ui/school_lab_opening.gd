extends "res://scripts/ui/opening_memory_film.gd"

## The existing film surface owns media only. Boot owns its local entry cursor;
## the campaign continues to own all pact, wish, power and reward decisions.
signal entry_checkpoint_changed(state: Dictionary, language: String, reduced: bool, muted: bool)
const BEATS := ["school","laboratory","questions","reply_experiment","reply_safety","experiment","done"]
const SHOTS := {
	"school":"res://assets/cinematics/memory-screens/city-high.ogv",
	"laboratory":"res://assets/cinematics/opening-cp45/lab-arrival.ogv",
	"experiment":"res://assets/cinematics/opening-cp45/experiment.ogv"
}
const POSTERS := {
	"school":"res://assets/cinematics/memory-screens/city-poster.webp",
	"laboratory":"res://assets/cinematics/opening-cp45/lab-arrival.webp",
	"experiment":"res://assets/cinematics/opening-cp45/experiment.webp"
}
var entry_state := {"beat":"school","asked":[]}
var _questions: VBoxContainer
var _dialogue_panel: PanelContainer
var _speaker: Label
var _copy: Label
var _language_button: Button
var _mute_button: Button
var _motion_button: Button
var _clock: Label
var _sequence_paused := false
var _media_failed := false
var _handoff_pending := false
var shot_overrides: Dictionary = {}

static func validate_state(raw: Variant) -> Dictionary:
	if not raw is Dictionary or raw.size()!=2 or raw.get("beat") not in BEATS: return {}
	if not raw.get("asked") is Array or raw.asked.size()>2: return {}
	var asked: Array=[]
	for id in raw.asked:
		if id not in ["experiment","safety"] or id in asked: return {}
		asked.append(id)
	if raw.beat.begins_with("reply_") and not asked.has(raw.beat.trim_prefix("reply_")): return {}
	return {"beat":raw.beat,"asked":asked}

func _ready() -> void:
	var clean := validate_state(entry_state)
	entry_state = clean if not clean.is_empty() else {"beat":"school","asked":[]}
	film_path = SHOTS.school
	poster_texture = load(POSTERS.school)
	var motion := reduced_motion
	# Build the inherited accessible surface before any media or callbacks run.
	reduced_motion = true
	super._ready()
	reduced_motion = motion
	for next_shot in ["laboratory","experiment"]:
		var path: String=shot_overrides.get(next_shot,SHOTS[next_shot])
		if ResourceLoader.exists(path) and ResourceLoader.load_threaded_get_status(path)==ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			ResourceLoader.load_threaded_request(path)
	subtitle.hide()
	_dialogue_panel = PanelContainer.new()
	root.add_child(_dialogue_panel)
	_dialogue_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_dialogue_panel.offset_left=-430
	_dialogue_panel.offset_right=430
	_dialogue_panel.offset_top=-310
	_dialogue_panel.offset_bottom=-30
	var style := StyleBoxFlat.new()
	style.bg_color=Color(.025,.035,.055,.96)
	style.border_color=Color(.43,.57,.69,.8)
	style.set_border_width_all(1)
	style.content_margin_left=24;style.content_margin_right=24
	style.content_margin_top=16;style.content_margin_bottom=16
	_dialogue_panel.add_theme_stylebox_override("panel",style)
	var column:=VBoxContainer.new()
	column.add_theme_constant_override("separation",12)
	_dialogue_panel.add_child(column)
	_speaker=Label.new();column.add_child(_speaker)
	_copy=Label.new();_copy.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(_copy)
	_questions=VBoxContainer.new();_questions.add_theme_constant_override("separation",8);column.add_child(_questions)
	for label in [_speaker,_copy]:
		label.add_theme_font_override("font",FONT)
		label.add_theme_font_size_override("font_size",22)
	var preferences:=HBoxContainer.new()
	preferences.position=Vector2(20,20)
	preferences.add_theme_constant_override("separation",10)
	root.add_child(preferences)
	_language_button=_button(preferences,"",func(): sync_preferences("en" if language=="ar" else "ar",reduced_motion,audio_muted))
	_mute_button=_button(preferences,"",func(): sync_preferences(language,reduced_motion,not audio_muted))
	_motion_button=_button(preferences,"",func(): sync_preferences(language,not reduced_motion,audio_muted))
	_clock=Label.new();root.add_child(_clock)
	_clock.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_clock.offset_left=-120;_clock.offset_right=120;_clock.offset_top=90;_clock.offset_bottom=155
	_clock.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	_clock.add_theme_font_size_override("font_size",42)
	_clock.text="11:11"
	pause_button.pressed.connect(func():
		_sequence_paused=video.paused
		_refresh_copy()
		_store_cursor())
	_apply_beat()
	if not reduced_motion and show_fracture and board_rect.has_area() and entry_state.beat=="school":
		video.stop();video.hide();ambient.stop()
		_fracture()

func _button(parent: Node, text: String, callback: Callable) -> Button:
	var button:=Button.new()
	button.text=text
	button.custom_minimum_size=Vector2(120,52)
	button.add_theme_font_override("font",FONT)
	button.add_theme_font_size_override("font_size",20)
	parent.add_child(button)
	button.pressed.connect(callback)
	return button

func _store_cursor() -> void:
	entry_checkpoint_changed.emit(entry_state.duplicate(true),language,reduced_motion,audio_muted)

func _set_beat(beat: String) -> void:
	entry_state.beat=beat
	_sequence_paused=false
	_store_cursor()
	_apply_beat()

func _apply_beat() -> void:
	if _done: return
	video.stop();video.paused=false;ambient.stop()
	var beat: String=entry_state.beat
	if beat=="done":
		super._finish()
		return
	var interactive:=beat=="questions" or beat.begins_with("reply_")
	var shot: String="laboratory" if interactive else beat
	var path: String=shot_overrides.get(shot,SHOTS.get(shot,""))
	var status:=ResourceLoader.load_threaded_get_status(path)
	video.stream=(ResourceLoader.load_threaded_get(path) if status in [ResourceLoader.THREAD_LOAD_IN_PROGRESS,ResourceLoader.THREAD_LOAD_LOADED] else load(path)) if ResourceLoader.exists(path) else null
	_media_failed=video.stream==null
	poster.texture=load(POSTERS[shot]) if ResourceLoader.exists(POSTERS[shot]) else poster_texture
	poster.show();video.hide()
	_dialogue_panel.visible=interactive
	if not interactive and not reduced_motion and not _media_failed: _play()
	if not interactive and beat=="school": ambient.stream=load("res://assets/cinematics/memory-screens/city.ogg")
	else: ambient.stream=preload("res://scripts/audio/procedural_cinematic_audio.gd").create_pressure_air(8.0,4511)
	ambient.volume_db=-80 if audio_muted else -10
	if not interactive and not reduced_motion and not audio_muted: ambient.play()
	video.paused=_sequence_paused
	ambient.stream_paused=_sequence_paused
	_refresh_copy()
	_store_cursor()

func _rebuild_questions() -> void:
	for child in _questions.get_children():
		_questions.remove_child(child);child.queue_free()
	var ar:=language=="ar"
	var beat: String=entry_state.beat
	_speaker.text="الأب" if ar else "Father"
	_copy.text=("لديّ سؤال قبل أن نبدأ." if ar else "I have a question before we begin.") if beat=="questions" else (("سنراقب الإشارات أثناء الفحص. ابقَ هادئًا." if ar else "We will monitor the signals during the examination. Stay still.") if beat=="reply_experiment" else ("أخبرني فورًا إن شعرت بشيء غير معتاد." if ar else "Tell me immediately if anything feels unusual."))
	if beat=="questions":
		_speaker.text="إيكو" if ar else "Echo"
		for pair in [["experiment","ما هذه التجربة؟","What is this experiment?"],["safety","ماذا عن الأمان؟","What about safety?"],["ready","أنا مستعد.","I am ready."]]:
			var button:=_button(_questions,pair[1] if ar else pair[2],_choose.bind(pair[0]))
			button.disabled=_sequence_paused
	else:
		var back:=_button(_questions,"العودة للأسئلة" if ar else "Back to questions",func():_set_beat("questions"))
		back.disabled=_sequence_paused
	if _questions.get_child_count()>0 and not _sequence_paused: _questions.get_child(0).grab_focus()

func _choose(id: String) -> void:
	if _done or _sequence_paused or entry_state.beat!="questions": return
	if id=="ready": _set_beat("experiment")
	elif id in ["experiment","safety"]:
		if id not in entry_state.asked: entry_state.asked.append(id)
		_set_beat("reply_"+id)

func _finish() -> void:
	if _done or _sequence_paused or _handoff_pending: return
	match entry_state.beat:
		"school": _set_beat("laboratory")
		"laboratory": _set_beat("questions")
		"experiment":
			entry_state.beat="done"
			_store_cursor()
			_handoff_pending=true
			video.paused=true;ambient.stop()
			if reduced_motion:
				_complete_entry()
			else:
				var curtain:=ColorRect.new()
				curtain.color=Color.BLACK
				root.add_child(curtain)
				curtain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				curtain.modulate.a=0
				_fracture_tween=create_tween()
				_fracture_tween.tween_property(curtain,"modulate:a",1.0,.35)
				_fracture_tween.tween_callback(_complete_entry)

func _complete_entry() -> void:
	if not _done: super._finish()

func sync_preferences(next_language: String, motion: bool, muted: bool) -> void:
	if not is_instance_valid(_questions): return
	language="en" if next_language=="en" else "ar"
	var changed_motion:=motion!=reduced_motion
	reduced_motion=motion;audio_muted=muted
	if changed_motion:
		if _fracture_tween and _fracture_tween.is_running(): _fracture_tween.kill()
		_apply_beat()
	else:
		ambient.volume_db=-80 if muted else -10
		_refresh_copy()
	_store_cursor()

func _refresh_copy() -> void:
	if not is_instance_valid(_questions): return
	var ar:=language=="ar"
	var interactive:bool=entry_state.beat=="questions" or entry_state.beat.begins_with("reply_")
	skip_button.text=("المتابعة" if reduced_motion or _media_failed else "تخطي اللقطة") if ar else ("Continue" if reduced_motion or _media_failed else "Skip shot")
	skip_button.visible=not interactive and not _sequence_paused
	pause_button.visible=true
	pause_button.text=("استئناف" if _sequence_paused else "إيقاف مؤقت") if ar else ("Resume" if _sequence_paused else "Pause")
	_language_button.text="English" if ar else "العربية"
	_mute_button.text=("مكتوم" if audio_muted else "صوت") if ar else ("Muted" if audio_muted else "Sound")
	_motion_button.text=("حركة أقل" if reduced_motion else "حركة") if ar else ("Reduced motion" if reduced_motion else "Motion")
	_dialogue_panel.layout_direction=Control.LAYOUT_DIRECTION_RTL if ar else Control.LAYOUT_DIRECTION_LTR
	for label in [_speaker,_copy]: label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT if ar else HORIZONTAL_ALIGNMENT_LEFT
	_clock.visible=entry_state.beat=="experiment" and (reduced_motion or _media_failed or video.stream_position>=4.0)
	if interactive: _rebuild_questions()

func _process(_delta: float) -> void:
	if not is_instance_valid(_clock): return
	_clock.visible=entry_state.beat=="experiment" and (reduced_motion or _media_failed or video.stream_position>=4.0)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ESCAPE:
		pause_button.pressed.emit()
		get_viewport().set_input_as_handled()

func _exit_tree() -> void:
	super._exit_tree()
	for shot in ["laboratory","experiment"]:
		var path: String=shot_overrides.get(shot,SHOTS[shot])
		if ResourceLoader.load_threaded_get_status(path) in [ResourceLoader.THREAD_LOAD_IN_PROGRESS,ResourceLoader.THREAD_LOAD_LOADED]:
			ResourceLoader.load_threaded_get(path)

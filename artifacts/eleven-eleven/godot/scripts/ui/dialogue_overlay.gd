extends Control

signal dialogue_started
signal line_displayed(index, line_data)
signal dialogue_completed

@export var typewriter_speed: float = 0.025
@export var reduced_motion: bool = false

var dialogue_lines: Array = [
	{
		"speaker": "ECHO // 11.11",
		"speaker_color": Color(0.0, 0.94, 1.0, 1.0),
		"text": "تم فك تشفير السجلات... 'مشروع زيو - العينة الأساسية'؟ ما الذي حدث في هذا القطاع؟"
	},
	{
		"speaker": "TACTICAL POD // COMPANION",
		"speaker_color": Color(1.0, 0.75, 0.2, 1.0),
		"text": "تنبيه: سجلات المنشأة تؤكد أن كبسولة الاستيقاظ لم تُفتح نتيجة خلل... بل تم تفعيلها عمداً من وحدة التحكم المركزية."
	},
	{
		"speaker": "ECHO // 11.11",
		"speaker_color": Color(0.0, 0.94, 1.0, 1.0),
		"text": "شخص ما كان يريدني أن أستيقظ... وأواجه هذا الكائن بالسلاح الأبيض."
	},
	{
		"speaker": "TACTICAL POD // COMPANION",
		"speaker_color": Color(1.0, 0.75, 0.2, 1.0),
		"text": "الترددات تشير إلى إشارة حيوية متبقية في عمق القطاع 11... يجب مواصلة التقدم قبل إغلاق بروتوكول الطوارئ."
	}
]

var current_line_index: int = -1
var is_active: bool = false
var is_typing: bool = false
var full_text: String = ""
var displayed_chars: int = 0
var typing_timer: float = 0.0
var presentation_language := "ar"
var continue_button: Button

@onready var speaker_lbl: Label = $DialogBox/VBox/SpeakerBadge/SpeakerLabel if has_node("DialogBox/VBox/SpeakerBadge/SpeakerLabel") else null
@onready var text_lbl: Label = $DialogBox/VBox/TextLabel if has_node("DialogBox/VBox/TextLabel") else null
@onready var continue_prompt: Label = $DialogBox/ContinuePrompt if has_node("DialogBox/ContinuePrompt") else null

func _ready() -> void:
	visible = false
	continue_button = Button.new()
	continue_button.name = "ContinueButton"
	$DialogBox.add_child(continue_button)
	continue_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	continue_button.offset_left = -220
	continue_button.offset_right = -24
	continue_button.offset_top = -60
	continue_button.offset_bottom = -12
	continue_button.add_theme_font_size_override("font_size", 22)
	continue_button.pressed.connect(advance_dialogue)
	get_viewport().size_changed.connect(_layout)
	_layout()
	set_presentation_language(presentation_language)

func _layout() -> void:
	var screen := get_viewport().get_visible_rect().size
	var box := $DialogBox as Panel
	box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	box.size = Vector2(minf(960.0, screen.x - 48.0), minf(230.0, screen.y * 0.45))
	box.position = Vector2((screen.x - box.size.x) * 0.5, screen.y - box.size.y - 24.0)
	$DialogBox/VBox.offset_bottom = -68
	if text_lbl: text_lbl.add_theme_font_size_override("font_size", 24)
	if speaker_lbl: speaker_lbl.add_theme_font_size_override("font_size", 18)
	if continue_prompt: continue_prompt.hide()

func set_presentation_language(language: String) -> void:
	presentation_language = "en" if language == "en" else "ar"
	layout_direction = Control.LAYOUT_DIRECTION_RTL if presentation_language == "ar" else Control.LAYOUT_DIRECTION_LTR
	if continue_button: continue_button.text = "متابعة" if presentation_language == "ar" else "Continue"
	if is_active:
		_apply_line_text()

func _apply_line_text() -> void:
	var line: Dictionary = dialogue_lines[current_line_index]
	full_text = line.get("text_" + presentation_language, line.get("text", ""))
	if speaker_lbl:
		speaker_lbl.text = line.get("speaker_" + presentation_language, line.get("speaker", "UNKNOWN"))
		speaker_lbl.modulate = line.get("speaker_color", Color.WHITE)
	if text_lbl:
		# Shape the complete Arabic line once; reveal characters without slicing
		# and reshaping the text every frame.
		text_lbl.text = full_text
		text_lbl.visible_characters = -1 if not is_typing else mini(displayed_chars, full_text.length())

func finish_typing() -> void:
	is_typing = false
	if text_lbl: text_lbl.visible_characters = -1

func start_dialogue(custom_lines: Array = []) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if custom_lines.size() > 0:
		dialogue_lines = custom_lines
	current_line_index = -1
	is_active = true
	visible = true
	_layout()
	if continue_button: continue_button.grab_focus()
	emit_signal("dialogue_started")
	advance_dialogue()

func _process(delta: float) -> void:
	if not is_active:
		return
	if is_typing:
		typing_timer += delta
		if reduced_motion:
			finish_typing()
			return
		if typing_timer >= typewriter_speed:
			displayed_chars += int(typing_timer / maxf(typewriter_speed, 0.001))
			typing_timer = fmod(typing_timer, maxf(typewriter_speed, 0.001))
			if text_lbl:
				text_lbl.visible_characters = displayed_chars
			if displayed_chars >= full_text.length():
				finish_typing()

func _gui_input(event: InputEvent) -> void:
	if not is_active: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		advance_dialogue()
		accept_event()
	elif event is InputEventScreenTouch and event.pressed:
		advance_dialogue()
		accept_event()

func _unhandled_input(event: InputEvent) -> void:
	if not is_active:
		return
	if event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and event.keycode == KEY_SPACE):
		advance_dialogue()
		get_viewport().set_input_as_handled()

func advance_dialogue() -> void:
	if is_typing:
		# Instant finish line
		finish_typing()
		return

	current_line_index += 1
	if current_line_index >= dialogue_lines.size():
		close_dialogue()
		return

	var line = dialogue_lines[current_line_index]
	displayed_chars = 0
	typing_timer = 0.0
	is_typing = not reduced_motion
	if continue_prompt:
		continue_prompt.visible = false

	if not speaker_lbl:
		speaker_lbl = find_child("SpeakerLabel", true, false) as Label
	if not text_lbl:
		text_lbl = find_child("TextLabel", true, false) as Label

	_apply_line_text()

	emit_signal("line_displayed", current_line_index, line)

func close_dialogue() -> void:
	if not is_active: return
	is_active = false
	is_typing = false
	visible = false
	emit_signal("dialogue_completed")

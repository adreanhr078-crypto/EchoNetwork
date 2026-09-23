extends Control

signal dialogue_started
signal line_displayed(index, line_data)
signal dialogue_completed

@export var typewriter_speed: float = 0.025

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

@onready var speaker_lbl: Label = $DialogBox/VBox/SpeakerBadge/SpeakerLabel if has_node("DialogBox/VBox/SpeakerBadge/SpeakerLabel") else null
@onready var text_lbl: Label = $DialogBox/VBox/TextLabel if has_node("DialogBox/VBox/TextLabel") else null
@onready var continue_prompt: Label = $DialogBox/ContinuePrompt if has_node("DialogBox/ContinuePrompt") else null

func _ready() -> void:
	visible = false

func start_dialogue(custom_lines: Array = []) -> void:
	if custom_lines.size() > 0:
		dialogue_lines = custom_lines
	current_line_index = -1
	is_active = true
	visible = true
	emit_signal("dialogue_started")
	advance_dialogue()

func _process(delta: float) -> void:
	if not is_active:
		return
	if is_typing:
		typing_timer += delta
		if typing_timer >= typewriter_speed:
			typing_timer = 0.0
			displayed_chars += 1
			if text_lbl:
				text_lbl.text = full_text.substr(0, displayed_chars)
			if displayed_chars >= full_text.length():
				is_typing = false
				if continue_prompt:
					continue_prompt.visible = true

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		advance_dialogue()
	elif event is InputEventScreenTouch and event.pressed:
		advance_dialogue()

func _unhandled_input(event: InputEvent) -> void:
	if not is_active:
		return
	if event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and event.keycode == KEY_SPACE):
		advance_dialogue()

func advance_dialogue() -> void:
	if is_typing:
		# Instant finish line
		is_typing = false
		if text_lbl:
			text_lbl.text = full_text
		if continue_prompt:
			continue_prompt.visible = true
		return

	current_line_index += 1
	if current_line_index >= dialogue_lines.size():
		close_dialogue()
		return

	var line = dialogue_lines[current_line_index]
	full_text = line.get("text", "")
	displayed_chars = 0
	is_typing = true
	if continue_prompt:
		continue_prompt.visible = false

	if not speaker_lbl:
		speaker_lbl = find_child("SpeakerLabel", true, false) as Label
	if not text_lbl:
		text_lbl = find_child("TextLabel", true, false) as Label

	if speaker_lbl:
		speaker_lbl.text = line.get("speaker", "UNKNOWN")
		speaker_lbl.modulate = line.get("speaker_color", Color.WHITE)

	if text_lbl:
		text_lbl.text = ""

	emit_signal("line_displayed", current_line_index, line)

func close_dialogue() -> void:
	is_active = false
	visible = false
	emit_signal("dialogue_completed")

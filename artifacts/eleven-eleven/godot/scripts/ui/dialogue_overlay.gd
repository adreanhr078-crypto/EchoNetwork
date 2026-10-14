extends Control
const DIALOGUE_FONT = preload("res://assets/fonts/NotoSansArabic.ttf")
const NativeUIDensity = preload("res://scripts/ui/native_ui_density.gd")

signal dialogue_started
signal line_displayed(index, line_data)
signal dialogue_completed

@export var typewriter_speed: float = 0.025
@export var reduced_motion: bool = false:
	set(value):
		reduced_motion = value
		if value and is_node_ready():
			_cancel_presentation()
			modulate.a = 1.0 if is_active else 0.0
			visible = is_active
			if text_lbl: text_lbl.modulate.a = 1.0
			finish_typing()

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
var _content_scroll: ScrollContainer
var _presentation_tween: Tween
var _line_tween: Tween
var _presentation_revision := 0
var _panel_style: StyleBoxFlat

@onready var speaker_lbl: Label = $DialogBox/VBox/SpeakerBadge/SpeakerLabel if has_node("DialogBox/VBox/SpeakerBadge/SpeakerLabel") else null
@onready var text_lbl: Label = $DialogBox/VBox/TextLabel if has_node("DialogBox/VBox/TextLabel") else null
@onready var continue_prompt: Label = $DialogBox/ContinuePrompt if has_node("DialogBox/ContinuePrompt") else null

func _ready() -> void:
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	var readable_theme := Theme.new()
	var readable_font := DIALOGUE_FONT.duplicate() as FontFile
	readable_font.oversampling = 1.0
	readable_theme.default_font = readable_font
	theme = readable_theme
	if speaker_lbl: speaker_lbl.add_theme_color_override("font_color", Color.WHITE)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.018, 0.028, 0.045, 0.97)
	panel_style.border_color = Color(0.25, 0.57, 0.65, 0.65)
	panel_style.set_border_width_all(1)
	panel_style.border_width_top = 2
	panel_style.set_corner_radius_all(10)
	panel_style.shadow_color = Color(0.0, 0.01, 0.02, 0.3)
	panel_style.shadow_size = 12
	_panel_style = panel_style
	$DialogBox.add_theme_stylebox_override("panel", panel_style)
	_content_scroll = ScrollContainer.new()
	_content_scroll.name = "DialogueContentScroll"
	_content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_content_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	$DialogBox.add_child(_content_scroll)
	_content_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content_scroll.offset_left = 20
	_content_scroll.offset_top = 12
	_content_scroll.offset_right = -20
	_content_scroll.offset_bottom = -76
	var content := $DialogBox/VBox as VBoxContainer
	content.reparent(_content_scroll)
	content.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	continue_button = Button.new()
	continue_button.name = "ContinueButton"
	$DialogBox.add_child(continue_button)
	continue_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	continue_button.offset_left = -220
	continue_button.offset_right = -24
	continue_button.offset_top = -60
	continue_button.offset_bottom = -12
	continue_button.custom_minimum_size = Vector2(140, 48)
	continue_button.add_theme_font_size_override("font_size", 18)
	continue_button.add_theme_color_override("font_color", Color(0.91, 0.95, 0.98))
	continue_button.add_theme_color_override("font_hover_color", Color.WHITE)
	_style_continue_button(Color(0.3, 0.65, 0.73))
	continue_button.pressed.connect(advance_dialogue)
	get_viewport().size_changed.connect(_layout)
	_layout()
	set_presentation_language(presentation_language)

func _style_continue_button(accent: Color) -> void:
	if not continue_button: return
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(7)
		style.set_border_width_all(2 if state == "focus" else 1)
		style.bg_color = Color(0.035, 0.065, 0.085, 0.98)
		if state == "hover": style.bg_color = Color(0.055, 0.105, 0.14, 1.0)
		if state == "pressed": style.bg_color = Color(0.025, 0.05, 0.07, 1.0)
		if state == "focus": style.bg_color = Color.TRANSPARENT
		style.border_color = Color(0.76, 0.9, 0.96) if state == "focus" else Color(accent, 0.7)
		continue_button.add_theme_stylebox_override(state, style)

func _cancel_presentation() -> void:
	_presentation_revision += 1
	if _presentation_tween and _presentation_tween.is_valid(): _presentation_tween.kill()
	if _line_tween and _line_tween.is_valid(): _line_tween.kill()
	_presentation_tween = null
	_line_tween = null

func _set_dialogue_input(enabled: bool) -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	$DialogBox.mouse_filter = mouse_filter
	if _content_scroll: _content_scroll.mouse_filter = mouse_filter
	if continue_button:
		continue_button.disabled = not enabled
		continue_button.mouse_filter = mouse_filter
		if not enabled: continue_button.release_focus()

func _finish_departure(revision: int) -> void:
	# Completion handlers may synchronously start another dialogue. An old
	# departure must never hide the new line or steal its input ownership.
	if revision == _presentation_revision and not is_active:
		visible = false

func _presentation_density() -> float:
	return NativeUIDensity.pixel_ratio()

func _layout() -> void:
	var stretch := get_viewport().get_stretch_transform().get_scale()
	stretch = Vector2(maxf(0.001, stretch.x), maxf(0.001, stretch.y))
	var density := _presentation_density()
	scale = Vector2.ONE * density / stretch
	var screen := get_viewport().get_visible_rect().size * stretch / density
	size = screen
	position = Vector2.ZERO
	var box := $DialogBox as Panel
	box.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	box.size = Vector2(minf(720.0, screen.x - 24.0), minf(screen.y - 24.0, clampf(screen.y * 0.42, 168.0, 244.0)))
	box.position = Vector2((screen.x - box.size.x) * 0.5, screen.y - box.size.y - 12.0)
	if text_lbl:
		text_lbl.add_theme_font_size_override("font_size", 20 if screen.y < 300 else 22)
		# Godot mirrors logical LEFT in RTL layouts; explicit RIGHT would
		# mirror a second time and put Arabic body text on the left.
		text_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	if speaker_lbl:
		speaker_lbl.add_theme_font_size_override("font_size", 17)
		speaker_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_content_scroll.get_child(0).size.x = box.size.x - 40
	if continue_prompt: continue_prompt.hide()

func set_presentation_language(language: String) -> void:
	presentation_language = "en" if language == "en" else "ar"
	layout_direction = Control.LAYOUT_DIRECTION_RTL if presentation_language == "ar" else Control.LAYOUT_DIRECTION_LTR
	if continue_button: continue_button.text = "متابعة" if presentation_language == "ar" else "Continue"
	if is_node_ready(): _layout()
	if is_active:
		_apply_line_text()

func _apply_line_text() -> void:
	var line: Dictionary = dialogue_lines[current_line_index]
	full_text = line.get("text_" + presentation_language, line.get("text", ""))
	if speaker_lbl:
		speaker_lbl.text = line.get("speaker_" + presentation_language, line.get("speaker", "UNKNOWN"))
		var accent: Color = line.get("speaker_color", Color(0.3, 0.75, 0.82))
		speaker_lbl.modulate = accent.lerp(Color(0.88, 0.94, 0.98), 0.2)
		if _panel_style: _panel_style.border_color = Color(accent.lerp(Color(0.32, 0.42, 0.5), 0.45), 0.65)
		_style_continue_button(accent.lerp(Color(0.32, 0.42, 0.5), 0.45))
	if text_lbl:
		# Shape the complete Arabic line once; reveal characters without slicing
		# and reshaping the text every frame.
		text_lbl.text = full_text
		text_lbl.visible_characters = -1 if not is_typing else mini(displayed_chars, full_text.length())

func finish_typing() -> void:
	is_typing = false
	if text_lbl: text_lbl.visible_characters = -1

func start_dialogue(custom_lines: Array = []) -> void:
	_cancel_presentation()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if custom_lines.size() > 0:
		dialogue_lines = custom_lines
	current_line_index = -1
	is_active = true
	visible = true
	_set_dialogue_input(true)
	modulate.a = 1.0 if reduced_motion else 0.0
	if text_lbl: text_lbl.modulate.a = 1.0
	if not reduced_motion:
		_presentation_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_presentation_tween.tween_property(self, "modulate:a", 1.0, 0.22)
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
	_content_scroll.scroll_vertical = 0
	if _line_tween and _line_tween.is_valid(): _line_tween.kill()
	if text_lbl:
		text_lbl.modulate.a = 1.0
		if current_line_index > 0 and not reduced_motion:
			text_lbl.modulate.a = 0.55
			_line_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			_line_tween.tween_property(text_lbl, "modulate:a", 1.0, 0.12)

	emit_signal("line_displayed", current_line_index, line)

func close_dialogue() -> void:
	if not is_active: return
	is_active = false
	is_typing = false
	_cancel_presentation()
	_set_dialogue_input(false)
	if reduced_motion:
		modulate.a = 0.0
		visible = false
	else:
		_presentation_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_presentation_tween.tween_property(self, "modulate:a", 0.0, 0.18)
		_presentation_tween.finished.connect(_finish_departure.bind(_presentation_revision))
	# Story and control handoff remain immediate; cosmetic departure does not
	# delay a decision, replay a completion, or capture resumed player input.
	emit_signal("dialogue_completed")

extends Control
const TERMINAL_FONT = preload("res://assets/fonts/NotoSansArabic.ttf")
const NativeUIDensity = preload("res://scripts/ui/native_ui_density.gd")

signal puzzle_completed(lore_data)
signal puzzle_closed

var freq_val: float = 80.0
var freq_target: float = 111.0

var phase_val: float = 0.0
var phase_target: float = 45.0

var harmonic_val: float = 1.0
var harmonic_target: float = 7.0

var is_solved: bool = false
var has_started: bool = false
var is_open := false
var _presentation_tween: Tween
var _presentation_revision := 0
var reduced_motion := false:
	set(value):
		reduced_motion = value
		if value and is_node_ready():
			_cancel_presentation()
			modulate.a = 1.0 if is_open else 0.0
			visible = is_open
var presentation_language := "ar"
var _content_scroll: ScrollContainer
var _title_label: Label
var _row_labels: Array[Label] = []
var _step_buttons: Array[Button] = []

func set_presentation_language(language: String) -> void:
	presentation_language = language
	var arabic := language == "ar"
	$Panel.layout_direction = Control.LAYOUT_DIRECTION_RTL if arabic else Control.LAYOUT_DIRECTION_LTR
	_ensure_nodes()
	if _row_labels.size()==3:
		_row_labels[0].text = "التردد:" if arabic else "Frequency:"
		_row_labels[1].text = "الطور:" if arabic else "Phase:"
		_row_labels[2].text = "القناة:" if arabic else "Channel:"
	for button in _step_buttons:
		button.tooltip_text = ("زيادة خطوة" if arabic else "Increase one step") if button.name=="IncreaseStep" else ("تقليل خطوة" if arabic else "Decrease one step")
	if proceed_btn: proceed_btn.text = "متابعة" if arabic else "Continue"
	if _title_label: _title_label.text = "القطاع 11 // ضبط الإشارة" if arabic else "SECTOR 11 // SIGNAL ALIGNMENT"
	_update_ui()

@onready var freq_slider: Slider = $Panel/VBox/FreqRow/FreqSlider if has_node("Panel/VBox/FreqRow/FreqSlider") else null
@onready var phase_slider: Slider = $Panel/VBox/PhaseRow/PhaseSlider if has_node("Panel/VBox/PhaseRow/PhaseSlider") else null
@onready var harmonic_slider: Slider = $Panel/VBox/HarmonicRow/HarmonicSlider if has_node("Panel/VBox/HarmonicRow/HarmonicSlider") else null

@onready var freq_lbl: Label = $Panel/VBox/FreqRow/FreqVal if has_node("Panel/VBox/FreqRow/FreqVal") else null
@onready var phase_lbl: Label = $Panel/VBox/PhaseRow/PhaseVal if has_node("Panel/VBox/PhaseRow/PhaseVal") else null
@onready var harmonic_lbl: Label = $Panel/VBox/HarmonicRow/HarmonicVal if has_node("Panel/VBox/HarmonicRow/HarmonicVal") else null

@onready var status_lbl: Label = $Panel/VBox/StatusLabel if has_node("Panel/VBox/StatusLabel") else null
@onready var progress_bar: ProgressBar = $Panel/VBox/SyncProgressBar if has_node("Panel/VBox/SyncProgressBar") else null
@onready var proceed_btn: Button = $Panel/VBox/ProceedBtn if has_node("Panel/VBox/ProceedBtn") else null

func _ensure_nodes() -> void:
	if not freq_slider: freq_slider = find_child("FreqSlider", true, false) as Slider
	if not phase_slider: phase_slider = find_child("PhaseSlider", true, false) as Slider
	if not harmonic_slider: harmonic_slider = find_child("HarmonicSlider", true, false) as Slider
	if not freq_lbl: freq_lbl = find_child("FreqVal", true, false) as Label
	if not phase_lbl: phase_lbl = find_child("PhaseVal", true, false) as Label
	if not harmonic_lbl: harmonic_lbl = find_child("HarmonicVal", true, false) as Label
	if not status_lbl: status_lbl = find_child("StatusLabel", true, false) as Label
	if not progress_bar: progress_bar = find_child("SyncProgressBar", true, false) as ProgressBar
	if not proceed_btn: proceed_btn = find_child("ProceedBtn", true, false) as Button

func get_progress_bar() -> ProgressBar:
	_ensure_nodes()
	return progress_bar

func _ready() -> void:
	visible = false
	_ensure_nodes()
	if freq_slider and not freq_slider.value_changed.is_connected(_on_freq_changed):
		freq_slider.value_changed.connect(_on_freq_changed)
	if phase_slider and not phase_slider.value_changed.is_connected(_on_phase_changed):
		phase_slider.value_changed.connect(_on_phase_changed)
	if harmonic_slider and not harmonic_slider.value_changed.is_connected(_on_harmonic_changed):
		harmonic_slider.value_changed.connect(_on_harmonic_changed)
	if proceed_btn and not proceed_btn.pressed.is_connected(_on_proceed_pressed):
		proceed_btn.pressed.connect(_on_proceed_pressed)

	var close_btn = find_child("CloseBtn", true, false) as Button
	if close_btn and not close_btn.pressed.is_connected(close_puzzle):
		close_btn.pressed.connect(close_puzzle)

	_build_readable_layout()
	set_presentation_language(presentation_language)
	_update_ui()

func _build_readable_layout() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	var readable_theme := Theme.new()
	var font := TERMINAL_FONT.duplicate() as FontFile
	font.oversampling = 1.0
	readable_theme.default_font = font
	theme = readable_theme
	var panel := $Panel as Panel
	var content := $Panel/VBox as VBoxContainer
	_title_label = content.get_node("Title") as Label
	_title_label.reparent(panel)
	_title_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_title_label.offset_left=16
	_title_label.offset_right=-80
	_title_label.offset_top=12
	_title_label.offset_bottom=60
	_title_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	_title_label.add_theme_font_size_override("font_size",18)
	_content_scroll=ScrollContainer.new()
	_content_scroll.name="TerminalContentScroll"
	_content_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	_content_scroll.follow_focus=true
	panel.add_child(_content_scroll)
	_content_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content_scroll.offset_left=16
	_content_scroll.offset_right=-16
	_content_scroll.offset_top=68
	_content_scroll.offset_bottom=-68
	content.reparent(_content_scroll)
	content.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	content.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation",8)
	status_lbl.add_theme_font_size_override("font_size",17)
	for entry in [[freq_slider,freq_lbl],[phase_slider,phase_lbl],[harmonic_slider,harmonic_lbl]]:
		var slider: Slider=entry[0]
		var value_label: Label=entry[1]
		var old_row := slider.get_parent() as HBoxContainer
		var row := VBoxContainer.new()
		row.name=old_row.name
		var index:=old_row.get_index()
		content.remove_child(old_row)
		content.add_child(row)
		content.move_child(row,index)
		row.add_theme_constant_override("separation",4)
		var header:=HBoxContainer.new()
		header.add_theme_constant_override("separation",8)
		row.add_child(header)
		var label := old_row.get_node("Label") as Label
		_row_labels.append(label)
		label.reparent(header)
		label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		label.custom_minimum_size.x=72
		label.add_theme_font_size_override("font_size",17)
		value_label.reparent(header)
		var controls:=HBoxContainer.new()
		controls.name="PrecisionControls"
		controls.add_theme_constant_override("separation",8)
		row.add_child(controls)
		var decrease:=_make_step_button(slider,-1)
		controls.add_child(decrease)
		slider.reparent(controls)
		controls.add_child(_make_step_button(slider,1))
		slider.custom_minimum_size=Vector2(0,48)
		old_row.queue_free()
	for label: Label in [freq_lbl,phase_lbl,harmonic_lbl]:
		label.custom_minimum_size.x=96
		label.add_theme_font_size_override("font_size",17)
		label.text_direction=Control.TEXT_DIRECTION_LTR
	progress_bar.custom_minimum_size.y=24
	proceed_btn.reparent(panel)
	proceed_btn.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	proceed_btn.offset_left=-216
	proceed_btn.offset_right=-16
	proceed_btn.offset_top=-64
	proceed_btn.offset_bottom=-16
	proceed_btn.custom_minimum_size=Vector2(140,48)
	proceed_btn.add_theme_font_size_override("font_size",18)
	var close := panel.get_node("CloseBtn") as Button
	close.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	close.offset_left=-64
	close.offset_right=-16
	close.offset_top=12
	close.offset_bottom=60
	close.custom_minimum_size=Vector2(48,48)
	close.text="×"
	get_viewport().size_changed.connect(_layout)
	_layout()

func _make_step_button(slider: Slider, direction: int) -> Button:
	var button:=Button.new()
	button.name="IncreaseStep" if direction>0 else "DecreaseStep"
	button.text="+" if direction>0 else "−"
	button.custom_minimum_size=Vector2(48,48)
	button.add_theme_font_size_override("font_size",22)
	for state in ["normal","hover","pressed","focus"]:
		var style:=StyleBoxFlat.new()
		style.bg_color=Color(0.035,0.065,0.085,0.98)
		style.border_color=Color(0.3,0.65,0.73,0.7) if state!="focus" else Color(0.76,0.9,0.96)
		style.set_border_width_all(2 if state=="focus" else 1)
		style.set_corner_radius_all(6)
		button.add_theme_stylebox_override(state,style)
	button.pressed.connect(_adjust_slider.bind(slider,direction))
	_step_buttons.append(button)
	return button

func _adjust_slider(slider: Slider, direction: int) -> void:
	if is_open: slider.value=clampf(slider.value+direction*slider.step,slider.min_value,slider.max_value)

func _presentation_density() -> float:
	return NativeUIDensity.pixel_ratio()

func _layout() -> void:
	if not _content_scroll: return
	var stretch := get_viewport().get_stretch_transform().get_scale()
	stretch=Vector2(maxf(.001,stretch.x),maxf(.001,stretch.y))
	var density := _presentation_density()
	scale=Vector2.ONE*density/stretch
	var screen := get_viewport().get_visible_rect().size*stretch/density
	size=screen
	position=Vector2.ZERO
	var panel := $Panel as Panel
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	panel.size=Vector2(minf(720,screen.x-24),minf(420,screen.y-24))
	panel.position=(screen-panel.size)*.5

func open_puzzle() -> void:
	_ensure_nodes()
	_cancel_presentation()
	is_open = true
	visible = true
	_set_input_enabled(true)
	modulate.a = 1.0 if reduced_motion else 0.0
	if not reduced_motion:
		_presentation_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_presentation_tween.tween_property(self, "modulate:a", 1.0, 0.22)
	if not has_started:
		has_started = true
		freq_val = 80.0
		phase_val = 0.0
		harmonic_val = 1.0
	if freq_slider: freq_slider.value = freq_val
	if phase_slider: phase_slider.value = phase_val
	if harmonic_slider: harmonic_slider.value = harmonic_val
	if proceed_btn: proceed_btn.visible = is_solved
	_update_ui()

func close_puzzle() -> void:
	if not is_open: return
	is_open = false
	_cancel_presentation()
	_set_input_enabled(false)
	if reduced_motion:
		visible = false
	else:
		_presentation_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_presentation_tween.tween_property(self, "modulate:a", 0.0, 0.18)
		_presentation_tween.finished.connect(_finish_departure.bind(_presentation_revision))
	emit_signal("puzzle_closed")

func _cancel_presentation() -> void:
	_presentation_revision += 1
	if _presentation_tween and _presentation_tween.is_valid(): _presentation_tween.kill()

func _finish_departure(revision: int) -> void:
	if revision == _presentation_revision and not is_open: visible = false

func _set_input_enabled(enabled: bool) -> void:
	for control in find_children("*", "Control", true, false):
		if not control.has_meta("presentation_mouse_filter"):
			control.set_meta("presentation_mouse_filter",control.mouse_filter)
		control.mouse_filter = control.get_meta("presentation_mouse_filter") if enabled else Control.MOUSE_FILTER_IGNORE
		if not enabled: control.release_focus()
		if control is BaseButton: control.disabled = not enabled
		if control is Slider: control.editable = enabled
	mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE

func _on_freq_changed(v: float) -> void:
	freq_val = v
	_update_ui()

func _on_phase_changed(v: float) -> void:
	phase_val = v
	_update_ui()

func _on_harmonic_changed(v: float) -> void:
	harmonic_val = v
	_update_ui()

func _update_ui() -> void:
	if freq_lbl: freq_lbl.text = "%.1f MHz" % freq_val
	if phase_lbl: phase_lbl.text = "%.0f°" % phase_val
	if harmonic_lbl: harmonic_lbl.text = "CH-%d" % int(harmonic_val)

	var freq_diff = abs(freq_val - freq_target) / 40.0
	var phase_diff = abs(phase_val - phase_target) / 90.0
	var harm_diff = abs(harmonic_val - harmonic_target) / 10.0

	var accuracy = clamp(1.0 - (freq_diff * 0.4 + phase_diff * 0.3 + harm_diff * 0.3), 0.0, 1.0)
	if progress_bar:
		progress_bar.value = accuracy * 100.0
	if status_lbl and not is_solved:
		status_lbl.text = "طابق أثر شاشة المحطة: 111 MHz · 45° · القناة 7" if presentation_language == "ar" else "Match the terminal trace: 111 MHz · 45° · channel 7"
	if status_lbl and is_solved:
		status_lbl.text = "استقرت الإشارة · الوصول متاح" if presentation_language == "ar" else "Signal aligned · access granted"

	# Formatting a hidden restored panel must not consume its completion event.
	# Publish the solve only after a real terminal interaction opens the panel.
	if visible and not is_solved and abs(freq_val - freq_target) <= 2.0 and abs(phase_val - phase_target) <= 5.0 and int(harmonic_val) == int(harmonic_target):
		_solve_puzzle()

func _solve_puzzle() -> void:
	is_solved = true
	if status_lbl:
		status_lbl.text = "استقرت الإشارة · الوصول متاح" if presentation_language == "ar" else "Signal aligned · access granted"
		status_lbl.modulate = Color(0.1, 1.0, 0.4, 1.0)
	if progress_bar:
		progress_bar.value = 100.0
	if proceed_btn:
		proceed_btn.visible = true

	var payload = {
		"signal_source": "INTERNAL_RELAY",
		"subject_code": "EX-011",
		"facility_sector": 11,
		"trace": "111.0_MHZ_PHASE_45_CHANNEL_7"
	}
	emit_signal("puzzle_completed", payload)

func _on_proceed_pressed() -> void:
	close_puzzle()

# Programmatic helper for testing
func auto_align_solution() -> void:
	freq_val = freq_target
	phase_val = phase_target
	harmonic_val = harmonic_target
	if freq_slider: freq_slider.value = freq_val
	if phase_slider: phase_slider.value = phase_val
	if harmonic_slider: harmonic_slider.value = harmonic_val
	_update_ui()

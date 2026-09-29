extends CanvasLayer

var main: Node
var overlay: Control
var panel: PanelContainer
var heading: Label
var status: Label
var resume_button: Button
var mute_button: Button
var motion_button: Button
var language_button: Button
var pause_button: Button
var session_paused := false
var _previous_mouse_mode := Input.MOUSE_MODE_VISIBLE
var _touch_was_visible := false
var _save_succeeded := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 90
	main = get_parent()
	pause_button = _button("", func(): set_session_paused(true))
	pause_button.name = "PauseButton"
	add_child(pause_button)
	pause_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	pause_button.offset_left = -176
	pause_button.offset_right = -24
	pause_button.offset_top = 24
	pause_button.offset_bottom = 96
	overlay = Control.new()
	add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.02, 0.03, 0.92)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel = PanelContainer.new()
	overlay.add_child(panel)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.042, 0.052)
	style.border_color = Color(0.45, 0.15, 0.19)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 32
	style.content_margin_right = 32
	style.content_margin_top = 24
	style.content_margin_bottom = 24
	panel.add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	panel.add_child(column)
	heading = Label.new()
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 36)
	column.add_child(heading)
	status = Label.new()
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_font_size_override("font_size", 24)
	column.add_child(status)
	resume_button = _button("", func(): set_session_paused(false))
	mute_button = _button("", func(): main.set_audio_muted(not main.audio_muted); refresh_labels())
	motion_button = _button("", func(): main.set_reduced_motion(not main.reduced_motion); refresh_labels())
	language_button = _button("", func(): main.set_presentation_language("en" if main.presentation_language == "ar" else "ar"))
	for button in [resume_button, mute_button, motion_button, language_button]:
		column.add_child(button)
	get_viewport().size_changed.connect(_layout)
	panel.minimum_size_changed.connect(func(): _layout.call_deferred())
	_layout()
	refresh_labels()
	overlay.hide()

func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 72)
	button.add_theme_font_size_override("font_size", 28)
	button.pressed.connect(action)
	return button

func _layout() -> void:
	var screen := get_viewport().get_visible_rect().size
	panel.size = Vector2(minf(620, screen.x - 48), 520)
	panel.position = (screen - panel.size) * 0.5

func refresh_labels() -> void:
	if not heading:
		return
	var arabic: bool = main.presentation_language == "ar"
	panel.layout_direction = Control.LAYOUT_DIRECTION_RTL if arabic else Control.LAYOUT_DIRECTION_LTR
	heading.text = "استراحة داخل النظام" if arabic else "A pause in the System"
	pause_button.text = "توقف" if arabic else "Pause"
	resume_button.text = "متابعة الرحلة" if arabic else "Continue"
	mute_button.text = ("الصوت: مكتوم" if main.audio_muted else "الصوت: يعمل") if arabic else ("Sound: muted" if main.audio_muted else "Sound: on")
	motion_button.text = ("حركة الكاميرا: أقل" if main.reduced_motion else "حركة الكاميرا: معتادة") if arabic else ("Camera motion: reduced" if main.reduced_motion else "Camera motion: standard")
	language_button.text = "لغة اللعب: العربية / English" if arabic else "Game language: English / العربية"
	status.text = ("توقف الوقت. حُفظ تقدم الغرفة." if _save_succeeded else "توقف الوقت. تعذر الحفظ. يمكنك متابعة اللعب.") if arabic else ("Time is paused. Room progress saved." if _save_succeeded else "Time is paused. Save failed. You can continue playing.")
	_layout.call_deferred()

func set_session_paused(paused: bool) -> void:
	if session_paused == paused:
		return
	if paused:
		_previous_mouse_mode = Input.mouse_mode
		var touch = main.hud.find_child("MobileTouchControls", true, false)
		_touch_was_visible = touch.visible if touch else false
		if touch:
			touch.reset_input()
			touch.set_interaction_blocked(true)
		main.player.mobile_input_vector = Vector2.ZERO
		main.player.mobile_sprint_active = false
		main.player.clear_traversal_input()
		for action in ["move_forward", "move_backward", "move_left", "move_right", "sprint", "jump", "interact", "attack_light"]:
			if InputMap.has_action(action):
				Input.action_release(action)
		_save_succeeded = main.save_native_checkpoint_now()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	session_paused = paused
	get_tree().paused = paused
	overlay.visible = paused
	pause_button.visible = not paused
	refresh_labels()
	if paused:
		resume_button.grab_focus()
	else:
		Input.action_release("attack_light")
		main.player._suppress_attack_until_release = true
		var touch = main.hud.find_child("MobileTouchControls", true, false)
		if touch:
			touch.set_interaction_blocked(not _touch_was_visible)
		Input.mouse_mode = _previous_mouse_mode

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed and not session_paused and pause_button.get_global_rect().has_point(event.position):
		set_session_paused(true)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		set_session_paused(not session_paused)
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		set_session_paused(not session_paused)

func _exit_tree() -> void:
	if session_paused and get_tree():
		get_tree().paused = false

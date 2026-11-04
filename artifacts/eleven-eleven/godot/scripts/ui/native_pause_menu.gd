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
var quality_button: Button
var pause_button: Button
var personal_system_button: Button
var session_paused := false
var _previous_mouse_mode := Input.MOUSE_MODE_VISIBLE
var _touch_was_visible := false
var _save_succeeded := false
var _control_sliders: Dictionary = {}
var _control_labels: Dictionary = {}
const Bindings = preload("res://scripts/ui/control_bindings.gd")
const FONT = preload("res://assets/fonts/NotoSansArabic.ttf")
const BACKGROUND = preload("res://assets/textures/ui/memory-aperture-v1.webp")
var _pages: Dictionary = {}
var _tabs: Dictionary = {}
var _binding_buttons: Dictionary = {}
var _binding_hint: Label
var _waiting_binding := ""
var _current_page := "journey"
var _menu_tween: Tween
var _volume_slider: HSlider
var _volume_label: Label
var _objective_title: Label
var _objective_copy: Label
var _reset_controls: Button

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
	personal_system_button=_button("",func():main.toggle_personal_system())
	personal_system_button.name="PersonalSystemButton"
	add_child(personal_system_button)
	personal_system_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	personal_system_button.offset_left=-352
	personal_system_button.offset_right=-200
	personal_system_button.offset_top=24
	personal_system_button.offset_bottom=96
	overlay = Control.new()
	add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var art := TextureRect.new()
	art.texture = BACKGROUND
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(art)
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(.008, .014, .025, .38)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel = PanelContainer.new()
	overlay.add_child(panel)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(.018, .028, .045, .90)
	style.border_color = Color(.38, .73, .85, .5)
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 22
	style.content_margin_bottom = 22
	panel.add_theme_stylebox_override("panel", style)
	var shell := VBoxContainer.new()
	shell.add_theme_constant_override("separation", 12)
	panel.add_child(shell)
	var identity := Label.new()
	identity.text = "11.11  /  ECHO NETWORK"
	identity.add_theme_color_override("font_color", Color("7edfff"))
	identity.add_theme_font_size_override("font_size", 18)
	shell.add_child(identity)
	heading = Label.new()
	heading.add_theme_font_override("font", FONT)
	heading.add_theme_font_size_override("font_size", 32)
	shell.add_child(heading)
	var divider := HSeparator.new()
	shell.add_child(divider)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 24)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shell.add_child(body)
	var navigation := VBoxContainer.new()
	navigation.custom_minimum_size.x = 200
	navigation.add_theme_constant_override("separation", 10)
	body.add_child(navigation)
	var scroll := ScrollContainer.new()
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	for key in ["journey", "controls", "display", "audio"]:
		var tab := _button("", _show_page.bind(key))
		navigation.add_child(tab)
		_tabs[key] = tab
		var page := VBoxContainer.new()
		page.add_theme_constant_override("separation", 14)
		page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content.add_child(page)
		_pages[key] = page
	status = Label.new()
	status.add_theme_font_override("font", FONT)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_font_size_override("font_size", 22)
	_pages.journey.add_child(status)
	_objective_title = Label.new()
	_objective_title.add_theme_font_override("font", FONT)
	_objective_title.add_theme_font_size_override("font_size", 28)
	_objective_title.add_theme_color_override("font_color", Color("8ce7ff"))
	_objective_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_pages.journey.add_child(_objective_title)
	_objective_copy = Label.new()
	_objective_copy.add_theme_font_override("font", FONT)
	_objective_copy.add_theme_font_size_override("font_size", 22)
	_objective_copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_pages.journey.add_child(_objective_copy)
	resume_button = _button("", func(): set_session_paused(false))
	_pages.journey.add_child(resume_button)
	mute_button = _button("", func(): main.set_audio_muted(not main.audio_muted); refresh_labels())
	motion_button = _button("", func(): main.set_reduced_motion(not main.reduced_motion); refresh_labels())
	language_button = _button("", func(): main.set_presentation_language("en" if main.presentation_language == "ar" else "ar"))
	quality_button = _button("", func():
		var tiers := ["low", "medium", "high", "ultra"]
		main.set_visual_quality(tiers[(tiers.find(main.visual_quality) + 1) % tiers.size()])
	)
	for button in [quality_button, motion_button, language_button]: _pages.display.add_child(button)
	_pages.audio.add_child(mute_button)
	_volume_label = Label.new()
	_volume_label.add_theme_font_override("font", FONT)
	_volume_label.add_theme_font_size_override("font_size", 22)
	_pages.audio.add_child(_volume_label)
	_volume_slider = HSlider.new()
	_volume_slider.min_value = 0
	_volume_slider.max_value = 1
	_volume_slider.step = .05
	_volume_slider.custom_minimum_size.y = 48
	_pages.audio.add_child(_volume_slider)
	_volume_slider.value_changed.connect(func(value: float):
		main.set_master_volume(value)
		refresh_labels()
	)
	_binding_hint = Label.new()
	_binding_hint.add_theme_font_override("font", FONT)
	_binding_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_binding_hint.add_theme_font_size_override("font_size", 20)
	_pages.controls.add_child(_binding_hint)
	_reset_controls = _button("", func():
		Bindings.apply({})
		var settings: Dictionary = main.get_control_preferences()
		main.set_control_preferences(settings)
		_waiting_binding = ""
		refresh_labels()
	)
	_pages.controls.add_child(_reset_controls)
	for action in Bindings.ACTIONS:
		var binding := _button("", _begin_binding.bind(action))
		_pages.controls.add_child(binding)
		_binding_buttons[action] = binding
	for key in ["mouse_sensitivity", "touch_sensitivity", "scale", "opacity", "inset_x", "inset_y", "joystick_x", "joystick_y", "deadzone"]:
		var row := VBoxContainer.new()
		_pages.controls.add_child(row)
		var label := Label.new()
		label.add_theme_font_override("font", FONT)
		label.add_theme_font_size_override("font_size", 20)
		row.add_child(label)
		_control_labels[key] = label
		var slider := HSlider.new()
		slider.custom_minimum_size = Vector2(0, 48)
		var position_setting: bool = key.begins_with("inset") or key.begins_with("joystick")
		slider.min_value = 0.85 if key == "scale" else (0.25 if key == "opacity" else (0.05 if key == "deadzone" else (0.0 if position_setting else 0.5)))
		slider.max_value = 1.3 if key == "scale" else (1.0 if key == "opacity" else (0.30 if key == "deadzone" else (100.0 if position_setting else 2.0)))
		slider.step = 1 if position_setting else (0.01 if key == "deadzone" else 0.05)
		row.add_child(slider)
		_control_sliders[key] = slider
		slider.value_changed.connect(func(value: float):
			var settings: Dictionary = main.get_control_preferences()
			settings[key] = value
			main.set_control_preferences(settings)
			refresh_labels()
		)
	get_viewport().size_changed.connect(_layout)
	panel.minimum_size_changed.connect(func(): _layout.call_deferred())
	_layout()
	refresh_labels()
	_show_page("journey")
	overlay.hide()

func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 56)
	button.add_theme_font_size_override("font_size", 22)
	button.add_theme_font_override("font", FONT)
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(.08, .16, .22, .95) if state in ["hover", "focus"] else Color(.025, .055, .085, .8)
		style.border_color = Color(.4, .82, .95, .85) if state != "normal" else Color(.3, .47, .55, .4)
		style.set_border_width_all(1)
		style.set_corner_radius_all(5)
		style.content_margin_left = 16
		style.content_margin_right = 16
		button.add_theme_stylebox_override(state, style)
	button.pressed.connect(action)
	return button

func _layout() -> void:
	var screen := get_viewport().get_visible_rect().size
	panel.size = Vector2(minf(1180, screen.x - 48), minf(780, screen.y - 48))
	panel.position = (screen - panel.size) * 0.5

func refresh_labels() -> void:
	if not heading:
		return
	var arabic: bool = main.presentation_language == "ar"
	panel.layout_direction = Control.LAYOUT_DIRECTION_RTL if arabic else Control.LAYOUT_DIRECTION_LTR
	heading.text = "استراحة داخل النظام" if arabic else "A pause in the System"
	pause_button.text = "توقف" if arabic else "Pause"
	personal_system_button.text="الحالة [I]" if arabic else "Status [I]"
	resume_button.text = "متابعة الرحلة" if arabic else "Continue"
	mute_button.text = ("الصوت: مكتوم" if main.audio_muted else "الصوت: يعمل") if arabic else ("Sound: muted" if main.audio_muted else "Sound: on")
	motion_button.text = ("حركة الكاميرا: أقل" if main.reduced_motion else "حركة الكاميرا: معتادة") if arabic else ("Camera motion: reduced" if main.reduced_motion else "Camera motion: standard")
	language_button.text = "لغة اللعب: العربية / English" if arabic else "Game language: English / العربية"
	var qualities := {"low":["منخفضة","Low"],"medium":["متوسطة","Medium"],"high":["عالية","High"],"ultra":["فائقة","Ultra"]}
	quality_button.text=("الجودة: " if arabic else "Quality: ")+qualities[main.visual_quality][0 if arabic else 1]+(" (تغيير)" if arabic else " (change)")
	status.text = ("توقف الوقت. حُفظ تقدم الغرفة." if _save_succeeded else "توقف الوقت. تعذر الحفظ. يمكنك متابعة اللعب.") if arabic else ("Time is paused. Room progress saved." if _save_succeeded else "Time is paused. Save failed. You can continue playing.")
	var settings: Dictionary = main.get_control_preferences()
	var captions := {"scale": ["حجم الأزرار", "Button size"], "opacity": ["وضوح الأزرار", "Button opacity"], "inset_x": ["موضع الأزرار الأفقي", "Horizontal inset"], "inset_y": ["موضع الأزرار الرأسي", "Vertical inset"], "mouse_sensitivity": ["حساسية الفأرة", "Mouse sensitivity"], "touch_sensitivity": ["حساسية كاميرا اللمس", "Touch camera sensitivity"]}
	captions.merge({"deadzone": ["نطاق سكون العصا", "Joystick deadzone"], "joystick_x": ["موضع العصا الأفقي", "Joystick horizontal inset"], "joystick_y": ["موضع العصا الرأسي", "Joystick vertical inset"]})
	for key in _control_sliders:
		_control_sliders[key].set_value_no_signal(settings.get(key, 1.0))
		_control_labels[key].text = "%s: %.2f" % [captions[key][0 if arabic else 1], settings.get(key, 1.0)]
	_refresh_control_map(arabic)
	_objective_title.text = main.hud.current_directive_title
	_objective_copy.text = main.hud.current_directive_desc
	_reset_controls.text = "استعادة مفاتيح التحكم الأصلية" if arabic else "Restore default keys"
	_volume_slider.set_value_no_signal(main.master_volume)
	_volume_label.text = ("المستوى العام: " if arabic else "Master volume: ") + str(roundi(main.master_volume * 100)) + "%"
	var names := {"journey": ["الرحلة", "Journey"], "controls": ["التحكم", "Controls"], "display": ["العرض والوصول", "Display & accessibility"], "audio": ["الصوت", "Audio"]}
	for key in _tabs: _tabs[key].text = names[key][0 if arabic else 1]
	_layout.call_deferred()

func _show_page(key: String) -> void:
	_current_page = key
	_waiting_binding = ""
	for id in _pages:
		_pages[id].visible = id == key
		_tabs[id].modulate = Color("8ce7ff") if id == key else Color.WHITE
	if is_instance_valid(_binding_hint): _refresh_control_map(main.presentation_language == "ar")

func _begin_binding(action: String) -> void:
	_waiting_binding = action
	_binding_hint.text = "اضغط المفتاح الجديد · Esc للإلغاء" if main.presentation_language == "ar" else "Press a new key · Esc cancels"

func _refresh_control_map(ar: bool) -> void:
	var names := {"move_forward": ["تقدم", "Forward"], "move_backward": ["تراجع", "Back"], "move_left": ["يسار", "Left"], "move_right": ["يمين", "Right"], "jump": ["قفز / صعود الحافة", "Jump / mantle"], "sprint": ["اندفاع", "Sprint"], "dodge": ["تدحرج / إفلات التسلق", "Roll / drop"], "interact": ["تفاعل", "Interact"], "attack_light": ["هجوم مكتسب", "Earned attack"], "companion_scan": ["مساعدة بيئية", "Environment help"]}
	for action in _binding_buttons:
		_binding_buttons[action].text = names[action][0 if ar else 1] + "  ·  " + Bindings.caption(action)
	if _waiting_binding.is_empty():
		_binding_hint.text = "اختر حركة لتغيير مفتاحها. للتسلق: اقفز نحو سطح معلّم واستمر للأمام؛ عند الحافة استمر للصعود. Esc: استراحة · I: الحالة · F8: حركة أقل." if ar else "Select an action to rebind. Climb: jump toward a marked wall and hold forward; keep holding at the ledge to mantle. Esc: pause · I: status · F8: reduced motion."

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
		for action in Bindings.ACTIONS:
			if InputMap.has_action(action):
				Input.action_release(action)
		_save_succeeded = main.save_native_checkpoint_now()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _menu_tween and _menu_tween.is_running(): _menu_tween.kill()
	_waiting_binding = ""
	session_paused = paused
	get_tree().paused = paused
	overlay.visible = paused
	pause_button.visible = not paused
	personal_system_button.visible=not paused
	refresh_labels()
	if paused:
		_show_page("journey")
		overlay.modulate.a = 1.0
		if not main.reduced_motion:
			overlay.modulate.a = .15
			_menu_tween = create_tween()
			_menu_tween.tween_property(overlay, "modulate:a", 1.0, .18)
		resume_button.grab_focus()
	else:
		Input.action_release("attack_light")
		main.player._suppress_attack_until_release = true
		var touch = main.hud.find_child("MobileTouchControls", true, false)
		if touch:
			touch.set_interaction_blocked(not _touch_was_visible)
		Input.mouse_mode = _previous_mouse_mode

func _input(event: InputEvent) -> void:
	if session_paused and not _waiting_binding.is_empty() and event is InputEventKey:
		get_viewport().set_input_as_handled()
		if not event.pressed or event.echo: return
		if event.keycode == KEY_ESCAPE:
			_waiting_binding = ""
			_refresh_control_map(main.presentation_language == "ar")
			return
		var key: int = event.physical_keycode if event.physical_keycode else event.keycode
		var bindings := Bindings.current()
		bindings[_waiting_binding] = key
		if not Bindings.apply(bindings):
			_binding_hint.text = "المفتاح مستخدم أو محجوز. اختر مفتاحًا آخر أو Esc للإلغاء." if main.presentation_language == "ar" else "Key is used or reserved. Choose another key or Esc to cancel."
			return
		var settings: Dictionary = main.get_control_preferences()
		settings.bindings = bindings
		main.set_control_preferences(settings)
		_waiting_binding = ""
		refresh_labels()
		return
	if event is InputEventScreenTouch and event.pressed and not session_paused and pause_button.get_global_rect().has_point(event.position):
		set_session_paused(true)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if not session_paused and main.opening_inspection and main.opening_inspection.is_active:
			main.opening_inspection.cancel()
			get_viewport().set_input_as_handled()
			return
		set_session_paused(not session_paused)
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if not session_paused and main.opening_inspection and main.opening_inspection.is_active:
			main.opening_inspection.cancel()
			return
		set_session_paused(not session_paused)

func _exit_tree() -> void:
	if session_paused and get_tree():
		get_tree().paused = false

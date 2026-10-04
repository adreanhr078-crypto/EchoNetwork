class_name MobileTouchControls
extends Control

## Touch input and localized action controls. Device acceptance is measured separately.

signal joystick_moved(vector: Vector2)
signal attack_tapped()
signal iai_charge_started()
signal iai_charge_released(ratio: float)
signal dodge_tapped()
signal sprint_changed(is_sprinting: bool)
signal jump_tapped()
signal lock_on_tapped()
signal scan_tapped()
signal camera_swiped(relative: Vector2)
signal use_tapped()
signal mute_tapped()
signal motion_tapped()
signal input_reset()

const JOYSTICK_MAX_RADIUS: float = 75.0
const IAI_CHARGE_THRESHOLD: float = 0.35
const IAI_FULL_CHARGE_TIME: float = 1.0

@onready var joystick_base: Control = $JoystickZone/JoystickBase if has_node("JoystickZone/JoystickBase") else null
@onready var joystick_stick: Control = $JoystickZone/JoystickBase/Stick if has_node("JoystickZone/JoystickBase/Stick") else null
@onready var attack_btn: Button = $ActionCluster/AttackBtn if has_node("ActionCluster/AttackBtn") else null
@onready var charge_bar: ProgressBar = $ActionCluster/AttackBtn/ChargeBar if has_node("ActionCluster/AttackBtn/ChargeBar") else null
@onready var lock_on_btn: Button = $ActionCluster/LockOnBtn if has_node("ActionCluster/LockOnBtn") else null
@onready var dodge_btn: Button = $ActionCluster/DodgeBtn if has_node("ActionCluster/DodgeBtn") else null
@onready var use_btn: Button = $ActionCluster/UseBtn if has_node("ActionCluster/UseBtn") else null
@onready var sprint_btn: Button = $ActionCluster/SprintBtn if has_node("ActionCluster/SprintBtn") else null

var is_joystick_active: bool = false
var joystick_touch_index: int = -1
var joystick_center: Vector2 = Vector2(160, 920)
var current_joystick_vector: Vector2 = Vector2.ZERO
var _raw_joystick_vector := Vector2.ZERO
var joystick_deadzone := 0.15
var joystick_inset := Vector2.ZERO
var _ui_touches: Dictionary = {}

var camera_touch_index: int = -1
var last_camera_pos: Vector2 = Vector2.ZERO

var is_attack_held: bool = false
var attack_hold_timer: float = 0.0
var _platform_touch_enabled: bool = false
var _action_touches: Dictionary = {}
var _combat_available := false
var _traversal_active := false
var _language := "ar"
var _interaction_available := false
var control_scale := 1.0
var control_opacity := 0.8
var control_inset := Vector2.ZERO
var reduced_feedback := false
var _muted := false
var _pulse_time := 0.0
var _pulse_center := Vector2.ZERO
var _pulse_radius := 0.0
const GLYPHS := {
	"JumpBtn": "jump", "DodgeBtn": "roll", "UseBtn": "interact",
	"ScanBtn": "scan", "AttackBtn": "attack", "LockOnBtn": "target"
}

func apply_control_preferences(settings: Dictionary) -> void:
	control_scale = _finite_setting(settings, "scale", 1.0, 0.85, 1.3)
	control_opacity = _finite_setting(settings, "opacity", 0.8, 0.25, 1.0)
	control_inset = Vector2(_finite_setting(settings, "inset_x", 0, 0, 100), _finite_setting(settings, "inset_y", 0, 0, 100))
	joystick_deadzone = _finite_setting(settings, "deadzone", 0.15, 0.05, 0.30)
	joystick_inset = Vector2(_finite_setting(settings, "joystick_x", 0, 0, 100), _finite_setting(settings, "joystick_y", 0, 0, 100))
	reset_input()
	_layout_controls()

func control_preferences() -> Dictionary:
	return {"scale": control_scale, "opacity": control_opacity, "inset_x": control_inset.x, "inset_y": control_inset.y, "deadzone": joystick_deadzone, "joystick_x": joystick_inset.x, "joystick_y": joystick_inset.y}

func joystick_radius() -> float:
	return JOYSTICK_MAX_RADIUS * control_scale

func _safe_rect() -> Rect2:
	var screen := get_viewport_rect().size
	if OS.get_name() not in ["Android", "iOS"]: return Rect2(Vector2.ZERO, screen)
	var safe := DisplayServer.get_display_safe_area()
	var window := Vector2(DisplayServer.window_get_size())
	if safe.size.x <= 0 or safe.size.y <= 0 or window.x <= 0 or window.y <= 0: return Rect2(Vector2.ZERO, screen)
	return Rect2(Vector2(safe.position) * screen / window, Vector2(safe.size) * screen / window).intersection(Rect2(Vector2.ZERO, screen))

func _finite_setting(settings: Dictionary, key: String, fallback: float, low: float, high: float) -> float:
	var value: Variant = settings.get(key, fallback)
	if not (value is float or value is int) or not is_finite(float(value)): return fallback
	return clampf(float(value), low, high)

func set_interaction_available(available: bool) -> void:
	_interaction_available = available
	if use_btn: use_btn.visible = available

func _style_controls() -> void:
	for button in find_children("*", "Button", true, false):
		var normal := StyleBoxFlat.new()
		normal.bg_color = Color(0.02, 0.03, 0.04, 0.07)
		normal.border_color = Color(0.94, 0.92, 0.85, 0.28)
		normal.set_border_width_all(1)
		normal.set_corner_radius_all(48)
		button.add_theme_stylebox_override("normal", normal)
		var pressed := normal.duplicate() as StyleBoxFlat
		pressed.bg_color = Color(0.06, 0.22, 0.26, 0.3)
		pressed.border_color = Color(0.55, 0.94, 1.0, 0.8)
		button.add_theme_stylebox_override("pressed", pressed)
		button.add_theme_stylebox_override("hover", pressed)
		button.add_theme_font_size_override("font_size", 17)
		button.add_theme_color_override("font_color", Color(0.96, 0.94, 0.86))
		if button.name in GLYPHS:
			var icon := TextureRect.new()
			icon.name = "ActionGlyph"
			icon.texture = load("res://assets/ui/player-controls/%s-v1.svg" % GLYPHS[button.name])
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			button.add_child(icon)
			# A code-native caption remains accessible/localized, independent of art.
			var caption := Label.new()
			caption.name = "ActionCaption"
			caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
			caption.add_theme_font_size_override("font_size", 16)
			button.add_child(caption)
	if joystick_base is ColorRect: joystick_base.color.a = 0
	if joystick_stick is ColorRect: joystick_stick.color.a = 0

func _layout_controls() -> void:
	if not is_node_ready(): return
	var screen := get_viewport_rect().size
	var unit := clampf(screen.y / 8.0, 96, 144) * control_scale
	if OS.get_name() == "Android":
		var dpi := maxf(160, DisplayServer.screen_get_dpi())
		var physical_height := maxf(1, DisplayServer.window_get_size().y)
		unit = maxf(unit, 48 * dpi / 160.0 * screen.y / physical_height)
	# The canvas remains 1080 logical pixels on phones; keep a 48px floor
	# at smaller diagnostic resolutions and reserve the center for camera drag.
	unit = minf(unit, (screen.y - 100) / 4.0)
	var safe := _safe_rect()
	var origin := safe.end - Vector2(32 + control_inset.x, 36 + control_inset.y)
	var slots := {"DodgeBtn": Vector2(-1, -1), "JumpBtn": Vector2(-1, -2.25), "UseBtn": Vector2(-2.3, -1.65), "ScanBtn": Vector2(-2.3, -0.4), "AttackBtn": Vector2(-1, -3.5), "LockOnBtn": Vector2(-2.3, -2.9)}
	var cluster := $ActionCluster as Control
	cluster.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for name in slots:
		var button := cluster.get_node(name) as Button
		button.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		button.position = origin + slots[name] * unit - Vector2(unit, unit) * 0.5
		button.size = Vector2(unit, unit)
		button.self_modulate.a = control_opacity
		var glyph := button.get_node_or_null("ActionGlyph") as TextureRect
		var caption := button.get_node_or_null("ActionCaption") as Label
		if glyph:
			glyph.position = Vector2(unit * 0.24, unit * 0.1)
			glyph.size = Vector2(unit * 0.52, unit * 0.52)
		if caption:
			caption.position = Vector2(0, unit * 0.66)
			caption.size = Vector2(unit, unit * 0.25)
	joystick_center = Vector2(safe.position.x + 150 + joystick_inset.x, safe.end.y - 150 - joystick_inset.y)
	joystick_center.x = clampf(joystick_center.x, safe.position.x + joystick_radius() * 1.5, screen.x * 0.5 - joystick_radius() * 1.5)
	joystick_center.y = clampf(joystick_center.y, safe.position.y + joystick_radius() * 1.5, safe.end.y - joystick_radius() * 1.5)
	if joystick_base:
		joystick_base.global_position = joystick_center - joystick_base.size * 0.5
	queue_redraw()

func _draw() -> void:
	if joystick_base:
		var center := joystick_base.get_global_rect().get_center() - global_position
		draw_circle(center, joystick_radius(), Color(0.025, 0.035, 0.045, 0.12 * control_opacity))
		draw_arc(center, joystick_radius(), 0, TAU, 64, Color(0.92, 0.92, 0.87, 0.38 * control_opacity), 1.5, true)
		var knob := center + _raw_joystick_vector * joystick_radius()
		draw_circle(knob, 25, Color(0.9, 0.96, 1.0, 0.2 * control_opacity))
		draw_arc(knob, 25, 0, TAU, 40, Color(0.8, 0.95, 1.0, 0.65 * control_opacity), 2, true)
	if _pulse_time > 0 and not reduced_feedback:
		var phase := 1.0 - _pulse_time / 0.22
		draw_arc(_pulse_center, _pulse_radius + 12 * phase, 0, TAU, 48, Color(0.52, 0.94, 1, (1.0 - phase) * 0.45), 2, true)

func refresh_labels(language: String, muted: bool, reduced: bool) -> void:
	_language = language
	_muted = muted
	var arabic := language == "ar"
	var labels := {
		"UseBtn": "تفاعل" if arabic else "USE",
		"SprintBtn": ("أفلت" if _traversal_active else "اندفع") if arabic else ("DROP" if _traversal_active else "DASH"),
		"JumpBtn": "اقفز" if arabic else "JUMP",
		"ScanBtn": "افحص" if arabic else "SCAN",
		"DodgeBtn": ("أفلت" if _traversal_active else "تدحرج") if arabic else ("DROP" if _traversal_active else "ROLL"),
		"AttackBtn": "هجوم" if arabic else "ATK",
		"LockOnBtn": "هدف" if arabic else "LOCK",
		"MuteBtn": ("مكتوم" if muted else "صوت") if arabic else ("MUTED" if muted else "SOUND"),
		"MotionBtn": ("أقل" if reduced else "حركة") if arabic else ("REDUCED" if reduced else "MOTION")
	}
	for node_name in labels:
		var button = find_child(node_name,true,false) as Button
		if button:
			button.tooltip_text = labels[node_name]
			var caption := button.get_node_or_null("ActionCaption") as Label
			if caption:
				caption.text = labels[node_name]
				button.text = ""
			else: button.text = labels[node_name]
	reduced_feedback = reduced

func _ready() -> void:
	var platform_name: String = OS.get_name()
	_platform_touch_enabled = platform_name == "Android" or platform_name == "iOS" or (platform_name == "Web" and DisplayServer.is_touchscreen_available())
	visible = _platform_touch_enabled
	_style_controls()
	get_viewport().size_changed.connect(_on_viewport_resized)
	_layout_controls()
	if _platform_touch_enabled:
		for button in find_children("*", "Button", true, false):
			button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_combat_available(false)
	if charge_bar:
		charge_bar.visible = false
	if use_btn:
		use_btn.visible = _interaction_available

func _on_viewport_resized() -> void:
	# Finger positions belong to the previous canvas; require a fresh press.
	reset_input()
	_layout_controls()

func set_interaction_blocked(blocked: bool) -> void:
	visible = _platform_touch_enabled and not blocked

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or (what == NOTIFICATION_VISIBILITY_CHANGED and is_inside_tree() and not is_visible_in_tree()):
		reset_input()

func reset_input() -> void:
	is_joystick_active = false
	joystick_touch_index = -1
	camera_touch_index = -1
	current_joystick_vector = Vector2.ZERO
	_raw_joystick_vector = Vector2.ZERO
	_ui_touches.clear()
	is_attack_held = false
	attack_hold_timer = 0.0
	for button in _action_touches.values():
		if is_instance_valid(button):
			button.modulate = Color.WHITE
	_action_touches.clear()
	_pulse_time = 0
	if charge_bar:
		charge_bar.visible = false
		charge_bar.value = 0.0
	if joystick_stick:
		joystick_stick.position = Vector2.ZERO
	emit_signal("joystick_moved", Vector2.ZERO)
	emit_signal("sprint_changed", false)
	input_reset.emit()
	queue_redraw()

func set_combat_available(available: bool) -> void:
	_combat_available = available
	if attack_btn:
		attack_btn.visible = available
	if lock_on_btn:
		lock_on_btn.visible = available
	if dodge_btn:
		dodge_btn.visible = true
	if sprint_btn: sprint_btn.visible = false
	if use_btn:
		use_btn.visible = _interaction_available

func set_traversal_active(active: bool) -> void:
	_traversal_active = active
	if dodge_btn:
		dodge_btn.visible = true
		var glyph := dodge_btn.get_node_or_null("ActionGlyph") as TextureRect
		if glyph: glyph.texture = load("res://assets/ui/player-controls/%s-v1.svg" % ("drop" if active else "roll"))
	refresh_labels(_language, _muted, reduced_feedback)

func _process(delta: float) -> void:
	if _pulse_time > 0:
		_pulse_time = maxf(0, _pulse_time - delta)
		queue_redraw()
	# Handle Attack Button Charging (Charged Iai Slash)
	if is_attack_held:
		attack_hold_timer += delta
		if attack_hold_timer >= IAI_CHARGE_THRESHOLD:
			if charge_bar:
				charge_bar.visible = true
				var charge_ratio = clamp((attack_hold_timer - IAI_CHARGE_THRESHOLD) / (IAI_FULL_CHARGE_TIME - IAI_CHARGE_THRESHOLD), 0.0, 1.0)
				charge_bar.value = charge_ratio * 100.0
			emit_signal("iai_charge_started")

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		_handle_screen_touch(event)
	elif event is InputEventScreenDrag:
		_handle_screen_drag(event)

func _handle_screen_touch(event: InputEventScreenTouch) -> void:
	if event.canceled:
		reset_input()
		return
	var screen_width: float = get_viewport_rect().size.x
	var is_left_half: bool = event.position.x < screen_width * 0.5

	if event.pressed:
		# Each action owns its finger; standard mouse emulation only covers one.
		var action := _action_at(event.position)
		if action:
			if action.disabled:
				_ui_touches[event.index] = true
				return
			if _action_touches.values().has(action):
				return
			_action_touches[event.index] = action
			action.modulate = Color(0.6, 0.95, 1.0)
			_pulse_center = action.get_global_rect().get_center() - global_position
			_pulse_radius = action.size.x * 0.5
			_pulse_time = 0.22
			queue_redraw()
			action.button_down.emit()
			if action.action_mode == BaseButton.ACTION_MODE_BUTTON_PRESS:
				action.pressed.emit()
			return
		if _over_external_ui(event.position):
			_ui_touches[event.index] = true
			return
		# 1. Left Half Touch -> Activate Joystick
		if is_left_half and not is_joystick_active and event.position.distance_to(joystick_center) <= joystick_radius() * 1.5:
			is_joystick_active = true
			joystick_touch_index = event.index
			_update_joystick(event.position)
		# 2. Right Half Touch -> Camera Look Drag (if not on buttons)
		elif not is_left_half and camera_touch_index == -1 and not _is_point_on_actions(event.position):
			camera_touch_index = event.index
			last_camera_pos = event.position
	else:
		if _ui_touches.has(event.index):
			_ui_touches.erase(event.index)
			return
		if _action_touches.has(event.index):
			var action: Button = _action_touches[event.index]
			_action_touches.erase(event.index)
			action.modulate = Color.WHITE
			action.button_up.emit()
			if action.action_mode == BaseButton.ACTION_MODE_BUTTON_RELEASE and not action.disabled and action.is_visible_in_tree() and action.get_global_rect().has_point(event.position) and not event.canceled:
				action.pressed.emit()
			return
		# Touch Released
		if event.index == joystick_touch_index:
			is_joystick_active = false
			joystick_touch_index = -1
			current_joystick_vector = Vector2.ZERO
			_raw_joystick_vector = Vector2.ZERO
			if joystick_stick:
				joystick_stick.position = Vector2.ZERO
			emit_signal("joystick_moved", Vector2.ZERO)
		elif event.index == camera_touch_index:
			camera_touch_index = -1

func _handle_screen_drag(event: InputEventScreenDrag) -> void:
	if event.index == joystick_touch_index and is_joystick_active:
		_update_joystick(event.position)
	elif event.index == camera_touch_index:
		var relative_delta = event.position - last_camera_pos
		last_camera_pos = event.position
		emit_signal("camera_swiped", relative_delta)
	queue_redraw()

func _update_joystick(touch_pos: Vector2) -> void:
	var diff := (touch_pos - joystick_center).limit_length(joystick_radius())
	_raw_joystick_vector = diff / joystick_radius()

	if joystick_stick:
		joystick_stick.position = diff

	var magnitude := _raw_joystick_vector.length()
	current_joystick_vector = _raw_joystick_vector.normalized() * ((magnitude - joystick_deadzone) / (1.0 - joystick_deadzone)) if magnitude > joystick_deadzone else Vector2.ZERO
	emit_signal("joystick_moved", current_joystick_vector)
	queue_redraw()

func _is_point_on_actions(pos: Vector2) -> bool:
	return _action_at(pos) != null

func _action_at(pos: Vector2) -> Button:
	for button in find_children("*", "Button", true, false):
		if button.is_visible_in_tree() and button.get_global_rect().has_point(pos):
			return button
	return null

func _over_external_ui(pos: Vector2) -> bool:
	for node in get_tree().root.find_children("*", "Control", true, false):
		var control := node as Control
		if control == self or is_ancestor_of(control) or not control.is_visible_in_tree(): continue
		var interactive := control is BaseButton or control is Range or control is LineEdit or control is TextEdit or control is ItemList or control is Tree or control is ScrollContainer
		interactive = interactive or (control.mouse_filter != Control.MOUSE_FILTER_IGNORE and not control.get_signal_connection_list("gui_input").is_empty())
		if interactive and control.get_global_rect().has_point(pos): return true
	return false

# UI Button Connectors
func _on_attack_btn_down() -> void:
	is_attack_held = true
	attack_hold_timer = 0.0

func _on_attack_btn_up() -> void:
	if is_attack_held:
		is_attack_held = false
		if attack_hold_timer >= IAI_CHARGE_THRESHOLD:
			var charge_ratio = clamp((attack_hold_timer - IAI_CHARGE_THRESHOLD) / (IAI_FULL_CHARGE_TIME - IAI_CHARGE_THRESHOLD), 0.0, 1.0)
			emit_signal("iai_charge_released", charge_ratio)
		else:
			emit_signal("attack_tapped")
		if charge_bar:
			charge_bar.visible = false
			charge_bar.value = 0.0

func _on_dodge_btn_down() -> void:
	emit_signal("dodge_tapped")

func _on_sprint_btn_down() -> void:
	emit_signal("sprint_changed", true)

func _on_sprint_btn_up() -> void:
	emit_signal("sprint_changed", false)

func _on_jump_btn_pressed() -> void:
	emit_signal("jump_tapped")

func _on_lock_on_btn_pressed() -> void:
	emit_signal("lock_on_tapped")

func _on_scan_btn_pressed() -> void:
	emit_signal("scan_tapped")

func _on_use_btn_pressed() -> void:
	emit_signal("use_tapped")

func _on_mute_btn_pressed() -> void:
	emit_signal("mute_tapped")

func _on_motion_btn_pressed() -> void:
	emit_signal("motion_tapped")

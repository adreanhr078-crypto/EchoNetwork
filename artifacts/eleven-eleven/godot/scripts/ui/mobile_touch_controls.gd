class_name MobileTouchControls
extends Control

## AAA Mobile Touch HUD for Godot 4.7
## Features dynamic virtual joystick, gesture camera look, and Genshin-style action cluster.

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

var is_joystick_active: bool = false
var joystick_touch_index: int = -1
var joystick_center: Vector2 = Vector2(160, 920)
var current_joystick_vector: Vector2 = Vector2.ZERO

var camera_touch_index: int = -1
var last_camera_pos: Vector2 = Vector2.ZERO

var is_attack_held: bool = false
var attack_hold_timer: float = 0.0

func _ready() -> void:
	var platform_name: String = OS.get_name()
	visible = platform_name == "Android" or platform_name == "iOS" or (platform_name == "Web" and DisplayServer.is_touchscreen_available())
	set_combat_available(false)
	if charge_bar:
		charge_bar.visible = false
	if use_btn:
		use_btn.visible = true

func set_combat_available(available: bool) -> void:
	if attack_btn:
		attack_btn.visible = available
	if lock_on_btn:
		lock_on_btn.visible = available
	if dodge_btn:
		dodge_btn.visible = available
	if use_btn:
		use_btn.visible = not available

func _process(delta: float) -> void:
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
	if event is InputEventScreenTouch:
		_handle_screen_touch(event)
	elif event is InputEventScreenDrag:
		_handle_screen_drag(event)

func _handle_screen_touch(event: InputEventScreenTouch) -> void:
	var screen_width: float = get_viewport_rect().size.x
	var is_left_half: bool = event.position.x < screen_width * 0.5

	if event.pressed:
		# 1. Left Half Touch -> Activate Joystick
		if is_left_half and not is_joystick_active:
			is_joystick_active = true
			joystick_touch_index = event.index
			joystick_center = event.position
			if joystick_base:
				joystick_base.global_position = joystick_center - joystick_base.size * 0.5
				joystick_base.visible = true
			_update_joystick(event.position)
		# 2. Right Half Touch -> Camera Look Drag (if not on buttons)
		elif not is_left_half and camera_touch_index == -1 and not _is_point_on_actions(event.position):
			camera_touch_index = event.index
			last_camera_pos = event.position
	else:
		# Touch Released
		if event.index == joystick_touch_index:
			is_joystick_active = false
			joystick_touch_index = -1
			current_joystick_vector = Vector2.ZERO
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

func _update_joystick(touch_pos: Vector2) -> void:
	var diff: Vector2 = touch_pos - joystick_center
	var dist: float = diff.length()
	if dist > JOYSTICK_MAX_RADIUS:
		diff = diff.normalized() * JOYSTICK_MAX_RADIUS

	if joystick_stick:
		joystick_stick.position = diff

	current_joystick_vector = (diff / JOYSTICK_MAX_RADIUS)
	emit_signal("joystick_moved", current_joystick_vector)

func _is_point_on_actions(pos: Vector2) -> bool:
	var actions: Control = get_node_or_null("ActionCluster")
	if actions:
		for button in actions.get_children():
			if button is Button and button.visible and button.get_global_rect().has_point(pos):
				return true
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
	emit_signal("sprint_changed", true)

func _on_dodge_btn_up() -> void:
	emit_signal("sprint_changed", false)

func _on_jump_btn_pressed() -> void:
	emit_signal("jump_tapped")

func _on_lock_on_btn_pressed() -> void:
	emit_signal("lock_on_tapped")

func _on_scan_btn_pressed() -> void:
	emit_signal("scan_tapped")

func _on_use_btn_pressed() -> void:
	emit_signal("use_tapped")

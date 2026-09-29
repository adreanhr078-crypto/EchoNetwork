extends Node

## A short real-room insert. Presentation never completes or opens the gate.
const PCAM = preload("res://addons/phantom_camera/scripts/phantom_camera/phantom_camera_3d.gd")
const HOST = preload("res://addons/phantom_camera/scripts/phantom_camera_host/phantom_camera_host.gd")
const LENS = preload("res://addons/phantom_camera/scripts/resources/camera_3d_resource.gd")
var main: Node
var room: Node3D
var active := false
var _elapsed := 0.0
var _previous_camera: Camera3D
var _camera: Camera3D
var _host: Node
var _return_shot: Node3D
var _gate_shot: Node3D
var _skip: Button
var _touch_was_visible := false
var _returning := false

func start() -> void:
	if active or main.reduced_motion or main.player.control_locked: return
	_previous_camera = get_viewport().get_camera_3d()
	if not _previous_camera: return
	_camera = Camera3D.new()
	_camera.name = "ServiceInsertCamera"
	_camera.fov = _previous_camera.fov
	add_child(_camera)
	_camera.global_transform = _previous_camera.global_transform
	_return_shot = Node3D.new()
	_return_shot.set_script(PCAM)
	_return_shot.priority = 10
	_return_shot.tween_duration = 0.35
	_return_shot.camera_3d_resource = _lens(_previous_camera.fov)
	add_child(_return_shot)
	_return_shot.global_transform = _previous_camera.global_transform
	_gate_shot = Node3D.new()
	_gate_shot.set_script(PCAM)
	_gate_shot.priority = 0
	_gate_shot.tween_duration = 0.5
	_gate_shot.camera_3d_resource = _lens(58)
	add_child(_gate_shot)
	_gate_shot.global_position = room.to_global(Vector3(2.8,6.9,-10.85))
	_gate_shot.look_at(room.to_global(Vector3(0.4,6.4,-12.75)),Vector3.UP)
	_host = Node.new()
	_host.set_script(HOST)
	_camera.add_child(_host)
	_camera.make_current()
	active = true
	_elapsed = 0
	_returning = false
	main.player.control_locked = true
	main.player.velocity = Vector3.ZERO
	var touch = main.hud.find_child("MobileTouchControls",true,false)
	_touch_was_visible = touch.visible
	touch.reset_input()
	touch.set_interaction_blocked(true)
	var overlay := CanvasLayer.new()
	overlay.layer = 25
	add_child(overlay)
	_skip = Button.new()
	_skip.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_skip.offset_left = -220
	_skip.offset_right = -32
	_skip.offset_top = -82
	_skip.offset_bottom = -30
	_skip.pressed.connect(finish)
	overlay.add_child(_skip)
	_gate_shot.priority = 20

func _lens(fov: float) -> Resource:
	var lens = LENS.new()
	for property in ["keep_aspect","cull_mask","h_offset","v_offset","projection","size","frustum_offset","near","far"]:
		lens.set(property,_previous_camera.get(property))
	lens.fov = fov
	return lens

func _process(delta: float) -> void:
	if not active: return
	_elapsed += delta
	_skip.text = "عودة للعب" if main.presentation_language == "ar" else "Return to play"
	if main.reduced_motion:
		finish()
		return
	if _elapsed >= 2.25 and not _returning:
		_returning = true
		_return_shot.priority = 30
	if _elapsed >= 2.65: finish()

func _unhandled_input(event: InputEvent) -> void:
	if active and _elapsed > 0.15 and event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_SPACE,KEY_E]:
		get_viewport().set_input_as_handled()
		finish()

func finish() -> void:
	if not active: return
	active = false
	if is_instance_valid(_previous_camera) and not _previous_camera.is_queued_for_deletion(): _previous_camera.make_current()
	if is_instance_valid(_host): _host.process_mode = Node.PROCESS_MODE_DISABLED
	if is_instance_valid(_skip): _skip.visible = false
	if is_instance_valid(main) and not main.is_queued_for_deletion():
		main.player.control_locked = false
		var touch = main.hud.find_child("MobileTouchControls",true,false)
		touch.reset_input()
		if main.native_pause_menu and main.native_pause_menu.session_paused:
			main.native_pause_menu._touch_was_visible = _touch_was_visible
		else:
			touch.set_interaction_blocked(not _touch_was_visible)

func _exit_tree() -> void: finish()

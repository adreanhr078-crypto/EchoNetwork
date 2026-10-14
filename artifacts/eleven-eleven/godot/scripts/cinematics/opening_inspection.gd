extends CanvasLayer

## Real-room clue inspection. No cloned asset, extra viewport or story receipt.
## Only the explicit confirmation invokes the existing evidence contract.
const FONT = preload("res://assets/fonts/NotoSansArabic.ttf")
var is_active := false
var main: Node3D
var evidence: Node3D
var interactor: Node3D
var camera: Camera3D
var previous_camera: Camera3D
var previous_mouse_mode := Input.MOUSE_MODE_VISIBLE
var previous_hud_visible := true
var guides: Dictionary = {}
var title: Label
var description: Label
var controls: Label
var panel: PanelContainer
var confirm_button: Button
var cancel_button: Button
var left_button: Button
var right_button: Button
var near_button: Button
var far_button: Button
var yaw := 0.0
var zoom := 1.0
var pitch := 0.0
var confirmed_count := 0
var cancelled_count := 0
var _drag_finger := -1
var _camera_base := Vector3(0.70,0.55,-0.12)

func configure(owner_main: Node3D) -> void:
	main = owner_main
	layer = 80
	camera = Camera3D.new()
	camera.name = "ClueInspectionCamera"
	camera.fov = 42.0
	camera.near = 0.035
	main.add_child(camera)
	panel = PanelContainer.new()
	panel.name = "ClueInspectionControls"
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_left = 32
	panel.offset_right = -32
	panel.offset_top = -390
	panel.offset_bottom = -20
	var theme := Theme.new()
	theme.default_font = FONT
	theme.default_font_size = 27
	panel.theme = theme
	var skin := StyleBoxFlat.new()
	skin.bg_color = Color(0.02,0.035,0.055,0.94)
	skin.border_color = Color(0.20,0.65,0.72,0.75)
	skin.set_border_width_all(1)
	skin.set_corner_radius_all(8)
	skin.content_margin_left = 20
	skin.content_margin_right = 20
	skin.content_margin_top = 12
	skin.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel",skin)
	add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",8)
	panel.add_child(column)
	title = Label.new()
	title.add_theme_font_size_override("font_size",34)
	title.modulate = Color(0.46,0.86,0.94)
	column.add_child(title)
	description = Label.new()
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.max_lines_visible = 2
	description.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	description.add_theme_font_size_override("font_size",27)
	column.add_child(description)
	controls = Label.new()
	controls.modulate = Color(0.68,0.76,0.84)
	controls.add_theme_font_size_override("font_size",22)
	column.add_child(controls)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",12)
	column.add_child(row)
	left_button = _button(row,func(): rotate_view(Vector2(-0.12,0)))
	right_button = _button(row,func(): rotate_view(Vector2(0.12,0)))
	near_button = _button(row,func(): change_zoom(-0.08))
	far_button = _button(row,func(): change_zoom(0.08))
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation",12)
	column.add_child(actions)
	var space := Control.new()
	space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(space)
	cancel_button = _button(actions,cancel)
	confirm_button = _button(actions,confirm)
	panel.hide()
	set_process_unhandled_input(false)

func _button(row: HBoxContainer, action: Callable) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(144,56)
	button.pressed.connect(action)
	row.add_child(button)
	return button

func open(clue: Node3D, actor: Node3D) -> void:
	if is_active or not is_instance_valid(main) or not is_instance_valid(actor): return
	if clue.get("evidence_id") not in ["clock","photo"] or clue.get("inspected") or actor.control_locked or actor.opening_recovery_active: return
	if not clue.get_node("InteractionArea").is_enabled: return
	evidence = clue
	interactor = actor
	previous_camera = main.get_viewport().get_camera_3d()
	previous_mouse_mode = Input.mouse_mode
	previous_hud_visible = main.hud.visible
	main._on_opening_dialogue_started()
	main.hud.hide()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	is_active = true
	yaw = 0.0
	pitch = 0.0
	zoom = 1.0
	_drag_finger = -1
	guides.clear()
	for visual in [clue._beacon_mesh,clue._ring_mesh,clue._orbit_ring_1,clue._orbit_ring_2,clue._beacon_light,clue.get_node("EvidenceLabel")]:
		if visual:
			guides[visual] = visual.visible
			visual.hide()
	_camera_base = Vector3(0.9744,0.7656,-0.167) if clue.evidence_id == "clock" else Vector3(0.922,0.651,0.5424)
	_update_camera()
	camera.make_current()
	refresh_labels()
	panel.show()
	confirm_button.grab_focus()
	set_process_unhandled_input(true)

func refresh_labels() -> void:
	if not is_active: return
	var ar: bool = main.presentation_language == "ar"
	var clock: bool = evidence.evidence_id == "clock"
	panel.layout_direction = Control.LAYOUT_DIRECTION_RTL if ar else Control.LAYOUT_DIRECTION_LTR
	title.text = ("الساعة المتوقفة" if clock else "الأثر الشخصي") if ar else ("The stopped clock" if clock else "A personal trace")
	description.text = ("العقربان ثابتان. انظر إلى الوجه قبل أن تحفظ هذا الأثر." if clock else "تآكلت الصورة، لكن الإحساس بها لم يختفِ. انظر أقرب، ثم اتبع الأثر.") if ar else ("Both hands are still. Examine the face before keeping this trace." if clock else "The photograph has worn away, but something familiar remains. Look closer, then follow the trace.")
	controls.text = "اسحب لتغيّر زاوية النظر · عجلة الفأرة للتقريب · Esc للعودة دون فحص" if ar else "Drag to change your view · Wheel to zoom · Esc to return without inspecting"
	left_button.text = "يسار" if ar else "Left"
	right_button.text = "يمين" if ar else "Right"
	near_button.text = "اقترب" if ar else "Closer"
	far_button.text = "ابتعد" if ar else "Further"
	cancel_button.text = "رجوع" if ar else "Return"
	confirm_button.text = ("احفظ الأثر" if clock else "اتبع الأثر") if ar else ("Keep this trace" if clock else "Follow the trace")

func rotate_view(amount: Vector2) -> void:
	if not is_active or get_tree().paused: return
	yaw = clampf(yaw+amount.x,-0.32,0.32)
	pitch = clampf(pitch+amount.y,-0.12,0.14)
	_update_camera()

func change_zoom(amount: float) -> void:
	if not is_active or get_tree().paused: return
	zoom = clampf(zoom+amount,0.82,1.18)
	_update_camera()

func _update_camera() -> void:
	if not is_instance_valid(evidence): return
	var center: Vector3 = evidence.global_position+Vector3(0,0.99,0)
	var offset := Basis(Vector3.UP,yaw)*(_camera_base*zoom)
	offset.y += pitch
	camera.global_position = center+offset
	# Frame the clue above the controls, retaining its real world position.
	camera.look_at(center-Vector3(0,0.18,0))

func _unhandled_input(event: InputEvent) -> void:
	if not is_active or get_tree().paused: return
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		rotate_view(Vector2(-event.relative.x*0.002,event.relative.y*0.001))
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			change_zoom(-0.05 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 0.05)
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch:
		if event.pressed and not panel.get_global_rect().has_point(event.position): _drag_finger = event.index
		elif event.index == _drag_finger: _drag_finger = -1
	elif event is InputEventScreenDrag and event.index == _drag_finger:
		rotate_view(Vector2(-event.relative.x*0.002,event.relative.y*0.001))
		get_viewport().set_input_as_handled()

func confirm() -> void:
	if not is_active or get_tree().paused: return
	var clue = evidence
	var actor = interactor
	_close()
	confirmed_count += 1
	if is_instance_valid(clue) and is_instance_valid(actor): clue.complete_inspection(actor)

func cancel() -> void:
	if not is_active or get_tree().paused: return
	cancelled_count += 1
	_close()

func interrupt() -> void:
	# A validated checkpoint replaces the view, including while paused. It must
	# never turn a pending preview into an evidence receipt.
	if is_active: _close()

func _close() -> void:
	is_active = false
	set_process_unhandled_input(false)
	panel.hide()
	_drag_finger = -1
	for visual in guides:
		if is_instance_valid(visual): visual.visible = guides[visual]
	guides.clear()
	if is_instance_valid(previous_camera): previous_camera.make_current()
	elif is_instance_valid(main.player.player_camera): main.player.player_camera.make_current()
	main.hud.visible = previous_hud_visible
	main._release_gameplay_modal_controls()
	if not main.player.control_locked: Input.mouse_mode = previous_mouse_mode
	evidence = null
	interactor = null

func _exit_tree() -> void:
	if is_instance_valid(camera): camera.queue_free()

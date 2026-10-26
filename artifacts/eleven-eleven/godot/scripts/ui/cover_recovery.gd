extends CanvasLayer

## Local presentation puzzle only. Never creates an account receipt or reward.
signal restored(board_rect: Rect2)
const COVER = preload("res://assets/textures/opening-cover.webp")
const FONT = preload("res://assets/fonts/NotoSansArabic.ttf")
const COLUMNS := 2
const ROWS := 3
const PIECE_COUNT := COLUMNS * ROWS
const INITIAL_ORDER := [1, 0, 2, 3, 5, 4]
var language := "ar"
var reduced_motion := false
var order: Array[int] = []
var history: Array = []
var tiles: Array[Button] = []
var selected := -1
var completed := false
var board: Control
var panel: VBoxContainer
var heading: Label
var detail: Label
var status: Label
var undo_button: Button
var reset_button: Button
var reference_button: Button
var language_button: Button
var reference: TextureRect
var _reference_open := false
var _scale := 1.0

func _ready() -> void:
	layer = 80
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var background := ColorRect.new()
	background.color = Color("080e19")
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	board = Control.new()
	add_child(board)
	for index in PIECE_COUNT:
		var tile := Button.new()
		tile.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tile.expand_icon = true
		tile.add_theme_constant_override("icon_max_width", 0)
		var atlas := AtlasTexture.new()
		atlas.atlas = COVER
		tile.icon = atlas
		tile.pressed.connect(_select.bind(index))
		board.add_child(tile)
		tiles.append(tile)
	reference = TextureRect.new()
	reference.texture = COVER
	reference.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	reference.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	reference.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board.add_child(reference)
	reference.hide()
	panel = VBoxContainer.new()
	panel.add_theme_constant_override("separation", 18)
	add_child(panel)
	heading = _label(38)
	detail = _label(23)
	status = _label(22)
	status.modulate = Color("8bdfff")
	reference_button = _button(func():
		_reference_open = not _reference_open
		reference.visible = _reference_open
		_refresh()
	)
	undo_button = _button(_undo)
	reset_button = _button(_shuffle)
	language_button = _button(func():
		language = "en" if language == "ar" else "ar"
		_refresh()
	)
	get_viewport().size_changed.connect(_layout)
	_shuffle()
	_layout()
	tiles[0].grab_focus()

func _label(font_size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(label)
	return label

func _button(action: Callable) -> Button:
	var button := Button.new()
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", 22)
	button.custom_minimum_size.y = 58
	var style := StyleBoxFlat.new()
	style.bg_color = Color("121e30")
	style.border_color = Color("35516e")
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	button.add_theme_stylebox_override("normal", style)
	panel.add_child(button)
	button.pressed.connect(action)
	return button

func _layout() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	_scale = maxf(1.0, viewport_size.y / maxf(1.0, get_window().size.y))
	var height := minf(viewport_size.y * .84, viewport_size.x * .44 * 1.5)
	var width := height * 2.0 / 3.0
	board.position = Vector2(viewport_size.x * .1, (viewport_size.y - height) * .5)
	board.size = Vector2(width, height)
	for index in PIECE_COUNT:
		var tile := tiles[index]
		tile.position = Vector2(index % COLUMNS * width / COLUMNS, index / COLUMNS * height / ROWS)
		tile.size = Vector2(width / COLUMNS, height / ROWS)
		tile.focus_neighbor_left = tiles[index - 1 if index % COLUMNS > 0 else index].get_path()
		tile.focus_neighbor_right = tiles[index + 1 if index % COLUMNS < COLUMNS - 1 else index].get_path()
		tile.focus_neighbor_top = tiles[index - COLUMNS if index >= COLUMNS else index].get_path()
		tile.focus_neighbor_bottom = tiles[index + COLUMNS if index < PIECE_COUNT - COLUMNS else index].get_path()
	# Tab also reaches the controls; arrow navigation remains inside the board.
	reference.position = Vector2.ZERO
	reference.size = board.size
	var panel_position := Vector2(board.position.x + width + viewport_size.x * .075, viewport_size.y * .13)
	# RTL resizing preserves the right edge. Size first, then place the panel.
	panel.size.x = maxf(260, viewport_size.x - panel_position.x - viewport_size.x * .08)
	panel.position = panel_position
	panel.add_theme_constant_override("separation", roundi(15 * _scale))
	for button in [undo_button, reset_button, reference_button, language_button]:
		button.custom_minimum_size.y = 50 * _scale
		button.add_theme_font_size_override("font_size", roundi(19 * _scale))
	heading.add_theme_font_size_override("font_size", roundi(31 * _scale))
	detail.add_theme_font_size_override("font_size", roundi(19 * _scale))
	status.add_theme_font_size_override("font_size", roundi(18 * _scale))

func _shuffle() -> void:
	if completed: return
	# Two simple swaps keep the first contact welcoming and bounded.
	order.assign(INITIAL_ORDER)
	selected = -1
	history.clear()
	_reference_open = false
	reference.hide()
	_refresh()

func _select(index: int) -> void:
	if completed or _reference_open: return
	if selected < 0:
		selected = index
	elif selected == index:
		selected = -1
	else:
		history.append(order.duplicate())
		var previous := order[selected]
		order[selected] = order[index]
		order[index] = previous
		selected = -1
	_refresh()
	for position in PIECE_COUNT:
		if order[position] != position: return
	completed = true
	_refresh()
	# Emission is deferred so the last input cannot also activate cinematic skip.
	_emit_restored.call_deferred()

func _emit_restored() -> void:
	if is_inside_tree() and not is_queued_for_deletion():
		restored.emit(Rect2(board.position, board.size))

func _undo() -> void:
	if completed or history.is_empty(): return
	order.assign(history.pop_back())
	selected = -1
	_refresh()

func _refresh() -> void:
	if not is_instance_valid(heading): return
	var ar := language == "ar"
	panel.layout_direction = Control.LAYOUT_DIRECTION_RTL if ar else Control.LAYOUT_DIRECTION_LTR
	heading.text = "قبل أن تتذكّر ما حدث…" if ar else "Before you remember what happened…"
	detail.text = "أَعِدْ للصورة وجهها الأول.\nست قطع فقط؛ اختر قطعتين لتبديلهما.\nلا مؤقت ولا عقوبة. يمكنك مشاهدة الغلاف كاملًا." if ar else "Restore the image that came before.\nJust six pieces. Select two to swap.\nNo timer or penalty. The full cover is always available."
	status.text = ("اكتملت الصورة. تنفتح القناة…" if ar else "Image restored. The channel opens…") if completed else (("قطعة محددة؛ اختر موضعها" if ar else "Piece selected; choose its place") if selected >= 0 else ("بوابة الاستعادة · الأثر الأول" if ar else "RECOVERY GATEWAY · FIRST TRACE"))
	undo_button.text = "تراجع" if ar else "Undo"
	reset_button.text = "إعادة الخلط" if ar else "Shuffle again"
	reference_button.text = ("العودة إلى القطع" if ar else "Return to pieces") if _reference_open else ("شاهد الصورة" if ar else "View reference")
	language_button.text = "English" if ar else "العربية"
	undo_button.disabled = history.is_empty() or completed
	reset_button.disabled = completed
	reference_button.disabled = completed
	for index in PIECE_COUNT:
		var tile := tiles[index]
		var piece := order[index]
		var source_size := Vector2(float(COVER.get_width()) / COLUMNS, float(COVER.get_height()) / ROWS)
		(tile.icon as AtlasTexture).region = Rect2(Vector2(piece % COLUMNS, piece / COLUMNS) * source_size, source_size)
		var style := StyleBoxFlat.new()
		style.bg_color = Color.TRANSPARENT
		style.border_color = Color("8bdfff") if selected == index else Color("23374b")
		style.set_border_width_all(3 if selected == index else 1)
		for state in ["normal", "hover", "pressed"]: tile.add_theme_stylebox_override(state, style)
		var focus := style.duplicate()
		focus.border_color = Color.WHITE
		focus.set_border_width_all(3)
		tile.add_theme_stylebox_override("focus", focus)
		tile.tooltip_text = ("الموضع %d من %d" if ar else "Position %d of %d") % [index + 1, PIECE_COUNT]
		tile.disabled = completed or _reference_open
	_layout()

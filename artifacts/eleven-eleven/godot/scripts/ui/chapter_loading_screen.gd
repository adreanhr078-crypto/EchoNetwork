extends CanvasLayer

## A persistent curtain: Boot can leave only after the destination has drawn.
## Progress labels describe real phases, never elapsed-time percentages.
signal retry_requested
const FONT = preload("res://assets/fonts/NotoSansArabic.ttf")
const POSTER = preload("res://assets/textures/ui/memory-aperture-v1.webp")
var language := "ar"
var reduced_motion := false
var phase := "preparing"
var heading: Label
var detail: Label
var retry_button: Button
var backdrop: Control
var _closing := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 110
	backdrop = Control.new()
	add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var base := ColorRect.new()
	base.color = Color("080e19")
	backdrop.add_child(base)
	base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var art := TextureRect.new()
	art.texture = POSTER
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.modulate = Color(.9, .95, 1)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.add_child(art)
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(.015, .025, .045, .25)
	backdrop.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	backdrop.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 36)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_END
	column.add_theme_constant_override("separation", 14)
	margin.add_child(column)
	var signature := Label.new()
	signature.text = "11.11  /  ECHO NETWORK"
	signature.add_theme_color_override("font_color", Color("7edfff"))
	signature.add_theme_font_size_override("font_size", 20)
	column.add_child(signature)
	heading = Label.new()
	heading.add_theme_font_size_override("font_size", 32)
	column.add_child(heading)
	var line := ColorRect.new()
	line.color = Color("65cfee")
	line.custom_minimum_size.y = 2
	column.add_child(line)
	detail = Label.new()
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_theme_font_size_override("font_size", 21)
	column.add_child(detail)
	retry_button = Button.new()
	retry_button.custom_minimum_size.y = 56
	retry_button.pressed.connect(func(): retry_requested.emit())
	column.add_child(retry_button)
	for control in [signature, heading, detail, retry_button]:
		control.add_theme_font_override("font", FONT)
	set_phase(phase)

func set_phase(value: String) -> void:
	phase = value
	if not is_instance_valid(heading): return
	var ar := language == "ar"
	backdrop.layout_direction = Control.LAYOUT_DIRECTION_RTL if ar else Control.LAYOUT_DIRECTION_LTR
	heading.text = "جارٍ الانتقال إلى عالم إيكو" if ar else "Entering Echo's world"
	var copy := {
		"preparing": ["تهيئة الرحلة…", "Preparing the journey…"],
		"resources": ["تحميل موارد العالم…", "Loading world resources…"],
		"scene": ["تجهيز المكان والشخصية…", "Preparing the scene and character…"],
		"camera": ["تجهيز الصورة والكاميرا…", "Preparing the view and camera…"],
		"failed": ["تعذر تحميل العالم. يمكنك إعادة المحاولة؛ تقدمك محفوظ.", "The world could not load. Retry to continue; your progress is retained."]
	}
	detail.text = copy.get(value, copy.preparing)[0 if ar else 1]
	retry_button.text = "إعادة المحاولة" if ar else "Retry"
	retry_button.visible = value == "failed"
	if retry_button.visible: retry_button.grab_focus()

func dismiss() -> void:
	if _closing: return
	_closing = true
	if not reduced_motion:
		var tween := create_tween()
		tween.tween_property(backdrop, "modulate:a", 0.0, .22)
		await tween.finished
	queue_free()

func _input(event: InputEvent) -> void:
	# Mouse/touch still reach Retry. Keyboard gameplay cannot leak through the
	# covered handoff; leave GUI navigation available in the error state.
	if phase != "failed" and (event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion):
		get_viewport().set_input_as_handled()

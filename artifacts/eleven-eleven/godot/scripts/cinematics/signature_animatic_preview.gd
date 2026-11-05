extends Control
## Internal P06 editorial tool. No production scene, save, network or contract owner.

const PACKET := "res://../art/production/signature-slice-20261104/"
const FONT := preload("res://assets/fonts/NotoSansArabic.ttf")
var shots: Array = []
var locks: Dictionary = {}
var index := 0
var decision_index := -1
var elapsed := 0.0
var preview_consent := false
var paused := true
var reduced_motion := true
var finished := false
var error_text := ""
var heading: Label
var details: Label
var state: Label
var art: TextureRect
var choices: HBoxContainer
var pause_button: Button
var motion_button: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	load_packet()

func _label(text_value: String, font_size: int) -> Label:
	var result := Label.new()
	result.text = text_value
	result.add_theme_font_override("font", FONT)
	result.add_theme_font_size_override("font_size", font_size)
	result.layout_direction = Control.LAYOUT_DIRECTION_RTL
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return result

func _button(parent: Control, text_value: String, action: Callable) -> Button:
	var result := Button.new()
	result.text = text_value
	result.custom_minimum_size = Vector2(130, 46)
	result.add_theme_font_override("font", FONT)
	result.add_theme_font_size_override("font_size", 16)
	result.layout_direction = Control.LAYOUT_DIRECTION_RTL
	result.pressed.connect(action)
	parent.add_child(result)
	return result

func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color("090c14")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 20)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)
	heading = _label("إيكو: من الرفض إلى القرار", 24)
	column.add_child(heading)
	column.add_child(_label("معاينة إخراج داخلية • لوحات مرجعية من المانهوا • الصوت والتماس والتمثيل النهائي قيد التأهيل", 15))
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 20)
	column.add_child(body)
	var image_frame := PanelContainer.new()
	image_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	image_frame.custom_minimum_size = Vector2(640, 340)
	image_frame.clip_contents = true
	body.add_child(image_frame)
	art = TextureRect.new()
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image_frame.add_child(art)
	details = _label("", 18)
	details.custom_minimum_size.x = 340
	details.size_flags_horizontal = Control.SIZE_FILL
	body.add_child(details)
	state = _label("", 16)
	state.custom_minimum_size.y = 30
	column.add_child(state)
	choices = HBoxContainer.new()
	choices.alignment = BoxContainer.ALIGNMENT_CENTER
	choices.add_theme_constant_override("separation", 12)
	column.add_child(choices)
	_button(choices, "معاينة ما بعد القبول", accept_preview)
	_button(choices, "أؤجل القرار", defer_preview)
	_button(choices, "أرفض وأوقف", reject_preview)
	var controls := HBoxContainer.new()
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	controls.add_theme_constant_override("separation", 8)
	column.add_child(controls)
	_button(controls, "السابق ←", previous_shot)
	pause_button = _button(controls, "تشغيل / Space", toggle_pause)
	_button(controls, "التالي →", next_shot)
	_button(controls, "البداية / R", restart)
	motion_button = _button(controls, "حركة مخفضة ✓", toggle_motion)
	_button(controls, "تخطٍ / Esc", skip_preview)

func load_packet() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(PACKET + "editorial-timeline.json"))
	var source_data = JSON.parse_string(FileAccess.get_file_as_string(PACKET + "source-lock.json"))
	if not data is Dictionary or not source_data is Dictionary:
		_fail("تعذر قراءة حزمة المعاينة. أعد بناء المصدر المؤهل.")
		return
	shots = data.get("shots", [])
	locks = source_data.get("files", {})
	decision_index = -1
	for i in shots.size():
		if shots[i].get("gate") == "explicit_preview_consent":
			if decision_index != -1:
				_fail("حزمة غير صالحة: أكثر من بوابة قرار.")
				return
			decision_index = i
	if shots.is_empty() or decision_index < 0 or decision_index >= shots.size() - 1:
		_fail("حزمة غير صالحة: بوابة القرار مفقودة.")
		return
	restart()

func _fail(message: String) -> void:
	error_text = message
	finished = true
	paused = true
	preview_consent = false
	art.texture = null
	choices.visible = false
	state.text = message
	state.add_theme_color_override("font_color", Color("ffc6b9"))

func _show_shot() -> void:
	var shot: Dictionary = shots[index]
	var relative_path: String = shot.get("page_path", "")
	if not relative_path.begins_with("public/manhwa/echo-network-final-2026-09-v1/") or ".." in relative_path:
		_fail("مسار لوحة غير مؤهل.")
		return
	var absolute := ProjectSettings.globalize_path("res://../" + relative_path)
	if not locks.has(relative_path) or FileAccess.get_sha256(absolute) != String(locks[relative_path]).to_lower():
		_fail("بصمة لوحة المصدر غير مطابقة. توقفت المعاينة بلا قبول.")
		return
	var page := Image.load_from_file(absolute)
	if page == null or page.is_empty():
		_fail("تعذر تحميل لوحة المصدر.")
		return
	var crop: Array = shot.get("crop_normalized", [])
	if crop.size() != 4 or float(crop[0]) < 0 or float(crop[1]) < 0 or float(crop[2]) > 1 or float(crop[3]) > 1 or float(crop[2]) <= float(crop[0]) or float(crop[3]) <= float(crop[1]):
		_fail("حدود لوحة غير صالحة.")
		return
	var rect := Rect2i(int(crop[0] * page.get_width()), int(crop[1] * page.get_height()), int((crop[2] - crop[0]) * page.get_width()), int((crop[3] - crop[1]) * page.get_height()))
	var panel := page.get_region(rect)
	if panel.get_width() > 1600:
		panel.resize(1600, maxi(1, int(1600.0 * panel.get_height() / panel.get_width())), Image.INTERPOLATE_LANCZOS)
	art.texture = ImageTexture.create_from_image(panel)
	art.scale = Vector2.ONE
	heading.text = "%s · %s · %s" % [shot.id, shot.event_id, shot.title_ar]
	details.text = "توجيه الأداء\n%s\n\nاتجاه الصوت — غير منتج\n%s\n\nالمصدر: صفحة PDF %d\nالزمن المقترح: %s" % [shot.acting_ar, shot.audio_direction_ar, shot.global_pdf_page, "قرار بلا مؤقت" if float(shot.duration_seconds) == 0 else "%.1f ثانية" % float(shot.duration_seconds)]
	choices.visible = index == decision_index
	_update_state()

func _update_state() -> void:
	if error_text != "": return
	pause_button.text = "تشغيل / Space" if paused else "وقفة / Space"
	motion_button.text = "حركة مخفضة ✓" if reduced_motion else "حركة خفيفة / M"
	if finished: return
	if index == decision_index:
		state.text = "القرار ينتظر فعلك. التالي والتخطي والوقت لا يقبلون العقد. هذه معاينة بلا حفظ أو تقدم."
	elif String(shots[index].get("gate", "")) == "gameplay_handoff":
		state.text = "نهاية المونتاج عند تسليم اللعب — القتال الفعلي والتماس واختبار المتعة ما زالت مفتوحة."
	else:
		state.text = "%d / %d · %s · لا صوت مسجل في هذه النسخة" % [index + 1, shots.size(), "متوقف" if paused else "تشغيل"]

func seek_shot(target: int) -> void:
	if shots.is_empty() or error_text != "" or finished: return
	index = clampi(target, 0, shots.size() - 1)
	if index > decision_index and not preview_consent:
		index = decision_index
	if index <= decision_index:
		preview_consent = false
	elapsed = 0.0
	_show_shot()

func next_shot() -> void:
	if index == decision_index or finished: return
	seek_shot(index + 1)

func previous_shot() -> void:
	seek_shot(index - 1)

func toggle_pause() -> void:
	if finished: return
	paused = not paused
	_update_state()

func toggle_motion() -> void:
	reduced_motion = not reduced_motion
	art.scale = Vector2.ONE
	_update_state()

func accept_preview() -> void:
	if index != decision_index or finished or error_text != "": return
	preview_consent = true
	seek_shot(decision_index + 1)

func defer_preview() -> void:
	if index != decision_index or finished: return
	paused = true
	preview_consent = false
	state.text = "أُجّل القرار. تبقى هنا بلا مهلة أو تقدم أو قوة مكتسبة."
	pause_button.text = "تشغيل / Space"

func reject_preview() -> void:
	if index != decision_index or finished: return
	_end("رُفض العرض في المعاينة. لم يُمنح عقد أو تقدم. البداية تعيد المراجعة.")

func skip_preview() -> void:
	_end("تُخطيت المعاينة بلا قبول أو حفظ أو مكافأة. البداية تعيد المراجعة.")

func _end(message: String) -> void:
	finished = true
	paused = true
	preview_consent = false
	choices.visible = false
	state.text = message
	art.scale = Vector2.ONE

func restart() -> void:
	if shots.is_empty() or decision_index < 0: return
	index = 0
	elapsed = 0.0
	preview_consent = false
	paused = true
	finished = false
	error_text = ""
	state.remove_theme_color_override("font_color")
	_show_shot()

func advance_clock(delta: float) -> void:
	if finished or paused or shots.is_empty(): return
	var duration: float = float(shots[index].get("duration_seconds", 0))
	if duration <= 0: return
	elapsed = minf(elapsed + maxf(delta, 0.0), duration)
	if not reduced_motion:
		art.pivot_offset = art.size * 0.5
		art.scale = Vector2.ONE * (1.0 + 0.02 * elapsed / duration)
	if elapsed >= duration: next_shot()

func _process(delta: float) -> void:
	advance_clock(delta)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	match event.physical_keycode:
		KEY_SPACE: toggle_pause()
		KEY_RIGHT: next_shot()
		KEY_LEFT: previous_shot()
		KEY_R: restart()
		KEY_M: toggle_motion()
		KEY_ESCAPE: skip_preview()
		_: return
	get_viewport().set_input_as_handled()

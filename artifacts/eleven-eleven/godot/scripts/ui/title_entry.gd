extends CanvasLayer

## Owner-supplied full-frame loop. Playback never grants story progress.
signal start_requested
const FILM = preload("res://assets/cinematics/title-moon-v1.ogv")
const POSTER = preload("res://assets/cinematics/title-moon-v1.webp")
const FONT = preload("res://assets/fonts/NotoSansArabic.ttf")
const WATER = preload("res://assets/cinematics/title-water-sfx-v1.ogg")
var language := "ar"
var reduced_motion := false
var video: VideoStreamPlayer
var poster: TextureRect
var start_button: Button
var motion_button: Button
var language_button: Button
var sound_button: Button
var water: AudioStreamPlayer
var audible := false
var _starting := false
var loop_count := 0
var _ui_scale := 1.0

func _ready() -> void:
	layer = 80
	_ui_scale = maxf(1.0, get_viewport().get_visible_rect().size.y / maxf(1.0,get_window().size.y))
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var root := Control.new()
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var backdrop := ColorRect.new()
	backdrop.color = Color.BLACK
	root.add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	poster = TextureRect.new()
	poster.texture = POSTER
	poster.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	poster.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	poster.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(poster)
	poster.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var aspect := AspectRatioContainer.new()
	aspect.ratio = 16.0/9.0
	aspect.stretch_mode = AspectRatioContainer.STRETCH_FIT
	aspect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(aspect)
	aspect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	video = VideoStreamPlayer.new()
	video.stream = FILM
	video.expand = true
	video.volume_db = -80.0
	video.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aspect.add_child(video)
	video.finished.connect(_repeat)
	water = AudioStreamPlayer.new()
	water.stream = WATER
	water.volume_db = -10.0
	add_child(water)
	water.finished.connect(func():
		if audible and not reduced_motion: water.play()
	)
	start_button = _button(root, "Tap to Start", Vector2(.5,.88), Vector2(380,56), _start)
	start_button.add_theme_font_size_override("font_size", roundi(25*_ui_scale))
	motion_button = _button(root, "", Vector2(.96,.05), Vector2(56,48), toggle_motion)
	language_button = _button(root, "English", Vector2(.04,.05), Vector2(110,48), _language)
	sound_button = _button(root, "", Vector2(.88,.05), Vector2(56,48), _sound)
	_refresh()
	if not reduced_motion: video.play()
	start_button.grab_focus()

func _button(root: Control, text: String, anchor: Vector2, dimensions: Vector2, action: Callable) -> Button:
	dimensions *= _ui_scale
	var button := Button.new()
	button.text = text
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", roundi(20*_ui_scale))
	button.add_theme_color_override("font_color", Color.WHITE)
	for state in ["normal", "hover", "pressed"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color(0,0,0,0)
	focus.border_color = Color.WHITE
	focus.set_border_width_all(2)
	focus.set_corner_radius_all(6)
	button.add_theme_stylebox_override("focus", focus)
	button.add_theme_color_override("font_shadow_color", Color.BLACK)
	button.add_theme_constant_override("shadow_outline_size", 3)
	root.add_child(button)
	button.set_anchor(SIDE_LEFT, anchor.x)
	button.set_anchor(SIDE_RIGHT, anchor.x)
	button.set_anchor(SIDE_TOP, anchor.y)
	button.set_anchor(SIDE_BOTTOM, anchor.y)
	var pivot := Vector2(.5,.5)
	if anchor.x > .9: pivot.x = 1.0
	if anchor.x < .1: pivot.x = 0.0
	button.offset_left = -dimensions.x*pivot.x
	button.offset_top = -dimensions.y*pivot.y
	button.offset_right = button.offset_left+dimensions.x
	button.offset_bottom = button.offset_top+dimensions.y
	button.pressed.connect(action)
	return button

func _refresh() -> void:
	start_button.text = "اضغط للبدء · Tap to Start" if language == "ar" else "Tap to Start"
	motion_button.text = "▷" if reduced_motion else "Ⅱ"
	motion_button.tooltip_text = ("تشغيل الفيديو" if reduced_motion else "إيقاف الحركة") if language == "ar" else ("Play video" if reduced_motion else "Pause motion")
	language_button.text = "English" if language == "ar" else "العربية"
	sound_button.text = "صوت" if language == "ar" else "SFX"
	sound_button.tooltip_text = ("كتم مؤثرات الماء" if audible else "تشغيل مؤثرات الماء") if language == "ar" else ("Mute water effects" if audible else "Enable water effects")
	video.visible = not reduced_motion
	poster.visible = reduced_motion or not video.is_playing()

func _process(_delta: float) -> void:
	if not reduced_motion and video.is_playing(): poster.hide()

func toggle_motion() -> void:
	reduced_motion = not reduced_motion
	if reduced_motion:
		video.stop()
		water.stop()
	else:
		video.play()
		if audible: water.play()
	_refresh()

func _sound() -> void:
	audible = not audible
	if audible and not reduced_motion: water.play()
	else: water.stop()
	_refresh()

func _language() -> void:
	language = "en" if language == "ar" else "ar"
	_refresh()

func _repeat() -> void:
	if not _starting and not reduced_motion:
		loop_count += 1
		video.play()

func _start() -> void:
	if _starting: return
	_starting = true
	start_button.disabled = true
	video.stop()
	water.stop()
	start_requested.emit()

func _exit_tree() -> void:
	if is_instance_valid(video): video.stop()
	if is_instance_valid(water): water.stop()

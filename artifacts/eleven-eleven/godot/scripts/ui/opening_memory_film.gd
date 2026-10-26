extends CanvasLayer

## Presentation after the played cover. Finish/skip never grants story progress.
signal finished
const COVER = preload("res://assets/textures/opening-cover.webp")
const POSTER = preload("res://assets/cinematics/opening-cover-poster.webp")
const FONT = preload("res://assets/fonts/NotoSansArabic.ttf")
var language := "ar"
var reduced_motion := false
var board_rect := Rect2()
var show_fracture := true
var film_path := "res://assets/cinematics/opening-cover-v2.ogv"
var poster_texture: Texture2D = POSTER
var ambient_path := ""
var audio_muted := true
var presentation_layer := 81
var hold_poster := false
var cue_ar := ""
var cue_en := ""
var cue_start := 4.5
var cue_end := 6.7
var continue_ar := "المتابعة إلى إيكو"
var continue_en := "Continue to Echo"
var video: VideoStreamPlayer
var skip_button: Button
var pause_button: Button
var root: Control
var _done := false
var _fracture_tween: Tween
var _playing := false
var poster: TextureRect
var ambient: AudioStreamPlayer
var subtitle: Label

func _ready() -> void:
	layer = presentation_layer
	root = Control.new()
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var black := ColorRect.new()
	black.color = Color.BLACK
	root.add_child(black)
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	poster = TextureRect.new()
	poster.texture = poster_texture
	poster.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	poster.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	poster.mouse_filter = Control.MOUSE_FILTER_IGNORE
	poster.visible = reduced_motion or not show_fracture
	root.add_child(poster)
	poster.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var aspect := AspectRatioContainer.new()
	aspect.ratio = 16.0 / 9.0
	aspect.stretch_mode = AspectRatioContainer.STRETCH_FIT
	aspect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(aspect)
	aspect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	video = VideoStreamPlayer.new()
	video.stream = load(film_path)
	video.expand = true
	# Existing source audio is not yet requalified under SFX_ONLY.
	video.volume_db = -80.0
	video.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aspect.add_child(video)
	video.hide()
	video.finished.connect(_finish)
	ambient = AudioStreamPlayer.new()
	if not ambient_path.is_empty(): ambient.stream = load(ambient_path)
	ambient.volume_db = -80.0 if audio_muted else -4.0
	add_child(ambient)
	skip_button = Button.new()
	skip_button.add_theme_font_override("font", FONT)
	var scale := maxf(1.0, get_viewport().get_visible_rect().size.y / maxf(1.0, get_window().size.y))
	skip_button.add_theme_font_size_override("font_size", roundi(20 * scale))
	root.add_child(skip_button)
	skip_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	skip_button.offset_left = -300 * scale
	skip_button.offset_top = -75 * scale
	skip_button.offset_right = -20 * scale
	skip_button.offset_bottom = -20 * scale
	skip_button.pressed.connect(_finish)
	pause_button = Button.new()
	pause_button.text = "إيقاف مؤقت" if language == "ar" else "Pause"
	pause_button.add_theme_font_override("font", FONT)
	pause_button.add_theme_font_size_override("font_size", roundi(20 * scale))
	root.add_child(pause_button)
	pause_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	pause_button.offset_left = -180 * scale
	pause_button.offset_right = -20 * scale
	pause_button.offset_top = 20 * scale
	pause_button.offset_bottom = 70 * scale
	pause_button.hide()
	pause_button.pressed.connect(func():
		video.paused = not video.paused
		ambient.stream_paused = video.paused
		_refresh_copy()
	)
	subtitle = Label.new()
	subtitle.add_theme_font_override("font", FONT)
	subtitle.add_theme_font_size_override("font_size", roundi(25 * scale))
	subtitle.add_theme_color_override("font_shadow_color", Color.BLACK)
	subtitle.add_theme_constant_override("shadow_outline_size", 6)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(subtitle)
	subtitle.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	subtitle.offset_left = -350 * scale
	subtitle.offset_right = 350 * scale
	subtitle.offset_top = -150 * scale
	subtitle.offset_bottom = -90 * scale
	_refresh_copy()
	# Do not move keyboard focus onto Skip while the solving Enter is held.
	if reduced_motion:
		skip_button.grab_focus.call_deferred()
	elif show_fracture and board_rect.has_area():
		_fracture()
	else:
		_play()

func _fracture() -> void:
	var shards := Node2D.new()
	root.add_child(shards)
	root.move_child(skip_button, -1)
	_fracture_tween = create_tween().set_parallel(true)
	for index in 32:
		var cell := index / 2
		var x := cell % 4
		var y := cell / 4
		var unit := board_rect.size / 4.0
		var corner := Vector2(x, y) * unit
		var points := PackedVector2Array([corner, corner + Vector2(unit.x, 0), corner + Vector2(0, unit.y)]) if index % 2 == 0 else PackedVector2Array([corner + Vector2(unit.x, 0), corner + unit, corner + Vector2(0, unit.y)])
		var center := (points[0] + points[1] + points[2]) / 3.0
		var shard := Polygon2D.new()
		var local_points := PackedVector2Array()
		var uvs := PackedVector2Array()
		for point in points:
			local_points.append(point - center)
			uvs.append(point / board_rect.size * Vector2(COVER.get_width(), COVER.get_height()))
		shard.polygon = local_points
		shard.uv = uvs
		shard.texture = COVER
		shard.position = board_rect.position + center
		shards.add_child(shard)
		var flight := Vector2((x - 1.5) * board_rect.size.x * .65, (y - 1.5) * board_rect.size.y * .6 + board_rect.size.y * .2)
		_fracture_tween.tween_property(shard, "position", shard.position + flight, 1.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		_fracture_tween.tween_property(shard, "rotation", (index % 5 - 2) * .16, 1.25)
		_fracture_tween.tween_property(shard, "modulate:a", 0.0, 1.25).set_delay(.12)
	_fracture_tween.chain().tween_callback(func():
		shards.queue_free()
		_play()
	)

func _play() -> void:
	if _done or not is_inside_tree(): return
	if video.stream == null:
		poster.show()
		subtitle.text = "تعذر تشغيل المشهد؛ يمكنك المتابعة." if language == "ar" else "The cinematic could not play. You can continue."
		subtitle.show()
		return
	_playing = true
	video.show()
	video.play()
	if ambient.stream and not audio_muted: ambient.play()
	pause_button.show()
	skip_button.grab_focus()

func sync_preferences(next_language: String, motion: bool, muted: bool) -> void:
	language = next_language
	audio_muted = muted
	ambient.volume_db = -80.0 if muted else -4.0
	if muted: ambient.stop()
	elif not _done and not motion and video.is_playing() and ambient.stream and not ambient.playing:
		ambient.play(video.stream_position)
		ambient.stream_paused = video.paused
	if motion != reduced_motion and not _done:
		reduced_motion = motion
		if motion:
			video.stop(); video.hide(); ambient.stop(); poster.show(); pause_button.hide()
		else: _play()
	_refresh_copy()

func _refresh_copy() -> void:
	skip_button.text = (continue_ar if reduced_motion else "تجاوز المشهد ❯❯") if language == "ar" else (continue_en if reduced_motion else "Skip cinematic ❯❯")
	pause_button.text = ("متابعة المشهد" if video.paused else "إيقاف مؤقت") if language == "ar" else ("Resume" if video.paused else "Pause")
	subtitle.text = cue_ar if language == "ar" else cue_en

func _process(_delta: float) -> void:
	if not is_instance_valid(subtitle): return
	if video.stream == null: return
	subtitle.visible = not subtitle.text.is_empty() and (reduced_motion or (_done and hold_poster) or (video.stream_position >= cue_start and video.stream_position <= cue_end))

func _finish() -> void:
	if _done: return
	_done = true
	if _fracture_tween and _fracture_tween.is_running(): _fracture_tween.kill()
	video.stop()
	ambient.stop()
	if hold_poster:
		video.hide(); poster.show(); skip_button.hide(); pause_button.hide()
	finished.emit()

func _exit_tree() -> void:
	cancel()

func cancel() -> void:
	# Cancellation releases media immediately and never invokes the handoff.
	_done = true
	if _fracture_tween and _fracture_tween.is_running(): _fracture_tween.kill()
	if is_instance_valid(video): video.stop()
	if is_instance_valid(ambient): ambient.stop()

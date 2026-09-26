class_name TutorialToastSystem
extends Control

## Genshin-style Contextual Tutorial Toast Banner
## Displays elegant keycap prompt cards at the top of the HUD.
## Automatically dismisses with a soft confirmation chime upon successful execution.

signal toast_completed(toast_id: String)

var active_toast_id: String = ""
var toast_panel: PanelContainer = null
var keycap_label: Label = null
var title_label: Label = null
var desc_label: Label = null
var _dismiss_timer: float = 0.0

func _ready() -> void:
	name = "TutorialToastSystem"
	set_anchors_preset(Control.PRESET_CENTER_TOP)
	offset_top = 48.0
	offset_left = -320.0
	offset_right = 320.0
	offset_bottom = 138.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()
	visible = false

func _build_ui() -> void:
	toast_panel = PanelContainer.new()
	toast_panel.name = "ToastPanel"
	toast_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.05, 0.08, 0.88)
	style.border_color = Color(0.0, 0.85, 1.0, 0.9)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	toast_panel.add_theme_stylebox_override("panel", style)
	add_child(toast_panel)

	var hbox := HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 14)
	toast_panel.add_child(hbox)

	keycap_label = Label.new()
	keycap_label.name = "Keycap"
	keycap_label.text = "[ SPACE ]"
	keycap_label.add_theme_color_override("font_color", Color(0.0, 0.95, 1.0))
	keycap_label.add_theme_font_size_override("font_size", 20)
	hbox.add_child(keycap_label)

	var sep := VSeparator.new()
	hbox.add_child(sep)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_child(vbox)

	title_label = Label.new()
	title_label.name = "Title"
	title_label.text = "RUNNING SLIDE"
	title_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	title_label.add_theme_font_size_override("font_size", 19)
	vbox.add_child(title_label)

	desc_label = Label.new()
	desc_label.name = "Description"
	desc_label.text = "Sprint and press [C] to slide under low obstacles"
	desc_label.add_theme_color_override("font_color", Color(0.75, 0.82, 0.9))
	desc_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(desc_label)

func show_toast(toast_id: String, keycap: String, title: String, description: String, timeout: float = 5.0) -> void:
	if not toast_panel:
		_build_ui()
	active_toast_id = toast_id
	if keycap_label:
		keycap_label.text = "[ %s ]" % keycap
	if title_label:
		title_label.text = title.to_upper()
	if desc_label:
		desc_label.text = description
	_dismiss_timer = timeout

	visible = true
	modulate.a = 0.0
	var tree := get_tree() if is_inside_tree() else null
	if tree:
		var tween = tree.create_tween()
		tween.tween_property(self, "modulate:a", 1.0, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		modulate.a = 1.0

func complete_action(toast_id: String) -> void:
	if active_toast_id != toast_id or not visible:
		return
	_play_chime()
	dismiss_toast()

func dismiss_toast() -> void:
	if not visible:
		return
	emit_signal("toast_completed", active_toast_id)
	active_toast_id = ""
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.25)
	tween.tween_callback(func(): visible = false)

func _play_chime() -> void:
	var audio_player := AudioStreamPlayer.new()
	add_child(audio_player)
	var sample_rate: float = 44100.0
	var duration: float = 0.28
	var num_samples: int = int(sample_rate * duration)
	var pcm_data := PackedByteArray()
	pcm_data.resize(num_samples * 2)

	for i in range(num_samples):
		var t: float = float(i) / sample_rate
		var env: float = exp(-t * 12.0)
		var wave: float = sin(2.0 * PI * 1760.0 * t) * 0.7 + sin(2.0 * PI * 2640.0 * t) * 0.3
		var sample_val: int = int(clampf(wave * env, -1.0, 1.0) * 32767.0)
		var idx: int = i * 2
		pcm_data[idx] = sample_val & 0xFF
		pcm_data[idx + 1] = (sample_val >> 8) & 0xFF

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = int(sample_rate)
	stream.data = pcm_data
	audio_player.stream = stream
	audio_player.play()
	audio_player.finished.connect(audio_player.queue_free)

func _process(delta: float) -> void:
	if visible and _dismiss_timer > 0.0:
		_dismiss_timer -= delta
		if _dismiss_timer <= 0.0:
			dismiss_toast()

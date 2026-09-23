class_name RealityGlitchOverlay
extends CanvasLayer

signal glitch_started(intensity: float)
signal glitch_ended()

@onready var color_rect: ColorRect = find_child("GlitchRect", true, false) as ColorRect
@onready var prompt_label: Label = find_child("SystemAnomalyLabel", true, false) as Label

var current_intensity: float = 0.0
var glitch_material: ShaderMaterial = null

func _ready() -> void:
	if not color_rect:
		color_rect = ColorRect.new()
		color_rect.name = "GlitchRect"
		color_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(color_rect)
	
	if color_rect.material is ShaderMaterial:
		glitch_material = color_rect.material as ShaderMaterial
	else:
		var shader = load("res://shaders/reality_glitch.gdshader")
		if shader:
			glitch_material = ShaderMaterial.new()
			glitch_material.shader = shader
			color_rect.material = glitch_material
	
	set_intensity(0.0)
	if prompt_label:
		prompt_label.visible = false

func set_intensity(val: float) -> void:
	current_intensity = clampf(val, 0.0, 1.0)
	if glitch_material:
		glitch_material.set_shader_parameter("glitch_intensity", current_intensity)

## Trigger an abrupt digital reality glitch pulse
func pulse_glitch(peak_intensity: float = 0.85, duration: float = 0.6) -> void:
	emit_signal("glitch_started", peak_intensity)
	set_intensity(peak_intensity)
	
	var tree = get_tree() if is_inside_tree() else null
	if not tree:
		return

	var tween = tree.create_tween()
	tween.tween_method(set_intensity, peak_intensity, 0.0, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.finished.connect(func(): emit_signal("glitch_ended"))

## Display reality simulation anomaly alert
func show_simulation_anomaly_alert(text: String = "[CRITICAL WARNING: CONSCIOUSNESS DESYNCHRONIZATION DETECTED - SIMULATION CORRUPTED BY ENTITY ZERO]", duration: float = 4.0) -> void:
	pulse_glitch(0.9, 1.0)
	if not prompt_label:
		prompt_label = Label.new()
		prompt_label.name = "SystemAnomalyLabel"
		prompt_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
		prompt_label.position.y = 80
		prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		prompt_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.35, 1.0))
		prompt_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
		prompt_label.add_theme_constant_override("shadow_offset_x", 2)
		prompt_label.add_theme_constant_override("shadow_offset_y", 2)
		prompt_label.add_theme_font_size_override("font_size", 18)
		add_child(prompt_label)

	prompt_label.text = text
	prompt_label.visible = true
	
	var tree = get_tree() if is_inside_tree() else null
	if tree:
		var timer = tree.create_timer(duration)
		timer.timeout.connect(func():
			if prompt_label: prompt_label.visible = false
		)

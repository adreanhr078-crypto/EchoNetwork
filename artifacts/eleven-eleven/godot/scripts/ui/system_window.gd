extends Control
const SYSTEM_FONT=preload("res://assets/fonts/NotoSansArabic.ttf")
const SYSTEM_GLASS=preload("res://assets/ui/system-red-glass-v1.png")

signal system_window_opened(type)
signal system_window_closed(type)
signal solo_leveling_choice_made(choice_id: String)
signal decision_made(choice_id: String)

enum WindowType {
	NOTIFICATION,
	QUEST_COMPLETED,
	LEVEL_UP,
	REWARD,
	SOLO_LEVELING_GLITCH
}

var current_type: WindowType = WindowType.NOTIFICATION
var follow_player: Node3D = null
var _window_generation: int = 0
var _popup_tween: Tween = null
var reduced_motion := false
var presentation_language := "ar"
var _modal := false
var _inspection_layout:=false
var _scroll: ScrollContainer
var _footer:VBoxContainer
var _signal_glass: Control

@onready var panel: Panel = $Panel if has_node("Panel") else null
@onready var header_lbl: Label = $Panel/VBox/SystemHeader if has_node("Panel/VBox/SystemHeader") else null
@onready var title_lbl: Label = $Panel/VBox/TitleLabel if has_node("Panel/VBox/TitleLabel") else null
@onready var desc_lbl: Label = $Panel/VBox/DescLabel if has_node("Panel/VBox/DescLabel") else null
@onready var stats_box: VBoxContainer = $Panel/VBox/StatsBox if has_node("Panel/VBox/StatsBox") else null
@onready var confirm_btn: Button = $Panel/VBox/ConfirmBtn if has_node("Panel/VBox/ConfirmBtn") else null

func _ensure_nodes() -> void:
	if not panel: panel = find_child("Panel", true, false) as Panel
	if not header_lbl: header_lbl = find_child("SystemHeader", true, false) as Label
	if not title_lbl: title_lbl = find_child("TitleLabel", true, false) as Label
	if not desc_lbl: desc_lbl = find_child("DescLabel", true, false) as Label
	if not stats_box: stats_box = find_child("StatsBox", true, false) as VBoxContainer
	if not confirm_btn: confirm_btn = find_child("ConfirmBtn", true, false) as Button

func _ready() -> void:
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_ensure_nodes()
	if confirm_btn and not confirm_btn.pressed.is_connected(close_window):
		confirm_btn.pressed.connect(close_window)
	# The content can exceed a landscape phone; preserve readable text and
	# reachable buttons instead of spilling beyond the panel.
	_scroll = ScrollContainer.new()
	_scroll.name = "ContentScroll"
	panel.add_child(_scroll)
	_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scroll.offset_left = 20
	_scroll.offset_top = 20
	_scroll.offset_right = -20
	_scroll.offset_bottom = -20
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var content := panel.get_node("VBox") as VBoxContainer
	content.reparent(_scroll)
	content.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.follow_focus = true
	_footer=VBoxContainer.new()
	_footer.name="DecisionFooter"
	_footer.add_theme_constant_override("separation",8)
	panel.add_child(_footer)
	confirm_btn.reparent(_footer)
	confirm_btn.custom_minimum_size.y=48
	_signal_glass = preload("res://scripts/ui/system_signal_glass.gd").new()
	_signal_glass.name = "SignalGlass"
	_signal_glass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_signal_glass)
	panel.move_child(_signal_glass,0)
	_signal_glass.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := TextureRect.new()
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_SCALE
	background.texture = SYSTEM_GLASS
	background.modulate = Color(0.65,0.6,0.6,0.38)
	panel.add_child(background)
	panel.move_child(background,0)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	header_lbl.add_theme_color_override("font_color",Color(1,0.67,0.68))
	header_lbl.add_theme_font_size_override("font_size",15)
	title_lbl.add_theme_font_size_override("font_size",22)
	desc_lbl.add_theme_font_size_override("font_size",16)
	_style_button(confirm_btn)
	for label in [header_lbl,title_lbl,desc_lbl]: label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	get_viewport().size_changed.connect(_layout_panel)
	set_presentation_language(presentation_language)

func set_presentation_language(language: String) -> void:
	presentation_language = "en" if language == "en" else "ar"
	layout_direction = Control.LAYOUT_DIRECTION_RTL if presentation_language == "ar" else Control.LAYOUT_DIRECTION_LTR
	if confirm_btn: confirm_btn.text = "إغلاق" if presentation_language == "ar" else "Close"

func _layout_panel() -> void:
	if not panel or not _scroll: return
	# Native boot uses a 1920x1080 canvas. Keep this dialog's text and 48px
	# targets readable when the containing window is smaller than that canvas.
	var stretch:=get_viewport().get_stretch_transform().get_scale()
	stretch=Vector2(maxf(0.001,stretch.x),maxf(0.001,stretch.y))
	scale=Vector2.ONE/stretch
	var screen := get_viewport().get_visible_rect().size*stretch
	size=screen
	position=Vector2.ZERO
	panel.size.x = maxf(240, minf(480, screen.x - 48))
	var content := _scroll.get_child(0) as Control
	_footer.visible=confirm_btn.visible or (stats_box.get_parent()==_footer and stats_box.visible)
	_footer.size.x=panel.size.x-40
	var footer_height:float=_footer.get_combined_minimum_size().y if _footer.visible else 0.0
	var reserved:float=footer_height+12 if footer_height>0 else 0.0
	panel.size.y = minf(maxf(190, content.get_combined_minimum_size().y + 40+reserved), maxf(160,screen.y - 48))
	_footer.position=Vector2(20,panel.size.y-20-footer_height)
	_footer.size.y=footer_height
	_scroll.offset_bottom=-20-reserved
	panel.pivot_offset = panel.size * 0.5
	if _inspection_layout: panel.position=Vector2(24,screen.y-panel.size.y-24)
	elif _modal: panel.position = (screen - panel.size) * 0.5
	else: panel.position = Vector2(screen.x - panel.size.x - 24, 24)

func set_player(target: Node3D) -> void:
	follow_player = target

func _process(delta: float) -> void:
	if not visible or not panel:
		return
	_layout_panel()
	if _modal or not follow_player or not is_instance_valid(follow_player): return
	var camera: Camera3D = get_viewport().get_camera_3d()
	if not camera or camera.is_position_behind(follow_player.global_position):
		return
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var anchor: Vector2 = camera.unproject_position(follow_player.global_position + Vector3(0, 1.45, 0))
	var stretch:=get_viewport().get_stretch_transform().get_scale()
	viewport_size*=stretch
	anchor*=stretch
	var target_position := Vector2(
		clampf(anchor.x + 108.0, 24.0, viewport_size.x - panel.size.x - 24.0),
		clampf(anchor.y - 56.0, 24.0, viewport_size.y - panel.size.y - 24.0)
	)
	panel.position = panel.position.lerp(target_position, minf(1.0, delta * 13.0))

func blocks_quest_tracker() -> bool:
	return visible and (current_type == WindowType.LEVEL_UP or current_type == WindowType.REWARD)

func show_system_window(type: WindowType, title: String, message: String, stats: Array = [], auto_close_delay: float = 0.0) -> void:
	_ensure_nodes()
	var crisp_theme:=Theme.new()
	var crisp_font:=SYSTEM_FONT.duplicate() as FontFile
	crisp_font.oversampling=1.0
	crisp_font.allow_system_fallback=false
	crisp_theme.default_font=crisp_font
	theme=crisp_theme
	_window_generation += 1
	var generation: int = _window_generation
	current_type = type
	_inspection_layout=false
	if _signal_glass: _signal_glass.begin(reduced_motion,type == WindowType.SOLO_LEVELING_GLITCH)
	visible = true
	_modal = auto_close_delay <= 0
	if _modal: Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var shield := get_node("ClickShield") as Control
	shield.visible = _modal
	shield.mouse_filter = Control.MOUSE_FILTER_STOP if _modal else Control.MOUSE_FILTER_IGNORE
	var compact: bool = type == WindowType.NOTIFICATION or type == WindowType.QUEST_COMPLETED
	if panel:
		panel.size = Vector2(410.0, 190.0 if compact else 300.0)
		panel.pivot_offset = panel.size * 0.5
	if stats_box:
		stats_box.visible = not stats.is_empty()
	if confirm_btn:
		confirm_btn.visible = not compact or auto_close_delay <= 0.0
		confirm_btn.disabled = false
		if _modal: confirm_btn.grab_focus()

	if title_lbl:
		title_lbl.text = title
	if desc_lbl:
		desc_lbl.text = message

	# Clear previous stats
	if stats_box:
		var content:=_scroll.get_child(0)
		if stats_box.get_parent()!=content:
			stats_box.reparent(content)
		for child in stats_box.get_children():
			# A choice can synchronously open the next screen while pressed emits.
			# Detach immediately, but release after the signal finishes.
			stats_box.remove_child(child)
			child.queue_free()

		for stat_line in stats:
			var lbl = Label.new()
			lbl.text = "◈ " + str(stat_line)
			lbl.add_theme_color_override("font_color", Color(0.92, 0.8, 0.77, 1.0))
			lbl.add_theme_font_size_override("font_size", 13)
			stats_box.add_child(lbl)

	# Type styling
	if header_lbl:
		match type:
			WindowType.NOTIFICATION:
				header_lbl.text = "النظام // 11:11" if presentation_language == "ar" else "SYSTEM // 11:11"
				header_lbl.modulate = Color(0.0, 0.85, 1.0, 1.0)
			WindowType.QUEST_COMPLETED:
				header_lbl.text = "مهمة مكتملة // 11:11" if presentation_language == "ar" else "TASK COMPLETE // 11:11"
				header_lbl.modulate = Color(0.2, 1.0, 0.5, 1.0)
			WindowType.LEVEL_UP:
				header_lbl.text = "ارتقاء المستوى // 11:11" if presentation_language == "ar" else "LEVEL UP // 11:11"
				header_lbl.modulate = Color(1.0, 0.85, 0.2, 1.0)
			WindowType.REWARD:
				header_lbl.text = "مكافأة // 11:11" if presentation_language == "ar" else "SYSTEM GIFT // 11:11"
				header_lbl.modulate = Color(0.9, 0.4, 1.0, 1.0)

	# Animate pop-in
	if header_lbl: header_lbl.modulate = Color.WHITE
	if panel:
		if _popup_tween and _popup_tween.is_running():
			_popup_tween.kill()
		panel.scale = Vector2.ONE if reduced_motion else Vector2(0.96, 0.96)
		panel.modulate.a = 1.0 if reduced_motion else 0.0
		_layout_panel()
		var tree = get_tree() if is_inside_tree() else null
		if tree and not reduced_motion:
			_popup_tween = create_tween().set_parallel(true)
			_popup_tween.tween_property(panel, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			_popup_tween.tween_property(panel, "modulate:a", 1.0, 0.18)

			if auto_close_delay > 0.0:
				tree.create_timer(auto_close_delay).timeout.connect(_close_if_generation.bind(generation))
		else:
			panel.scale = Vector2.ONE
			panel.modulate.a = 1.0
			if tree and auto_close_delay > 0:
				tree.create_timer(auto_close_delay).timeout.connect(_close_if_generation.bind(generation))

	emit_signal("system_window_opened", current_type)

func set_inspection_layout() -> void:
	_inspection_layout=true
	_layout_panel()

func _close_if_generation(generation: int) -> void:
	if visible and generation == _window_generation:
		close_window()

func show_quest_update(completed_title: String, next_title: String) -> void:
	show_system_window(
		WindowType.QUEST_COMPLETED,
		"مهمة مكتملة // TASK COMPLETE",
		completed_title + "\n◈ التالي: " + next_title,
		[],
		3.5
	)

func close_window() -> void:
	_ensure_nodes()
	_window_generation += 1
	visible = false
	get_node("ClickShield").hide()
	emit_signal("system_window_closed", current_type)

# Convenience shortcuts
func show_level_up(level_num: int = 2) -> void:
	show_system_window(
		WindowType.LEVEL_UP,
		"LEVEL UP! [LV. %02d]" % level_num,
		"لقد استوفيت شروط النظام. تم فتح قيود القوة الكامنة.",
		[
			"HP CAPACITY: 200 -> 250 (+50)",
			"ATTACK POWER: +25% [ESSENCE OF ZEO]",
			"SINGULARITY: RIGHT EYE AURA UNLOCKED",
			"PASSIVE: SHADOW CORROSION RESISTANCE"
		]
	)

func show_reward_window(item_name: String = "SHADOW KATANA // نصل ملوك الظلال", subtitle: String = "") -> void:
	var desc = subtitle if subtitle != "" else "قرر النظام منحك سلاحاً يتناسب مع تطورك في المنشأة:"
	show_system_window(
		WindowType.REWARD,
		"SYSTEM GIFT ACQUIRED",
		desc,
		[
			"ITEM: " + item_name,
			"TYPE: COLD WEAPON / DARK FLAME RESONANCE",
			"CRITICAL IAI DAMAGE: 180 -> 240 (+60)",
			"EFFECT: SHADOW TRAILS & VOID SLICE ACTIVE"
		]
	)

func show_decision(title: String, message: String, choices: Array, callback: Callable = Callable()) -> void:
	show_system_window(WindowType.SOLO_LEVELING_GLITCH, title, message)
	header_lbl.text = "النظام // 11:11" if presentation_language == "ar" else "SYSTEM // 11:11"
	header_lbl.modulate = Color.WHITE
	title_lbl.modulate = Color.WHITE
	desc_lbl.modulate = Color.WHITE
	confirm_btn.hide()
	stats_box.show()
	stats_box.reparent(_footer)
	var generation := _window_generation
	for choice: Dictionary in choices:
		var button := Button.new()
		button.text = choice["text"]
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.custom_minimum_size.y = 48
		_style_button(button)
		stats_box.add_child(button)
		button.pressed.connect(_choose_decision.bind(String(choice["id"]),generation,callback))
	if stats_box.get_child_count() > 0: stats_box.get_child(0).grab_focus()
	_layout_panel()

func _choose_decision(id: String, generation: int, callback: Callable) -> void:
	if not visible or generation != _window_generation: return
	if not reduced_motion:
		preload("res://scripts/ui/system_window_fracture.gd").play(self,panel)
	close_window()
	decision_made.emit(id)
	if callback.is_valid(): callback.call(id)

func _style_button(button: Button) -> void:
	if not button: return
	button.add_theme_color_override("font_color",Color(1,0.94,0.89))
	button.add_theme_color_override("font_hover_color",Color.WHITE)
	button.add_theme_font_size_override("font_size",16)
	for kind in ["normal","hover","pressed","focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.12,0.025,0.034,0.96) if kind == "normal" else Color(0.22,0.045,0.055,0.98)
		style.border_color = Color(0.7,0.18,0.23) if kind != "focus" else Color(1,0.82,0.73)
		style.set_border_width_all(2 if kind == "focus" else 1)
		style.set_corner_radius_all(4)
		style.content_margin_left = 14
		style.content_margin_right = 14
		style.content_margin_top = 10
		style.content_margin_bottom = 10
		button.add_theme_stylebox_override(kind,style)

func show_solo_leveling_glitch_prompt(on_choice_callback: Callable = Callable()) -> void:
	# Approved PDF page 61: one specific wish, then an explicit acceptance.
	# Do not substitute an automatic timer or unrelated second answer.
	var ar := presentation_language == "ar"
	show_decision("لقد تجاوزت حدودك" if ar else "You have exceeded your limits",
		"ما هي أمنيتك؟\n\nالخروج… والانتقام من كل من له علاقة بالنظام، مهما كان الثمن.\n\nهل تقبل؟" if ar else "What is your wish?\n\nEscape… and take revenge on everyone connected to the System, whatever the cost.\n\nDo you accept?",
		[{"id":"ESCAPE_SYSTEM_AT_ANY_COST", "text":"نعم، أقبل." if ar else "Yes, I accept."}],
		func(id: String):
			solo_leveling_choice_made.emit(id)
			if on_choice_callback.is_valid(): on_choice_callback.call(id)
	)

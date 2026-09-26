extends Control

signal system_window_opened(type)
signal system_window_closed(type)
signal solo_leveling_choice_made(choice_id: String)

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
	_ensure_nodes()
	if confirm_btn and not confirm_btn.pressed.is_connected(close_window):
		confirm_btn.pressed.connect(close_window)

func set_player(target: Node3D) -> void:
	follow_player = target

func _process(delta: float) -> void:
	if not visible or not panel or not follow_player or not is_instance_valid(follow_player):
		return
	var camera: Camera3D = get_viewport().get_camera_3d()
	if not camera or camera.is_position_behind(follow_player.global_position):
		return
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var anchor: Vector2 = camera.unproject_position(follow_player.global_position + Vector3(0, 1.45, 0))
	var target_position := Vector2(
		clampf(anchor.x + 108.0, 24.0, viewport_size.x - panel.size.x - 24.0),
		clampf(anchor.y - 56.0, 24.0, viewport_size.y - panel.size.y - 24.0)
	)
	panel.position = panel.position.lerp(target_position, minf(1.0, delta * 13.0))

func blocks_quest_tracker() -> bool:
	return visible and (current_type == WindowType.LEVEL_UP or current_type == WindowType.REWARD)

func show_system_window(type: WindowType, title: String, message: String, stats: Array = [], auto_close_delay: float = 0.0) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_ensure_nodes()
	_window_generation += 1
	var generation: int = _window_generation
	current_type = type
	visible = true
	var compact: bool = type == WindowType.NOTIFICATION or type == WindowType.QUEST_COMPLETED
	if panel:
		panel.size = Vector2(410.0, 190.0 if compact else 300.0)
		panel.pivot_offset = panel.size * 0.5
	if stats_box:
		stats_box.visible = not stats.is_empty()
	if confirm_btn:
		confirm_btn.visible = not compact or auto_close_delay <= 0.0

	if title_lbl:
		title_lbl.text = title
	if desc_lbl:
		desc_lbl.text = message

	# Clear previous stats
	if stats_box:
		for child in stats_box.get_children():
			child.queue_free()

		for stat_line in stats:
			var lbl = Label.new()
			lbl.text = "◈ " + str(stat_line)
			lbl.add_theme_color_override("font_color", Color(0.15, 0.95, 1.0, 1.0))
			lbl.add_theme_font_size_override("font_size", 13)
			stats_box.add_child(lbl)

	# Type styling
	if header_lbl:
		match type:
			WindowType.NOTIFICATION:
				header_lbl.text = "◈ [ SYSTEM NOTIFICATION // إشعار النظام ] ◈"
				header_lbl.modulate = Color(0.0, 0.85, 1.0, 1.0)
			WindowType.QUEST_COMPLETED:
				header_lbl.text = "◈ [ QUEST COMPLETED // تم إنجاز المهمة ] ◈"
				header_lbl.modulate = Color(0.2, 1.0, 0.5, 1.0)
			WindowType.LEVEL_UP:
				header_lbl.text = "★ [ LEVEL UP // ارتقاء المستوى المكتسب ] ★"
				header_lbl.modulate = Color(1.0, 0.85, 0.2, 1.0)
			WindowType.REWARD:
				header_lbl.text = "◆ [ SYSTEM GIFT // مكافأة النظام الكبرى ] ◆"
				header_lbl.modulate = Color(0.9, 0.4, 1.0, 1.0)

	# Animate pop-in
	if panel:
		if _popup_tween and _popup_tween.is_running():
			_popup_tween.kill()
		panel.scale = Vector2(0.85, 0.85)
		panel.modulate.a = 0.0
		var tree = get_tree() if is_inside_tree() else null
		if tree:
			_popup_tween = tree.create_tween().set_parallel(true)
			_popup_tween.tween_property(panel, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			_popup_tween.tween_property(panel, "modulate:a", 1.0, 0.18)

			if auto_close_delay > 0.0:
				tree.create_timer(auto_close_delay).timeout.connect(func():
					if visible and generation == _window_generation:
						close_window()
				)
		else:
			panel.scale = Vector2.ONE
			panel.modulate.a = 1.0

	emit_signal("system_window_opened", current_type)

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

func show_solo_leveling_glitch_prompt(on_choice_callback: Callable = Callable()) -> void:
	current_type = WindowType.SOLO_LEVELING_GLITCH
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_ensure_nodes()
	if header_lbl:
		header_lbl.text = "SYSTEM // UNREGISTERED SINGULARITY DETECTED [ERROR 11:11]"
		header_lbl.modulate = Color(1.0, 0.15, 0.25)
	if title_lbl:
		title_lbl.text = "لقد تعديت حدودك // LIMIT EXCEEDED"
		title_lbl.modulate = Color(1.0, 0.9, 0.95)
	if desc_lbl:
		desc_lbl.text = "توقف كل شيء في المحاكاة العصبية.\nيصل النظام إلى نقطة الانهيار... ما هي أمنيتك؟"
		desc_lbl.modulate = Color(0.9, 0.7, 0.75)
	if stats_box:
		for c in stats_box.get_children():
			c.queue_free()
		var btn1 := Button.new()
		btn1.text = "✦ [ الانتقام والخروج من النظام مهما كان الثمن ]"
		btn1.modulate = Color(1.0, 0.2, 0.35)
		btn1.custom_minimum_size.y = 44
		stats_box.add_child(btn1)
		var btn2 := Button.new()
		btn2.text = "✦ [ نعم... لا أهتم بما سيحدث ]"
		btn2.modulate = Color(0.7, 0.75, 0.85)
		btn2.custom_minimum_size.y = 36
		stats_box.add_child(btn2)
		btn1.pressed.connect(func():
			visible = false
			emit_signal("solo_leveling_choice_made", "REVENGE_AT_ALL_COSTS")
			if on_choice_callback.is_valid():
				on_choice_callback.call("REVENGE_AT_ALL_COSTS")
		)
		btn2.pressed.connect(func():
			visible = false
			emit_signal("solo_leveling_choice_made", "ACCEPT_DONT_CARE")
			if on_choice_callback.is_valid():
				on_choice_callback.call("ACCEPT_DONT_CARE")
		)
	if confirm_btn:
		confirm_btn.visible = false
	emit_signal("system_window_opened", current_type)


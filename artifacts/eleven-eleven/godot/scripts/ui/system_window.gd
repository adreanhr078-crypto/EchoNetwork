extends Control

signal system_window_opened(type)
signal system_window_closed(type)

enum WindowType {
	NOTIFICATION,
	QUEST_COMPLETED,
	LEVEL_UP,
	REWARD
}

var current_type: WindowType = WindowType.NOTIFICATION

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

func show_system_window(type: WindowType, title: String, message: String, stats: Array = [], auto_close_delay: float = 0.0) -> void:
	_ensure_nodes()
	current_type = type
	visible = true

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
		panel.scale = Vector2(0.85, 0.85)
		panel.modulate.a = 0.0
		var tree = get_tree() if is_inside_tree() else null
		if tree:
			var tween = tree.create_tween().set_parallel(true)
			tween.tween_property(panel, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tween.tween_property(panel, "modulate:a", 1.0, 0.18)

			if auto_close_delay > 0.0:
				tree.create_timer(auto_close_delay).timeout.connect(func():
					if visible:
						close_window()
				)
		else:
			panel.scale = Vector2.ONE
			panel.modulate.a = 1.0

	emit_signal("system_window_opened", current_type)

func close_window() -> void:
	_ensure_nodes()
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

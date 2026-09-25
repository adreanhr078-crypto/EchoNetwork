class_name LootNotificationFeed
extends Control

## AAA Loot Notification Toast Feed
## Genshin-tier floating loot cards that slide in from the right when items, yen, or chest rewards are acquired.
## Features rarity tier color accents, animated slide/fade tweening, and crystalline audio chimes.

signal loot_toast_spawned(item_name: String, amount: int, rarity: String)
signal loot_toast_dismissed(item_name: String)

const ProceduralCinematicAudio = preload("res://scripts/audio/procedural_cinematic_audio.gd")

const RARITY_COLORS: Dictionary = {
	"COMMON": Color(0.82, 0.85, 0.90, 1.0),
	"EXQUISITE": Color(0.0, 0.94, 1.0, 1.0),
	"PRECIOUS": Color(0.78, 0.22, 1.0, 1.0),
	"LUXURIOUS": Color(1.0, 0.84, 0.12, 1.0)
}

var active_toasts: Array = []
var max_concurrent_toasts: int = 4
var toast_vbox: VBoxContainer = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_setup_container()

func _setup_container() -> void:
	if toast_vbox:
		return
	toast_vbox = find_child("ToastVBox", true, false) as VBoxContainer
	if not toast_vbox:
		toast_vbox = VBoxContainer.new()
		toast_vbox.name = "ToastVBox"
		toast_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		toast_vbox.add_theme_constant_override("separation", 8)
		add_child(toast_vbox)
		toast_vbox.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		toast_vbox.offset_left = -280.0
		toast_vbox.offset_top = 110.0
		toast_vbox.offset_right = -24.0
		toast_vbox.offset_bottom = 400.0

## Adds a new loot toast notification to the stack
func show_loot(item_name: String, amount: int = 1, rarity: String = "COMMON", category: String = "ITEM") -> Dictionary:
	_setup_container()
	var clean_rarity: String = rarity.to_upper()
	if not RARITY_COLORS.has(clean_rarity):
		clean_rarity = "COMMON"
	var border_color: Color = RARITY_COLORS[clean_rarity]

	# Build Card Panel
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(250.0, 44.0)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.015, 0.025, 0.045, 0.88)
	style.border_width_left = 4
	style.border_color = border_color
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	card.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_theme_constant_override("separation", 10)
	card.add_child(hbox)

	# Rarity Gem / Category Icon Indicator
	var gem := ColorRect.new()
	gem.custom_minimum_size = Vector2(10.0, 10.0)
	gem.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	gem.color = border_color
	hbox.add_child(gem)

	# Item Name Label
	var name_lbl := Label.new()
	name_lbl.text = item_name
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_color_override("font_color", Color(0.95, 0.96, 0.98, 1.0))
	name_lbl.add_theme_font_size_override("font_size", 14)
	hbox.add_child(name_lbl)

	# Amount Badge Label
	var amount_lbl := Label.new()
	amount_lbl.text = "+" + str(amount) if amount > 0 else str(amount)
	if category == "CURRENCY":
		amount_lbl.text = "+" + str(amount) + " ¥"
	amount_lbl.add_theme_color_override("font_color", border_color)
	amount_lbl.add_theme_font_size_override("font_size", 14)
	hbox.add_child(amount_lbl)

	toast_vbox.add_child(card)
	active_toasts.append(card)

	# Audio Chime
	if is_inside_tree():
		var audio := AudioStreamPlayer.new()
		add_child(audio)
		audio.stream = ProceduralCinematicAudio.create_loot_toast_chime()
		audio.play()
		audio.finished.connect(func(): audio.queue_free())

	# Animated Entrance & Auto-Dismiss
	card.modulate.a = 0.0
	card.position.x = 60.0
	var tree := get_tree() if is_inside_tree() else null
	if tree:
		var tween := tree.create_tween()
		tween.tween_property(card, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(card, "position:x", 0.0, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_interval(2.4)
		tween.tween_property(card, "modulate:a", 0.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.parallel().tween_property(card, "position:x", 40.0, 0.35)
		tween.tween_callback(func():
			if is_instance_valid(card):
				active_toasts.erase(card)
				card.queue_free()
				emit_signal("loot_toast_dismissed", item_name)
		)

	emit_signal("loot_toast_spawned", item_name, amount, clean_rarity)
	return {
		"item_name": item_name,
		"amount": amount,
		"rarity": clean_rarity,
		"color": border_color
	}

func get_active_toast_count() -> int:
	return active_toasts.size()

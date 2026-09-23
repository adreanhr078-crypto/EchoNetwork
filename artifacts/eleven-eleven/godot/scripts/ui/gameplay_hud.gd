class_name GameplayHUD
extends CanvasLayer

@onready var player_hp_bar: ProgressBar = $VitalsContainer/PlayerHPBar if has_node("VitalsContainer/PlayerHPBar") else null
@onready var player_stamina_bar: ProgressBar = $VitalsContainer/PlayerStaminaBar if has_node("VitalsContainer/PlayerStaminaBar") else null
@onready var combo_container: Control = $ComboContainer if has_node("ComboContainer") else null
@onready var combo_label: Label = $ComboContainer/ComboLabel if has_node("ComboContainer/ComboLabel") else null
@onready var combo_badge: Label = $ComboContainer/ComboBadge if has_node("ComboContainer/ComboBadge") else null

@onready var boss_container: Control = $BossContainer if has_node("BossContainer") else null
@onready var boss_hp_bar: ProgressBar = $BossContainer/BossHPBar if has_node("BossContainer/BossHPBar") else null

@onready var phase2_banner: Control = $Phase2Banner if has_node("Phase2Banner") else null
@onready var stagger_banner: Control = $StaggerBanner if has_node("StaggerBanner") else null
@onready var slam_warning_banner: Control = $SlamWarningBanner if has_node("SlamWarningBanner") else null

@onready var intro_banner: Control = $IntroBanner if has_node("IntroBanner") else null
@onready var intro_title: Label = $IntroBanner/Title if has_node("IntroBanner/Title") else null
@onready var intro_subtitle: Label = $IntroBanner/Subtitle if has_node("IntroBanner/Subtitle") else null

func show_boss_intro(title: String, subtitle: String, duration: float = 3.0) -> void:
	if intro_banner:
		if intro_title:
			intro_title.text = title
		if intro_subtitle:
			intro_subtitle.text = subtitle
		intro_banner.visible = true
		intro_banner.modulate.a = 0.0
		var tween = create_tween()
		tween.tween_property(intro_banner, "modulate:a", 1.0, 0.4)
		tween.tween_interval(max(0.2, duration - 0.8))
		tween.tween_property(intro_banner, "modulate:a", 0.0, 0.4)
		tween.tween_callback(func(): intro_banner.visible = false)

func update_player_hp(current: float, max_val: float) -> void:
	if player_hp_bar:
		player_hp_bar.max_value = max_val
		player_hp_bar.value = current

func update_player_stamina(current: float, max_val: float) -> void:
	if player_stamina_bar:
		player_stamina_bar.max_value = max_val
		player_stamina_bar.value = current

func update_combo(count: int, multiplier: int) -> void:
	if combo_container:
		combo_container.visible = count >= 2
		if combo_label:
			combo_label.text = str(count)
		if combo_badge:
			if multiplier >= 3:
				combo_badge.text = "✦ MAX CHAIN ×3"
				combo_badge.modulate = Color(1.0, 0.75, 0.1)
			elif multiplier >= 2:
				combo_badge.text = "✦ CHAIN ×2"
				combo_badge.modulate = Color(0.3, 1.0, 0.8)
			else:
				combo_badge.text = "HIT CHAIN"
				combo_badge.modulate = Color(0.8, 0.9, 1.0)

func update_boss_hp(current: float, max_val: float) -> void:
	if boss_hp_bar:
		boss_hp_bar.max_value = max_val
		boss_hp_bar.value = current
	if boss_container:
		boss_container.visible = current > 0.0

func set_phase2(active: bool) -> void:
	if phase2_banner:
		phase2_banner.visible = active
	if boss_hp_bar:
		boss_hp_bar.modulate = Color(1.0, 0.2, 0.3) if active else Color(0.2, 0.8, 1.0)

func set_stagger(active: bool) -> void:
	if stagger_banner:
		stagger_banner.visible = active

func set_slam_warning(active: bool) -> void:
	if slam_warning_banner:
		slam_warning_banner.visible = active

@onready var victory_banner: Control = $VictoryBanner if has_node("VictoryBanner") else null
@onready var victory_title: Label = $VictoryBanner/TitleCard/Title if has_node("VictoryBanner/TitleCard/Title") else null
@onready var victory_subtitle: Label = $VictoryBanner/TitleCard/Subtitle if has_node("VictoryBanner/TitleCard/Subtitle") else null

func show_victory_banner(title: String = "TARGET NEUTRALIZED", subtitle: String = "SECTOR 11 CONTAINMENT RESTORED // SPECIMEN DISSOLVED", duration: float = 4.0) -> void:
	if not victory_banner:
		victory_banner = find_child("VictoryBanner", true, false)
	if victory_banner:
		if not victory_title:
			victory_title = victory_banner.find_child("Title", true, false)
		if not victory_subtitle:
			victory_subtitle = victory_banner.find_child("Subtitle", true, false)
		if victory_title:
			victory_title.text = title
		if victory_subtitle:
			victory_subtitle.text = subtitle
		victory_banner.visible = true
		victory_banner.modulate.a = 0.0
		var tree = get_tree() if is_inside_tree() else null
		if tree:
			var tween = tree.create_tween()
			tween.tween_property(victory_banner, "modulate:a", 1.0, 0.6)
			tween.tween_interval(duration)
			tween.tween_property(victory_banner, "modulate:a", 0.0, 0.8)
			tween.tween_callback(func(): victory_banner.visible = false)
		else:
			victory_banner.modulate.a = 1.0

@onready var quest_container: Control = $QuestContainer if has_node("QuestContainer") else null
@onready var quest_title: Label = $QuestContainer/QuestTitle if has_node("QuestContainer/QuestTitle") else null
@onready var quest_desc: Label = $QuestContainer/QuestDesc if has_node("QuestContainer/QuestDesc") else null
@onready var mobile_controls: Control = $MobileTouchControls if has_node("MobileTouchControls") else null

var current_directive_title: String = ""
var current_directive_desc: String = ""

func set_directive(title: String, desc: String) -> void:
	current_directive_title = title
	current_directive_desc = desc
	if not quest_title:
		quest_title = find_child("QuestTitle", true, false)
	if not quest_desc:
		quest_desc = find_child("QuestDesc", true, false)
	if quest_title:
		quest_title.text = title
	if quest_desc:
		quest_desc.text = desc

	if quest_container:
		quest_container.modulate = Color(0.0, 0.95, 1.0, 1.0)
		var tree = get_tree() if is_inside_tree() else null
		if tree:
			var tween = tree.create_tween()
			tween.tween_property(quest_container, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.5)

func complete_directive(next_title: String, next_desc: String) -> void:
	set_directive(next_title, next_desc)
	if quest_container:
		quest_container.modulate = Color(0.2, 1.0, 0.5, 1.0)
		var tree = get_tree() if is_inside_tree() else null
		if tree:
			var tween = tree.create_tween()
			tween.tween_property(quest_container, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.6)

@onready var terminal_puzzle: Control = $TerminalHackPuzzle if has_node("TerminalHackPuzzle") else null
@onready var dialogue_overlay: Control = $DialogueOverlay if has_node("DialogueOverlay") else null

func open_terminal_puzzle() -> void:
	if not terminal_puzzle:
		terminal_puzzle = find_child("TerminalHackPuzzle", true, false)
	if terminal_puzzle and terminal_puzzle.has_method("open_puzzle"):
		terminal_puzzle.open_puzzle()

func close_terminal_puzzle() -> void:
	if not terminal_puzzle:
		terminal_puzzle = find_child("TerminalHackPuzzle", true, false)
	if terminal_puzzle and terminal_puzzle.has_method("close_puzzle"):
		terminal_puzzle.close_puzzle()

func start_dialogue(lines: Array = []) -> void:
	if not dialogue_overlay:
		dialogue_overlay = find_child("DialogueOverlay", true, false)
	if dialogue_overlay and dialogue_overlay.has_method("start_dialogue"):
		dialogue_overlay.start_dialogue(lines)

@onready var system_window: Control = $SystemWindow if has_node("SystemWindow") else null

func show_level_up(level_num: int = 2) -> void:
	if not system_window:
		system_window = find_child("SystemWindow", true, false)
	if system_window and system_window.has_method("show_level_up"):
		system_window.show_level_up(level_num)

func show_system_reward(item_name: String = "SHADOW KATANA // نصل ملوك الظلال", subtitle: String = "") -> void:
	if not system_window:
		system_window = find_child("SystemWindow", true, false)
	if system_window and system_window.has_method("show_reward_window"):
		system_window.show_reward_window(item_name, subtitle)

func close_system_window() -> void:
	if not system_window:
		system_window = find_child("SystemWindow", true, false)
	if system_window and system_window.has_method("close_window"):
		system_window.close_window()

@onready var interaction_prompt: Control = $InteractionPromptHUD if has_node("InteractionPromptHUD") else null

func show_interaction_prompt(interactable: Node) -> void:
	if not interaction_prompt:
		interaction_prompt = find_child("InteractionPromptHUD", true, false)
	if interaction_prompt and interaction_prompt.has_method("show_prompt"):
		interaction_prompt.show_prompt(interactable)

func hide_interaction_prompt() -> void:
	if not interaction_prompt:
		interaction_prompt = find_child("InteractionPromptHUD", true, false)
	if interaction_prompt and interaction_prompt.has_method("hide_prompt"):
		interaction_prompt.hide_prompt()






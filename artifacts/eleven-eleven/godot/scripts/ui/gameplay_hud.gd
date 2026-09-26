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

const ProceduralCinematicAudio = preload("res://scripts/audio/procedural_cinematic_audio.gd")

var ghost_hp_bar: ProgressBar = null
var ghost_tween: Tween = null

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

func _setup_ghost_hp_bar(max_val: float) -> void:
	if ghost_hp_bar != null:
		return
	if not player_hp_bar:
		player_hp_bar = find_child("PlayerHPBar", true, false) as ProgressBar
	if player_hp_bar:
		ghost_hp_bar = player_hp_bar.find_child("GhostHPBar", true, false) as ProgressBar
		if not ghost_hp_bar:
			ghost_hp_bar = ProgressBar.new()
			ghost_hp_bar.name = "GhostHPBar"
			ghost_hp_bar.show_percentage = false
			ghost_hp_bar.modulate = Color(1.0, 0.42, 0.42, 0.85)
			ghost_hp_bar.max_value = max_val
			ghost_hp_bar.value = player_hp_bar.value
			player_hp_bar.add_child(ghost_hp_bar)
			ghost_hp_bar.set_anchors_preset(Control.PRESET_FULL_RECT)
			player_hp_bar.move_child(ghost_hp_bar, 0)

func update_player_hp(current: float, max_val: float) -> void:
	if not player_hp_bar:
		player_hp_bar = find_child("PlayerHPBar", true, false) as ProgressBar
	if player_hp_bar:
		_setup_ghost_hp_bar(max_val)
		var old_val: float = player_hp_bar.value
		player_hp_bar.max_value = max_val
		player_hp_bar.value = current
		if ghost_hp_bar:
			ghost_hp_bar.max_value = max_val
			if current < old_val:
				# Damage taken: ghost bar holds briefly then catches up
				if ghost_tween and ghost_tween.is_valid():
					ghost_tween.kill()
				var tree = get_tree() if is_inside_tree() else null
				if tree:
					ghost_tween = tree.create_tween()
					ghost_tween.tween_interval(0.22)
					ghost_tween.tween_property(ghost_hp_bar, "value", current, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				else:
					ghost_hp_bar.value = current
			else:
				ghost_hp_bar.value = current

func update_player_stamina(current: float, max_val: float) -> void:
	if not player_stamina_bar:
		player_stamina_bar = find_child("PlayerStaminaBar", true, false) as ProgressBar
	if player_stamina_bar:
		player_stamina_bar.max_value = max_val
		player_stamina_bar.value = current
		var ratio: float = current / maxf(1.0, max_val)
		if ratio < 0.25 and ratio > 0.0:
			player_stamina_bar.modulate = Color(1.0, 0.65, 0.2, 1.0)
		elif ratio <= 0.0:
			player_stamina_bar.modulate = Color(1.0, 0.25, 0.25, 1.0)
		else:
			player_stamina_bar.modulate = Color(1.0, 1.0, 1.0, 1.0)

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
var follow_player: Node3D = null

func set_player(target: Node3D) -> void:
	follow_player = target
	if system_window and system_window.has_method("set_player"):
		system_window.set_player(target)

func _process(delta: float) -> void:
	if not quest_container:
		return
	var overlay_open: bool = (terminal_puzzle and terminal_puzzle.visible) or (dialogue_overlay and dialogue_overlay.visible)
	var major_system_window: bool = false
	if system_window and system_window.has_method("blocks_quest_tracker"):
		major_system_window = bool(system_window.call("blocks_quest_tracker"))
	quest_container.visible = not overlay_open and not major_system_window
	if not quest_container.visible:
		return
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var safe_margin: float = 30.0
	var target_position := Vector2(
		maxf(safe_margin, viewport_size.x - quest_container.size.x - safe_margin),
		maxf(safe_margin, viewport_size.y * 0.12)
	)
	quest_container.position = quest_container.position.lerp(target_position, minf(1.0, delta * 14.0))
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
	var completed_title: String = current_directive_title
	set_directive(next_title, next_desc)
	if system_window and system_window.has_method("show_quest_update") and completed_title != "":
		system_window.show_quest_update(completed_title, next_title)
	if is_inside_tree():
		var fanfare := AudioStreamPlayer.new()
		fanfare.name = "QuestFanfare"
		add_child(fanfare)
		fanfare.stream = ProceduralCinematicAudio.create_quest_complete_fanfare()
		fanfare.volume_db = -3.0
		fanfare.play()
		fanfare.finished.connect(func(): if is_instance_valid(fanfare): fanfare.queue_free())
	if quest_container:
		quest_container.modulate = Color(0.2, 1.0, 0.5, 1.0)
		var tree = get_tree() if is_inside_tree() else null
		if tree:
			var tween = tree.create_tween()
			tween.tween_property(quest_container, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.6)

@onready var terminal_puzzle: Control = $TerminalHackPuzzle if has_node("TerminalHackPuzzle") else null
@onready var dialogue_overlay: Control = $DialogueOverlay if has_node("DialogueOverlay") else null

func open_terminal_puzzle() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
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

const LootNotificationFeedScript = preload("res://scripts/ui/loot_notification_feed.gd")
const CompassRadarBarScript = preload("res://scripts/ui/compass_radar_bar.gd")

var _loot_feed: LootNotificationFeedScript = null
var loot_feed: LootNotificationFeedScript:
	get:
		if not _loot_feed:
			_loot_feed = find_child("LootNotificationFeed", true, false) as LootNotificationFeedScript
			if not _loot_feed and is_inside_tree():
				_loot_feed = LootNotificationFeedScript.new()
				_loot_feed.name = "LootNotificationFeed"
				add_child(_loot_feed)
			elif not _loot_feed:
				_loot_feed = LootNotificationFeedScript.new()
				_loot_feed.name = "LootNotificationFeed"
		return _loot_feed
	set(val):
		_loot_feed = val

var _compass_bar: CompassRadarBarScript = null
var compass_bar: CompassRadarBarScript:
	get:
		if not _compass_bar:
			_compass_bar = find_child("CompassRadarBar", true, false) as CompassRadarBarScript
			if not _compass_bar and is_inside_tree():
				_compass_bar = CompassRadarBarScript.new()
				_compass_bar.name = "CompassRadarBar"
				add_child(_compass_bar)
				_compass_bar.set_anchors_preset(Control.PRESET_CENTER_TOP)
				_compass_bar.offset_top = 16.0
				_compass_bar.offset_left = -230.0
				_compass_bar.offset_right = 230.0
				_compass_bar.offset_bottom = 50.0
			elif not _compass_bar:
				_compass_bar = CompassRadarBarScript.new()
				_compass_bar.name = "CompassRadarBar"
		return _compass_bar
	set(val):
		_compass_bar = val

func show_loot_toast(item_name: String, amount: int = 1, rarity: String = "COMMON", category: String = "ITEM") -> Dictionary:
	return loot_feed.show_loot(item_name, amount, rarity, category)

func update_compass(cam_yaw: float, player_pos: Vector3) -> void:
	compass_bar.update_compass(cam_yaw, player_pos)

func add_compass_marker(id: String, world_pos: Vector3, label: String, type: String = "QUEST") -> void:
	compass_bar.add_marker(id, world_pos, label, type)

func remove_compass_marker(id: String) -> void:
	compass_bar.remove_marker(id)

const TutorialToastSystemScript = preload("res://scripts/ui/tutorial_toast_system.gd")

var _tutorial_toast: TutorialToastSystemScript = null
var tutorial_toast: TutorialToastSystemScript:
	get:
		if not _tutorial_toast:
			_tutorial_toast = find_child("TutorialToastSystem", true, false) as TutorialToastSystemScript
			if not _tutorial_toast and is_inside_tree():
				_tutorial_toast = TutorialToastSystemScript.new()
				_tutorial_toast.name = "TutorialToastSystem"
				add_child(_tutorial_toast)
			elif not _tutorial_toast:
				_tutorial_toast = TutorialToastSystemScript.new()
				_tutorial_toast.name = "TutorialToastSystem"
		return _tutorial_toast
	set(val):
		_tutorial_toast = val

func show_tutorial_toast(toast_id: String, keycap: String, title: String, description: String, timeout: float = 5.0) -> void:
	tutorial_toast.show_toast(toast_id, keycap, title, description, timeout)

func complete_tutorial_action(toast_id: String) -> void:
	tutorial_toast.complete_action(toast_id)

func notify_in_game_dialogue(speaker: String, text: String, color: Color = Color.WHITE) -> void:
	if has_method("start_dialogue"):
		start_dialogue([{"speaker": speaker, "speaker_color": color, "text": text}])




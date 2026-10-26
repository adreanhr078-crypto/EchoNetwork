extends Control
const SYSTEM_FONT=preload("res://assets/fonts/NotoSansArabic.ttf")
const SYSTEM_GLASS=preload("res://assets/ui/system-red-glass-v1.png")
const NativeUIDensity = preload("res://scripts/ui/native_ui_density.gd")

signal system_window_opened(type)
signal system_window_closed(type)
signal solo_leveling_choice_made(choice_id: String)
signal decision_made(choice_id: String)

enum WindowType {
	NOTIFICATION,
	QUEST_COMPLETED,
	LEVEL_UP,
	REWARD,
	SOLO_LEVELING_GLITCH,
	EXPERIENCE_GAIN,
	TASK_ASSIGNED,
	TASK_PROGRESS
}

var current_type: WindowType = WindowType.NOTIFICATION
var follow_player: Node3D = null
var _window_generation: int = 0
var _popup_tween: Tween = null
var reduced_motion := false:
	set(value):
		reduced_motion = value
		if value and is_node_ready():
			if _popup_tween and _popup_tween.is_valid(): _popup_tween.kill()
			if panel:
				panel.scale = Vector2.ONE
				panel.modulate.a = 0.0 if _closing else 1.0
			if _closing:
				visible = false
				_closing=false
				_drain_notices.call_deferred()
			if _progress_tween and _progress_tween.is_valid(): _progress_tween.kill()
			if _progress_bar and not _active_notice.is_empty(): _progress_bar.value=_active_notice.get("to",0)
			if _signal_glass: _signal_glass.begin(true, current_type == WindowType.SOLO_LEVELING_GLITCH)
var _closing := false
var presentation_language := "ar"
var _modal := false
var _inspection_layout:=false
var _scroll: ScrollContainer
var _footer:VBoxContainer
var _signal_glass: Control
var _glass_background: TextureRect
var _identity: Label
var _progress_bar: ProgressBar
var _progress_label: Label
var _pending_notices: Array[Dictionary] = []
var _seen_notice_ids: Dictionary = {}
var _active_notice: Dictionary = {}
var _draining_notice := false
var _notice_suspended := false
var _notice_remaining := 0.0
var _notice_audio: AudioStreamPlayer
var _progress_tween: Tween
var _accent := Color(.25,.85,1.0)
var _follow_initialized := false
var _status_view := false
var _status_snapshot: Dictionary = {}
var _status_age := 0.0
var _convenience_serial := 0
var _localized_decision: Dictionary = {}

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
	# Keep one font/theme for this window's lifetime. Replacing FontFile RIDs
	# on every message can invalidate an in-flight shaped Arabic/Latin run.
	var crisp_theme:=Theme.new()
	var crisp_font:=SYSTEM_FONT.duplicate() as FontFile
	crisp_font.oversampling=1.0
	crisp_font.allow_system_fallback=false
	crisp_theme.default_font=crisp_font
	theme=crisp_theme
	_identity=Label.new()
	_identity.name="EchoIdentity"
	_identity.add_theme_font_size_override("font_size",12)
	_identity.add_theme_color_override("font_color",Color(.57,.72,.82))
	_identity.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var identity_row:=HBoxContainer.new()
	identity_row.name="ChannelIdentity"
	identity_row.add_theme_constant_override("separation",12)
	content.add_child(identity_row)
	content.move_child(identity_row,0)
	identity_row.add_child(_identity)
	_identity.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	header_lbl.reparent(identity_row)
	header_lbl.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	header_lbl.size_flags_stretch_ratio=3.0
	_progress_label=Label.new()
	_progress_label.name="ConfirmedProgressLabel"
	_progress_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	_progress_label.add_theme_font_size_override("font_size",14)
	content.add_child(_progress_label)
	_progress_bar=ProgressBar.new()
	_progress_bar.name="ConfirmedProgress"
	_progress_bar.custom_minimum_size.y=5
	_progress_bar.show_percentage=false
	_progress_bar.mouse_filter=Control.MOUSE_FILTER_IGNORE
	content.add_child(_progress_bar)
	_progress_label.hide()
	_progress_bar.hide()
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
	_glass_background=background
	background.modulate = Color(0.50,0.46,0.49,0.16)
	panel.add_child(background)
	panel.move_child(background,0)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	header_lbl.add_theme_color_override("font_color",Color(1,0.67,0.68))
	header_lbl.add_theme_font_size_override("font_size",15)
	title_lbl.add_theme_font_size_override("font_size",22)
	desc_lbl.add_theme_font_size_override("font_size",16)
	_style_button(confirm_btn)
	_notice_audio=AudioStreamPlayer.new()
	_notice_audio.name="PersonalSystemCue"
	_notice_audio.process_mode=Node.PROCESS_MODE_PAUSABLE
	_notice_audio.volume_db=-19.0
	_notice_audio.stream=_make_notice_cue()
	add_child(_notice_audio)
	for label in [header_lbl,title_lbl,desc_lbl]: label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	get_viewport().size_changed.connect(_layout_panel)
	set_presentation_language(presentation_language)

func set_presentation_language(language: String) -> void:
	presentation_language = "en" if language == "en" else "ar"
	layout_direction = Control.LAYOUT_DIRECTION_RTL if presentation_language == "ar" else Control.LAYOUT_DIRECTION_LTR
	if confirm_btn: confirm_btn.text = "إغلاق" if presentation_language == "ar" else "Close"
	if _identity: _identity.text="إيكو // ECHO" if presentation_language=="ar" else "ECHO"
	if not _active_notice.is_empty(): _refresh_notice_text()
	if _status_view: _refresh_status_text()
	_refresh_decision_text()

func _presentation_density() -> float:
	return NativeUIDensity.pixel_ratio()

func _layout_panel() -> void:
	if not panel or not _scroll or _closing: return
	# Native boot uses a 1920x1080 canvas. Keep this dialog's text and 48px
	# targets readable when the containing window is smaller than that canvas.
	var stretch:=get_viewport().get_stretch_transform().get_scale()
	stretch=Vector2(maxf(0.001,stretch.x),maxf(0.001,stretch.y))
	var density := _presentation_density()
	scale=Vector2.ONE*density/stretch
	var screen := get_viewport().get_visible_rect().size*stretch/density
	size=screen
	position=Vector2.ZERO
	var compact_notice:=not _modal and (screen.y<500 or screen.x<960 or current_type in [WindowType.TASK_PROGRESS,WindowType.EXPERIENCE_GAIN])
	var width_limit:=minf(360,screen.x*.43) if compact_notice else (480.0 if _modal else 410.0)
	panel.size.x = maxf(240, minf(width_limit, screen.x - 48))
	_scroll.offset_left=20 if _modal else 28
	_scroll.offset_right=-_scroll.offset_left
	# Label mirrors LEFT to the reading start under Godot RTL layout.
	title_lbl.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER if _modal else HORIZONTAL_ALIGNMENT_LEFT
	var content := _scroll.get_child(0) as Control
	var desired_title:=18 if compact_notice else 22
	if title_lbl.get_theme_font_size("font_size")!=desired_title: title_lbl.add_theme_font_size_override("font_size",desired_title)
	_identity.visible=current_type!=WindowType.SOLO_LEVELING_GLITCH and not compact_notice
	desc_lbl.visible=not compact_notice or current_type==WindowType.EXPERIENCE_GAIN or _status_view
	var separation:=8 if current_type!=WindowType.SOLO_LEVELING_GLITCH else 12
	if content.get_theme_constant("separation")!=separation: content.add_theme_constant_override("separation",separation)
	_footer.visible=confirm_btn.visible or (stats_box.get_parent()==_footer and stats_box.visible)
	_footer.size.x=panel.size.x-40
	var footer_height:float=_footer.get_combined_minimum_size().y if _footer.visible else 0.0
	var reserved:float=footer_height+12 if footer_height>0 else 0.0
	panel.size.y = minf(maxf(152 if compact_notice else 190, content.get_combined_minimum_size().y + 52+reserved), maxf(160,screen.y - 48))
	_footer.position=Vector2(20,panel.size.y-20-footer_height)
	_footer.size.y=footer_height
	_scroll.offset_bottom=-20-reserved
	panel.pivot_offset = panel.size * 0.5
	if _inspection_layout: panel.position=Vector2(24,screen.y-panel.size.y-24)
	elif _modal: panel.position = (screen - panel.size) * 0.5
	elif not is_instance_valid(follow_player) or reduced_motion:
		panel.position = Vector2(screen.x - panel.size.x - 24,minf(72,maxf(24,screen.y-panel.size.y-24)))

func set_player(target: Node3D) -> void:
	follow_player = target

func _process(delta: float) -> void:
	if _status_view:
		panel.visible=not (_notice_suspended or _player_input_owned())
		if not panel.visible:return
		_status_age+=delta
		if _status_age>=.15 and is_instance_valid(follow_player):
			_status_age=0.0
			var hp:float=float(follow_player.get("hp"))
			var stamina:float=float(follow_player.get("stamina"))
			if hp!=_status_snapshot.hp or stamina!=_status_snapshot.stamina:
				_status_snapshot.hp=hp
				_status_snapshot.stamina=stamina
				_refresh_status_text()
	if not _active_notice.is_empty():
		var suspended:=_notice_suspended or _player_input_owned()
		panel.visible=not suspended
		if suspended: return
		_notice_remaining-=delta
		if _notice_remaining<=0.0: close_window()
	elif not visible and not _closing:
		_drain_notices()
	if not visible or not panel or _closing:
		return
	_layout_panel()
	if _modal or _inspection_layout or reduced_motion or not is_instance_valid(follow_player): return
	var camera: Camera3D = get_viewport().get_camera_3d()
	if not camera or camera.is_position_behind(follow_player.global_position):
		return
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var anchor: Vector2 = camera.unproject_position(follow_player.global_position + Vector3(0, 1.45, 0))
	var stretch:=get_viewport().get_stretch_transform().get_scale()
	viewport_size*=stretch/_presentation_density()
	anchor*=stretch/_presentation_density()
	var target_position := Vector2(
		clampf(anchor.x + 128.0, 24.0, viewport_size.x - panel.size.x - 24.0),
		clampf(anchor.y - 56.0, 24.0, viewport_size.y - panel.size.y - 24.0)
	)
	# Keep the reticle's immediate area clear, even when Echo moves across
	# the frame. On compact landscapes the card uses a narrower text layout.
	target_position.x=clampf(maxf(target_position.x,viewport_size.x*.5+48),24,viewport_size.x-panel.size.x-24)
	panel.position=panel.position.clamp(Vector2(24,24),Vector2(maxf(24,viewport_size.x-panel.size.x-24),maxf(24,viewport_size.y-panel.size.y-24)))
	panel.position = panel.position.lerp(target_position, minf(1.0, delta * 13.0)) if _follow_initialized else target_position
	_follow_initialized=true

func blocks_quest_tracker() -> bool:
	return visible and panel.visible and (_status_view or not _active_notice.is_empty() or current_type in [WindowType.LEVEL_UP,WindowType.REWARD])

func show_system_window(type: WindowType, title: String, message: String, stats: Array = [], auto_close_delay: float = 0.0, passive:bool=false) -> void:
	_ensure_nodes()
	_localized_decision.clear()
	_status_view=false
	# A real decision/inspection takes priority over a passive receipt. Keep
	# the interrupted notice, remaining reading time and already-played cue.
	if not _draining_notice and not _active_notice.is_empty():
		_notice_audio.stop()
		_active_notice["remaining"]=_notice_remaining
		_pending_notices.push_front(_active_notice)
		_active_notice={}
	if _progress_tween and _progress_tween.is_valid(): _progress_tween.kill()
	_progress_bar.hide()
	_progress_label.hide()
	panel.show()
	preload("res://scripts/ui/system_window_fracture.gd").clear_owned(self)
	_window_generation += 1
	_follow_initialized=false
	_closing = false
	var generation: int = _window_generation
	current_type = type
	_inspection_layout=false
	if _signal_glass: _signal_glass.begin(reduced_motion,type == WindowType.SOLO_LEVELING_GLITCH)
	visible = true
	_modal = auto_close_delay <= 0 and not passive
	if _modal: Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var shield := get_node("ClickShield") as Control
	shield.visible = _modal
	shield.mouse_filter = Control.MOUSE_FILTER_STOP if _modal else Control.MOUSE_FILTER_IGNORE
	_set_presentation_input(_modal)
	var compact: bool = type in [WindowType.NOTIFICATION,WindowType.QUEST_COMPLETED,WindowType.EXPERIENCE_GAIN,WindowType.TASK_ASSIGNED,WindowType.TASK_PROGRESS]
	if panel:
		panel.size = Vector2(410.0, 190.0 if compact else 300.0)
		panel.pivot_offset = panel.size * 0.5
	if stats_box:
		stats_box.visible = not stats.is_empty()
	if confirm_btn:
		confirm_btn.visible = auto_close_delay <= 0.0 and not passive
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
			lbl.text = str(stat_line)
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
			WindowType.EXPERIENCE_GAIN:
				header_lbl.text="تقدم مؤكد // 11:11" if presentation_language=="ar" else "CONFIRMED PROGRESS // 11:11"
			WindowType.TASK_ASSIGNED:
				header_lbl.text="مهمة جديدة // 11:11" if presentation_language=="ar" else "NEW TASK // 11:11"
			WindowType.TASK_PROGRESS:
				header_lbl.text="تقدم المهمة // 11:11" if presentation_language=="ar" else "TASK PROGRESS // 11:11"
	_apply_window_finish(type)

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
			_popup_tween.tween_property(panel, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			_popup_tween.tween_property(panel, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

			if auto_close_delay > 0.0 and not _draining_notice:
				tree.create_timer(auto_close_delay,false).timeout.connect(_close_if_generation.bind(generation))
		else:
			panel.scale = Vector2.ONE
			panel.modulate.a = 1.0
			if tree and auto_close_delay > 0 and not _draining_notice:
				tree.create_timer(auto_close_delay,false).timeout.connect(_close_if_generation.bind(generation))

	emit_signal("system_window_opened", current_type)

func set_inspection_layout() -> void:
	_inspection_layout=true
	_layout_panel()

func _close_if_generation(generation: int) -> void:
	if visible and generation == _window_generation:
		close_window()

func show_quest_update(completed_title: String, next_title: String) -> void:
	var ar:=presentation_language=="ar"
	if _defer_convenience(WindowType.QUEST_COMPLETED,"مهمة مكتملة","Task complete",completed_title+"\nالتالي: "+next_title,completed_title+"\nNext: "+next_title,[]):return
	show_system_window(
		WindowType.QUEST_COMPLETED,
		"مهمة مكتملة" if ar else "Task complete",
		completed_title + ("\nالتالي: " if ar else "\nNext: ") + next_title,
		[],
		3.5
	)

func close_window() -> void:
	if not visible or _closing: return
	_ensure_nodes()
	_notice_audio.stop()
	_window_generation += 1
	_closing = true
	_active_notice={}
	_status_view=false
	_modal = false
	if _popup_tween and _popup_tween.is_valid(): _popup_tween.kill()
	get_node("ClickShield").hide()
	_set_presentation_input(false)
	if reduced_motion:
		visible = false
		_closing=false
		_drain_notices.call_deferred()
	else:
		_popup_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_popup_tween.tween_property(panel, "modulate:a", 0.0, 0.18)
		_popup_tween.finished.connect(_finish_departure.bind(_window_generation))
	emit_signal("system_window_closed", current_type)

func _finish_departure(generation: int) -> void:
	if generation == _window_generation and _closing:
		visible = false
		_closing=false
		_drain_notices.call_deferred()

func _set_presentation_input(enabled: bool) -> void:
	var controls := find_children("*", "Control", true, false)
	controls.append(self)
	for control: Control in controls:
		# Preserve each child's original role: decorative glass stays ignored,
		# while scroll and choice controls regain their own input filters.
		if not control.has_meta("presentation_mouse_filter"):
			control.set_meta("presentation_mouse_filter", control.mouse_filter)
		control.mouse_filter = control.get_meta("presentation_mouse_filter") if enabled else Control.MOUSE_FILTER_IGNORE
		if not enabled: control.release_focus()
		if control is BaseButton: control.disabled = not enabled

# Convenience shortcuts
func _defer_convenience(type:WindowType, title_ar:String, title_en:String, message_ar:String, message_en:String, stats:Array) -> bool:
	if not ((visible and _modal) or _notice_suspended or _player_input_owned() or _status_view):return false
	# Legacy callers have no receipt identifier. Preserve their supplied data,
	# but route their display through the same modal-priority queue.
	_convenience_serial+=1
	_enqueue_notice({"id":"legacy-display:%d"%_convenience_serial,"type":type,"title_ar":title_ar,"title_en":title_en,"message_ar":message_ar,"message_en":message_en,"stats":stats.duplicate()})
	return true

func show_level_up(level_num: int = 2, changed_stats: Array = []) -> void:
	if _defer_convenience(WindowType.LEVEL_UP,"المستوى %02d"%level_num,"Level %02d"%level_num,"تم تثبيت الارتقاء.","The advancement is confirmed.",changed_stats):return
	show_system_window(
		WindowType.LEVEL_UP,
		("المستوى %02d" if presentation_language=="ar" else "Level %02d") % level_num,
		"تم تثبيت الارتقاء." if presentation_language=="ar" else "The advancement is confirmed.",
		changed_stats, 3.5
	)

func show_reward_window(item_name: String = "SHADOW KATANA // نصل ملوك الظلال", subtitle: String = "") -> void:
	if _defer_convenience(WindowType.REWARD,"تم استلام المكافأة","Reward received",subtitle if not subtitle.is_empty() else "تمت إضافة العنصر المؤكد.",subtitle if not subtitle.is_empty() else "The confirmed item was added.",[item_name]):return
	var desc = subtitle if subtitle != "" else ("تمت إضافة العنصر المؤكد." if presentation_language=="ar" else "The confirmed item was added.")
	show_system_window(
		WindowType.REWARD,
		"تم استلام المكافأة" if presentation_language=="ar" else "Reward received",
		desc,
		[item_name], 3.5
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

func show_localized_decision(copy: Dictionary, choices: Array, callback: Callable = Callable()) -> void:
	var localized: Array = []
	for choice: Dictionary in choices:
		localized.append({"id":choice.id, "text":choice.get("text_"+presentation_language, "")})
	show_decision(copy.get("title_"+presentation_language,""), copy.get("message_"+presentation_language,""), localized, callback)
	_localized_decision = {"copy":copy.duplicate(true), "choices":choices.duplicate(true)}
	_refresh_decision_text()

func _refresh_decision_text() -> void:
	if _localized_decision.is_empty() or not visible: return
	var copy: Dictionary = _localized_decision.copy
	header_lbl.text = "النظام // 11:11" if presentation_language == "ar" else "SYSTEM // 11:11"
	title_lbl.text = copy.get("title_"+presentation_language, "")
	desc_lbl.text = copy.get("message_"+presentation_language, "")
	for index in mini(stats_box.get_child_count(), _localized_decision.choices.size()):
		stats_box.get_child(index).text = _localized_decision.choices[index].get("text_"+presentation_language, "")
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
		style.bg_color = Color(0.065,0.035,0.047,0.72) if kind == "normal" else Color(0.12,0.055,0.075,0.84)
		style.border_color = Color(0.48,0.23,0.28,0.65) if kind != "focus" else Color(0.92,0.78,0.77)
		style.set_border_width_all(2 if kind == "focus" else 1)
		style.set_corner_radius_all(4)
		style.content_margin_left = 14
		style.content_margin_right = 14
		style.content_margin_top = 10
		style.content_margin_bottom = 10
		button.add_theme_stylebox_override(kind,style)

func _apply_window_finish(type: WindowType) -> void:
	var personal:=type!=WindowType.SOLO_LEVELING_GLITCH
	_accent=Color(.3,.85,1.0)
	if type==WindowType.LEVEL_UP: _accent=Color(.95,.76,.35)
	elif type==WindowType.REWARD: _accent=Color(.7,.52,1.0)
	elif not personal: _accent=Color(.64,.31,.36)
	var style:=panel.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	style.bg_color=Color(.014,.025,.043,.86) if personal else Color(.018,.013,.025,.72)
	style.border_color=Color(_accent,.48 if personal else .48)
	style.set_border_width_all(1)
	style.shadow_color=Color(_accent,.055)
	style.shadow_size=8
	panel.add_theme_stylebox_override("panel",style)
	_glass_background.modulate=Color(.45,.6,.7,.06) if personal else Color(.50,.46,.49,.16)
	_identity.visible=personal
	header_lbl.add_theme_color_override("font_color",_accent)
	_signal_glass.set_palette(_accent,personal)
	var track:=StyleBoxFlat.new();track.bg_color=Color(.08,.15,.2)
	var fill:=StyleBoxFlat.new();fill.bg_color=_accent
	_progress_bar.add_theme_stylebox_override("background",track)
	_progress_bar.add_theme_stylebox_override("fill",fill)

func _player_input_owned() -> bool:
	return is_instance_valid(follow_player) and follow_player.get("control_locked")==true

func set_notice_suspended(value: bool) -> void:
	_notice_suspended=value

func _enqueue_notice(event: Dictionary) -> bool:
	var id:String=event.get("id","")
	if id.is_empty() or _seen_notice_ids.has(id): return false
	_seen_notice_ids[id]=true
	# Presentation history is bounded. Progression and reward deduplication
	# remain owned by their actual save/server; this cache never grants either.
	if _seen_notice_ids.size()>128: _seen_notice_ids.erase(_seen_notice_ids.keys()[0])
	var group:String=event.get("group","")
	if not group.is_empty():
		# Update an already visible counter in place. A burst of pickups must
		# not create a second entrance, queue backlog or repeated sound.
		if not _closing and _active_notice.get("group","")==group:
			var old_value:float=float(_progress_bar.value)
			var consumed:bool=_active_notice.get("cue_consumed",false)
			var completed:bool=event.type==WindowType.QUEST_COMPLETED and current_type!=WindowType.QUEST_COMPLETED
			_active_notice=event
			_active_notice["from"]=old_value
			_active_notice["cue_consumed"]=consumed
			current_type=event.type
			_notice_remaining=_notice_duration(current_type)
			_refresh_notice_text()
			if completed and panel.visible and not _notice_suspended and not _player_input_owned() and not AudioServer.is_bus_mute(0): _notice_audio.play()
			_layout_panel()
			return true
		for index in _pending_notices.size():
			if _pending_notices[index].get("group","")==group:
				_pending_notices[index]=event
				return true
	if _pending_notices.size()>=6: _pending_notices.pop_front()
	_pending_notices.append(event)
	return true

func queue_story_update(id: String, title_ar: String, title_en: String, detail_ar: String, detail_en: String, done: int=-1, total: int=0) -> bool:
	var kind:=WindowType.TASK_PROGRESS if total>0 and done<total else WindowType.QUEST_COMPLETED
	return _enqueue_notice({"id":id,"group":id.rsplit(":",true,1)[0],"type":kind,"title_ar":title_ar,"title_en":title_en,"message_ar":detail_ar,"message_en":detail_en,"from":done,"to":done,"total":total})

func queue_task_assigned(id: String, title_ar: String, title_en: String, detail_ar: String, detail_en: String) -> bool:
	if id.is_empty() or _seen_notice_ids.has(id): return false
	_pending_notices.assign(_pending_notices.filter(func(event:Dictionary):return event.type!=WindowType.TASK_ASSIGNED))
	if not _active_notice.is_empty() and current_type==WindowType.TASK_ASSIGNED: close_window()
	return _enqueue_notice({"id":id,"type":WindowType.TASK_ASSIGNED,"title_ar":title_ar,"title_en":title_en,"message_ar":detail_ar,"message_en":detail_en})

func dismiss_task_assignments() -> void:
	# A new story-owned objective supersedes old assignment cards only.
	# Earned receipts, experience and completion notices keep their queue order.
	_pending_notices.assign(_pending_notices.filter(func(event: Dictionary): return event.type != WindowType.TASK_ASSIGNED))
	if not _active_notice.is_empty() and current_type == WindowType.TASK_ASSIGNED:
		close_window()

func queue_experience_gain(id: String, gain: int, previous: int, current: int, threshold: int) -> bool:
	# A presentation endpoint for the caller's committed XP data. It cannot
	# authenticate a receipt, write XP, alter a level or unlock a power.
	if gain<=0 or previous<0 or current-previous!=gain or threshold<=0 or current>threshold: return false
	return _enqueue_notice({"id":id,"type":WindowType.EXPERIENCE_GAIN,"title_ar":"خبرة مكتسبة","title_en":"Experience gained","message_ar":"\u2066+%d XP\u2069"%gain,"message_en":"+%d XP"%gain,"from":previous,"to":current,"total":threshold})

func _notice_duration(type:WindowType) -> float:
	match type:
		WindowType.TASK_PROGRESS: return 2.4
		WindowType.EXPERIENCE_GAIN: return 2.8
		WindowType.TASK_ASSIGNED: return 3.2
	return 3.5

func _drain_notices() -> void:
	if visible or _closing or _pending_notices.is_empty() or _notice_suspended or _player_input_owned(): return
	_active_notice=_pending_notices.pop_front()
	_notice_remaining=float(_active_notice.get("remaining",_notice_duration(_active_notice.type)))
	_draining_notice=true
	show_system_window(_active_notice.type,"","",_active_notice.get("stats",[]),_notice_duration(_active_notice.type))
	_draining_notice=false
	_set_presentation_input(false)
	_refresh_notice_text()
	if not _active_notice.get("cue_consumed",false):
		_active_notice["cue_consumed"]=true
		if current_type not in [WindowType.TASK_PROGRESS,WindowType.EXPERIENCE_GAIN] and not AudioServer.is_bus_mute(0): _notice_audio.play()
	_layout_panel()

func _refresh_notice_text() -> void:
	if _active_notice.is_empty(): return
	var suffix:="ar" if presentation_language=="ar" else "en"
	title_lbl.text=_active_notice.get("title_"+suffix,"")
	desc_lbl.text=_active_notice.get("message_"+suffix,"")
	match current_type:
		WindowType.QUEST_COMPLETED: header_lbl.text="مهمة مكتملة // 11:11" if suffix=="ar" else "TASK COMPLETE // 11:11"
		WindowType.TASK_ASSIGNED: header_lbl.text="مهمة جديدة // 11:11" if suffix=="ar" else "NEW TASK // 11:11"
		WindowType.TASK_PROGRESS: header_lbl.text="تقدم المهمة // 11:11" if suffix=="ar" else "TASK PROGRESS // 11:11"
		WindowType.EXPERIENCE_GAIN: header_lbl.text="تقدم مؤكد // 11:11" if suffix=="ar" else "CONFIRMED PROGRESS // 11:11"
	var total:int=_active_notice.get("total",0)
	_progress_bar.visible=total>0
	_progress_label.visible=total>0
	if total>0:
		_progress_bar.max_value=total
		_progress_label.text=_number_ratio(int(_active_notice.to),total)
		_progress_bar.value=_active_notice.get("from",0)
		if _progress_tween and _progress_tween.is_valid(): _progress_tween.kill()
		if reduced_motion: _progress_bar.value=_active_notice.to
		else:
			_progress_tween=create_tween()
			_progress_tween.tween_property(_progress_bar,"value",float(_active_notice.to),.65).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _make_notice_cue() -> AudioStreamWAV:
	# One short UI transient, no melody or music bed. The master mute and
	# pausable player own its output; a muted receipt never replays on unmute.
	var bytes:=PackedByteArray()
	var rate:=24000
	var count:=int(rate*.18)
	bytes.resize(count*2)
	for index in count:
		var time:=float(index)/rate
		var envelope:=minf(1.0,time/.006)*exp(-time*34.0)
		var sample:=(sin(TAU*620*time)*.65+sin(TAU*1240*time)*.18)*envelope
		bytes.encode_s16(index*2,int(clampf(sample,-1,1)*18000))
	var stream:=AudioStreamWAV.new()
	stream.format=AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate=rate
	stream.data=bytes
	return stream

func show_personal_status(snapshot: Dictionary) -> bool:
	for key in ["hp","max_hp","stamina","max_stamina"]:
		if not snapshot.has(key) or not is_finite(float(snapshot[key])): return false
	if float(snapshot.max_hp)<=0 or float(snapshot.max_stamina)<=0:return false
	show_system_window(WindowType.NOTIFICATION,"","",[],0.0,true)
	_status_snapshot=snapshot.duplicate(true)
	_status_view=true
	_status_age=0.0
	_refresh_status_text()
	_set_presentation_input(false)
	_layout_panel()
	return true

func update_status_objective(title: String) -> void:
	if not _status_view:return
	_status_snapshot["objective"]=title
	_refresh_status_text()

func _refresh_status_text() -> void:
	var ar:=presentation_language=="ar"
	header_lbl.text="الحالة // [ I ]" if ar else "STATUS // [ I ]"
	title_lbl.text="حالة إيكو" if ar else "Echo status"
	var bound:bool=_status_snapshot.get("pact_confirmed",false)
	desc_lbl.text=("الارتباط بزيرو: مُثبت" if bound else "القدرات: مقفلة") if ar else ("Bond with Zero: confirmed" if bound else "Abilities: locked")
	var lines:=[
		("الصحة: " if ar else "Health: ")+_number_ratio(roundi(_status_snapshot.hp),roundi(_status_snapshot.max_hp)),
		("التحمل: " if ar else "Stamina: ")+_number_ratio(roundi(_status_snapshot.stamina),roundi(_status_snapshot.max_stamina)),
		("الهدف: " if ar else "Objective: ")+String(_status_snapshot.get("objective",""))
	]
	stats_box.show()
	for i in lines.size():
		if stats_box.get_child_count()<=i:
			var label:=Label.new()
			label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
			label.add_theme_font_size_override("font_size",15)
			stats_box.add_child(label)
		stats_box.get_child(i).text=lines[i]

func _number_ratio(current:int, maximum:int) -> String:
	var text:="%d / %d"%[current,maximum]
	return "\u2066"+text+"\u2069" if presentation_language=="ar" else text

func show_solo_leveling_glitch_prompt(on_choice_callback: Callable = Callable()) -> void:
	# Approved PDF page 61: one specific wish, then an explicit acceptance.
	# Do not substitute an automatic timer or unrelated second answer.
	show_localized_decision({"title_ar":"لقد تجاوزت حدودك", "title_en":"You have exceeded your limits",
		"message_ar":"ما هي أمنيتك؟\n\nالخروج… والانتقام من كل من له علاقة بالنظام، مهما كان الثمن.\n\nهل تقبل؟", "message_en":"What is your wish?\n\nEscape… and take revenge on everyone connected to the System, whatever the cost.\n\nDo you accept?"},
		[{"id":"ESCAPE_SYSTEM_AT_ANY_COST", "text_ar":"نعم، أقبل.", "text_en":"Yes, I accept."}],
		func(id: String):
			solo_leveling_choice_made.emit(id)
			if on_choice_callback.is_valid(): on_choice_callback.call(id)
	)

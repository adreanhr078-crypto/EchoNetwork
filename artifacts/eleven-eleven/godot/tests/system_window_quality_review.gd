extends SceneTree

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	var args:=OS.get_cmdline_user_args()
	var cinematic := args.has("--cinematic")
	var language:="en" if args.has("--english") else "ar"
	root.size = Vector2i(360,800) if args.has("--portrait") else (Vector2i(320,240) if args.has("--narrow") else Vector2i(844,390))
	root.content_scale_size = Vector2i(1920,1080) if args.has("--native-canvas") else root.size
	var window = load("res://scenes/ui/system_window.tscn").instantiate()
	root.add_child(window)
	window.set_presentation_language(language)
	window.reduced_motion = not cinematic
	var decisions: Array = []
	window.decision_made.connect(func(id: String): decisions.append(id))
	window.show_solo_leveling_glitch_prompt()
	if cinematic:
		for i in range(60):
			await process_frame
			await _capture("cinematic",i)
	for i in range(10): await process_frame
	assert(window.visible and window.get_node("ClickShield").visible)
	assert(decisions.is_empty(), "Displaying a wish must never accept it")
	assert(window.stats_box.get_child_count() == 1, "Only the approved wish is offered")
	var stretch:=root.get_stretch_transform()
	var rect: Rect2 = stretch*window.panel.get_global_rect()
	assert(rect.position.x >= 0 and rect.position.y >= 0)
	print("UI viewport=",root.get_visible_rect()," panel=",rect)
	var actual_view:=stretch*root.get_visible_rect()
	assert(rect.end.x <= actual_view.size.x and rect.end.y <= actual_view.size.y, "Landscape window must fit its viewport")
	var choice_rect: Rect2 = stretch*window.stats_box.get_child(0).get_global_rect()
	assert(choice_rect.size.y >= 48 and rect.encloses(choice_rect), "Explicit acceptance must remain visible outside the scrolling text")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var folder := ProjectSettings.globalize_path("res://../audits/evidence/quality-repair-20261006/system-window/")
		DirAccess.make_dir_recursive_absolute(folder)
		root.get_texture().get_image().save_png(folder+"wish-"+language+"-%dx%d.png" % [root.size.x,root.size.y])
	var button_position:Vector2=window.stats_box.get_child(0).get_global_rect().get_center()
	for pressed in [true,false]:
		var click:=InputEventMouseButton.new()
		click.button_index=MOUSE_BUTTON_LEFT
		click.position=button_position
		click.global_position=button_position
		click.pressed=pressed
		root.push_input(click,true)
		await process_frame
	assert(decisions == ["ESCAPE_SYSTEM_AT_ANY_COST"])
	assert(not window.visible and not window.get_node("ClickShield").visible)
	if cinematic:
		for i in range(42):
			await process_frame
			await _capture("cinematic",60+i)
		assert(root.find_child("SystemWindowFracture",true,false) == null,"Fracture overlay must release its memory and never block input")
	window.show_decision("العقد", "الثمن أن يبقى زيرو معك إلى النهاية.", [{"id":"accept", "text":"أعطني ما أحتاجه"},{"id":"decline", "text":"ليس الآن"}])
	var stale: int = window._window_generation
	window.show_system_window(0, "السجل", "تمت قراءة سجل العينة.", [], 0)
	window._choose_decision("accept",stale,Callable())
	assert(window.visible and decisions.size() == 1, "A replaced decision cannot accept an old choice")
	window.show_decision("First","First explicit action",[{"id":"FIRST","text":"Continue"}],func(_id:String):
		window.show_decision("Second","Second explicit action",[{"id":"SECOND","text":"Finish"}]))
	window.stats_box.get_child(0).pressed.emit()
	assert(window.visible and window.stats_box.get_child_count()==1 and window.stats_box.get_child(0).text=="Finish","Synchronous next decision must detach the emitting button safely")
	assert(decisions==["ESCAPE_SYSTEM_AT_ANY_COST","FIRST"],"Chained presentation cannot accept the next decision")
	window.stats_box.get_child(0).pressed.emit()
	assert(decisions==["ESCAPE_SYSTEM_AT_ANY_COST","FIRST","SECOND"])
	window.queue_free()
	await process_frame
	print("PASS System UI: phone bounds, scroll, explicit wish, stale decision, modal release")
	quit()

func _capture(label: String, frame: int) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var folder := ProjectSettings.globalize_path("res://../audits/evidence/quality-repair-20261006/system-window/"+label+"/")
	DirAccess.make_dir_recursive_absolute(folder)
	root.get_texture().get_image().save_png(folder+"%04d.png" % frame)

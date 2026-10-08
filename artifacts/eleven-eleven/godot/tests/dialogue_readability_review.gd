extends SceneTree

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	root.size = Vector2i(360,800) if args.has("--portrait") else (Vector2i(320,240) if args.has("--narrow") else Vector2i(960,540))
	root.content_scale_size = Vector2i(1920,1080)
	var dialogue = load("res://scenes/ui/dialogue_overlay.tscn").instantiate()
	root.add_child(dialogue)
	dialogue.reduced_motion = true
	dialogue.set_presentation_language("en" if args.has("--english") else "ar")
	var completed := []
	dialogue.dialogue_completed.connect(func(): completed.append(true))
	var long_ar := "أين… أنا؟ هذه الساعة متوقفة. " .repeat(12)
	var long_en := "Where am I? The clock has stopped. ".repeat(12)
	dialogue.start_dialogue([{"speaker_ar":"إيكو","speaker_en":"Echo","text_ar":long_ar,"text_en":long_en},{"speaker_ar":"إيكو","speaker_en":"Echo","text_ar":"11:11","text_en":"11:11"}])
	for i in 12: await process_frame
	var stretch := root.get_stretch_transform()
	var box:Rect2 = stretch*dialogue.get_node("DialogBox").get_global_rect()
	var button:Rect2 = stretch*dialogue.continue_button.get_global_rect()
	assert(box.position.x>=0 and box.position.y>=0 and box.end.x<=root.size.x+.1 and box.end.y<=root.size.y+.1,"Dialogue must fit the physical viewport")
	assert(button.size.y>=47.9 and box.encloses(button),"Actual native-canvas button must remain >=48px and visible outside scroll")
	assert(dialogue.current_line_index==0 and completed.is_empty(),"Showing or scrolling a line cannot advance story")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		var folder:=ProjectSettings.globalize_path("res://../audits/evidence/quality-execution-20261006/dialogue/")
		DirAccess.make_dir_recursive_absolute(folder)
		root.get_texture().get_image().save_png(folder+"%s-%dx%d.png" % [dialogue.presentation_language,root.size.x,root.size.y])
	for pressed in [true,false]:
		var click:=InputEventMouseButton.new()
		click.button_index=MOUSE_BUTTON_LEFT
		click.position=dialogue.continue_button.get_global_rect().get_center()
		click.global_position=click.position
		click.pressed=pressed
		root.push_input(click,true)
		await process_frame
	assert(dialogue.current_line_index==1 and completed.is_empty(),"Actual click must advance one line only")
	dialogue.continue_button.pressed.emit()
	assert(completed.size()==1 and not dialogue.visible and not dialogue.is_active)
	dialogue.close_dialogue()
	assert(completed.size()==1,"Close callback must remain idempotent")
	dialogue.queue_free()
	await process_frame
	print("PASS dialogue: native-canvas physical bounds, pinned >=48px continuation, complete RTL/LTR text, actual click, explicit progression and idempotent completion")
	quit(0)

extends SceneTree

func _initialize() -> void: _run.call_deferred()
func check(condition: bool, message: String) -> bool:
	if not condition:
		push_error(message)
		quit(1)
	return condition
func _run() -> void:
	var args := OS.get_cmdline_user_args()
	root.size = Vector2i(320,240) if args.has("--narrow") else Vector2i(640,360)
	root.content_scale_size = Vector2i(1920,1080)
	var puzzle = load("res://scenes/ui/terminal_hack_puzzle.tscn").instantiate()
	root.add_child(puzzle)
	puzzle.reduced_motion=true
	puzzle.set_presentation_language("en" if args.has("--english") else "ar")
	puzzle.open_puzzle()
	for unused in 8: await process_frame
	var stretch := root.get_stretch_transform()
	var close = puzzle.find_child("CloseBtn",true,false)
	var close_rect: Rect2 = stretch*close.get_global_rect()
	if not check(close_rect.size.y>=47.9 and close_rect.size.x>=47.9,"Terminal close target is smaller than 48 physical pixels"): return
	var panel: Rect2 = stretch*puzzle.get_node("Panel").get_global_rect()
	if not check(panel.position.x>=0 and panel.position.y>=0 and panel.end.x<=root.size.x+.1 and panel.end.y<=root.size.y+.1,"Terminal must fit its actual viewport"): return
	var completed := []
	puzzle.puzzle_completed.connect(func(_data): completed.append(true))
	for entry in [[puzzle.freq_slider,puzzle.freq_target],[puzzle.phase_slider,puzzle.phase_target],[puzzle.harmonic_slider,puzzle.harmonic_target]]:
		var slider: Slider = entry[0]
		slider.grab_focus()
		for unused in 3: await process_frame
		var rect: Rect2 = stretch*slider.get_global_rect()
		var scroll_rect: Rect2 = stretch*puzzle._content_scroll.get_global_rect()
		print("Slider ",slider.name," viewport=",rect," scroll=",scroll_rect," offset=",puzzle._content_scroll.scroll_vertical)
		if not check(scroll_rect.encloses(rect),"Focused slider is clipped by its scroll viewport"): return
		if not check(rect.size.y>=47.9 and panel.encloses(rect),"Focused terminal slider must be visible, scrollable and >=48px tall"): return
		var ratio: float = (entry[1]-slider.min_value)/(slider.max_value-slider.min_value)
		if slider.is_layout_rtl(): ratio=1.0-ratio
		# The press itself hovers the slider; Godot then uses its larger
		# highlighted grabber, including in the value-to-position mapping.
		var width: float = slider.get_theme_icon("grabber_highlight").get_width()
		var at := slider.get_global_transform()*Vector2(width*.5+(slider.size.x-width)*ratio,slider.size.y*.5)
		for pressed in [true,false]:
			var touch := InputEventMouseButton.new()
			touch.button_index=MOUSE_BUTTON_LEFT
			touch.position=at
			touch.global_position=at
			touch.pressed=pressed
			root.push_input(touch,true)
			await process_frame
		print("Pointer ",slider.name," expected=",entry[1]," actual=",slider.value)
		var pixel_precision: float=(slider.max_value-slider.min_value)/maxf(1,rect.size.x-width)
		if not check(absf(slider.value-entry[1])<=pixel_precision+slider.step,"Pointer selection exceeded its physical pixel resolution"): return
		# Real pixel coordinates cannot express every narrow-slider value.
		# Reach the exact unchanged trace through the actual 48px step controls.
		for unused in 12:
			if absf(slider.value-entry[1])<=slider.step*.1: break
			var button: Button=slider.get_parent().get_node("IncreaseStep" if slider.value<entry[1] else "DecreaseStep")
			var button_rect: Rect2=stretch*button.get_global_rect()
			if not check(button_rect.size.x>=47.9 and button_rect.size.y>=47.9,"Precision controls must remain 48px physical targets"): return
			for pressed in [true,false]:
				var click:=InputEventMouseButton.new()
				click.button_index=MOUSE_BUTTON_LEFT
				click.position=button.get_global_rect().get_center()
				click.global_position=click.position
				click.pressed=pressed
				root.push_input(click,true)
				await process_frame
		if not check(absf(slider.value-entry[1])<=slider.step*.1,"Actual pointer precision buttons cannot reach the exact unchanged trace value"): return
	if not check(puzzle.is_solved and completed.size()==1,"Actual slider input must solve and signal exactly once"): return
	for unused in 3: await process_frame
	var proceed: Rect2 = stretch*puzzle.proceed_btn.get_global_rect()
	if not check(proceed.size.y>=47.9 and panel.encloses(proceed),"Solved continuation must remain pinned and >=48px"): return
	puzzle.queue_free()
	await process_frame
	print("PASS terminal: physical bounds and 48px targets, RTL/LTR, focus scrolling, actual pointer solution and single completion")
	quit(0)

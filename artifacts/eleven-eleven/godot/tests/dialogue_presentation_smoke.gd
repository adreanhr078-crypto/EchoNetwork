extends SceneTree

var completed := 0
var chain_next := false
var checks := 0
var dialogue: Control

func _initialize() -> void: _run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		push_error(message)
		quit(1)
		assert(false, message)

func on_completed() -> void:
	completed += 1
	if chain_next:
		chain_next = false
		dialogue.start_dialogue([{"speaker":"NEXT", "text":"A new line must retain input ownership."}])

func _run() -> void:
	root.size = Vector2i(960, 540)
	dialogue = load("res://scenes/ui/dialogue_overlay.tscn").instantiate()
	root.add_child(dialogue)
	dialogue.typewriter_speed = 0.25
	dialogue.dialogue_completed.connect(on_completed)
	dialogue.start_dialogue([{"speaker":"ECHO", "speaker_color":Color(0.0,0.94,1.0), "text":"The complete line remains shaped while its characters appear."}])
	check(dialogue.is_active and dialogue.visible and is_zero_approx(dialogue.modulate.a), "Entrance starts without advancing the line")
	check(not dialogue.continue_button.disabled and dialogue.continue_button.has_focus(), "Entrance retains keyboard and touch ownership")
	await create_timer(0.08).timeout
	check(dialogue.modulate.a > 0.0 and dialogue.modulate.a < 1.0, "Entrance interpolates instead of jumping")
	check(dialogue.current_line_index == 0 and completed == 0, "Time and cosmetic effects cannot advance story")
	dialogue.advance_dialogue()
	check(not dialogue.is_typing and dialogue.current_line_index == 0, "First input reveals the line without closing it")
	await create_timer(0.2).timeout
	check(is_equal_approx(dialogue.modulate.a, 1.0), "Entrance reaches full readable opacity")
	dialogue.advance_dialogue()
	check(completed == 1 and not dialogue.is_active and dialogue.visible, "Completion transfers control immediately while departure remains cosmetic")
	check(dialogue.mouse_filter == Control.MOUSE_FILTER_IGNORE and dialogue.continue_button.disabled and not dialogue.continue_button.has_focus(), "Departing panel cannot intercept resumed input")
	dialogue.close_dialogue()
	check(completed == 1, "Repeated close cannot replay a story completion")
	await create_timer(0.25).timeout
	check(not dialogue.visible and is_zero_approx(dialogue.modulate.a), "Departure ends without leaving an invisible input panel")
	dialogue.start_dialogue([{"speaker":"ECHO", "text":"First."}])
	await create_timer(0.25).timeout
	chain_next = true
	dialogue.close_dialogue()
	check(completed == 2 and dialogue.is_active and dialogue.speaker_lbl.text == "NEXT", "Synchronous completion may start the next story line")
	await create_timer(0.3).timeout
	check(dialogue.visible and dialogue.is_active and is_equal_approx(dialogue.modulate.a, 1.0), "An old departure must never hide the new dialogue")
	dialogue.close_dialogue()
	dialogue.reduced_motion = true
	check(not dialogue.visible and completed == 3, "Live reduced motion cancels departure without repeating completion")
	dialogue.reduced_motion = false
	dialogue.start_dialogue([{"speaker_ar":"إيكو", "speaker_en":"Echo", "text_ar":"أين أنا؟", "text_en":"Where am I?"}])
	await create_timer(0.06).timeout
	dialogue.reduced_motion = true
	check(dialogue.visible and is_equal_approx(dialogue.modulate.a, 1.0) and not dialogue.is_typing and dialogue.text_lbl.visible_characters == -1, "Live reduced motion finishes entrance and text immediately")
	await process_frame
	check(dialogue.text_lbl.get_character_bounds(0).position.x > dialogue.text_lbl.size.x * 0.5, "Short Arabic text starts on the visual right, without double RTL mirroring")
	dialogue.set_presentation_language("en")
	await process_frame
	check(dialogue.text_lbl.get_character_bounds(0).position.x < dialogue.text_lbl.size.x * 0.25, "English text starts on the visual left after a live locale change")
	check(dialogue.full_text == "Where am I?" and dialogue.current_line_index == 0 and completed == 3, "Language changes presentation without advancing story")
	dialogue.advance_dialogue()
	check(completed == 4 and not dialogue.visible, "Reduced motion closes immediately")
	dialogue.queue_free()
	await process_frame
	print("PASS dialogue presentation: %d checks; fades, immediate control handoff, chained-dialogue ownership, live reduced motion and locale" % checks)
	quit(0)

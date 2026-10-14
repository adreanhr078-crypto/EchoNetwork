extends SceneTree

var checks := 0
var completed := 0
var closed := 0
var window: Control
var chain_next := false

func _initialize() -> void: _run.call_deferred()
func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		push_error(message)
		quit(1)
		assert(false, message)
func on_window_closed(_type: int) -> void:
	closed += 1
	if chain_next:
		chain_next = false
		window.show_system_window(0, "Next", "The next screen retains ownership.")
func _run() -> void:
	root.size = Vector2i(960,540)
	window = load("res://scenes/ui/system_window.tscn").instantiate()
	root.add_child(window)
	window.system_window_closed.connect(on_window_closed)
	window.show_system_window(0, "Signal", "Presentation cannot decide for the player.")
	await create_timer(0.25).timeout
	var position: Vector2 = window.panel.position
	window.close_window()
	check(closed == 1 and not window._modal and window.visible and not window.get_node("ClickShield").visible, "System departure releases its shield and modal ownership immediately")
	check(window.panel.mouse_filter == Control.MOUSE_FILTER_IGNORE and window._scroll.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Departing system glass cannot intercept resumed gameplay clicks")
	window.close_window()
	check(closed == 1, "System closure is idempotent")
	await create_timer(0.08).timeout
	check(window.panel.position.is_equal_approx(position), "Closing a centered screen must not teleport to the notification corner")
	window.show_decision("Choice", "The decision remains explicit.", [{"id":"WAIT", "text":"Wait"}])
	await create_timer(0.25).timeout
	check(window.visible and window._modal and window.stats_box.get_child_count()==1, "A stale departure cannot hide or resolve the next decision")
	var choices := []
	window.decision_made.connect(func(id): choices.append(id))
	var old_button: Button = window.stats_box.get_child(0)
	old_button.pressed.emit()
	old_button.pressed.emit()
	check(choices == ["WAIT"] and closed == 2 and not window._modal, "Repeated choice input cannot duplicate a decision during departure")
	window.reduced_motion = true
	check(not window.visible, "Live reduced motion ends a cosmetic system departure immediately")
	window.reduced_motion = false
	window.show_system_window(0, "First", "First")
	chain_next = true
	window.close_window()
	await create_timer(0.3).timeout
	check(window.visible and window._modal and window.title_lbl.text == "Next", "A synchronous closure handler can open the next screen safely")
	window.reduced_motion = true
	check(window.panel.scale == Vector2.ONE and is_equal_approx(window.panel.modulate.a,1.0), "Live reduced motion cancels entrance scale and opacity interpolation")
	var puzzle = load("res://scenes/ui/terminal_hack_puzzle.tscn").instantiate()
	root.add_child(puzzle)
	var puzzle_closed := []
	puzzle.puzzle_closed.connect(func(): puzzle_closed.append(true))
	puzzle.open_puzzle()
	puzzle.freq_slider.value = 100.0
	puzzle.close_puzzle()
	check(not puzzle.is_open and puzzle.visible and not puzzle.freq_slider.editable and puzzle.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Terminal departure cannot retain editing or modal input")
	puzzle.close_puzzle()
	check(puzzle_closed.size()==1, "Terminal close cannot repeat a continuation")
	puzzle.open_puzzle()
	await create_timer(0.3).timeout
	check(puzzle.visible and puzzle.is_open and puzzle.freq_slider.editable and is_equal_approx(puzzle.freq_val,100.0), "Reopening cancels stale terminal departure and preserves unsolved progress")
	puzzle.reduced_motion=true
	puzzle.close_puzzle()
	check(not puzzle.visible, "Reduced motion closes terminal immediately")
	var prompt = load("res://scenes/ui/interaction_prompt_hud.tscn").instantiate()
	root.add_child(prompt)
	var target := Node.new()
	root.add_child(target)
	prompt.show_prompt(target)
	await create_timer(0.08).timeout
	var alpha: float = prompt.modulate.a
	prompt.show_prompt(target)
	check(prompt.modulate.a >= alpha, "Repeated proximity refresh cannot restart and flicker the prompt")
	prompt.hide_prompt()
	prompt.show_prompt(target)
	await create_timer(0.2).timeout
	check(prompt.visible and is_equal_approx(prompt.modulate.a,1.0), "Rapid proximity reentry cancels obsolete hint departure")
	prompt.reduced_motion=true
	prompt.hide_prompt()
	check(not prompt.visible, "Reduced motion hides a hint immediately")
	var toast = load("res://scripts/ui/tutorial_toast_system.gd").new()
	root.add_child(toast)
	toast.toast_completed.connect(func(id):
		completed += 1
		if id == "FIRST": toast.show_toast("NEXT", "E", "Next", "A synchronous hint must survive.")
	)
	toast.show_toast("FIRST", "E", "First", "First")
	toast.dismiss_toast()
	await create_timer(0.3).timeout
	check(completed==1 and toast.active_toast_id=="NEXT" and toast.visible, "Completing a hint cannot clear or hide a synchronously opened next hint")
	for node in [window,puzzle,prompt,target,toast]: node.queue_free()
	await process_frame
	print("PASS shared UI presentation: %d checks; modal handoff, explicit decisions, stale fades, terminal state, proximity refresh and chained hints" % checks)
	quit(0)

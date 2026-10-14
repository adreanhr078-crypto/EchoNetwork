extends SceneTree
const Dialogue = preload("res://scripts/ui/dialogue_overlay.gd")
const Terminal = preload("res://scripts/ui/terminal_hack_puzzle.gd")
const SystemWindowScript = preload("res://scripts/ui/system_window.gd")
class PhoneDialogue extends Dialogue:
	func _presentation_density() -> float: return 3.0
class PhoneTerminal extends Terminal:
	func _presentation_density() -> float: return 3.0
class PhoneWindow extends SystemWindowScript:
	func _presentation_density() -> float: return 3.0
func _initialize() -> void: _run.call_deferred()
func check(ok: bool, message: String) -> bool:
	if not ok:
		push_error(message)
		quit(1)
	return ok
func _run() -> void:
	root.size=Vector2i(2460,1080)
	root.content_scale_size=Vector2i(1920,1080)
	var fixtures=[
		["res://scenes/ui/dialogue_overlay.tscn",PhoneDialogue],
		["res://scenes/ui/terminal_hack_puzzle.tscn",PhoneTerminal],
		["res://scenes/ui/system_window.tscn",PhoneWindow]]
	for fixture in fixtures:
		var ui=load(fixture[0]).instantiate()
		ui.set_script(fixture[1])
		root.add_child(ui)
		ui.reduced_motion=true
		if ui is Dialogue:
			ui.start_dialogue([{"speaker":"إيكو","text":"أين… أنا؟"}])
		elif ui is Terminal: ui.open_puzzle()
		else: ui.show_system_window(0,"النظام","الاتصال مستقر.")
		for unused in 5: await process_frame
		var stretch=root.get_stretch_transform()
		var panel=ui.get_node("DialogBox" if ui is Dialogue else "Panel")
		var rect:Rect2=stretch*panel.get_global_rect()
		if not check(Rect2(Vector2.ZERO,root.size).encloses(rect),"480dpi dialog must fit physical landscape viewport"): return
		var button:Button=ui.continue_button if ui is Dialogue else (ui.find_child("CloseBtn",true,false) if ui is Terminal else ui.confirm_btn)
		if not check((stretch*button.get_global_rect()).size.y>=143.9,"Phone target must be 48dp (144px), not 48 physical pixels"): return
		if ui is Terminal:
			ui.harmonic_slider.grab_focus()
			for unused in 3: await process_frame
			if not check((stretch*ui._content_scroll.get_global_rect()).encloses(stretch*ui.harmonic_slider.get_global_rect()),"480dpi scrolling must expose the focused slider"): return
		ui.queue_free()
		await process_frame
	print("PASS actual shared layouts with injected480dpi: 2460x1080 physical bounds, 48dp targets, scroll focus; real phone still required")
	quit(0)

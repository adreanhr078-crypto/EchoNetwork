extends SceneTree

const Fracture=preload("res://scripts/ui/system_window_fracture.gd")

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	var first: Control=load("res://scenes/ui/system_window.tscn").instantiate()
	var second: Control=load("res://scenes/ui/system_window.tscn").instantiate()
	root.add_child(first)
	root.add_child(second)
	first.reduced_motion=true
	second.reduced_motion=true
	var choices: Array[String]=[]
	first.decision_made.connect(func(id: String): choices.append(id))
	first.show_decision("العقد","القرار لك.",[{"id":"DEFER","text":"ليس الآن"}])
	# Simulate a still-live native snapshot while running the ownership check
	# headlessly. The real rendered fixture independently captures the pixels.
	var old:=CanvasLayer.new()
	old.set_meta(Fracture.OWNER_META,first.get_instance_id())
	root.add_child(old)
	var unrelated:=CanvasLayer.new()
	unrelated.set_meta(Fracture.OWNER_META,second.get_instance_id())
	root.add_child(unrelated)
	first.set_presentation_language("en")
	first.show_decision("Zero's pact","Your choice.",[{"id":"ACCEPT","text":"Accept"},{"id":"DEFER","text":"Not yet"}])
	assert(not old.visible and old.is_queued_for_deletion(),"A fresh language/decision must remove its previous snapshot immediately")
	assert(unrelated.visible and not unrelated.is_queued_for_deletion(),"A second window's fracture belongs to that window")
	assert(first.visible and choices.is_empty() and first.stats_box.get_child_count()==2,"Cleaning decorative pixels must preserve both explicit choices")
	first.stats_box.get_child(1).pressed.emit()
	assert(choices==["DEFER"] and not first.visible)
	# Clear only the second owner and preserve the already emitted choice.
	Fracture.clear_owned(second)
	assert(not unrelated.visible and unrelated.is_queued_for_deletion())
	assert(choices==["DEFER"])
	first.queue_free()
	second.queue_free()
	await process_frame
	print("PASS fracture ownership: rapid new decision/language clears only its stale pixels; unrelated snapshot and explicit consent survive")
	quit(0)

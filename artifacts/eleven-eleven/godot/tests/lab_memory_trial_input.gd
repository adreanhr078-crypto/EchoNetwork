extends RefCounted

## Shared public-input segment used by continuous and scoped route reviews.
static func play(tree: SceneTree, main: Node, room: Node3D, walk: Callable, capture: Callable, stop_at_insert := false) -> bool:
	var trial: Node = room.narrative_trial
	if trial.phase != "recognition": return false
	var dialogue: Node = main.hud.find_child("DialogueOverlay",true,false)
	dialogue.finish_typing()
	await frames(tree,main,18)
	await capture.call("lab-father")
	await drain(tree, main)
	if trial.phase != "memories" or main.player.control_locked: return false
	for spec in [["shizuka",-4.5],["yuki",4.5]]:
		for point in [Vector3(2.5,1.2,-16.7),Vector3(spec[1],1.2,-16.7),Vector3(spec[1],1.2,-19.4)]:
			if not await walk.call(point): return false
		var target: Node = main.player.get_nearest_interactable()
		if not target or target.get("memory_id") != spec[0]:
			push_error("Actual memory station unreachable: "+str(spec)+" target="+str(target))
			return false
		if not main.player.interact_with_nearest().get("success",false): return false
		dialogue.finish_typing()
		await frames(tree,main,18)
		await capture.call("lab-memory-"+spec[0])
		await drain(tree, main)
	var window: Node = main.hud.find_child("SystemWindow",true,false)
	if trial.memories.size()!=2 or trial.phase!="refusal" or not window.visible: return false
	if room.confrontation_done or room.contract_done or main.player.combat_available: return false
	await capture.call("lab-impossible-demand")
	window.stats_box.get_child(0).pressed.emit()
	await drain(tree,main)
	if is_instance_valid(trial.memory_insert):
		if not main.player.control_locked or room.confrontation_done: return false
		await capture.call("lab-memory-insert")
		if stop_at_insert: return true
		trial.memory_insert.skip_button.pressed.emit()
		await frames(tree,main,4)
	if trial.phase!="abyss" or not window.visible or room.confrontation_done: return false
	await frames(tree,main,18) # Observe the settled UI, not the closing dialogue fade.
	await capture.call("lab-resistance")
	# Time, reduced motion and closing presentation cannot answer the action.
	for i in 12: await frames(tree,main,1)
	if room.confrontation_done or room.contract_done: return false
	window.stats_box.get_child(0).pressed.emit()
	await frames(tree,main,100)
	return room.confrontation_done and not room.contract_done and not room.wish_done and not main.player.combat_available

static func drain(tree: SceneTree, main: Node) -> void:
	var dialogue: Node = main.hud.find_child("DialogueOverlay",true,false)
	for i in 24:
		if not dialogue.is_active: break
		dialogue.continue_button.pressed.emit()
		await frames(tree,main,1)
	await frames(tree,main,3)

static func frames(tree: SceneTree, main: Node, count: int) -> void:
	for i in count:
		if tree.paused: main.native_pause_menu.resume_button.pressed.emit()
		await tree.process_frame
		await tree.physics_frame

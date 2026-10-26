extends SceneTree
var failed := 0
var evidence := "res://../audits/evidence/pre-tripo-20261018/cp37/title-native/"
func _initialize() -> void: _run.call_deferred()
func check(ok: bool, label: String) -> void:
	print("%s %s" % ["PASS" if ok else "FAIL", label])
	if not ok: failed += 1
func wait_frames(count: int) -> void:
	for frame in count: await process_frame
func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(evidence.path_join(name+".png"))
func _run() -> void:
	root.unfocusable = true
	root.size = Vector2i(1280,720)
	evidence=ProjectSettings.globalize_path("res://").path_join("../audits/evidence/pre-tripo-20261018/cp37/title-native/").simplify_path()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence="): evidence=argument.trim_prefix("--evidence=")
	DirAccess.make_dir_recursive_absolute(evidence)
	var boot = load("res://scenes/boot.tscn").instantiate()
	root.add_child(boot)
	current_scene=boot
	await wait_frames(12)
	var title=boot.get_child(0)
	check(title.get_script().resource_path.ends_with("title_entry.gd"),"actual boot opens title first")
	check(not root.has_node("Main"),"no journey beneath the title")
	check(title.video.stream is VideoStreamTheora,"native video decoder")
	check(title.video.is_playing(),"plays on startup")
	await capture("ar-first")
	# Real time decoder playback, beyond the complete ten-second source.
	await create_timer(11.0).timeout
	if not is_instance_valid(title):
		check(false,"title interrupted before scripted start")
		quit(1)
		return
	check(title.loop_count >= 1 and title.video.is_playing(),"full source loops without starting the game")
	title.motion_button.grab_focus()
	var key:=InputEventKey.new()
	key.keycode=KEY_ENTER;key.pressed=true;Input.parse_input_event(key)
	await wait_frames(3)
	key=InputEventKey.new();key.keycode=KEY_ENTER;key.pressed=false;Input.parse_input_event(key)
	await wait_frames(3)
	check(title.reduced_motion and not title.video.is_playing() and title.poster.visible,"keyboard reduced-motion alternative")
	await capture("ar-reduced")
	title.language_button.emit_signal("pressed")
	check(title.language=="en" and title.start_button.text=="Tap to Start","live English")
	await capture("en-reduced")
	title.start_button.grab_focus()
	key=InputEventKey.new();key.keycode=KEY_SPACE;key.pressed=true;Input.parse_input_event(key)
	await wait_frames(2)
	key=InputEventKey.new();key.keycode=KEY_SPACE;key.pressed=false;Input.parse_input_event(key)
	await wait_frames(100)
	check(not is_instance_valid(title),"start releases title and decoder")
	var cover: Node = null
	for node in boot.get_children():
		if node.get_script() and node.get_script().resource_path.ends_with("cover_recovery.gd"): cover=node
	check(is_instance_valid(cover) and current_scene==boot,"title hands off to the real cover before the journey")
	if not is_instance_valid(cover): quit(1); return
	check(not cover.completed and cover.order.size()==6,"cover starts with six pieces without granting progression")
	for index in cover.order.size():
		if not is_instance_valid(cover): break
		if cover.order[index]==index: continue
		var other: int=cover.order.find(index)
		for position in [index,other]:
			cover.tiles[position].grab_focus()
			key=InputEventKey.new();key.keycode=KEY_ENTER;key.pressed=true;Input.parse_input_event(key)
			await wait_frames(1)
			key=InputEventKey.new();key.keycode=KEY_ENTER;key.pressed=false;Input.parse_input_event(key)
			await wait_frames(2)
	await wait_frames(5)
	var film: Node = null
	for node in boot.get_children():
		if node.get_script() and node.get_script().resource_path.ends_with("school_lab_opening.gd"): film=node
	check(is_instance_valid(film) and film.reduced_motion and not film.video.is_playing(),"solved cover opens reduced-motion film alternative")
	if not is_instance_valid(film): quit(1); return
	await capture("cover-to-film-reduced")
	for shot in 2:
		film.skip_button.grab_focus()
		key=InputEventKey.new();key.keycode=KEY_ENTER;key.pressed=true;Input.parse_input_event(key)
		await wait_frames(1)
		key=InputEventKey.new();key.keycode=KEY_ENTER;key.pressed=false;Input.parse_input_event(key)
		await wait_frames(3)
	check(current_scene==boot and film.entry_state.beat=="questions","skipping both shots waits for father readiness")
	film._questions.get_child(2).grab_focus()
	key=InputEventKey.new();key.keycode=KEY_ENTER;key.pressed=true;Input.parse_input_event(key)
	await wait_frames(1)
	key=InputEventKey.new();key.keycode=KEY_ENTER;key.pressed=false;Input.parse_input_event(key)
	await wait_frames(3)
	check(film.entry_state.beat=="experiment","explicit keyboard readiness begins the experiment")
	film.skip_button.grab_focus()
	key=InputEventKey.new();key.keycode=KEY_ENTER;key.pressed=true;Input.parse_input_event(key)
	await wait_frames(1)
	key=InputEventKey.new();key.keycode=KEY_ENTER;key.pressed=false;Input.parse_input_event(key)
	await wait_frames(100)
	check(current_scene!=boot and current_scene.has_node("NativeCampaignController"),"played cover and explicit continue open actual connected journey")
	check(current_scene.presentation_language=="en" and current_scene.reduced_motion,"title language and reduced motion reach the actual journey")
	current_scene.set_audio_muted(true)
	var persisted:=ConfigFile.new()
	persisted.load(current_scene.native_preferences_path)
	check(persisted.get_value("entry","cover_completed",false) and persisted.get_value("entry","film_seen",false),"game settings preserve played entry presentation state")
	print("TITLE_ENTRY_REVIEW failed=%d" % failed)
	var hashes:={}
	for path in ["scripts/boot.gd","scripts/ui/title_entry.gd","scripts/ui/cover_recovery.gd","scripts/ui/opening_memory_film.gd","tests/title_entry_review.gd"]:
		hashes[path]=FileAccess.get_sha256("res://"+path)
	var report:=FileAccess.open(evidence.path_join("review.json"),FileAccess.WRITE)
	report.store_string(JSON.stringify({"failed":failed,"display":DisplayServer.get_name(),"source_hashes":hashes,"scope":"Actual rendered title decoder and keyboard path through unsolved6-piece cover, Reduced Motion film and connected native journey; no server receipt or independent enjoyment acceptance"},"\t"));report.close()
	quit(0 if failed==0 else 1)

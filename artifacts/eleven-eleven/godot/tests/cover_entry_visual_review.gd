extends SceneTree
var failed := 0
var completed := 0
var folder := ""
func _initialize() -> void: _run.call_deferred()
func check(ok: bool,label: String) -> void:
	print("%s %s" % ["PASS" if ok else "FAIL",label])
	if not ok: failed+=1
func frames(count: int) -> void:
	for index in count: await process_frame
func capture(name: String) -> void:
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(folder.path_join(name+".png"))
func click(button: Control) -> void:
	var center:=button.get_global_rect().get_center()
	for pressed in [true,false]:
		var event:=InputEventMouseButton.new()
		event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;event.position=center;event.global_position=center
		root.push_input(event,true)
		await frames(2)
func _run() -> void:
	root.unfocusable=true
	folder=ProjectSettings.globalize_path("res://../audits/evidence/pre-tripo-20261018/cp37/cover-native-v1").simplify_path()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence="):folder=arg.trim_prefix("--evidence=")
	DirAccess.make_dir_recursive_absolute(folder)
	root.size=Vector2i(1280,720)
	var cover=load("res://scripts/ui/cover_recovery.gd").new()
	root.add_child(cover)
	await frames(5)
	check(not cover.board.get_global_rect().intersects(cover.panel.get_global_rect()),"RTL panel does not overlap the playable board")
	check(not cover.completed,"fresh local cover is not a receipt")
	check(cover.order.size()==6 and cover.tiles.size()==6,"Owner opening uses exactly six large pieces")
	check(cover.order==[1,0,2,3,5,4],"Opening is a gentle two-swap arrangement")
	await capture("ar-unsolved")
	var initial: Array=cover.order.duplicate()
	await click(cover.tiles[0]);await click(cover.tiles[1])
	check(cover.order!=initial and cover.history.size()==1,"public pointer swaps two pieces")
	await click(cover.undo_button)
	check(cover.order==initial and cover.history.is_empty(),"undo restores the played move")
	await click(cover.reference_button)
	check(cover.reference.visible and cover.tiles[0].disabled,"reference does not solve and blocks covered pieces")
	await capture("reference")
	await click(cover.reference_button)
	await click(cover.language_button)
	check(cover.language=="en","live English on the actual puzzle")
	await capture("en-unsolved")
	await click(cover.language_button)
	cover.restored.connect(func(rect: Rect2):
		completed+=1
		var film=load("res://scripts/ui/opening_memory_film.gd").new()
		film.board_rect=rect
		root.add_child(film)
		film.finished.connect(func(): completed+=1)
		cover.hide()
	)
	for index in cover.order.size():
		if cover.order[index]==index: continue
		var other: int=cover.order.find(index)
		await click(cover.tiles[index]);await click(cover.tiles[other])
	await frames(2)
	check(cover.completed and completed==1,"only the actual solved arrangement emits once")
	if not cover.completed: quit(1); return
	await capture("fracture")
	await create_timer(2.0).timeout
	var film=root.get_child(root.get_child_count()-1)
	check(film.video.is_playing(),"fracture starts real native film decoder")
	await capture("film")
	await create_timer(25.0).timeout
	check(completed==2,"full film finishes without granting gameplay flags")
	film.skip_button.emit_signal("pressed")
	check(completed==2,"late duplicate skip cannot finish twice")
	film.queue_free();cover.queue_free()
	await frames(3)
	print("COVER_ENTRY_REVIEW failed=%d" % failed)
	quit(0 if failed==0 else 1)

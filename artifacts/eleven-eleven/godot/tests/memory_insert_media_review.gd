extends SceneTree
var failures := 0
var completions := 0
var folder := ""
func _initialize() -> void: _run.call_deferred()
func check(ok: bool,label: String) -> void:
	print("%s %s" % ["PASS" if ok else "FAIL",label])
	if not ok: failures+=1
func frames(count: int) -> void:
	for i in count: await process_frame
func capture(name: String) -> void:
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(folder.path_join(name+".png"))
func _run() -> void:
	root.unfocusable=true;root.size=Vector2i(1280,720)
	folder=ProjectSettings.globalize_path("res://../audits/evidence/pre-tripo-20261018/cp37/memory-insert-media").simplify_path()
	DirAccess.make_dir_recursive_absolute(folder)
	var film=load("res://scripts/ui/opening_memory_film.gd").new()
	film.film_path="res://assets/cinematics/lab-memory-collapse-v1.ogv"
	film.poster_texture=load("res://assets/cinematics/lab-memory-bottom-v1.webp")
	film.ambient_path="res://assets/cinematics/lab-memory-water-v1.ogg"
	film.show_fracture=false;film.hold_poster=true
	film.cue_ar="أحتاج… أعلى…";film.cue_en="I need… to go up…"
	root.add_child(film)
	film.finished.connect(func(): completions+=1)
	await frames(8)
	check(film.video.is_playing() and not film.subtitle.visible,"actual8sec decoder starts before the timed subtitle")
	film.pause_button.pressed.emit()
	var position: float=film.video.stream_position
	await create_timer(.4).timeout
	check(film.video.paused and absf(film.video.stream_position-position)<.05,"player pause freezes film time")
	film.pause_button.pressed.emit()
	paused=true
	position=film.video.stream_position
	await create_timer(.4).timeout
	check(absf(film.video.stream_position-position)<.05,"game pause freezes media time")
	paused=false
	film.sync_preferences("en",false,false)
	check(film.ambient.playing and film.ambient.volume_db>-80 and film.subtitle.text=="I need… to go up…","live English and audible time-aligned SFX routing")
	film.sync_preferences("ar",false,true)
	check(film.ambient.volume_db==-80 and film.video.volume_db==-80,"mute covers separate SFX and original video remains silent")
	await create_timer(4.8).timeout
	check(film.subtitle.visible,"AR subtitle appears only during the underwater cue")
	await capture("underwater-subtitle")
	await create_timer(3.7).timeout
	check(completions==1 and film.poster.visible and not film.video.visible and not film.skip_button.visible,"full take ends on held bottom poster exactly once")
	await capture("held-bottom")
	film.skip_button.pressed.emit()
	check(completions==1,"late skip cannot replay a completion")
	film.queue_free();await frames(3)
	var reduced=load("res://scripts/ui/opening_memory_film.gd").new()
	reduced.reduced_motion=true;reduced.show_fracture=false
	reduced.poster_texture=load("res://assets/cinematics/lab-memory-bottom-v1.webp")
	reduced.cue_ar="أحتاج… أعلى…"
	root.add_child(reduced)
	reduced.finished.connect(func(): completions+=1)
	await frames(3)
	check(not reduced.video.is_playing() and reduced.subtitle.visible,"reduced motion preserves the complete line and waits for the player")
	reduced.cancel();reduced.skip_button.pressed.emit()
	check(completions==1,"rollback cancellation never executes a handoff")
	reduced.queue_free();await frames(2)
	print("MEMORY_INSERT_MEDIA failures=%d" % failures)
	quit(0 if failures==0 else 1)

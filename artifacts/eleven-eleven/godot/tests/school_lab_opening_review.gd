extends SceneTree
const Opening=preload("res://scripts/ui/school_lab_opening.gd")
var film: CanvasLayer
var checks:=0
var failures:=0
var completions:=0
var saved: Dictionary={}
var folder:="res://../audits/evidence/chapter-cp45-20261020/stage04/"
func _initialize() -> void: _run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures+=1
	print("PASS " if ok else "FAIL ",label)
func frames(count:int) -> void:
	for i in count: await process_frame
func make_film(state:Dictionary={"beat":"school","asked":[]}, motion:=false, missing:=false) -> void:
	if is_instance_valid(film):
		film.queue_free();await frames(2)
	film=Opening.new()
	film.entry_state=state
	film.reduced_motion=motion
	film.show_fracture=false
	film.audio_muted=true
	if missing: film.shot_overrides={"school":"res://missing-fixture.ogv","laboratory":"res://missing-fixture.ogv","experiment":"res://missing-fixture.ogv"}
	film.entry_checkpoint_changed.connect(func(cursor:Dictionary,language:String,reduced:bool,muted:bool):
		saved={"cursor":cursor,"language":language,"reduced":reduced,"muted":muted}
	)
	film.finished.connect(func():completions+=1)
	root.add_child(film)
	await frames(3)
func capture(id:String) -> void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder+id+".png")
func click(button:Control) -> void:
	await frames(2)
	var center:=button.get_global_rect().get_center()
	for pressed in [true,false]:
		var event:=InputEventMouseButton.new()
		event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed
		event.position=center;event.global_position=center
		root.push_input(event,true)
		await frames(2)
func _run() -> void:
	root.unfocusable=true
	root.size=Vector2i(1280,720)
	folder=ProjectSettings.globalize_path(folder)
	DirAccess.make_dir_recursive_absolute(folder)
	check(Opening.validate_state({"beat":"reply_safety","asked":[]}).is_empty(),"Malformed reply cursor rejected")
	check(Opening.validate_state({"beat":"questions","asked":["safety","safety"]}).is_empty(),"Duplicate question ids rejected")
	await make_film()
	check(film.video.is_playing() and film.entry_state.beat=="school","Actual school decoder starts")
	film.pause_button.pressed.emit()
	var position:float=film.video.stream_position
	await frames(3)
	check(film._sequence_paused and is_equal_approx(position,film.video.stream_position),"Pause freezes the media decoder")
	film.skip_button.pressed.emit()
	check(film.entry_state.beat=="school","Paused skip is inert")
	film.pause_button.pressed.emit()
	film.skip_button.pressed.emit()
	await frames(3)
	check(film.entry_state.beat=="laboratory" and film.video.is_playing(),"Skip transitions school to actual laboratory decoder")
	await capture("laboratory")
	film.skip_button.pressed.emit()
	check(film.entry_state.beat=="questions" and completions==0 and film._questions.get_child_count()==3,"Father questions wait without a timer")
	film._finish()
	check(film.entry_state.beat=="questions","Skip cannot choose readiness")
	film._questions.get_child(0).pressed.emit()
	check(film.entry_state.beat=="reply_experiment" and saved.cursor.asked==["experiment"],"Question changes live reply and saved information history")
	var resume: Dictionary=saved.cursor.duplicate(true)
	film.sync_preferences("en",false,true)
	check(film._speaker.text=="Father" and film._copy.text.begins_with("We will"),"Reply translates live to English")
	await capture("father-en")
	await make_film(resume,true)
	check(film.entry_state.beat=="reply_experiment" and film.entry_state.asked==["experiment"] and not film.video.is_playing(),"Load resumes exact unanswered dialogue beat with Reduced Motion")
	film._questions.get_child(0).pressed.emit()
	film._questions.get_child(1).pressed.emit()
	check(film.entry_state.beat=="reply_safety" and film.entry_state.asked.size()==2,"Safety is a distinct inspectable reply")
	await capture("father-ar")
	film.pause_button.pressed.emit()
	check(film._questions.get_child(0).disabled,"Paused dialogue cannot advance")
	film.sync_preferences("en",false,true)
	check(film._sequence_paused and not film.video.is_playing(),"Preference change while paused cannot autoplay dialogue")
	film.pause_button.pressed.emit()
	film._questions.get_child(0).pressed.emit()
	film._questions.get_child(2).pressed.emit()
	check(film.entry_state.beat=="experiment" and completions==0,"Explicit readiness alone starts experiment")
	film.sync_preferences("ar",true,true)
	await frames(1)
	check(film._clock.visible and film._clock.text=="11:11","11:11 remains a live Godot label")
	film.skip_button.pressed.emit();film._finish()
	check(completions==1 and saved.cursor.beat=="done","Completion emits exactly once without a pact or reward")
	await make_film({"beat":"laboratory","asked":[]},false,true)
	check(film._media_failed and film.skip_button.visible,"Missing media retains readable poster and continue action")
	film.skip_button.pressed.emit()
	check(film.entry_state.beat=="questions" and film._questions.get_child_count()==3,"Missing decoder never blocks live father questions")
	film.cancel()
	check(completions==1,"Cancellation emits no completion")
	await make_film()
	await create_timer(17.0).timeout
	check(film.entry_state.beat=="questions" and completions==1,"Natural school and lab playback stop at father input")
	await capture("questions-ar")
	await click(film._questions.get_child(2))
	check(film.entry_state.beat=="experiment","Public pointer confirms readiness")
	await create_timer(4.5).timeout
	check(film._clock.visible,"Actual experiment decoder reaches live11:11 cue")
	await capture("experiment-1111")
	await create_timer(2.5).timeout
	check(completions==2 and film._done,"Natural experiment and sensory fade hand off once")
	var report:Dictionary={"status":"PASS" if failures==0 else "FAIL","checks":checks,"failures":failures,"renderer":DisplayServer.get_name(),"resume_policy":"Replay current shot from its safe start; resume dialogue and questions exactly; no implicit readiness","sources":{}}
	for path in ["res://scripts/boot.gd","res://scripts/ui/school_lab_opening.gd","res://assets/cinematics/opening-cp45/lab-arrival.ogv","res://assets/cinematics/opening-cp45/experiment.ogv"]: report.sources[path]=FileAccess.get_sha256(path)
	var file:=FileAccess.open(folder+"report.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("SCHOOL_LAB_REVIEW ",JSON.stringify(report))
	film.queue_free();await frames(2)
	quit(1 if failures else 0)

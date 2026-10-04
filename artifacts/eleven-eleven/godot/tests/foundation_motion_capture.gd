extends SceneTree

## Actual rendered controller/motor review. Entry into maintenance is staged;
## route and story acceptance are tested separately by opening_route_input_smoke.
var main: Node
var player: EchoPlayer
var touch: MobileTouchControls
var fps := 30
var folder := ""
var frame := 0
var trace := []

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	_cleanup()
	var args := OS.get_cmdline_user_args()
	if not args.is_empty(): fps = int(args[0])
	if fps not in [30,60,120]: quit(1); return
	root.size = Vector2i(960,540)
	root.content_scale_size = Vector2i(1920,1080)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
	var attempt := args[1] if args.size() > 1 else "final"
	folder = ProjectSettings.globalize_path("res://../audits/evidence/third-person-foundation-20261001/implementation/render/motion-%d-%s/" % [fps,attempt])
	DirAccess.make_dir_recursive_absolute(folder)
	main = load("res://scenes/system_journey_preview.tscn").instantiate()
	main.native_checkpoint_path = "user://foundation_render_opening.json"
	main.native_preferences_path = "user://foundation_render.cfg"
	root.add_child(main)
	main.get_node("SystemJourneyPreview").checkpoint_path = "user://foundation_render_journey.json"
	await process_frame
	main.set_audio_muted(true)
	player = main.player
	player.finish_opening_recovery()
	var dialogue = main.hud.find_child("DialogueOverlay",true,false)
	for i in range(8):
		if dialogue.is_active: dialogue.continue_button.pressed.emit()
		await process_frame
	touch = main.hud.find_child("MobileTouchControls",true,false)
	touch._platform_touch_enabled = true
	touch.set_interaction_blocked(false)
	player.set_gameplay_orbit(Vector3(-0.15,0,0))
	for i in range(35): await physics_frame
	await _capture("opening_orbit",0.5)
	_touch(0,touch.joystick_center,true)
	_drag(0,touch.joystick_center+Vector2(0,-45))
	await _capture("partial_walk",0.6)
	_touch(1,Vector2(1200,450),true)
	for i in range(fps/2):
		_drag(1,Vector2(1200-i*3.0,450))
		await _capture_frame("move_and_look")
	_touch(1,Vector2.ZERO,false)
	_drag(0,touch.joystick_center+Vector2(0,-75))
	await _capture("full_run",0.6)
	_touch(0,Vector2.ZERO,false)
	# The same player and approved room; only entry is staged for render review.
	main.opening_web_handoff.reported_milestones.append("memory_scene_completed")
	for i in range(8): await physics_frame
	player.surface_motor.reset(player)
	player.position = Vector3(0,0.06,-23.1)
	player.velocity = Vector3.ZERO
	player.stamina = 100
	player.set_gameplay_orbit(Vector3(-0.15,0,0))
	for i in range(30): await physics_frame
	_touch(0,touch.joystick_center,true)
	_drag(0,touch.joystick_center+Vector2(0,-75))
	player.request_jump()
	for i in range(fps*3):
		await _capture_frame("climb")
		if player.surface_motor.hanging: break
	if not player.surface_motor.hanging: push_error("capture never reached actual hang"); quit(1); return
	_drag(0,touch.joystick_center)
	await _capture("hang",0.25)
	_drag(0,touch.joystick_center+Vector2(45,0))
	await _capture("sidle_right",0.35)
	_drag(0,touch.joystick_center+Vector2(-45,0))
	await _capture("sidle_left",0.35)
	_drag(0,touch.joystick_center+Vector2(0,-75))
	player.request_jump()
	for i in range(fps*2):
		await _capture_frame("mantle")
		if not player.is_climbing(): break
	_touch(0,Vector2.ZERO,false)
	await _capture("mantle_landed",0.3)
	if not player.is_on_floor(): push_error("capture mantle not grounded"); quit(1); return
	# Verify/render the public camera ownership handoff at each target cadence.
	player.suspend_gameplay_camera()
	player.camera_boom.rotation = Vector3(-0.1,0.8,0)
	player.player_camera.fov = 58
	await _capture("cinematic_owned",0.2)
	player.resume_gameplay_camera()
	await _capture("live_return",0.45)
	var file := FileAccess.open(folder+"trace.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"target_cadence":fps,"fixed_step_render":true,"physical_phone":false,"fixture":"staged entry, actual controller/motor, separate route test","frames":trace},"\t"))
	file.close()
	print("CAPTURE motion fps=",fps," frames=",frame," folder=",folder)
	main.queue_free()
	await process_frame
	_cleanup()
	quit(0)

func _cleanup() -> void:
	for base in ["user://foundation_render_opening.json","user://foundation_render.cfg","user://foundation_render_journey.json"]:
		for suffix in ["",".bak",".tmp"]:
			if FileAccess.file_exists(base+suffix): DirAccess.remove_absolute(base+suffix)

func _capture(label: String, seconds: float) -> void:
	for i in range(ceili(seconds*fps)): await _capture_frame(label)

func _capture_frame(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.resize(960,540)
	image.save_png(folder+"frame-%05d.png" % frame)
	trace.append({"frame":frame,"label":label,"position":[player.position.x,player.position.y,player.position.z],"camera":[player.player_camera.global_position.x,player.player_camera.global_position.y,player.player_camera.global_position.z],"fov":player.player_camera.fov,"yaw":player.camera_boom.rotation.y,"pitch":player.camera_boom.rotation.x})
	frame += 1

func _touch(index: int, at: Vector2, down: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = at
	event.pressed = down
	touch._input(event)

func _drag(index: int, at: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = at
	touch._input(event)

extends SceneTree

## Actual Echo public inputs, from one declared entry anchor.
## No position correction, synthetic mantle signal, save or chapter receipt.
var world: Node3D
var room: Node3D
var player: EchoPlayer
var capture_directory := ""
var automatic_focus_resume := true
var report := {"scope":"Isolated real motor test;not chapter acceptance","samples":[],"checks":[]}

func _initialize() -> void:
	process_frame.connect(_resume_test_focus_pause)
	_run.call_deferred()

func _resume_test_focus_pause() -> void:
	# The background/unfocusable review window can trigger the real focus-loss
	# pause. Resume through its existing UI callback; do not disable game pause.
	if not automatic_focus_resume or not paused or not is_instance_valid(world):return
	var menu = world.get("native_pause_menu")
	if is_instance_valid(menu):
		report.focus_pause_resumes = int(report.get("focus_pause_resumes",0))+1
		menu.resume_button.pressed.emit()

func _pos() -> Vector3:return room.to_local(player.global_position)

func _capture(label: String) -> void:
	print("STORMWORKS_PHASE ",label," ",_pos())
	if capture_directory.is_empty() or DisplayServer.get_name() == "headless":return
	await RenderingServer.frame_post_draw
	var path := capture_directory.path_join(label+".png")
	var saved := root.get_texture().get_image().save_png(path) == OK
	if not report.has("captures"):report.captures = []
	report.captures.append({"path":path,"saved":saved,"room_position":str(_pos()),"animation":player.current_anim})

func _frames(count: int) -> void:
	for frame in count:
		await physics_frame
		await process_frame
		if frame % 4 == 0:
			report.samples.append({"position":str(_pos()),"velocity":str(player.velocity),"hanging":player.surface_motor.hanging,"climbing":player.traversal.is_climbing(),"transition":player.surface_motor._transition_kind,"floor":player.is_on_floor()})

func _aim(target: Vector3) -> void:
	var direction := room.to_global(target)-player.global_position
	player.set_gameplay_orbit(Vector3(0,atan2(-direction.x,-direction.z),0))

func _steer(target: Vector3, sprint: bool = true, amount: float = 1.0) -> void:
	var direction := room.to_global(target)-player.global_position
	direction.y = 0
	direction = direction.normalized()
	var forward := -player.player_camera.global_basis.z
	forward.y = 0
	forward = forward.normalized()
	var right := forward.cross(Vector3.UP).normalized()
	# The boolean is mobile ownership. Analog magnitude selects walk/run.
	var magnitude := amount if sprint else amount*.7
	player.set_mobile_input_vector(Vector2(direction.dot(right),-direction.dot(forward))*magnitude,true)

func _go_to(target: Vector3) -> bool:
	for frame in 180:
		var distance := Vector2(_pos().x-target.x,_pos().z-target.z).length()
		if distance < .12:break
		_steer(target,false,clampf(distance*2,.25,1))
		await _frames(1)
	player.set_mobile_input_vector(Vector2.ZERO,false)
	await _frames(10)
	return player.is_on_floor() and Vector2(_pos().x-target.x,_pos().z-target.z).length() < .4

func _vault_course() -> void:
	var reached := await _go_to(Vector3(-3,2.95,-13.9))
	if reached: reached = await _go_to(Vector3(-4,2.95,-13.9))
	report.checks.append({"check":"vault_approach","pass":reached,"position":str(_pos())})
	if not reached:return
	var target := Vector3(-4,2.95,-16.2)
	_aim(target)
	await _frames(30)
	_steer(target)
	var desired := (room.to_global(target)-player.global_position).normalized()
	var wall: Dictionary = player.surface_motor._wall(player,desired,.35)
	report.vault_entry = {"input":str(player.resolve_movement_input()),"world_direction":str(player.movement_world_direction(player.resolve_movement_input())),"wall":str(wall.get("collider")),"normal":str(wall.get("normal")),"point":str(wall.get("position"))}
	if not wall.is_empty():
		var probe: Vector3 = wall.position+desired*.08
		var top: Dictionary = player.surface_motor._ray(player,Vector3(probe.x,_pos().y+1.05,probe.z),Vector3(probe.x,_pos().y+.4,probe.z))
		report.vault_entry.top = {"point":str(top.get("position")),"normal":str(top.get("normal")),"body":str(top.get("collider")),"on_floor":player.is_on_floor()}
	player.request_jump()
	for frame in 150:
		_steer(target)
		await _frames(1)
		if report.get("vault_completions",0) > 0:break
		if _pos().y < -.1 or _pos().z < -16.4:break
	player.set_mobile_input_vector(Vector2.ZERO,false)
	await _frames(12)
	report.checks.append({"check":"actual_vault_completed","pass":report.get("vault_completions",0) == 1 and player.is_on_floor() and _pos().z < -15.8 and _pos().y > 2.7,"position":str(_pos())})

func _final_bridge_course() -> void:
	var reached := await _go_to(Vector3(-2.2,2.95,-16.05))
	if reached:reached = await _go_to(Vector3(-2.2,2.95,-15.2))
	if reached:reached = await _go_to(Vector3(-1.8,2.95,-15.2))
	report.checks.append({"check":"final_grip_approach","pass":reached,"position":str(_pos())})
	if not reached:return
	var target := Vector3(-1.8,5.6,-17.1)
	_aim(target)
	await _frames(30)
	_steer(target)
	player.request_jump()
	var caught := false
	for frame in 100:
		_steer(target)
		await _frames(1)
		if player.surface_motor.hanging:
			caught = true
			break
	player.set_mobile_input_vector(Vector2.ZERO,false)
	report.checks.append({"check":"final_short_ledge_catch","pass":caught,"position":str(_pos())})
	if not caught:return
	await _capture("final-grip")
	await _frames(5)
	player.request_jump()
	for frame in 180:
		await _frames(1)
		if player.is_on_floor() and _pos().y > 5.4:break
	await _frames(12)
	report.checks.append({"check":"final_mantle_supported","pass":player.is_on_floor() and _pos().y > 5.4 and _pos().y < 6,"position":str(_pos())})

func _jump_to(target: Vector3, label: String) -> bool:
	_aim(target)
	_steer(target)
	player.request_jump()
	var airborne := false
	var landed := false
	for frame in 100:
		_steer(target)
		await _frames(1)
		if not player.is_on_floor(): airborne = true
		var horizontal := Vector2(_pos().x-target.x,_pos().z-target.z).length()
		if airborne and player.is_on_floor() and horizontal < .6 and absf(_pos().y-target.y) < .35:
			landed = true
			break
		if _pos().y < -.1:break
	player.set_mobile_input_vector(Vector2.ZERO,false)
	await _frames(12)
	landed = landed and player.is_on_floor() and absf(_pos().y-target.y) < .35
	report.checks.append({"check":label,"pass":landed,"position":str(_pos()),"airborne":airborne})
	if landed:await _capture(label)
	return landed

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():quit(2);return
	world = Node3D.new()
	root.add_child(world)
	room = load("res://scenes/environment/maintenance_stormworks.tscn").instantiate()
	if room.get_script() == null:quit(2);return
	world.add_child(room)
	player = load("res://scenes/player/echo_player.tscn").instantiate()
	player.position = Vector3(-1.15,.1,-3.4)
	world.add_child(player)
	await _exercise_course()
	report.transition_rejection = player.surface_motor.last_transition_rejection
	report.status = "PASS_SCOPED" if report.checks.all(func(row: Dictionary):return row.get("pass",false)) else "FAIL_SCOPED"
	var file := FileAccess.open(args[0],FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"));file.close()
	print("STORMWORKS_PARKOUR ",report.status," ",report.checks)
	world.queue_free()
	for i in 3:await process_frame
	quit(0 if report.status == "PASS_SCOPED" else 1)

func _exercise_course() -> void:
	player.finish_opening_recovery()
	player.control_locked = false
	player.surface_traversal_enabled = true
	player.surface_motor.vault_completed.connect(func():report.vault_completions = int(report.get("vault_completions",0))+1)
	player.camera_boom.rotation.y = 0
	player.set_mobile_input_vector(Vector2.ZERO,false)
	await _frames(12)
	player.set_mobile_input_vector(Vector2(0,-1),true)
	for frame in 45:
		await _frames(1)
		if _pos().z < -3.45:break
	player.request_jump()
	var grabbed := false
	for frame in 100:
		await _frames(1)
		if player.surface_motor.hanging:
			grabbed = true
			break
	player.set_mobile_input_vector(Vector2.ZERO,false)
	report.checks.append({"check":"first_ledge_from_public_jump","pass":grabbed,"position":str(_pos())})
	if grabbed:
		await _capture("first-grip")
		await _frames(5)
		player.set_mobile_input_vector(Vector2(0,-1),false)
		player.request_jump()
		for frame in 180:
			await _frames(1)
			if player.is_on_floor() and _pos().y > 2:break
		player.set_mobile_input_vector(Vector2.ZERO,false)
		await _frames(5)
		report.checks.append({"check":"first_mantle_supported","pass":player.is_on_floor() and _pos().y > 2 and _pos().y < 2.6,"position":str(_pos())})
		if report.checks.back().get("pass",false):
			await _capture("first-mantle")
			# Use the first platform's real run-up before the diagonal gap.
			var target := Vector3(-4.95,2.18,-8)
			for frame in 60:
				_steer(target)
				await _frames(1)
				if _pos().x < -1.65:break
			if await _jump_to(target,"first_diagonal_gap"):
				target = Vector3(-3.5,2.18,-11.6)
				for frame in 60:
					_steer(target)
					await _frames(1)
					if _pos().z < -8.45:break
				if await _jump_to(target,"second_gap"):
					target = Vector3(-2.3,2.95,-14.65)
					for frame in 60:
						_steer(target)
						await _frames(1)
						if _pos().z < -12.18:break
					if await _jump_to(target,"rising_gap_to_vault_deck"):
						await _vault_course()
						if report.checks.back().get("pass",false):
							await _capture("vault-landing")
							await _final_bridge_course()
							if report.checks.back().get("pass",false):await _capture("final-mantle")

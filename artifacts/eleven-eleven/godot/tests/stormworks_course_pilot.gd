extends RefCounted

## Actual-input course pilot shared by the fresh connected chapter review.
var tree: SceneTree
var world: Node3D
var room: Node3D
var player: EchoPlayer
var capture_directory := ""
var exercise_fall_retry := false
var report := {"checks":[],"samples":[]}

func _fall_and_retry() -> bool:
	var director = world.get_node("SystemJourneyPreview")
	var stage_before: int = director.stage
	var step_before: int = director.course_step
	var anchor: Vector3 = director._retry_anchor
	var left_platform := false
	var falling := false
	var restored := false
	var lowest := INF
	# Walk off the first platform into the existing gap. Only the production
	# controller may restore the actor; the driver never writes its position.
	for frame in 240:
		_steer(Vector3(-3.4,2.3,-6.3),false)
		await _frames(1)
		lowest = minf(lowest,_pos().y)
		left_platform = left_platform or player.global_position.distance_to(anchor) > .8
		falling = falling or (not player.is_on_floor() and player.velocity.y < -1)
		if left_platform and falling and player.global_position.distance_to(anchor)<.4 and _pos().y > 2:
			restored = true
			break
	player.set_mobile_input_vector(Vector2.ZERO,false)
	await _frames(12)
	var safe: bool = restored and player.is_on_floor() and director.stage==stage_before and director.course_step==step_before and not player.combat_available and not player.control_locked and not player.surface_motor.hanging and not player.surface_motor.native_mantle_active
	report.fall_retry={"left_platform":left_platform,"falling":falling,"lowest_y":lowest,"restored_by_production_controller":restored,"stage_before":stage_before,"stage_after":director.stage,"course_step_before":step_before,"course_step_after":director.course_step}
	report.checks.append({"check":"actual_fall_checkpoint_retry_without_progress_grant","pass":safe})
	await _capture("fall-retry-return")
	return safe

func _pos() -> Vector3:return room.to_local(player.global_position)

func _capture(label: String) -> void:
	print("STORMWORKS_PHASE ",label," ",_pos())
	if capture_directory.is_empty() or DisplayServer.get_name() == "headless":return
	await RenderingServer.frame_post_draw
	var path := capture_directory.path_join(label+".png")
	var saved := tree.root.get_texture().get_image().save_png(path) == OK
	if not report.has("captures"):report.captures = []
	var active:=tree.root.get_camera_3d()
	var data:={"path":path,"saved":saved,"room_position":str(_pos()),"animation":player.current_anim,"gameplay_camera_current":player.player_camera.current,"camera_position":str(active.global_position),"camera_rotation":str(active.global_rotation),"boom_length":player.camera_boom.spring_length,"player_screen":str(active.unproject_position(player.global_position+Vector3.UP))}
	if label=="first_diagonal_gap" and OS.get_cmdline_user_args().has("--camera-diagnosis"):
		data.occlusion=_camera_occlusion(active)
		report.checks.append({"check":"first_gap_camera_to_avatar_not_opaque_occluded","pass":data.occlusion.is_empty()})
		print("STORMWORKS_CAMERA_DIAGNOSIS ",JSON.stringify(data))
	report.captures.append(data)

func _camera_occlusion(camera: Camera3D) -> Array:
	var from:=camera.global_position
	var to:=player.global_position+Vector3.UP
	var hits:=[]
	for mesh: MeshInstance3D in world.find_children("*","MeshInstance3D",true,false):
		if player.is_ancestor_of(mesh) or not mesh.mesh or not mesh.is_visible_in_tree():continue
		if mesh.material_override is ShaderMaterial:
			var visibility=mesh.material_override.get_shader_parameter("camera_visibility")
			if visibility!=null and float(visibility)<=.05:continue
		var inverse:=mesh.global_transform.affine_inverse()
		var a:=inverse*from;var b:=inverse*to
		if mesh.get_aabb().intersects_segment(a,b)==null:continue
		var triangles:=mesh.mesh.get_faces()
		var closest:=INF
		for i in range(0,triangles.size(),3):
			var point=Geometry3D.segment_intersects_triangle(a,b,triangles[i],triangles[i+1],triangles[i+2])
			if point!=null:closest=minf(closest,from.distance_to(mesh.to_global(point)))
		if closest<INF:hits.append({"mesh":str(mesh.get_path()),"distance":closest})
	hits.sort_custom(func(a,b):return a.distance<b.distance)
	return hits

func _frames(count: int) -> void:
	for frame in count:
		# Match the parent connected driver: an OS focus pause is not a blocked
		# doorway. Resume through the real menu, then reassert public input.
		if tree.paused:
			var menu=world.get("native_pause_menu")
			if menu:
				menu.resume_button.pressed.emit()
				report.resumed_pauses=int(report.get("resumed_pauses",0))+1
		await tree.physics_frame
		await tree.process_frame
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
	var passed:=player.is_on_floor() and Vector2(_pos().x-target.x,_pos().z-target.z).length() < .4
	if not passed:
		var collisions:=[]
		for index in player.get_slide_collision_count():
			var collision:KinematicCollision3D=player.get_slide_collision(index)
			collisions.append({"path":str(collision.get_collider().get_path()),"normal":str(collision.get_normal()),"point":str(collision.get_position())})
		report.blocked_walk={"target":str(target),"position":str(_pos()),"collisions":collisions,"control_locked":player.control_locked,"animation":player.current_anim,"tree_paused":tree.paused}
		print("STORMWORKS_BLOCKED_WALK ",JSON.stringify(report.blocked_walk))
	return passed

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
			if exercise_fall_retry and not await _fall_and_retry(): return
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

extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var room = load("res://scenes/environment/maintenance_vertical.tscn").instantiate()
	world.add_child(room)
	var player: EchoPlayer = load("res://scenes/player/echo_player.tscn").instantiate()
	player.position = Vector3(0, 0.1, -5.1)
	world.add_child(player)
	player.finish_opening_recovery()
	player.surface_traversal_enabled = true
	for i in range(8): await physics_frame
	if not _check(room.get_node("COLL_CLIMB_FirstWall").is_in_group("climbable"), "missing authored climb surface"): return
	Input.action_press("move_forward")
	player.request_jump() # same path as touch Jump
	for i in range(5): await physics_frame
	if not _check(player.traversal.is_climbing(), "real player did not enter climb from touch request"): return
	for i in range(160):
		await physics_frame
		if player.surface_motor.hanging: break
	if not _check(player.surface_motor.hanging, "climb did not reach ledge"): return
	print("HANG ",player.position," stamina=",player.stamina)
	if not _check_leg_planes(player): return
	var hang := player.position
	var visual_origin := player.visual_root.position
	for i in range(8): await physics_frame
	if not _check(player.position.distance_to(hang) < 0.1 and player.stamina < 100.0, "hang drifted or did not cost stamina"): return
	player.request_jump()
	for i in range(120):
		await physics_frame
		if not _check_leg_planes(player): return
		if not player.traversal.is_climbing(): break
	Input.action_release("move_forward")
	for i in range(20): await physics_frame
	if not _check(player.is_on_floor() and player.position.y > 3.3 and player.position.z < -5.5, "mantle failed to land on authored platform"): return
	print("MANTLE ",player.position)
	if not _check(player.visual_root.position.distance_to(visual_origin) < 0.001, "mantle retained a visual origin offset"): return
	if not _check(not player.combat_available and not player.contract_with_zero_sealed, "traversal granted Zero/combat"): return
	# A new fixture for untagged walls and a blocked overhead capsule path.
	player.surface_motor.reset(player)
	player.position = Vector3(0, 0.1, -5.1)
	player.velocity = Vector3.ZERO
	room.get_node("COLL_CLIMB_FirstWall").remove_from_group("climbable")
	for i in range(28): await physics_frame
	Input.action_press("move_forward")
	player.request_jump()
	for i in range(8): await physics_frame
	Input.action_release("move_forward")
	if not _check(not player.traversal.is_climbing(), "untagged smooth wall became climbable"): return
	room.get_node("COLL_CLIMB_FirstWall").add_to_group("climbable")
	player.position = Vector3(0, 1.9, -5.1)
	player.velocity = Vector3.ZERO
	player.traversal.start_climbing(Vector3.BACK, Vector3(0,2.9,-5.75))
	player.surface_motor.hanging = true
	var ceiling := StaticBody3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2,0.3,2)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	ceiling.add_child(collision)
	ceiling.position = Vector3(0,4.0,-5.1)
	world.add_child(ceiling)
	for i in range(3): await physics_frame
	if not _check(not player.surface_motor._begin_mantle(player), "mantle crossed obstructed headroom"): return
	ceiling.queue_free()
	player.request_dodge() # same path as the touch Dodge button
	for i in range(3): await physics_frame
	if not _check(not player.traversal.is_climbing() and not player.is_dodging, "touch Dodge did not release the wall cleanly"): return
	player.traversal.start_climbing(Vector3.BACK, Vector3(0,2.9,-5.75))
	player.stamina = 0
	for i in range(5): await physics_frame
	if not _check(not player.traversal.is_climbing(), "zero stamina did not release wall"): return
	world.queue_free()
	for i in range(3): await process_frame
	# Headless process frames can run faster than the audio mixer. Allow its
	# pending one-shot WAV playback references to retire after scene disposal.
	await create_timer(0.10).timeout
	print("PASS maintenance traversal: real touch jump latch, explicit surfaces, stamina, hang, swept mantle, blocked headroom, exhaustion and no Zero")
	quit(0)

func _check(condition: bool, detail: String) -> bool:
	if not condition:
		push_error(detail)
		quit(1)
	return condition

func _check_leg_planes(player: EchoPlayer) -> bool:
	var skeleton := player.find_child("Skeleton3D",true,false) as Skeleton3D
	for suffix in ["1", "2"]:
		var right := skeleton.to_global(skeleton.get_bone_global_pose(skeleton.find_bone("tripo__1_Right_Limb_"+suffix)).origin)
		var left := skeleton.to_global(skeleton.get_bone_global_pose(skeleton.find_bone("tripo__1_Left_Limb_"+suffix)).origin)
		if not _check(right.is_finite() and left.is_finite() and right.x < left.x, "knees/ankles crossed their anatomical planes"): return false
	var hip := skeleton.to_global(skeleton.get_bone_global_pose(skeleton.find_bone("tripo__1_Right_Limb_0")).origin)
	for side in ["Right", "Left"]:
		var ankle := skeleton.to_global(skeleton.get_bone_global_pose(skeleton.find_bone("tripo__1_"+side+"_Limb_2")).origin)
		if not _check(ankle.y < hip.y + 0.05, "folded ankle rose above hip during mantle"): return false
	return true

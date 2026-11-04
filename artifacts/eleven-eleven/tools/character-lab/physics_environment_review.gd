extends SceneTree
## Isolated Jolt/tool availability test; no production physics setting changes.
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size()!=1: quit(2);return
	var world := Node3D.new()
	root.add_child(world)
	var floor := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size=Vector3(4,.2,4)
	floor_shape.shape=box
	floor.position.y=-.1
	floor.add_child(floor_shape)
	world.add_child(floor)
	var ball := RigidBody3D.new()
	ball.position.y=1.75
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius=.25
	shape.shape=sphere
	ball.add_child(shape)
	world.add_child(ball)
	var finite := true
	var minimum_y := INF
	for frame in 180:
		await physics_frame
		finite=finite and ball.position.is_finite() and ball.linear_velocity.is_finite()
		minimum_y=minf(minimum_y,ball.position.y)
	var settled := absf(ball.position.y-.25)<.01 and ball.linear_velocity.length()<.02
	var capabilities := {}
	for name in ["SpringBoneSimulator3D","SpringBoneCollisionCapsule3D","SpringBoneCollisionSphere3D","SoftBody3D","PhysicalBoneSimulator3D"]:
		capabilities[name]=ClassDB.class_exists(name)
	var passed := finite and settled and minimum_y>=.235 and not capabilities.values().has(false)
	var report := {"status":"PASS_ISOLATED_JOLT_AND_API" if passed else "FAIL", "engine":Engine.get_version_info().string,
		"configured_backend":ProjectSettings.get_setting("physics/3d/physics_engine"),"physics_hz":Engine.physics_ticks_per_second,
		"ticks":180,"finite":finite,"settled_center_y":ball.position.y,"minimum_center_y":minimum_y,"capabilities":capabilities,
		"scope":"Actual isolated rigid body floor collision;API availability only for spring/cloth. No Echo wing/body/cloth or production backend acceptance."}
	var file := FileAccess.open(args[0],FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"));file.close()
	print("PHYSICS_ENVIRONMENT ",JSON.stringify(report))
	world.queue_free()
	await process_frame
	quit(0 if passed else 1)

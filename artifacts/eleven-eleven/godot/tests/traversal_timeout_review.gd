extends SceneTree
func _initialize() -> void:_run.call_deferred()
func _run() -> void:
	var world:=Node3D.new();root.add_child(world)
	var ground:=StaticBody3D.new();var col:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(20,.2,20);col.shape=box;ground.position.y=-.1;ground.add_child(col);world.add_child(ground)
	var actor:EchoPlayer=load("res://scenes/player/echo_player.tscn").instantiate();world.add_child(actor);actor.finish_opening_recovery()
	for i in 8:await physics_frame
	actor.set_physics_process(false)
	var motor=actor.surface_motor
	var completed:Array=[];motor.mantle_completed.connect(func():completed.append(true))
	# A corrupt/stalled transition cursor still has clear ground at its distant
	# endpoint. The old watchdog teleported4m there and emitted completion.
	motor._mantle_points.assign([Vector3(0,0,-2),Vector3(0,0,-4)])
	motor._transition_support=ground
	motor._transition_local_points.assign([ground.to_local(Vector3(0,0,-2)),ground.to_local(Vector3(0,0,-4))])
	motor._transition_kind="mantle";motor._mantle_duration=.1;motor._mantle_elapsed=.5
	var before:=actor.global_position
	motor.tick(actor,1.0/60.0,Vector2.ZERO,false,false)
	var distance:=before.distance_to(actor.global_position)
	var ok:bool=distance<.1 and completed.is_empty() and motor._mantle_points.is_empty() and actor.velocity.y<0 and not actor.contract_with_zero_sealed
	print("PASS" if ok else "FAIL"," traversal watchdog releases into gravity without teleport/completion; displacement=",distance)
	world.queue_free();for i in 3:await process_frame
	quit(0 if ok else 1)

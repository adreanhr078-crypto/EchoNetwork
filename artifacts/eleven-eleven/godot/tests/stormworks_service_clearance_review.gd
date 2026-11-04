extends SceneTree
## One declared portal approach, public movement only; no progression receipt.
func _initialize() -> void:_run.call_deferred()
func _run() -> void:
	var world:=Node3D.new();root.add_child(world)
	var room=load("res://scenes/environment/maintenance_stormworks.tscn").instantiate();world.add_child(room)
	room.restore_service_open()
	var player=load("res://scenes/player/echo_player.tscn").instantiate()
	player.position=Vector3(.060248,5.521001,-17.6446)
	world.add_child(player);player.finish_opening_recovery();player.set_gameplay_orbit(Vector3.ZERO)
	for frame in 10:await physics_frame
	player.set_mobile_input_vector(Vector2(0,-.7),true)
	for frame in 100:await physics_frame
	player.set_mobile_input_vector(Vector2.ZERO,false)
	var hits:=[]
	for index in player.get_slide_collision_count():
		var hit:KinematicCollision3D=player.get_slide_collision(index)
		hits.append({"collider":str(hit.get_collider().get_path()),"point":str(hit.get_position()),"normal":str(hit.get_normal())})
	var report:={"position":str(player.position),"hits":hits,"gate_collision_disabled":room._gate_collider.disabled,"passed":player.position.z< -18.8}
	print("SERVICE_CLEARANCE ",JSON.stringify(report))
	world.queue_free();await process_frame;quit(0 if report.passed else 1)

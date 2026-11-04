extends SceneTree
## Isolated reproduction of a camera obstruction found in the earned route.
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var world:=Node3D.new();root.add_child(world)
	var room=load("res://scenes/environment/maintenance_stormworks.tscn").instantiate();world.add_child(room)
	var player=load("res://scenes/player/echo_player.tscn").instantiate()
	player.position=Vector3(-4.793321,2.18369,-7.85148)
	world.add_child(player);player.finish_opening_recovery();player.set_physics_process(false)
	player.set_gameplay_orbit(Vector3(0,.89,0))
	for frame in 30: await process_frame;await physics_frame
	var from: Vector3=player.player_camera.global_position
	var to: Vector3=player.global_position+Vector3.UP*1.4
	var ray:=PhysicsRayQueryParameters3D.create(from,to,1,[player.get_rid()])
	ray.hit_back_faces=true;ray.hit_from_inside=true
	var hit:=world.get_world_3d().direct_space_state.intersect_ray(ray)
	var visual_hits:=[]
	for mesh: MeshInstance3D in room.find_children("*","MeshInstance3D",true,false):
		if not mesh.mesh or not mesh.is_visible_in_tree():continue
		var inv:=mesh.global_transform.affine_inverse()
		var a:=inv*from;var b:=inv*to
		if mesh.get_aabb().intersects_segment(a,b)==null:continue
		var triangles:=mesh.mesh.get_faces()
		var best:=INF
		for i in range(0,triangles.size(),3):
			var point=Geometry3D.segment_intersects_triangle(a,b,triangles[i],triangles[i+1],triangles[i+2])
			if point!=null:best=minf(best,from.distance_to(mesh.to_global(point)))
		if best<INF:visual_hits.append({"mesh":str(mesh.get_path()),"distance":best,"bounds":str(mesh.get_aabb())})
	visual_hits.sort_custom(func(a,b):return a.distance<b.distance)
	var report:={"camera":str(from),"target":str(to),"boom":player.camera_boom.spring_length,"physics_hit":str(hit.get("collider")),"visual_hits":visual_hits}
	var path: String=OS.get_cmdline_user_args()[0]
	var file:=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("CAMERA_OCCLUSION ",JSON.stringify(report))
	world.queue_free();await process_frame;quit()

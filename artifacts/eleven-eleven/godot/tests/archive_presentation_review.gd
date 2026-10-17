extends SceneTree
func _initialize() -> void: _run.call_deferred()
func _check(ok: bool,message: String) -> bool:
	if not ok:
		push_error(message)
		quit(1)
	return ok
func _run() -> void:
	var room = load("res://scenes/environment/memory_archive_wing.tscn").instantiate()
	root.add_child(room)
	room.set_audio_muted(true)
	await process_frame
	var count: int = room.find_children("*","CollisionShape3D",true,false).size()
	for name in ["NorthRack_6","NorthRack_11","NorthRack_16","SouthRack_6","SouthRack_11","SouthRack_16"]:
		var tower: StaticBody3D = room.get_node(name)
		var bounds := AABB()
		var found := false
		for mesh in tower.get_node("Model").find_children("*","MeshInstance3D",true,false):
			var local: AABB = tower.global_transform.affine_inverse()*mesh.global_transform*mesh.get_aabb()
			bounds = bounds.merge(local) if found else local
			found = true
		if not _check(found and bounds.position.y>=-0.01 and absf(bounds.size.y-6.5)<0.01 and bounds.size.x<=2.41 and bounds.size.z<=1.81,"Server visual does not fit actual climb collider: "+name+str(bounds)): return
	var shard: Area3D = room._shard_nodes.shard_shizuka
	var anchor := shard.transform
	var visual := shard.get_node("ShardVisual") as MeshInstance3D
	var before := visual.transform
	await create_timer(0.16).timeout
	if not _check(shard.transform==anchor and visual.transform!=before,"Shard animation moved trigger or failed to animate visual"): return
	if not _check(not room.gate_open and room.collected_shards.is_empty() and room.find_children("*","CollisionShape3D",true,false).size()==count,"Presentation advanced gameplay or added physics"): return
	room.reduced_motion = true
	var frozen: float = room._archive_time
	var still := visual.transform
	await create_timer(0.16).timeout
	if not _check(is_equal_approx(room._archive_time,frozen) and visual.transform==still and not room._air_motes._air.visible,"Reduced Motion retained archive motion"): return
	room.reduced_motion = false
	paused = true
	await create_timer(0.16).timeout
	if not _check(is_equal_approx(room._archive_time,frozen),"Pause advanced archive clock"): return
	paused = false
	await create_timer(0.16).timeout
	if not _check(room._archive_time>frozen,"Archive clock failed to resume"): return
	room._collect_shard("shard_shizuka")
	var releases: int = room._air_motes.release_count
	room._collect_shard("shard_shizuka")
	if not _check(releases==1 and room._air_motes.release_count==1 and not room._memory_sound.playing,"Repeated/muted shard replayed presentation"): return
	room._collect_shard("shard_yuki")
	room._collect_shard("shard_sector11")
	# process_frame resumes before the room runs _process; allow its actual
	# presentation frame to execute before inspecting the decoder marker.
	await process_frame
	await process_frame
	if not _check(room._decoder_beacon.visible and not room.gate_open,"Three memories did not guide the decoder or bypassed its decision"): return
	room.restore_state(room.get_state())
	if not _check(room._air_motes.release_count==3 and not room._memory_sound.playing,"Restore replayed archive VFX/SFX"): return
	room.queue_free()
	await process_frame
	print("PASS archive presentation: six measured visual/collider fits, visual-only shard motion, pause/RM, no progression mutation, single collection bursts/mute/silent restore and decoder-ready guidance")
	quit(0)

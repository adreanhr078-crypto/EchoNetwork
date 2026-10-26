extends SceneTree
var checks:=0
func _initialize() -> void: _run.call_deferred()
func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok:push_error(label);quit(1);assert(ok,label)
func _run() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("Engine-baked skin review requires a real renderer with registered skins")
		quit(2);return
	var folder:=OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(folder)
	root.size=Vector2i(1280,720)
	var world:=Node3D.new();root.add_child(world)
	var key:=DirectionalLight3D.new();key.rotation_degrees=Vector3(-30,-35,0);key.light_energy=1.2;world.add_child(key)
	var player:EchoPlayer=load("res://scenes/player/echo_player.tscn").instantiate();world.add_child(player)
	player.global_position=Vector3(-50.3,9.4,-304.0)
	player.finish_opening_recovery();player.set_physics_process(false);player.set_process(false)
	player.contract_with_zero_sealed=true
	player.manifest_zero_wing()
	player.set_zero_eye_active(true)
	var model:Node3D=player.visual_root
	var source:Skeleton3D=model.find_child("Skeleton3D",true,false)
	var ap:=player.animation_player
	ap.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	ap.play("RUN",0);ap.seek(.2,true);ap.pause()
	var foreign_visible:=0
	for frame in 45:await process_frame
	for mesh:MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		if mesh.skin and mesh.is_visible_in_tree() and mesh.get_node_or_null(mesh.skeleton)!=source:foreign_visible+=1
	check(foreign_visible>0,"Actual visible wing did not exercise the foreign-skin case")
	var before:Array[Transform3D]=[]
	for bone in source.get_bone_count():before.append(source.get_bone_pose(bone))
	var offset:=Vector3(-1.3,0,0)
	GhostTrailSpawner.spawn_ghost(world,model,1.5,Color(.12,.7,.9,.14),offset)
	var ghosts:=get_nodes_in_group("echo_motion_ghost")
	check(ghosts.size()==1,"Actual body snapshot was not created")
	var ghost:Node3D=ghosts[0]
	var rig:Skeleton3D=ghost.find_children("*","Skeleton3D",true,false)[0]
	check(rig.get_bone_count()==68,"Foreign wing replaced the captured body rig")
	var frozen:Array[Transform3D]=[]
	for bone in 68:
		check(source.get_bone_pose(bone).is_equal_approx(before[bone]),"Snapshot modified the actual body")
		check(rig.get_bone_pose(bone).is_equal_approx(before[bone]),"Snapshot invented a different body pose")
		frozen.append(rig.get_bone_pose(bone))
	var clones:=ghost.find_children("*","MeshInstance3D",true,false)
	check(not clones.is_empty(),"Snapshot contains no actual skin")
	for mesh:MeshInstance3D in clones:
		check(mesh.get_node_or_null(mesh.skeleton)==rig and mesh.material_override is ShaderMaterial,"Snapshot bypassed its own rig or authored shader")
		for bind in mesh.skin.get_bind_count():check(rig.find_bone(mesh.skin.get_bind_name(bind))>=0,"Foreign accessory skin bound to the body")
	for frame in 3:await process_frame
	var maximum_surface_error:=0.0
	for mesh:MeshInstance3D in clones:
		var original:MeshInstance3D=instance_from_id(mesh.get_meta("source_skin_instance_id"))
		var original_baked:=original.bake_mesh_from_current_skeleton_pose()
		var clone_baked:=mesh.bake_mesh_from_current_skeleton_pose()
		check(original_baked!=null and clone_baked!=null,"Current renderer did not register both source and captured skin")
		for surface in original_baked.get_surface_count():
			var vertices:PackedVector3Array=original_baked.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			var captured:PackedVector3Array=clone_baked.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			check(vertices.size()==captured.size(),"Snapshot changed actual baked skin topology")
			for vertex in range(0,vertices.size(),maxi(1,vertices.size()/512)):
				var expected:Vector3=original.global_transform*vertices[vertex]+offset
				var actual:Vector3=mesh.global_transform*captured[vertex]
				maximum_surface_error=maxf(maximum_surface_error,expected.distance_to(actual))
	check(maximum_surface_error<.0002,"Non-origin snapshot distorted actual skin: "+str(maximum_surface_error))
	ap.play("RUN",0);ap.seek(.4,true);ap.pause()
	for bone in 68:check(rig.get_bone_pose(bone).is_equal_approx(frozen[bone]),"Snapshot followed the live animation instead of freezing")
	var ink:ShaderMaterial=clones[0].material_override
	for frame in 3:await process_frame
	var opacity:float=ink.get_shader_parameter("opacity")
	paused=true
	for frame in 8:await process_frame
	check(is_equal_approx(opacity,ink.get_shader_parameter("opacity")),"Pause advanced the snapshot dissolve")
	paused=false
	var camera:=Camera3D.new();world.add_child(camera)
	camera.fov=32
	camera.global_position=player.global_position+Vector3(3,1.6,-4.2);camera.look_at(player.global_position+Vector3(-.5,1,0));camera.make_current()
	if DisplayServer.get_name()!="headless":
		for frame in 3:await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(folder+"/actual-wing-and-body-snapshot.png")
	ghost.queue_free()
	for frame in 3:await process_frame
	player.reduced_motion=true
	GhostTrailSpawner.spawn_ghost(world,model)
	check(get_nodes_in_group("echo_motion_ghost").is_empty(),"Reduced Motion created an animated body echo")
	player.reduced_motion=false
	for index in 4:GhostTrailSpawner.spawn_ghost(world,model)
	check(get_nodes_in_group("echo_motion_ghost").size()==3,"Snapshot pool exceeded its existing three-body bound")
	for node in get_nodes_in_group("echo_motion_ghost"):node.queue_free()
	world.queue_free()
	for frame in 3:await process_frame
	var file:=FileAccess.open(folder+"/review.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"status":"PASS","checks":checks,"actual_foreign_visible_meshes":foreign_visible,"body_joints":68,"maximum_baked_skin_error_m":maximum_surface_error,"source_or_animation_modified":false,"renderer":RenderingServer.get_current_rendering_method(),"scope":"Actual current short-jacket body, active iris and independently rigged manifested wing at a non-origin world transform. Engine-baked skin comparison, snapshot bind identity/frozen pose/source protection/pause/Reduced Motion/three-ghost bound. Separate action/art/device acceptance."},"\t"));file.close()
	print("GHOST_SKIN_SNAPSHOT PASS checks=",checks," foreign_visible=",foreign_visible)
	quit(0)

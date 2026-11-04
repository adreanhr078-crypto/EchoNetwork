extends "res://tests/combat_contact_regression.gd"
var folder:String
var samples:Array=[]
var failures:Array[String]=[]
var cached_indices:Dictionary={}
var camera:Camera3D
func check(ok:bool,label:String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func body_floor(avatar:Node3D) -> float:
	var minimum:=INF
	for mesh:MeshInstance3D in avatar.find_children("*","MeshInstance3D",true,false):
		if not mesh.skin:continue
		var id:=mesh.get_instance_id()
		if not cached_indices.has(id):
			var arrays:=mesh.mesh.surface_get_arrays(0)
			var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			var bones:PackedInt32Array=arrays[Mesh.ARRAY_BONES]
			var weights:PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
			var rig:=mesh.get_node(mesh.skeleton) as Skeleton3D
			var influences:=int(bones.size()/vertices.size())
			var ids:=PackedInt32Array()
			for vertex in vertices.size():
				var wing:=false
				for influence in influences:
					var slot:=vertex*influences+influence
					if weights[slot]<=1e-8:continue
					var bone:=mesh.skin.get_bind_bone(bones[slot])
					if bone<0:bone=rig.find_bone(mesh.skin.get_bind_name(bones[slot]))
					if rig.get_bone_name(bone).begins_with("Wing"):wing=true;break
				if not wing:ids.append(vertex)
			cached_indices[id]=ids
		var baked:ArrayMesh=mesh.bake_mesh_from_current_skeleton_pose()
		var posed:PackedVector3Array=baked.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		for vertex in cached_indices[id]:minimum=minf(minimum,(mesh.global_transform*posed[vertex]).y)
	return minimum
func _run() -> void:
	folder=OS.get_cmdline_user_args()[0];DirAccess.make_dir_recursive_absolute(folder)
	root.size=Vector2i(1280,720)
	_body(Vector3(0,-.2,0),Vector3(80,.2,80))
	var floor_mesh:=MeshInstance3D.new();var box:=BoxMesh.new();box.size=Vector3(80,.1,80);floor_mesh.mesh=box;floor_mesh.position.y=-.05;root.add_child(floor_mesh)
	var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("202730");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_energy=.65;root.add_child(env)
	var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-40,-30,0);light.light_energy=1.2;root.add_child(light)
	player=load("res://scenes/player/echo_player.tscn").instantiate();player.avatar_scene_override=load("res://scenes/characters/echo_school_candidate.tscn");root.add_child(player);player.finish_opening_recovery()
	await _steps(20)
	camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=2.6;root.add_child(camera);camera.make_current()
	for pact in [false,true]:
		if pact:player.awaken_zero_pact(.9)
		await _steps(20)
		player.set_mobile_input_vector(Vector2.ZERO,false)
		player.request_dodge()
		var started:=false;var paused_once:=false;var count:=0;var low:=INF;var phase:=0.0;var shots:=0
		for frame in 180:
			await process_frame
			if not player.is_dodging:
				if started:break
				continue
			started=true
			var point:Vector3=player.global_position+Vector3.UP*.8
			camera.global_position=point+Vector3(4,.25,2);camera.look_at(point)
			await RenderingServer.frame_post_draw
			var avatar:=player.visual_root.get_node("EchoOpeningUniform") as Node3D
			var floor_y:=body_floor(avatar);low=minf(low,floor_y);count+=1
			phase=maxf(phase,player.animation_player.current_animation_position/player.animation_player.current_animation_length)
			if shots==0 or (shots==1 and phase>.45) or (shots==2 and phase>.9):
				root.get_texture().get_image().save_png(folder.path_join("%s-roll-%d.png"%["pact" if pact else "school",shots]));shots+=1
			if not paused_once and phase>.3:
				paused_once=true
				var clock:=player.animation_player.current_animation_position;var recovery:=player.dodge_timer
				paused=true;await create_timer(.15,true,false,true).timeout
				check(is_equal_approx(clock,player.animation_player.current_animation_position) and is_equal_approx(recovery,player.dodge_timer),"Pause preserves native roll and its capsule clock")
				paused=false
		check(started and count>=4 and phase>.9,"Public roll completes its original source in the existing bounded action")
		check(low>=-.002,"Actual GPU body skin stays above the flat floor during the public roll")
		samples.append({"pact":pact,"captures":count,"maximum_native_phase":phase,"lowest_body_skin_y":low,"rig":player.rig_profile.id})
	var file:=FileAccess.open(folder.path_join("review.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"status":"PASS" if failures.is_empty() else "FAIL","failures":failures,"samples":samples,"renderer":RenderingServer.get_current_rendering_method(),"scope":"Public native roll/pause on flat floor,actual GPU body skin;source keys/capsule retained. Slopes,feather/world/camera contacts and wholechapter separate."},"\t"));file.close()
	quit(0 if failures.is_empty() else 1)

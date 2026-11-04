extends "res://tests/combat_contact_regression.gd"

const Profile=preload("res://scripts/player/echo_rig_profile.gd")
var checks:=0
var failures:Array[String]=[]
var folder: String
var cases: String
var case_reports:Array=[]
var render_review:=false
var review_camera:Camera3D
func check(ok:bool,label:String) -> bool:
	checks+=1
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
	return ok
func finish() -> void:
	var file:=FileAccess.open(folder.path_join("review.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"status":"PASS" if failures.is_empty() else "FAIL","checks":checks,"failures":failures,"cases":case_reports,"renderer":RenderingServer.get_current_rendering_method(),"scope":"Actual optional player/earned avatar cache,all423native body poses and key equality. GPU floor/actual renders only when rendered. Mount contact remains explicit;story journey,final art/performance/devices separate."},"\t"));file.close()
	quit(0 if failures.is_empty() else 1)
func _run() -> void:
	var args:=OS.get_cmdline_user_args()
	folder=args[0];cases=args[1];render_review=args.has("--render")
	DirAccess.make_dir_recursive_absolute(folder)
	root.size=Vector2i(1280,720)
	_body(Vector3(-20,-.2,-20),Vector3(80,.2,80))
	player=load("res://scenes/player/echo_player.tscn").instantiate()
	player.avatar_scene_override=load("res://scenes/characters/echo_school_candidate.tscn")
	root.add_child(player)
	player.finish_opening_recovery()
	await _steps(20)
	var normal:=player.visual_root.get_node("EchoOpeningUniform")
	var body_id:=player.get_instance_id()
	var camera_id:=player.player_camera.get_instance_id()
	var before:=player.global_position
	if not check(not player.set_earned_contract_appearance(true) and player.rig_profile.id==Profile.SCHOOL65_ID,"Appearance cannot grant a pact before explicit authority"):finish();return
	player.set_combat_available(true)
	var blade_id:=player.find_child("KatanaBlade",true,false).get_instance_id()
	player.awaken_zero_pact(.9)
	await _steps(20)
	if not check(player.rig_profile.get("id")==Profile.PACT72_ID,"Earned presentation selects the verified72-bone target"):finish();return
	var avatar:=player.visual_root.get_node("EchoOpeningUniform")
	var rig:Skeleton3D=avatar.find_child("Skeleton3D",true,false)
	if not check(player.get_instance_id()==body_id and player.player_camera.get_instance_id()==camera_id and player.global_position.distance_to(before)<.001,"Transformation preserves the actual body,capsule position and camera"):finish();return
	check(player.find_child("KatanaBlade",true,false).get_instance_id()==blade_id and player._hand_weapon_socket.get_parent()==rig,"Equipped weapon survives the measured new hand socket")
	check(player.footstep_system.anim_player==player.animation_player,"Foot contacts follow the active animation owner")
	player.control_locked=true
	player.animation_player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var libraries:Dictionary=avatar.source_libraries()
	var actions:Dictionary=avatar.source_actions()
	var names:Dictionary=avatar.PACT_FILES
	if render_review:
		var env:=WorldEnvironment.new();env.environment=Environment.new()
		env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("202730")
		env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color("cad5ef");env.environment.ambient_light_energy=.7
		root.add_child(env)
		var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-40,-30,0);light.light_energy=1.3;root.add_child(light)
		var rim:=DirectionalLight3D.new();rim.rotation_degrees=Vector3(-20,145,0);rim.light_energy=.65;root.add_child(rim)
		review_camera=Camera3D.new();review_camera.projection=Camera3D.PROJECTION_ORTHOGONAL;root.add_child(review_camera);review_camera.make_current()
	var converter:=Basis(Vector3(1,0,0),Vector3(0,0,-1),Vector3(0,1,0))
	for alias:String in libraries:
		var source:Animation=libraries[alias].get_animation(actions[alias])
		var clip:Animation=player.animation_player.get_animation(alias)
		var exact:=clip.get_track_count()==source.get_track_count() and clip.length==source.length
		var keys:=0
		for track in source.get_track_count():
			exact=exact and source.track_get_type(track)==clip.track_get_type(track) and source.track_get_key_count(track)==clip.track_get_key_count(track) and source.track_get_path(track).get_subname(0)==clip.track_get_path(track).get_subname(0)
			for key in source.track_get_key_count(track):
				exact=exact and source.track_get_key_time(track,key)==clip.track_get_key_time(track,key) and source.track_get_key_value(track,key)==clip.track_get_key_value(track,key)
				keys+=1
		check(exact,"Source keys remain exact after node-path binding: "+alias)
		var reference:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(cases.path_join(names[alias]).path_join("blender-reference.json")))
		var loop:=clip.loop_mode;clip.loop_mode=Animation.LOOP_NONE
		var max_position:=0.0;var max_rotation:=0.0;var lowest_body:=INF
		player.is_dodging=alias=="preset_biped_roll_001"
		if player.is_dodging:avatar.wing_reveal=0
		for frame in reference.samples.size():
			var sample:Dictionary=reference.samples[frame]
			player.animation_player.play(alias,0)
			player.animation_player.seek(float(sample.time),true)
			player.animation_player.pause()
			await process_frame
			for role:String in reference.target_bones:
				var index:=rig.find_bone(str(reference.target_bones[role]).replace(":","_"))
				var expected:Dictionary=sample.bones[role];var p:Array=expected.position;var q:Array=expected.quaternion_wxyz
				var actual:Transform3D=avatar.global_transform.affine_inverse()*rig.global_transform*rig.get_bone_global_pose(index)
				max_position=maxf(max_position,actual.origin.distance_to(converter*Vector3(p[0],p[1],p[2])))
				var rotation:Quaternion=(converter*Basis(Quaternion(q[1],q[2],q[3],q[0]))).get_rotation_quaternion()
				var relative:Quaternion=(actual.basis.orthonormalized().get_rotation_quaternion().inverse()*rotation).normalized()
				max_rotation=maxf(max_rotation,rad_to_deg(2*atan2(Vector3(relative.x,relative.y,relative.z).length(),absf(relative.w))))
			if render_review and frame in [0,int(reference.samples.size()/2),reference.samples.size()-1]:
				await RenderingServer.frame_post_draw
				await _capture_pose(alias,frame,avatar)
		clip.loop_mode=loop
		case_reports.append({"alias":alias,"samples":reference.samples.size(),"keys_compared_exactly":keys,"max_body_position_error_m":max_position,"max_body_rotation_error_degrees":max_rotation})
		if not check(max_position<.0001 and max_rotation<.1,"All65body joints match the saved Blender source on the actual player: "+alias):finish();return
	player.is_dodging=false
	player.control_locked=false
	check(player.set_earned_contract_appearance(false) and player.visual_root.get_node("EchoOpeningUniform")==normal,"Normal appearance reuses its original cached avatar")
	check(player.set_earned_contract_appearance(true) and player.visual_root.get_node("EchoOpeningUniform")==avatar,"Earned appearance reuses its cached Pact72 avatar")
	check(player.player_camera.get_instance_id()==camera_id and player.find_child("KatanaBlade",true,false).get_instance_id()==blade_id,"Repeated presentation changes preserve camera and weapon identity")
	finish()

func _capture_pose(alias:String,frame:int,avatar:Node3D) -> void:
	var low:=Vector3(INF,INF,INF);var high:=Vector3(-INF,-INF,-INF)
	for mesh:MeshInstance3D in avatar.find_children("*","MeshInstance3D",true,false):
		if not mesh.skin:continue
		var skin:ArrayMesh=mesh.bake_mesh_from_current_skeleton_pose();var bounds:=skin.get_aabb()
		for corner in 8:
			var point:Vector3=mesh.global_transform*bounds.get_endpoint(corner);low=low.min(point);high=high.max(point)
	var center:Vector3=(low+high)*.5
	for view in ["front","side"]:
		review_camera.size=maxf(high.y-low.y+.25,(high.x-low.x+.25)*.5625)
		review_camera.global_position=center+(Vector3(0,0,5) if view=="front" else Vector3(5,0,0))
		review_camera.look_at(center)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(folder.path_join("%s-%03d-%s.png"%[alias,frame,view]))

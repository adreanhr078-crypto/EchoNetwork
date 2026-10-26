extends "res://tests/campaign_room_render_review.gd"

## Four native High composition views. The inherited cold fixture and one
## explicit actor spawn are declared; these are never earned-route evidence.
var _four_views_captured:=false

func _capture(_label:String)->void:
	if _four_views_captured:return
	_four_views_captured=true
	var args:=OS.get_cmdline_user_args()
	if args.size()<3:
		push_error("Expected room id,label and an absolute evidence folder")
		quit(1);return
	folder=args[2]+"/"
	DirAccess.make_dir_recursive_absolute(folder)
	var id:String=args[0]
	var ids:=["specimen","archive","reactor","decon","mirror"]
	var index:=ids.find(id)
	if index<0:push_error("Unsupported visual inventory room");quit(1);return
	main.set_visual_quality("high")
	main.set_reduced_motion(false)
	var director:Node=main.get_node("NativeCampaignController")
	var room:Node3D=director.rooms[index]
	var progress_before:=JSON.stringify(director.progress)
	var sets:Dictionary={
		"specimen":[["entry",Vector3(-3,2.2,3),Vector3(-15,2,-5)],["reverse",Vector3(-27,2.4,-14),Vector3(-12,2,0)],["lateral",Vector3(-27,3,3),Vector3(-12,1.8,-7)],["hero",Vector3(-21.8,2.5,-8.2),Vector3(-20,2.1,-12)]],
		"archive":[["entry",Vector3(-2,2.2,0),Vector3(-14,2.4,0)],["reverse",Vector3(-20,2.6,1.5),Vector3(-3,2,0)],["lateral",Vector3(-19,5,10),Vector3(-8,3,-4)],["hero",Vector3(-8,2.3,-3.3),Vector3(-11,1.6,0)]],
		"reactor":[["entry",Vector3(1.8,-1.8,-6.5),Vector3(0,-1.5,-23)],["reverse",Vector3(0,2.2,-41),Vector3(0,-1.4,-22)],["lateral",Vector3(-15,3,-22),Vector3(0,-2,-24)],["hero",Vector3(9,0,-16),Vector3(0,-2,-22)]],
		"decon":[["entry",Vector3(0,2.2,-2),Vector3(0,2.4,-17)],["reverse",Vector3(0,2.8,-29),Vector3(0,2.4,-14)],["lateral",Vector3(-10.5,5,-15),Vector3(2,2,-18)],["hero",Vector3(0,2,-13),Vector3(-6.5,2,-16)]],
		"mirror":[["entry",Vector3(0,2.2,-2),Vector3(0,2.5,-22)],["reverse",Vector3(0,3,-32.5),Vector3(0,2,-12)],["lateral",Vector3(-11.8,3.6,-18),Vector3(0,2.3,-21)],["hero",Vector3(6,2.2,-24),Vector3(0,2,-30)]]
	}
	var camera:=Camera3D.new();camera.fov=65;camera.near=.08
	room.add_child(camera)
	camera.environment=main.player.player_camera.environment
	camera.make_current();main.hud.hide()
	var records:=[]
	for view in sets[id]:
		camera.position=view[1];camera.look_at(room.to_global(view[2]))
		await _frames(15)
		var query:=PhysicsPointQueryParameters3D.new()
		query.position=camera.global_position;query.collide_with_areas=false
		var overlaps:=room.get_world_3d().direct_space_state.intersect_point(query)
		# Hide only known capture HUD buttons,after their normal UI update.
		# Keep the world's post effects and all 3D state/labels intact.
		await RenderingServer.frame_pre_draw
		for control in root.find_children("*","Button",true,false):
			if control.text.contains("الحالة") or control.text.contains("توقف") or control.text in ["Pause","Status [I]"]:control.hide()
		await RenderingServer.frame_post_draw
		var filename:=String(view[0])+".png"
		root.get_texture().get_image().save_png(folder+filename)
		records.append({"view":view[0],"file":filename,"local_camera":str(camera.position),"local_target":str(view[2]),"solid_overlap_count":overlaps.size(),"sha256":FileAccess.get_sha256(folder+filename)})
	camera.queue_free();main.player.player_camera.make_current()
	var hashes:={}
	var paths:=["res://tests/room_four_high_views_review.gd","res://tests/campaign_room_render_review.gd","res://scripts/environment/"+director.FILES[index]+".gd","res://engine_visuals/HyperAnimeWorldManager.gd","res://scripts/systems/native_campaign_controller.gd","res://assets/characters/echo_v31_short_jacket.glb"]
	for node in room.find_children("*","Node",true,false):
		if not node.scene_file_path.is_empty() and not paths.has(node.scene_file_path):paths.append(node.scene_file_path)
	for path in paths:hashes[path]=FileAccess.get_sha256(path)
	var file:=FileAccess.open(folder+"four-high-views.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"room":id,"shared_hyper_preset":main.get_node("/root/HyperAnimeWorldManager").preset,"tier":main.get_node("/root/HyperAnimeWorldManager").quality,"renderer":RenderingServer.get_current_rendering_method(),"framebuffer":[root.size.x,root.size.y],"render_scale":root.scaling_3d_scale,"reduced_motion":main.reduced_motion,"views":records,"source_hashes":hashes,"progress_unchanged":progress_before==JSON.stringify(director.progress),"scope":"Four fixed actual native High cameras in a validated cold checkpoint with an explicit actor spawn. Camera-overlap review remains mandatory. No public route,moving acting,sound,performance,fun or final art acceptance."},"\t"));file.close()
	print("ROOM_FOUR_HIGH_VIEWS ",id)

extends SceneTree

## Isolated rendered art diagnosis after the connected fixture exhausted the
## current device's Vulkan memory. Never substitutes for a player journey.
func _initialize()->void:_run.call_deferred()

func _frames(count:int)->void:
	for i in count:await process_frame

func _run()->void:
	var args:=OS.get_cmdline_user_args()
	if args.is_empty():quit(2);return
	var folder:=args[0];DirAccess.make_dir_recursive_absolute(folder)
	root.size=Vector2i(1280,720);root.unfocusable=true
	var room:Node3D=load("res://scripts/environment/decontamination_quarantine_wing.gd").new()
	root.add_child(room)
	room.set_audio_muted(true)
	var reference:=CharacterBody3D.new();reference.name="CameraCalibrationOnly"
	room.add_child(reference);reference.position=Vector3(0,.1,-2)
	var camera:=Camera3D.new();camera.fov=65;camera.near=.08
	room.add_child(camera);camera.make_current()
	var manager:Node=root.get_node("HyperAnimeWorldManager")
	manager.attach_scene(room,reference);manager.set_quality("high")
	await _frames(10)
	var views:=[ ["entry",Vector3(0,2.2,-2),Vector3(0,2.4,-17)], ["reverse",Vector3(0,2.8,-29),Vector3(0,2.4,-14)], ["lateral",Vector3(-9.3,5,-15),Vector3(2,2,-18)], ["hero",Vector3(0,2,-13),Vector3(-6.5,2,-16)] ]
	var records:=[]
	for view in views:
		camera.position=view[1];camera.look_at(view[2]);await _frames(10)
		await RenderingServer.frame_post_draw
		var path:=folder.path_join(view[0]+".png")
		root.get_texture().get_image().save_png(path)
		records.append({"view":view[0],"sha256":FileAccess.get_sha256(path)})
	var hashes:={}
	for p in ["res://scripts/environment/decon_tripo_architecture.gd","res://shaders/clinical_architecture_surface.gdshader","res://scripts/environment/decontamination_quarantine_wing.gd"]:hashes[p]=FileAccess.get_sha256(p)
	if args.has("--decon-whole-v2-candidate") or args.has("--review-default-decon"):
		for p in preload("res://scripts/environment/decon_precision_refinement.gd").evidence_paths():
			hashes[p]=FileAccess.get_sha256(p)
		for p in ["res://scripts/environment/decon_whole_v2_architecture.gd","res://assets/environments/decon_clinical/decon_whole_v2_static.glb","res://assets/environments/decon_clinical/decon_whole_v2_gate.glb","res://assets/environments/decon_clinical/decon_whole_v2_terminal.glb","res://assets/environments/decon_clinical/decon_whole_v2_basecolor.png","res://assets/environments/decon_clinical/decon_whole_v2_normal.png","res://assets/environments/decon_clinical/decon_whole_v2_orm.png"]:
			hashes[p]=FileAccess.get_sha256(p)
	var file:=FileAccess.open(folder.path_join("review.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"scope":"ISOLATED_STATIC_ART_ONLY;no playable actor or connected-route acceptance","renderer":RenderingServer.get_current_rendering_method(),"tier":manager.quality,"views":records,"source_hashes":hashes},"\t"));file.close()
	print("PASS isolated decon rendered capture;art review pending")
	room.queue_free();await _frames(4);quit(0)

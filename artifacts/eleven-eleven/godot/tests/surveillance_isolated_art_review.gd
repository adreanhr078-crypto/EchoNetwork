extends SceneTree
func _initialize()->void:_run.call_deferred()
func _frames(count:int)->void:
 for i in count:await process_frame
func _run()->void:
 var args:=OS.get_cmdline_user_args()
 if args.is_empty() or DisplayServer.get_name()=="headless":quit(2);return
 var folder:String=args[0];DirAccess.make_dir_recursive_absolute(folder)
 root.size=Vector2i(1280,720);root.unfocusable=true
 var room:Node3D=load("res://scenes/environment/mirror_chamber_room.tscn").instantiate();root.add_child(room);room.audio_muted=true
 var reference:=CharacterBody3D.new();reference.name="CameraCalibrationOnly";room.add_child(reference);reference.position=Vector3(0,.1,-2)
 var camera:=Camera3D.new();camera.fov=65;camera.near=.08;room.add_child(camera);camera.make_current()
 var manager:Node=root.get_node("HyperAnimeWorldManager");manager.attach_scene(room,reference);manager.set_quality("high")
 await _frames(15)
 var views:=[ ["entry",Vector3(0,2.2,-2),Vector3(0,3.8,-24)], ["reverse",Vector3(0,3,-33),Vector3(0,2.8,-10)], ["lateral",Vector3(-12,4.8,-18),Vector3(6,2.5,-13)], ["resource",Vector3(-8.7,2.2,-8),Vector3(-13.8,2.4,-9.5)] ]
 var records:=[]
 for view in views:
  camera.position=view[1];camera.look_at(view[2]);await _frames(10);await RenderingServer.frame_post_draw
  var path:String=folder.path_join(view[0]+".png");root.get_texture().get_image().save_png(path);records.append({"view":view[0],"sha256":FileAccess.get_sha256(path)})
 var hashes:={}
 for p in preload("res://scripts/environment/surveillance_room_architecture.gd").evidence_paths():hashes[p]=FileAccess.get_sha256(p)
 for p in ["res://scripts/environment/mirror_chamber_room.gd","res://scripts/environment/mirror_room_presentation.gd","res://scripts/environment/specimen_mechanical_dressing.gd","res://shaders/clinical_architecture_surface.gdshader"]:hashes[p]=FileAccess.get_sha256(p)
 var report:={"status":"CAPTURED_ART_REVIEW_PENDING","scope":"ISOLATED_STATIC_HIGH1280;no native player or earned-route acceptance","renderer":RenderingServer.get_current_rendering_method(),"tier":manager.quality,"views":records,"source_hashes":hashes,"candidate_present":room.has_node("SurveillanceTripoArchitecture")}
 var file:=FileAccess.open(folder.path_join("review.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close();print("PASS surveillance capture;art/player acceptance pending")
 room.queue_free()
 for i in 12:
  await process_frame
  await RenderingServer.frame_post_draw
 if RenderingServer.has_method("force_sync"):RenderingServer.call("force_sync")
 quit(0)

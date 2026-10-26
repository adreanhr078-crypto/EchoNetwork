extends "res://tests/native_security_route_input_smoke.gd"

## Existing real touch-input route and cold reloads,with explicit High and
## isolated versioned evidence. The current room still owns every action.
var _evidence:String
var _checks:=0
var _failed:=false
var _samples:=[]

func _initialize()->void:
	root.unfocusable=true;root.size=Vector2i(1280,720)
	super._initialize()

func _run()->void:
	_evidence=OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(_evidence)
	await super._run()
	var file:=FileAccess.open(_evidence+"/public-route-review.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":_checks,"failed":_failed,"retries":retries,"samples":_samples,"renderer":RenderingServer.get_current_rendering_method(),"framebuffer":[root.size.x,root.size.y],"scope":"Existing maintenance-end fixture then actual touch diversion/cover/latch,physical crossing and3cold spawns;not fresh chapter,real-phone performance or art acceptance."},"\t"));file.close()

func _spawn()->void:
	await super._spawn()
	main.set_visual_quality("high")
	for i in 4:await process_frame;await physics_frame

func _check(ok:bool,label:String)->bool:
	_checks+=1
	if not ok:_failed=true
	return super._check(ok,label)

func _capture(id:String)->void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(_evidence+"/"+id+".png")
	_samples.append({"id":id,"position":str(main.player.global_position),"tier":main.get_node("/root/HyperAnimeWorldManager").quality,"progress":controller.progress.duplicate(true),"camera_current":main.player.player_camera.current,"control_locked":main.player.control_locked})

func _clear()->void:
	super._clear()
	for suffix in ["",".bak",".tmp",".bak.tmp"]:
		if FileAccess.file_exists(BASE+"_campaign.json"+suffix):DirAccess.remove_absolute(BASE+"_campaign.json"+suffix)

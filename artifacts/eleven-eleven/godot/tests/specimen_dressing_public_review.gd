extends "res://tests/native_campaign_route_review.gd"

## Reuse the existing connected public-input route,with explicit High and
## versioned evidence instead of overwriting the historical route captures.
var _high_ready:=false
var _evidence:String
var _samples:=[]
var _specimen_retries:=0
var _retry_samples:=[]

func _walk(point:Vector3)->bool:
	# The older diagnostic pilot waited at(-23,0,3),which can be seen by the
	# unmodified sweep. Use the actual zero-retry fresh-chapter pilot's cover
	# waypoint(-13,0,3). Only public input changes;never the actor transform,
	# detector angle/range/grace or original colliders.
	if is_instance_valid(campaign) and room==campaign.rooms[0] and point.is_equal_approx(Vector3(-23,0,3)):
		return await super._walk(Vector3(-13,0,3))
	return await super._walk(point)

func _specimen_sweep_window(toward_north:bool)->void:
	# Match the accepted full_chapter_journey_review pilot's actual window,
	# not the legacy cold-route driver's3.4rad window from another approach.
	var begin:=.6 if toward_north else 1.1
	for i in 380:
		_resume_capture_driver()
		var angle:float=fposmod(room._scanner_sweep_angle,TAU)
		if angle>begin and angle<begin+.06:return
		await physics_frame
	_check(false,"No live specimen sweep window within one full native cycle")

func _capture()->void:
	if not _high_ready:
		_evidence=OS.get_cmdline_user_args()[0]
		DirAccess.make_dir_recursive_absolute(_evidence)
		root.size=Vector2i(1280,720);main.set_visual_quality("high")
		campaign.rooms[0].retry_requested.connect(func(anchor:Vector3):
			_specimen_retries+=1
			_retry_samples.append({"position":str(campaign.rooms[0].to_local(player.global_position)),"anchor":str(anchor),"phase":campaign.rooms[0]._scanner_sweep_angle,"current_room":campaign.current})
			print("SPECIMEN_SCANNER_RETRY ",_retry_samples[-1]))
		_high_ready=true
		for i in 8:await process_frame;await physics_frame
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	var filename:="public-%03d.png"%shot
	root.get_texture().get_image().save_png(_evidence+"/"+filename)
	_samples.append({"file":filename,"position":str(player.global_position),"room_local":str(room.to_local(player.global_position)),"progress":campaign.progress.duplicate(true),"combat_available":player.combat_available,"control_locked":player.control_locked})
	shot+=1

func _finish_review()->void:
	var saved:Dictionary=Campaign.load_checkpoint(base+"_campaign.json")
	if not _check(saved.completed==["specimen"],"Physical room04 crossing persisted exactly specimen completion"):return
	if _specimen_retries>0:
		var retry_file:=FileAccess.open(_evidence+"/scanner-retries.json",FileAccess.WRITE)
		retry_file.store_string(JSON.stringify(_retry_samples,"\t"));retry_file.close()
	if not _check(_specimen_retries==0,"Original scanner public traversal incurred no retry"):return
	if not _check(player.player_camera.current and not player.control_locked,"Original exploration camera and player control retained at handoff"):return
	var checks:={"saved_completion":saved.completed,"scanner_retries":_specimen_retries,"camera_current":player.player_camera.current,"control_locked":player.control_locked,"no_pre_pact_power":not player.combat_available,"solid_floor":player.is_on_floor(),"renderer":RenderingServer.get_current_rendering_method(),"tier":main.get_node("/root/HyperAnimeWorldManager").quality,"framebuffer":[root.size.x,root.size.y],"public_samples":_samples,"focus_interruptions":focus_interruptions,"scope":"Existing validated security fixture,then entirely public input across specimen,actual terminal,physical threshold and archive buffer;not fresh chapter or fun acceptance."}
	var out:=FileAccess.open(_evidence+"/connected-public-review.json",FileAccess.WRITE)
	out.store_string(JSON.stringify(checks,"\t"));out.close()
	await super._finish_review()

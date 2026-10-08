extends "res://tests/room_route_input_review.gd"

## Restored-hospital fixture: proves the final inspection presentation and input
## ownership only. It is not evidence of traversing the preceding campaign.
const Campaign=preload("res://scripts/systems/native_campaign_checkpoint.gd")
const Journey=preload("res://scripts/systems/native_journey_checkpoint.gd")
const Saves=preload("res://scripts/systems/save_manager.gd")

func _run() -> void:
	root.size=Vector2i(960,540)
	root.content_scale_size=Vector2i(1920,1080)
	var base:String="user://hospital_inspection_%d" % OS.get_process_id()
	Saves.save_opening_checkpoint({"schema":Saves.OPENING_SCHEMA,"milestones":{"wake":true,"clock":true,"photo":true,"memory":true,"terminal":true,"conduit":true,"ending":true},"terminal":{"frequency":111.0,"phase":45.0,"harmonic":7.0}},base+"_opening.json")
	var file:=FileAccess.open(base+"_maintenance.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema":"echo-maintenance-preview-v1","stage":6}))
	file.close()
	Journey.save_checkpoint({"schema":Journey.SCHEMA,"completed":Journey.EVENTS,"security":{"gate_open":true,"scanner_trace":true,"service_trace":false}},base+"_journey.json")
	var progress:=Campaign.initial()
	for id in ["specimen","archive","reactor","decon","mirror","lab"]:
		progress.flags[id]={}
		for key in Campaign.FLAGS[id]: progress.flags[id][key]=true
		progress=Campaign.advance(progress,id)
	if not _check(Campaign.save_checkpoint(progress,base+"_campaign.json"),"Valid restored-hospital fixture failed"): return
	var main=load("res://scenes/native_journey.tscn").instantiate()
	main.native_checkpoint_path=base+"_opening.json"
	main.native_preferences_path=base+"_prefs.cfg"
	main.get_node("SystemJourneyPreview").checkpoint_path=base+"_maintenance.json"
	main.get_node("NativeJourneyController").checkpoint_path=base+"_journey.json"
	main.get_node("NativeCampaignController").checkpoint_path=base+"_campaign.json"
	root.add_child(main)
	review_main=main
	for i in 40: await physics_frame
	main.set_audio_muted(true)
	main.set_reduced_motion(true)
	var campaign=main.get_node("NativeCampaignController")
	player=main.player
	room=campaign.hospital
	review_kind="hospital-inspection-final"
	var window=main.hud.find_child("SystemWindow",true,false)
	if not _check(window.visible and player.control_locked and not room.bed_awakened_done,"Restored bedside must retain explicit awakening ownership"): return
	window.stats_box.get_child(0).pressed.emit()
	for i in 15: await physics_frame
	if not _check(room.bed_awakened_done and not player.control_locked,"Awakening did not release exploration"): return
	for point in [Vector3(1.6,0,1.18),Vector3(1.6,0,-1.0)]:
		if not await _walk(point): return
	if not _use("VanityMirrorStation"): return
	for i in 12: await physics_frame
	if not _check(campaign._mark_inspection!=null and player.control_locked,"Inspection must own camera and input"): return
	var stretch:=root.get_stretch_transform()
	var rect:Rect2=stretch*window.panel.get_global_rect()
	if not _check(rect.position.x>=0 and rect.position.y>=0 and rect.end.x<=960 and rect.end.y<=540,"Native-canvas inspection panel must remain physically on screen"): return
	await _capture()
	window.close_window()
	for i in 5: await physics_frame
	if not _check(not player.control_locked and player.player_camera.current,"Dismissal must restore actual gameplay camera"): return
	if not _check(Campaign.load_checkpoint(base+"_campaign.json").completed.size()==7,"Actual mirror interaction was not persisted"): return
	main.queue_free()
	for i in 5: await process_frame
	for name in ["_opening.json","_maintenance.json","_journey.json","_campaign.json","_prefs.cfg"]:
		for suffix in ["",".bak",".tmp",".bak.tmp"]:
			if FileAccess.file_exists(base+name+suffix): DirAccess.remove_absolute(base+name+suffix)
	print("PASS restored hospital: actual walking/E, native-canvas panel bounds, real skin inspection, explicit dismissal, camera/input restoration and persistence; preceding journey and patient animation are outside this fixture")
	quit(0)

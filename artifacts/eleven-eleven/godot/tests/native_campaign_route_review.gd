extends "res://tests/room_route_input_review.gd"

const Campaign=preload("res://scripts/systems/native_campaign_checkpoint.gd")
const Journey=preload("res://scripts/systems/native_journey_checkpoint.gd")
const Saves=preload("res://scripts/systems/save_manager.gd")
var base: String="user://campaign_review_%d" % OS.get_process_id()
var main: Node
var campaign: Node

func _run() -> void:
	root.size=Vector2i(960,540)
	var opening: Dictionary={"schema":Saves.OPENING_SCHEMA,"milestones":{"wake":true,"clock":true,"photo":true,"memory":true,"terminal":true,"conduit":true,"ending":true},"terminal":{"frequency":111.0,"phase":45.0,"harmonic":7.0}}
	Saves.save_opening_checkpoint(opening,base+"_opening.json")
	var file:=FileAccess.open(base+"_maintenance.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema":"echo-maintenance-preview-v1","stage":6}))
	file.close()
	Journey.save_checkpoint({"schema":Journey.SCHEMA,"completed":Journey.EVENTS,"security":{"gate_open":true,"scanner_trace":true,"service_trace":false}},base+"_journey.json")
	main=load("res://scenes/native_journey.tscn").instantiate()
	main.native_checkpoint_path=base+"_opening.json"
	main.native_preferences_path=base+"_prefs.cfg"
	main.get_node("SystemJourneyPreview").checkpoint_path=base+"_maintenance.json"
	main.get_node("NativeJourneyController").checkpoint_path=base+"_journey.json"
	main.get_node("NativeCampaignController").checkpoint_path=base+"_campaign.json"
	root.add_child(main)
	review_main=main
	for i in 25: await physics_frame
	main.set_audio_muted(true)
	main.set_reduced_motion(true)
	player=main.player
	campaign=main.get_node("NativeCampaignController")
	if not _check(campaign.active and campaign.current==0,"Native extension did not activate after security"): return
	player.set_gameplay_orbit(Vector3.ZERO)
	review_kind="campaign-connected"
	room=campaign.conduits[0]
	if not await _walk(Vector3(0,0,-14.8)): return
	room=campaign.rooms[0]
	# Cover route follows the authored scanner's occluding plinths.
	for point in [Vector3(-2.5,0,2),Vector3(-2.5,0,3),Vector3(-26,0,3),Vector3(-26,0,-10.4)]:
		if not await _walk(point): return
	if not _check(player.get_nearest_interactable()==room,"Specimen terminal must be physically available"): return
	if not _check(player.interact_with_nearest().get("accepted",false),"Specimen record rejected"): return
	for i in 55: await physics_frame
	if not _check(campaign.current==0,"Opening a gate must not complete traversal"): return
	for point in [Vector3(-28,0,-10.4),Vector3(-28,0,-12),Vector3(-30.8,0,-12)]:
		if not await _walk(point): return
	if not _check(campaign.current==1,"Physical specimen threshold did not advance"): return
	room=campaign.conduits[1]
	if not await _walk(Vector3(-13.8,0,0)): return
	room=campaign.rooms[1]
	for point in [Vector3(-1.7,0,-3.2),Vector3(-6,0,-3.2),Vector3(-6,0,4.1),Vector3(-6,0,2.5),Vector3(-16,0,2.5),Vector3(-16,0,-4.1),Vector3(-20,0,-3),Vector3(-20,0,9),Vector3(-3.8,0,9),Vector3(-3.8,3.6,0.5),Vector3(-11,3.6,0),Vector3(-3.8,3.6,0.5),Vector3(-3.8,0,9),Vector3(-1.7,0,9),Vector3(-1.7,0,-3.2),Vector3(-9.5,0,-3.2)]:
		if not await _walk(point): return
	if not _check(player.get_nearest_interactable()==room,"Archive terminal must be physically available"): return
	if not _check(player.interact_with_nearest().get("success",false),"Archive decode rejected"): return
	for i in 55: await physics_frame
	for point in [Vector3(-1.7,0,-3.2),Vector3(-1.7,0,-12),Vector3(-11,0,-12),Vector3(-11,0,-14.8)]:
		if not await _walk(point): return
	if not _check(campaign.current==2,"Physical archive threshold did not advance"): return
	room=campaign.conduits[2]
	if not await _walk(Vector3(0,0,-14.8)): return
	room=campaign.rooms[2]
	for point in [Vector3(0,-4,-5.5),Vector3(0,-4,-7),Vector3(-3,-3.45,-8.42)]:
		if not await _walk(point): return
	await _safe_hazard(false)
	for point in [Vector3(-9.2,-2,-11),Vector3(-11,-2,-12.3),Vector3(-11,-2,-16)]:
		if not await _walk(point): return
	if not _use("BreakerAConsole"): return
	for point in [Vector3(-11,-2,-14.8),Vector3(-8.5,-2,-14.8)]:
		if not await _walk(point): return
	await _safe_hazard(false)
	for point in [Vector3(0,-2,-14.8),Vector3(11,-2,-14.8),Vector3(11,-2,-17.5)]:
		if not await _walk(point): return
	await _safe_hazard(true)
	for point in [Vector3(11,-2,-24.2),Vector3(11,-2,-28)]:
		if not await _walk(point): return
	if not _use("BreakerBConsole"): return
	for i in 65: await physics_frame
	for point in [Vector3(11,-2,-30.1),Vector3(11,0.2,-35.8),Vector3(0,0.2,-35.8),Vector3(0,0,-40),Vector3(0,0,-44.8)]:
		if not await _walk(point): return
	if not _check(campaign.current==3,"Physical reactor threshold did not advance"): return
	room=campaign.conduits[3]
	if not await _walk(Vector3(0,0,-15.8)): return
	room=campaign.rooms[3]
	for point in [Vector3(-8.5,0,-2),Vector3(-8.5,0,-9),Vector3(-8.5,3.2,-15.5),Vector3(-2,3.2,-16)]:
		if not await _walk(point): return
	if not _use("QuarantineOverrideTerminal"): return
	for i in 55: await physics_frame
	for point in [Vector3(-8.5,3.2,-16),Vector3(-8.5,0,-9),Vector3(0,0,-9),Vector3(0,0,-32.8)]:
		if not await _walk(point): return
	if not _check(campaign.current==4,"Physical quarantine threshold did not advance"): return
	room=campaign.conduits[4]
	if not await _walk(Vector3(0,0,-15.8)): return
	room=campaign.rooms[4]
	for point in [Vector3(7.2,0,-2),Vector3(7.2,0,-14),Vector3(8,0,-14),Vector3(8,0,-16.6),Vector3(3.5,2.4,-16.6),Vector3(1.5,2.4,-18)]:
		if not await _walk(point): return
	if not _use("MasterSecurityTerminal"): return
	for i in 55: await physics_frame
	for point in [Vector3(3.5,2.4,-16.6),Vector3(8,0,-16.6),Vector3(9,0,-20),Vector3(9,0,-30),Vector3(0,0,-30),Vector3(0,0,-36.8)]:
		if not await _walk(point): return
	if not _check(campaign.current==5,"Physical surveillance threshold did not advance"): return
	room=campaign.conduits[5]
	if not await _walk(Vector3(0,0,-15.8)): return
	room=campaign.rooms[5]
	if not _check(not player.combat_available and not room.contract_done,"Early power authority before explicit pact"): return
	for point in [Vector3(0,0,-9),Vector3(0,1.2,-14),Vector3(2.5,1.2,-14),Vector3(2.5,1.2,-18.4)]:
		if not await _walk(point): return
	if not _use("KinjaNeuralRigTerminal"): return
	for i in 100: await physics_frame
	if not _check(room.confrontation_done and not room.contract_done and not room.breach_open,"Memory presentation auto-accepted the pact or escape"): return
	print("PASS connected actual native route: security exit, six separate rooms, five buffers, physical gates, reachable shards/breakers/terminals, no teleport after fixture spawn, no automatic pact or premature power")
	if OS.get_cmdline_user_args().has("--complete") and not await _complete_campaign(): return
	main.queue_free()
	for i in 5: await process_frame
	for name in ["_opening.json","_maintenance.json","_journey.json","_campaign.json","_prefs.cfg"]:
		for suffix in ["",".bak",".tmp",".bak.tmp"]:
			if FileAccess.file_exists(base+name+suffix): DirAccess.remove_absolute(base+name+suffix)
	quit(0)

func _complete_campaign() -> bool:
	var window=main.hud.find_child("SystemWindow",true,false)
	if not _check(window.visible and window.stats_box.get_child_count()==2,"Pact must present explicit accept and defer buttons"): return false
	window.stats_box.get_child(0).pressed.emit()
	for i in 15: await physics_frame
	if not _check(room.contract_done and player.combat_available and not room.wish_done,"Explicit pact did not unlock the controlled confrontation"): return false
	for point in [Vector3(2.5,1.2,-14),Vector3(0,1.2,-14),Vector3(0,0,-9),Vector3(7,0,-9),Vector3(7,0,-28.8),Vector3(0,0,-28.8)]:
		if not await _walk(point): return false
	for contact in 3:
		player.face_world_direction(campaign.kinja.global_position-player.global_position)
		player.perform_attack()
		for i in 90: await physics_frame
		if not _check(campaign.kinja.contacts==contact+1,"Actual melee did not contact Kinja exactly once"): return false
	if not _check(not room.revenge_done and not room.wish_done,"Three attacks cannot automatically finish revenge or accept the wish"): return false
	var approach:Vector3=room.to_local(campaign.kinja.global_position)+Vector3.FORWARD*1.5
	approach.y=0.0
	if not await _walk(approach): return false
	if not _check(player.get_nearest_interactable()==campaign.kinja,"Kinja must be physically reachable after approach; player="+str(room.to_local(player.global_position))+" actor="+str(room.to_local(campaign.kinja.global_position))+" nearby="+str(player.nearby_interactables)): return false
	if not _check(player.interact_with_nearest().get("collar_requested",false),"Confrontation interaction rejected"): return false
	if not _check(window.visible and window.stats_box.get_child_count()==1,"Confrontation must require explicit continuation"): return false
	window.stats_box.get_child(0).pressed.emit()
	for i in 5: await physics_frame
	if not _check(room.revenge_done and not room.wish_done and not room.breach_open,"Revenge auto-accepted the wish"): return false
	window.stats_box.get_child(0).pressed.emit()
	for i in 15: await physics_frame
	if not _check(room.wish_done and room.breach_open and campaign.hospital==null,"Accepted wish must open a physical breach before transfer"): return false
	var film:bool=OS.get_cmdline_user_args().has("--film") and DisplayServer.get_name()!="headless"
	if film: main.set_reduced_motion(false)
	for point in [Vector3(3,0,-28.8),Vector3(3,0,-35),Vector3(0,0,-35),Vector3(0,0,-39.0)]:
		if not await _walk(point): return false
	player.set_mobile_input_vector(Vector2(0,-1),true)
	for i in 35: await physics_frame
	player.set_mobile_input_vector(Vector2.ZERO,false)
	if not _check(campaign.hospital!=null and campaign.progress.completed.size()==6,"Physical breach did not transfer to the ward"): return false
	if not _check(player.control_locked and not player.combat_available,"Hospital awakening must own input and remove combat"): return false
	if film:
		if not _check(campaign._movie!=null,"Actual ward transfer did not play its native film"): return false
		for i in 60: await physics_frame
		var film_player=campaign._movie.get_node("FilmFrame/AwakeningFilm")
		var film_size:Vector2=film_player.size
		if not _check(absf(film_size.x/film_size.y-864.0/496.0)<0.002,"Film must retain its authored aspect ratio"): return false
		await _capture()
		# Exercise the real skip button, then the finished/skip race.
		campaign._movie.get_child(campaign._movie.get_child_count()-1).pressed.emit()
		var generation:int=window._window_generation
		campaign._finish_hospital_movie()
		if not _check(window._window_generation==generation,"Duplicate film completion replaced the explicit wake decision"): return false
	window.stats_box.get_child(0).pressed.emit()
	for i in 15: await physics_frame
	room=campaign.hospital
	if not _check(room.bed_awakened_done and not player.control_locked,"Explicit awakening must release bedside exploration"): return false
	for point in [Vector3(1.6,0,1.18),Vector3(1.6,0,-1.0)]:
		if not await _walk(point): return false
	if not _use("VanityMirrorStation"): return false
	for i in 10: await physics_frame
	if not _check(room.mark_revealed_done and campaign.progress.completed.size()==7,"Physical mirror interaction did not persist the final chapter event"): return false
	if not _check(campaign._mark_inspection!=null and player.control_locked,"Skin inspection must own camera and input until explicit dismissal"): return false
	await _capture()
	window.close_window()
	for i in 3: await physics_frame
	if not _check(not player.control_locked and player.player_camera.current,"Inspection dismissal must restore the actual exploration camera and input"): return false
	print("PASS functional pact, controlled melee, explicit revenge continuation, sole Canon wish, physical breach, hospital input ownership and actual mirror interaction; skeletal staging acceptance remains OPEN")
	print("CAPTURE scope: virtual public input, rendered actual runtime; focus interruptions resumed via actual Pause UI=",focus_interruptions)
	return true


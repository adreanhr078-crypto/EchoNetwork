extends SceneTree

## Test-only checkpoint fixture starts at the existing lab; normal progression
## is unchanged. Rendered captures use the actual connected native controller.
const Campaign=preload("res://scripts/systems/native_campaign_checkpoint.gd")
const Journey=preload("res://scripts/systems/native_journey_checkpoint.gd")
const Saves=preload("res://scripts/systems/save_manager.gd")
var main: Node
var campaign: Node
var room: Node3D
var presentation: Node3D
var base := "user://pact_review_%d" % OS.get_process_id()
var folder := ""

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	root.size=Vector2i(1280,720)
	root.content_scale_size=root.size
	folder=ProjectSettings.globalize_path("res://../audits/evidence/room-color-cinematics-20261007/zero-connected-cinematics-v1/")
	DirAccess.make_dir_recursive_absolute(folder)
	var opening: Dictionary={"schema":Saves.OPENING_SCHEMA,"milestones":{"wake":true,"clock":true,"photo":true,"memory":true,"terminal":true,"conduit":true,"ending":true},"terminal":{"frequency":111.0,"phase":45.0,"harmonic":7.0}}
	assert(Saves.save_opening_checkpoint(opening,base+"_opening.json"))
	var file:=FileAccess.open(base+"_maintenance.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema":"echo-maintenance-preview-v1","stage":6}))
	file.close()
	assert(Journey.save_checkpoint({"schema":Journey.SCHEMA,"completed":Journey.EVENTS,"security":{"gate_open":true,"scanner_trace":true,"service_trace":false}},base+"_journey.json"))
	var progress:=Campaign.initial()
	for id in ["specimen","archive","reactor","decon","mirror"]:
		progress.flags[id]={}
		for key in Campaign.FLAGS[id]: progress.flags[id][key]=true
		progress=Campaign.advance(progress,id)
	assert(Campaign.save_checkpoint(progress,base+"_campaign.json"))
	main=load("res://scenes/native_journey.tscn").instantiate()
	main.native_checkpoint_path=base+"_opening.json"
	main.native_preferences_path=base+"_prefs.cfg"
	main.get_node("SystemJourneyPreview").checkpoint_path=base+"_maintenance.json"
	main.get_node("NativeJourneyController").checkpoint_path=base+"_journey.json"
	main.get_node("NativeCampaignController").checkpoint_path=base+"_campaign.json"
	root.add_child(main)
	process_frame.connect(_resume_capture_driver)
	main.set_audio_muted(true)
	main.set_reduced_motion(false)
	for i in 30: await physics_frame
	campaign=main.get_node("NativeCampaignController")
	room=campaign.rooms[5]
	presentation=room.story_presentation
	assert(presentation.generated_zero.body_animation_kind=="imported_native_clip")
	assert(presentation.generated_zero.skeleton.get_bone_count()==41)
	assert(presentation.generated_zero.source_player.has_animation("pact/agree"))
	assert(not presentation._zero_fallback.visible,"Verified source must replace only the temporary body")
	assert(campaign.current==5 and not main.player.combat_available)
	main.player.global_position=room.to_global(Vector3(0,0.1,-29))
	main.player.set_gameplay_orbit(Vector3(0.04,0,0))
	for i in 8: await physics_frame
	assert(not presentation._zero.visible,"Full Zero must be absent before collapse")
	await _capture("01-lab-before-collapse")
	assert(room.initiate_memory_confrontation().success)
	for i in 90: await physics_frame
	var window=main.hud.find_child("SystemWindow",true,false)
	assert(presentation._zero.visible and window.visible and not room.contract_done)
	assert(presentation.generated_zero.source_player.assigned_animation=="idle","Manifestation must use actual native Idle without choosing a pact")
	assert(window.stats_box.get_child_count()==2,"Pact must preserve accept and defer")
	assert(presentation.active and presentation._camera.current)
	await _capture("02-zero-explicit-pact-ar")
	var deadline:=Time.get_ticks_msec()+8000
	while presentation.active and Time.get_ticks_msec()<deadline: await process_frame
	print("NATURAL return: active=",presentation.active," elapsed=",presentation._elapsed," window=",window.visible," lock=",main.player.control_locked," scale=",Engine.time_scale)
	assert(not presentation.active and window.visible and main.player.control_locked,"Natural insert completion must retain the explicit pending pact")
	main.set_reduced_motion(true)
	for i in 6: await process_frame
	assert(window.visible and main.player.control_locked and not room.contract_done,"Reduced motion after a completed insert cannot release the pending pact")
	main.set_reduced_motion(false)
	for i in 6: await process_frame
	window.stats_box.get_child(1).pressed.emit()
	for i in 4: await physics_frame
	assert(not room.contract_done and not main.player.combat_available and not presentation.active)
	assert(not main.player.control_locked and main.player.player_camera.current,"Deferral must restore actual exploration")
	main.set_presentation_language("en")
	root.size=Vector2i(960,540)
	root.content_scale_size=root.size
	campaign._show_pact()
	for i in 4: await physics_frame
	assert(window.stats_box.get_child(1).text=="Not yet")
	await _capture("02b-zero-explicit-pact-en-960x540")
	window.stats_box.get_child(1).pressed.emit()
	main.set_presentation_language("ar")
	root.size=Vector2i(1280,720)
	root.content_scale_size=root.size
	campaign._show_pact()
	window.stats_box.get_child(0).pressed.emit()
	for i in 12: await physics_frame
	assert(room.contract_done and main.player.combat_available and not room.revenge_done)
	assert(campaign.kinja.trauma_pose and campaign.kinja.trauma_pose.skeleton.get_bone_count()==33,"Reviewed Kinja acting must be connected to the actual campaign")
	assert(presentation.active and main.player.control_locked)
	assert(presentation.generated_zero.source_player.assigned_animation=="pact/agree","Native acknowledgement must start only after explicit acceptance")
	assert(not presentation._sound,"Muted pact cannot allocate a chime player")
	await _capture("03-accepted-pact-insert")
	# Use the actual skip control; it returns the live camera without story advance.
	presentation._skip.pressed.emit()
	for i in 27: await physics_frame
	assert(not presentation.active and not main.player.control_locked and main.player.player_camera.current)
	assert(not room.revenge_done and not room.wish_done)
	for contact in 3:
		main.player.face_world_direction(campaign.kinja.global_position-main.player.global_position)
		main.player.perform_attack()
		for i in 85: await physics_frame
		assert(campaign.kinja.contacts==contact+1,"Actual controlled melee must contact once")
		assert(campaign.kinja.trauma_pose.contacts==contact+1,"Each real contact must drive the bound visual pose")
	assert(not room.revenge_done)
	assert(campaign.kinja.trigger_interaction(main.player).collar_requested)
	for i in 4: await physics_frame
	assert(window.visible and window.stats_box.get_child_count()==1 and presentation.active)
	assert(campaign.kinja.trauma_pose.collar,"The explicit collar interaction must drive the bound Kinja pose")
	await _capture("04-revenge-explicit-continuation-ar")
	# Changing accessibility during an active shot must settle the same camera,
	# keep the pending choice, and freeze all decorative movement.
	main.set_reduced_motion(true)
	# Settings reach room/camera presentation during process updates. A loaded
	# renderer may run several physics steps before its next presentation frame.
	for i in 6: await process_frame
	print("REDUCED toggle: insert_active=",presentation.active," window=",window.visible," lock=",main.player.control_locked," main=",main.reduced_motion," room=",room.reduced_motion," paused=",paused)
	assert(not presentation.active and window.visible and main.player.control_locked)
	var phase: float=presentation._phase
	var transform: Transform3D=presentation._shards[0].transform
	var filament: Transform3D=presentation._splinters[0].transform
	var source_pose: Array[Transform3D]=[]
	for index in presentation.generated_zero.skeleton.get_bone_count(): source_pose.append(presentation.generated_zero.skeleton.get_bone_pose(index))
	var eye_phase=presentation.generated_zero._eye_materials[0].get_shader_parameter("phase")
	presentation._process(0.5)
	assert(presentation._phase==phase and presentation._shards[0].transform==transform)
	assert(presentation._splinters[0].transform==filament,"Reduced motion must preserve Zero's detailed static geometry without orbit drift")
	assert(not presentation.generated_zero.source_player.is_playing())
	assert(presentation.generated_zero._eye_materials[0].get_shader_parameter("phase")==eye_phase)
	for index in source_pose.size(): assert(presentation.generated_zero.skeleton.get_bone_pose(index)==source_pose[index])
	window.stats_box.get_child(0).pressed.emit()
	for i in 5: await physics_frame
	assert(room.revenge_done and not room.wish_done and not room.breach_open)
	assert(window.visible,"Revenge must leave the separate Canon wish decision")
	window.stats_box.get_child(0).pressed.emit()
	for i in 5: await physics_frame
	assert(room.wish_done and room.breach_open and presentation.stage=="stasis")
	# Resume presentation silently, without replaying consent or the sound.
	var saved: Dictionary=room.get_state()
	room.restore_state(saved)
	assert(not presentation._sound and presentation.stage=="stasis")
	room.audio_muted=false
	presentation._play_chime()
	assert(presentation._sound and presentation._sound.playing)
	room.audio_muted=true
	presentation._process(0.01)
	assert(not presentation._sound.playing,"Mute changes must stop an active presentation sound")
	await _capture("05-wish-stasis-reduced")
	main.queue_free()
	for i in 8: await process_frame
	for name in ["_opening.json","_maintenance.json","_journey.json","_campaign.json","_prefs.cfg"]:
		for suffix in ["",".bak",".tmp",".bak.tmp"]:
			if FileAccess.file_exists(base+name+suffix): DirAccess.remove_absolute(base+name+suffix)
	print("PASS actual native lab: no early Zero, explicit defer/accept, mute, skip/live camera recovery, three actual melee contacts, separate revenge/wish, reduced-motion toggle and silent restore")
	print("PASS reviewed narrow Kinja skeletal acting is connected; original static source remains preserved")
	print("PASS real41-bone Zero native Idle and source acknowledgement follow explicit decision; reduced motion holds actual source pose and eye/field phase")
	print("UNVERIFIED paired Echo collar grip and facial acting; full cinematic scene acceptance remains open")
	quit(0)

func _capture(label: String) -> void:
	if DisplayServer.get_name()=="headless": return
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder+"final-"+label+".png")

func _resume_capture_driver() -> void:
	if paused and is_instance_valid(main) and main.native_pause_menu:
		main.native_pause_menu.resume_button.pressed.emit()

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
var capture_motion := false
var capture_complete := false
var deliberate_pause := false
var motion_samples: Array[Dictionary] = []
var run_fingerprints: Dictionary = {}
var import_fingerprints: Dictionary = {}
const RUN_FILES: Array[String] = [
	"res://scripts/cinematics/zero_generated_model_slot.gd",
	"res://scripts/cinematics/pact_revenge_presentation.gd",
	"res://scripts/main.gd",
	"res://scripts/player/echo_player.gd",
	"res://scripts/player/echo_facial_controller.gd",
	"res://scripts/player/echo_skin_identifier.gd",
	"res://scripts/player/echo_contract_hair.gd",
	"res://assets/characters/contract/echo_opening_v13_hair_mask.png",
	"res://assets/characters/contract/echo_v31_authored_68_hair_mask.png",
	"res://shaders/anime_cel.gdshader",
	"res://scripts/player/zero_eye_singularity.gd",
	"res://scripts/player/zero_shadow_wing.gd",
	"res://scripts/player/zero_manifestation_attachment.gd",
	"res://scenes/player/zero_eye_singularity.tscn",
	"res://scenes/player/zero_shadow_wing.tscn",
	"res://shaders/zero_feather_detail.gdshader",
	"res://assets/characters/echo_opening_uniform_v13.glb",
	"res://assets/characters/echo_shadow_wing_feathers_v1.glb",
	"res://assets/characters/echo_shadow_wing_feathers_v1_Color_dc3f46f8-b751-49dc-ace0-ac498826561a.jpg",
	"res://assets/characters/echo_shadow_wing_feathers_v1_NormalGL_dc3f46f8-b751-49dc-ace0-ac498826561a.png",
	"res://assets/characters/echo_shadow_wing_feathers_v1_ORM_dc3f46f8-b751-49dc-ace0-ac498826561a.jpg",
	"res://scripts/systems/native_campaign_controller.gd",
	"res://scripts/environment/dr_kinja_lab_room.gd",
	"res://scripts/characters/kinja_revenge_actor.gd",
	"res://scripts/cinematics/kinja_trauma_pose.gd",
	"res://scripts/ui/system_window.gd",
	"res://scripts/ui/system_window_fracture.gd",
	"res://scripts/audio/pact_audio_director.gd",
	"res://assets/audio/pact/void_bed.ogg",
	"res://assets/audio/pact/revenge_bed.ogg",
	"res://assets/audio/pact/contract_seal.ogg",
	"res://assets/audio/pact/stasis_release.ogg",
	"res://assets/audio/pact/contact_1.ogg",
	"res://assets/audio/pact/contact_2.ogg",
	"res://assets/audio/pact/contact_3.ogg",
	"res://scenes/native_journey.tscn",
	"res://scenes/system_journey_preview.tscn",
	"res://scenes/player/echo_player.tscn",
	"res://assets/characters/zero_manifestation_profile_v1.json",
	"res://assets/characters/zero_manifestation_idle_v1.glb",
	"res://assets/animations/zero/zero_pact_agree_v1.res",
	"res://assets/characters/kinja_revenge_rig_v1.glb",
	"res://tests/pact_revenge_presentation_review.gd"
]

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	for path in RUN_FILES:
		run_fingerprints[path]=FileAccess.get_sha256(path)
		if String(run_fingerprints[path]).length()!=64:
			push_error("FAIL connected fixture: missing source dependency "+path)
			quit(2)
			return
		if path.ends_with(".gd"):
			var script:=load(path) as Script
			if not script or not script.can_instantiate():
				push_error("FAIL connected fixture: non-instantiable dependency "+path)
				quit(2)
				return
	var checked_imports: Dictionary={}
	for path in RUN_FILES:
		if not _guard_current_import(path,checked_imports): return
	root.size=Vector2i(1280,720)
	root.content_scale_size=root.size
	# The real native scene remains rendered while this unattended fixture
	# avoids taking keyboard focus from the owner's other production tools.
	root.unfocusable=true
	folder=ProjectSettings.globalize_path("res://../audits/evidence/room-color-cinematics-20261007/zero-connected-cinematics-v1/")
	var arguments:=OS.get_cmdline_user_args()
	for index in arguments.size():
		if arguments[index]=="--capture-motion": capture_motion=true
		if arguments[index]=="--capture-complete": capture_complete=true
		if arguments[index]=="--review-out" and index+1<arguments.size(): folder=arguments[index+1].trim_suffix("/")+"/"
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
	window.decision_made.connect(func(id: String): print("FIXTURE explicit decision: ",id))
	assert(presentation._zero.visible and window.visible and not room.contract_done)
	assert(presentation.generated_zero.source_player.assigned_animation=="idle","Manifestation must use actual native Idle without choosing a pact")
	assert(window.stats_box.get_child_count()==2,"Pact must preserve accept and defer")
	assert(presentation.active and presentation._camera.current)
	assert(main.hud.get_node("QuestContainer").modulate.a==0.0,"Passive objectives cannot obscure the cinematic body or pact decision")
	await _capture("02-zero-explicit-pact-ar")
	main.set_audio_muted(false)
	for i in 4: await process_frame
	assert(presentation.audio_director._void.playing and presentation.audio_director.decision_pending,"Actual pending decision must use its quiet, ducked ambience")
	main.set_audio_muted(true)
	for i in 4: await process_frame
	assert(presentation.audio_director._void.stream_paused and not presentation.audio_director._transient.playing,"Mute must settle actual ambience and transients while preserving the decision")
	var deadline:=Time.get_ticks_msec()+8000
	while presentation.active and Time.get_ticks_msec()<deadline: await process_frame
	print("NATURAL return: active=",presentation.active," elapsed=",presentation._elapsed," window=",window.visible," lock=",main.player.control_locked," contract=",room.contract_done," kind=",presentation._kind," scale=",Engine.time_scale)
	assert(not presentation.active and window.visible and main.player.control_locked,"Natural insert completion must retain the explicit pending pact")
	assert(main.hud.get_node("QuestContainer").modulate.a==1.0,"Natural completion must restore the gameplay readout")
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
	_assert_no_old_decision_snapshot(window)
	for i in 4: await physics_frame
	assert(window.stats_box.get_child(1).text=="Not yet")
	await _capture("02b-zero-explicit-pact-en-960x540")
	window.stats_box.get_child(1).pressed.emit()
	main.set_presentation_language("ar")
	root.size=Vector2i(1280,720)
	root.content_scale_size=root.size
	campaign._show_pact()
	window.stats_box.get_child(0).pressed.emit()
	if capture_complete:
		# This separate capture follows the one real acceptance from its native
		# start through its complete source gesture and natural camera return.
		# The normal fixture still owns independent pause/skip/reduced checks.
		if not await _capture_complete_accepted_motion(): return
		main.queue_free()
		for i in 8: await process_frame
		_cleanup_fixture_saves()
		quit(0)
		return
	for i in 12: await physics_frame
	assert(room.contract_done and main.player.combat_available and not room.revenge_done)
	assert(campaign.kinja.trauma_pose and campaign.kinja.trauma_pose.skeleton.get_bone_count()==33,"Reviewed Kinja acting must be connected to the actual campaign")
	assert(presentation.active and main.player.control_locked)
	var wing: Node3D=main.player.find_child("ZeroShadowWing",true,false)
	assert(wing.supports_cinematic_framing() and wing.visible and wing.is_wing_manifested,"The bounded contract-authorized feather rig must remain in the accepted portrait")
	assert(presentation._suppressed_wing==null,"A validated feather rig cannot inherit the legacy prism suppression")
	assert(not campaign.kinja.visible,"The pending revenge actor must not intrude on Echo's acknowledgement to Zero")
	assert(not presentation._skip.get_global_rect().intersects(main.native_pause_menu.pause_button.get_global_rect()),"Return and pause controls must remain independently reachable")
	assert(presentation.generated_zero.source_player.assigned_animation=="pact/agree","Native acknowledgement must start only after explicit acceptance")
	assert(presentation.audio_director.transient_count==0 and not presentation.audio_director._transient.playing,"Muted pact cannot play or replay its seal transient")
	# Use the real pause UI while an acknowledged pact is still acting. A
	# frozen SceneTree must hold source bones, shader phase and shot camera.
	deliberate_pause=true
	main.native_pause_menu.pause_button.pressed.emit()
	assert(paused and main.native_pause_menu.session_paused)
	var paused_time: float=presentation.generated_zero.source_player.current_animation_position
	var paused_phase: float=presentation._phase
	var paused_camera: Transform3D=presentation._camera.global_transform
	var paused_pose: Array[Transform3D]=[]
	for bone in presentation.generated_zero.skeleton.get_bone_count(): paused_pose.append(presentation.generated_zero.skeleton.get_bone_pose(bone))
	for frame in 12: await process_frame
	assert(paused_time==presentation.generated_zero.source_player.current_animation_position)
	assert(paused_phase==presentation._phase and paused_camera==presentation._camera.global_transform)
	for bone in paused_pose.size(): assert(paused_pose[bone]==presentation.generated_zero.skeleton.get_bone_pose(bone))
	main.native_pause_menu.resume_button.pressed.emit()
	deliberate_pause=false
	assert(not paused and not main.native_pause_menu.session_paused)
	for frame in 4: await process_frame
	assert(presentation.generated_zero.source_player.current_animation_position>paused_time)
	await _capture("03-accepted-pact-insert")
	if capture_motion and DisplayServer.get_name()!="headless":
		if not await _capture_accepted_motion(): return
	# Use the actual skip control; it returns the live camera without story advance.
	presentation._skip.pressed.emit()
	for i in 27: await physics_frame
	assert(not presentation.active and not main.player.control_locked and main.player.player_camera.current)
	assert(campaign.kinja.visible,"Returning to the laboratory must restore its actual revenge actor")
	assert(main.hud.get_node("QuestContainer").modulate.a==1.0 and presentation._quiet_hud.is_empty())
	assert(not room.revenge_done and not room.wish_done)
	for contact in 3:
		main.player.face_world_direction(campaign.kinja.global_position-main.player.global_position)
		main.player.perform_attack()
		for i in 85: await physics_frame
		assert(campaign.kinja.contacts==contact+1,"Actual controlled melee must contact once")
		assert(campaign.kinja.trauma_pose.contacts==contact+1,"Each real contact must drive the bound visual pose")
		assert(presentation.audio_director.last_contact==contact+1,"Each actual contact must be consumed once by the muted audio presentation")
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
	assert(presentation.audio_director.transient_count==0 and not presentation.audio_director._transient.playing and presentation.stage=="stasis")
	main.set_audio_muted(false)
	for i in 4: await process_frame
	assert(presentation.audio_director.transient_count==0 and not presentation.audio_director._transient.playing,"Unmuting a restored wish cannot replay a previously consumed cue")
	main.set_audio_muted(true)
	await _capture("05-wish-stasis-reduced")
	var report:={"status":"CONNECTED_NATIVE_BEHAVIOR_PASS_VISUAL_REVIEW_REQUIRED","engine":Engine.get_version_info().string,"rendering_method":RenderingServer.get_current_rendering_method(),"display":DisplayServer.get_name(),"source_idle_tracks":presentation.generated_zero.source_player.get_animation("idle").get_track_count(),"source_idle_duration":presentation.generated_zero.source_player.get_animation("idle").length,"pact_after_explicit_accept_only":true,"pause_exact_bones_camera_phase":true,"mute_no_presentation_sound":true,"reduced_motion_exact_bones_shader_field":true,"real_melee_contacts":campaign.kinja.contacts,"separate_wish_decision":true,"silent_stasis_restore":true,"motion_samples":motion_samples,"fingerprint":{},"import_fingerprint":import_fingerprints}
	for path in RUN_FILES:
		if FileAccess.get_sha256(path)!=run_fingerprints[path]:
			push_error("FAIL connected fixture: dependency changed during this run "+path)
			quit(2)
			return
		report.fingerprint[path]=run_fingerprints[path]
	if not _imports_unchanged(): return
	var evidence:=FileAccess.open(folder+"connected-native-review.json",FileAccess.WRITE)
	evidence.store_string(JSON.stringify(report,"\t"))
	evidence.close()
	main.queue_free()
	for i in 8: await process_frame
	_cleanup_fixture_saves()
	print("PASS actual native lab: no early Zero, explicit defer/accept, mute, skip/live camera recovery, three actual melee contacts, separate revenge/wish, reduced-motion toggle and silent restore")
	print("PASS reviewed narrow Kinja skeletal acting is connected; original static source remains preserved")
	print("PASS real41-bone Zero native Idle and source acknowledgement follow explicit decision; reduced motion holds actual source pose and eye/field phase")
	print("PASS real pause/resume holds exact native bones, camera and shader phase during the accepted insert")
	print("UNVERIFIED paired Echo collar grip and facial acting; full cinematic scene acceptance remains open")
	quit(0)

func _capture(label: String) -> void:
	if DisplayServer.get_name()=="headless": return
	for i in 3: await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(folder+"final-"+label+".png")

func _resume_capture_driver() -> void:
	if paused and not deliberate_pause and is_instance_valid(main) and main.native_pause_menu:
		main.native_pause_menu.resume_button.pressed.emit()

func _capture_accepted_motion() -> bool:
	DirAccess.make_dir_recursive_absolute(folder+"accepted-cycle/")
	# Run this rendered fixture with --fixed-fps 30. Sampling records actual
	# connected native playback and camera movement; it never seeks a source.
	for frame in 81:
		if not presentation.active or not presentation._camera:
			push_error("FAIL native motion capture: source insert ended before all 81 frames")
			quit(2)
			return false
		# Force this actual scene render even when its desktop window is not
		# presenting. Waiting on a suspended window draw can otherwise hang QA.
		RenderingServer.force_draw(false)
		if main.hud.get_node("QuestContainer").visible:
			push_error("FAIL native motion capture: gameplay colour tween redrew a passive panel over the source gesture")
			quit(2)
			return false
		var player: AnimationPlayer=presentation.generated_zero.source_player
		var wing: Node3D=main.player.find_child("ZeroShadowWing",true,false)
		if not wing.visible or not wing.is_wing_manifested:
			push_error("FAIL native motion capture: the accepted contract's feather rig was suppressed")
			quit(2)
			return false
		motion_samples.append({"frame":frame,"shot_elapsed":presentation._elapsed,"clip":player.assigned_animation,"source_time":player.current_animation_position,"field_phase":presentation._phase,"camera":var_to_str(presentation._camera.global_transform),"wing_visible":wing.visible,"wing_phase":wing.local_time,"wing_socket":var_to_str(wing.global_transform)})
		root.get_texture().get_image().save_png(folder+"accepted-cycle/frame-%03d.png" % (frame+1))
		await process_frame
	return true

func _capture_complete_accepted_motion() -> bool:
	var player: AnimationPlayer=presentation.generated_zero.source_player
	var clip: Animation=player.get_animation("pact/agree")
	var completed: Dictionary={"count":0}
	player.animation_finished.connect(func(label: StringName) -> void:
		if label==&"pact/agree": completed.count+=1)
	var keys:=0
	var last_key_time:=0.0
	for track in clip.get_track_count():
		keys+=clip.track_get_key_count(track)
		if clip.track_get_key_count(track)>0:
			last_key_time=maxf(last_key_time,clip.track_get_key_time(track,clip.track_get_key_count(track)-1))
	if clip.length<=0.0 or keys==0 or last_key_time<clip.length-1.0/30.0-0.00001:
		return _capture_failure("Full acknowledgement source has no complete final-key coverage")
	DirAccess.make_dir_recursive_absolute(folder+"accepted-complete/")
	var samples: Array[Dictionary]=[]
	var pact_times: Array[float]=[]
	var pose_hashes: Dictionary={}
	for frame in 200:
		if not presentation.active: break
		if player.assigned_animation!="pact/agree" and completed.count==0:
			if frame>3: return _capture_failure("Actual acceptance did not start its original acknowledgement")
			await process_frame
			continue
		var wing: Node3D=main.player.find_child("ZeroShadowWing",true,false)
		if not room.contract_done or not wing.visible or not wing.is_wing_manifested:
			return _capture_failure("Authorized feather rig disappeared during the full acknowledgement")
		if main.hud.get_node("QuestContainer").visible or campaign.kinja.visible:
			return _capture_failure("Passive HUD or revenge actor intruded on the complete pact portrait")
		if DisplayServer.get_name()!="headless": RenderingServer.force_draw(false)
		var poses: Array[Transform3D]=[]
		for bone in presentation.generated_zero.skeleton.get_bone_count():
			poses.append(presentation.generated_zero.skeleton.get_bone_pose(bone))
		var pose_hash:=var_to_bytes(poses).hex_encode().sha256_text()
		pose_hashes[pose_hash]=true
		var sample: Dictionary={"frame":samples.size(),"shot_elapsed":presentation._elapsed,"clip":player.assigned_animation,"source_time":player.current_animation_position,"pose_sha256":pose_hash,"camera":var_to_str(presentation._camera.global_transform),"wing_visible":wing.visible,"wing_phase":wing.local_time,"wing_socket":var_to_str(wing.global_transform)}
		samples.append(sample)
		if player.assigned_animation=="pact/agree": pact_times.append(player.current_animation_position)
		if DisplayServer.get_name()!="headless": root.get_texture().get_image().save_png(folder+"accepted-complete/frame-%03d.png" % samples.size())
		await process_frame
	if presentation.active or completed.count!=1 or pact_times.is_empty():
		return _capture_failure("Full acknowledgement did not finish exactly once before its natural return")
	if pact_times[0]>1.0/30.0+0.00001 or pact_times[-1]<last_key_time-1.0/30.0-0.00001:
		return _capture_failure("Full acknowledgement missed its original start or final gesture samples")
	var step_error:=0.0
	for index in range(1,pact_times.size()):
		step_error=maxf(step_error,absf((pact_times[index]-pact_times[index-1])-1.0/30.0))
	if step_error>0.00001 or pose_hashes.size()<pact_times.size()/2:
		return _capture_failure("Full source gesture did not advance at its original 30fps or remained visually frozen")
	if not main.player.player_camera.current or main.player.control_locked or not campaign.kinja.visible or room.revenge_done or room.wish_done:
		return _capture_failure("Natural pact return changed authority or failed to restore exploration")
	var hashes: Dictionary={}
	for path in RUN_FILES:
		if FileAccess.get_sha256(path)!=run_fingerprints[path]: return _capture_failure("Full capture dependency changed during playback: "+path)
		hashes[path]=run_fingerprints[path]
	if not _imports_unchanged(): return false
	var report: Dictionary={"status":"ACTUAL_COMPLETE_NATIVE_ACKNOWLEDGEMENT_VISUAL_REVIEW_REQUIRED","engine":Engine.get_version_info().string,"display":DisplayServer.get_name(),"rendering_method":RenderingServer.get_current_rendering_method(),"source_tracks":clip.get_track_count(),"source_keys":keys,"source_length":clip.length,"source_last_key_time":last_key_time,"actual_first_source_time":pact_times[0],"actual_last_source_time":pact_times[-1],"source_finished_events":completed.count,"pact_source_samples":pact_times.size(),"unique_native_pose_samples":pose_hashes.size(),"maximum_30fps_step_error":step_error,"frame_count":samples.size(),"natural_camera_return":true,"single_explicit_contract_acceptance":true,"revenge_and_wish_unaccepted":true,"samples":samples,"fingerprint":hashes,"import_fingerprint":import_fingerprints}
	var evidence:=FileAccess.open(folder+"complete-native-acknowledgement.json",FileAccess.WRITE)
	evidence.store_string(JSON.stringify(report,"\t"))
	evidence.close()
	print("PASS complete original acknowledgement: tracks=",clip.get_track_count()," keys=",keys," length=",clip.length," actual source=",pact_times[0],"..",pact_times[-1]," completion events=",completed.count," frames=",samples.size()," step error=",step_error)
	print("PASS natural live-camera return after one explicit pact; revenge and wish remain separate and unaccepted")
	return true

func _capture_failure(message: String) -> bool:
	push_error("FAIL complete native capture: "+message)
	quit(2)
	return false

func _cleanup_fixture_saves() -> void:
	for name in ["_opening.json","_maintenance.json","_journey.json","_campaign.json","_prefs.cfg"]:
		for suffix in ["",".bak",".tmp",".bak.tmp"]:
			if FileAccess.file_exists(base+name+suffix): DirAccess.remove_absolute(base+name+suffix)

func _guard_current_import(path: String, checked: Dictionary) -> bool:
	# A changed GLB can still load its previous cached .scn. Freeze the actual
	# imported resources and reject an importer whose source digest is stale.
	if checked.has(path): return true
	checked[path]=true
	if not path.get_extension().to_lower() in ["glb","png","jpg","ogg"]: return true
	var settings:=ConfigFile.new()
	if settings.load(path+".import")!=OK: return _capture_failure("Missing importer metadata: "+path)
	import_fingerprints[path+".import"]=FileAccess.get_sha256(path+".import")
	import_fingerprints[path]=FileAccess.get_sha256(path)
	var pattern:=RegEx.new()
	pattern.compile('source_md5="([0-9a-f]{32})"')
	var destinations: Variant=settings.get_value("deps","dest_files",[])
	if destinations.is_empty(): return _capture_failure("Importer has no compiled resource: "+path)
	for value in destinations:
		var destination: String=value
		var digest_path:=destination.get_basename()+".md5"
		if not FileAccess.file_exists(destination) or not FileAccess.file_exists(digest_path): return _capture_failure("Missing compiled resource or importer digest: "+path)
		var source_match:=pattern.search(FileAccess.get_file_as_string(digest_path))
		if not source_match or source_match.get_string(1)!=FileAccess.get_md5(path): return _capture_failure("Source and compiled importer disagree: "+path)
		import_fingerprints[destination]=FileAccess.get_sha256(destination)
		import_fingerprints[digest_path]=FileAccess.get_sha256(digest_path)
	for descriptor in ResourceLoader.get_dependencies(path):
		for token in String(descriptor).split("::"):
			if token.begins_with("res://") and not _guard_current_import(token,checked): return false
	return true

func _imports_unchanged() -> bool:
	for path in import_fingerprints:
		if FileAccess.get_sha256(path)!=import_fingerprints[path]: return _capture_failure("Compiled playback dependency changed during capture: "+String(path))
	return true

func _assert_no_old_decision_snapshot(window: Control) -> void:
	for child in root.get_children():
		if child is CanvasLayer and child.get_meta("system_window_fracture_owner",0)==window.get_instance_id():
			assert(not child.visible,"A fresh decision cannot retain pixels of the previous language or choice")

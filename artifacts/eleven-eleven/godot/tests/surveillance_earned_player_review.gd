extends "res://tests/stormworks_parkour_input_review.gd"
var campaign:Node
func _source_manifest()->Dictionary:
 var hashes:={}
 for p in preload("res://scripts/environment/surveillance_room_architecture.gd").evidence_paths():hashes[p]=FileAccess.get_sha256(p)
 for p in ["res://scripts/environment/mirror_chamber_room.gd","res://scripts/environment/mirror_room_presentation.gd","res://scripts/environment/specimen_mechanical_dressing.gd","res://shaders/clinical_architecture_surface.gdshader"]:hashes[p]=FileAccess.get_sha256(p)
 return hashes
func _record(label:String,passed:bool,detail:Variant=null)->void:
 report.checks.append({"check":label,"pass":passed,"detail":detail});print("SURVEILLANCE_PLAYER ",label," ",passed)
func _walk_leg(target:Vector3,exit_leg:bool=false)->bool:
 var distance:float=Vector2(_pos().x-target.x,_pos().z-target.z).length()
 for i in ceili(distance/2.0)+3:
  if await _go_to(target):return true
  if exit_leg and campaign.current==5:return true
  var remaining:float=Vector2(_pos().x-target.x,_pos().z-target.z).length()
  if remaining>=distance-.1:return false
  distance=remaining
 return false
func _run()->void:
 var args:=OS.get_cmdline_user_args()
 if args.size()<2:quit(2);return
 var earned:String=args[0];var folder:String=args[1]
 var source_manifest:Dictionary=_source_manifest()
 if DirAccess.dir_exists_absolute(folder):quit(2);return
 DirAccess.make_dir_recursive_absolute(folder);capture_directory=folder.path_join("frames");DirAccess.make_dir_recursive_absolute(capture_directory)
 var profile:String=folder.path_join("profile");DirAccess.make_dir_recursive_absolute(profile)
 var original_hashes:={}
 for name in ["opening.json","maintenance.json","route.json","campaign.json","preferences.cfg"]:
  var path:String=earned.path_join(name)
  if not FileAccess.file_exists(path) or DirAccess.copy_absolute(path,profile.path_join(name))!=OK:quit(2);return
  original_hashes[name]=FileAccess.get_sha256(path)
 var state:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(profile.path_join("campaign.json")))
 if state.get("completed")!=["specimen","archive","reactor","decon"]:quit(2);return
 root.size=Vector2i(1280,720);root.unfocusable=true
 world=load("res://scenes/native_journey.tscn").instantiate();world.native_checkpoint_path=profile.path_join("opening.json");world.native_preferences_path=profile.path_join("preferences.cfg")
 world.get_node("SystemJourneyPreview").checkpoint_path=profile.path_join("maintenance.json");world.get_node("NativeJourneyController").checkpoint_path=profile.path_join("route.json");world.get_node("NativeCampaignController").checkpoint_path=profile.path_join("campaign.json");root.add_child(world)
 for i in 45:
  if paused and world.native_pause_menu:world.native_pause_menu.resume_button.pressed.emit()
  await physics_frame;await process_frame
 player=world.player;campaign=world.get_node("NativeCampaignController");room=campaign.rooms[4]
 world.set_visual_quality("high");world.set_reduced_motion(false);world.set_audio_muted(true)
 var dialogue:Node=world.hud.find_child("DialogueOverlay",true,false)
 for i in 8:
  if dialogue.is_active:dialogue.continue_button.pressed.emit()
  await process_frame
 _record("actual_earned_after_decon_restore",campaign.current==4 and campaign.progress.completed==state.completed and not room.mirror_inspected and not room.override_done and not room.gate_open)
 _record("native_player_camera_no_combat",player.is_on_floor() and root.get_camera_3d()==player.player_camera and not player.control_locked and not player.combat_available,str(_pos()))
 var architecture:Node=room.get_node_or_null("SurveillanceTripoArchitecture")
 _record("measured_candidate_installed",architecture!=null and architecture.get_meta("source_revision","")=="room08-p2-20261029")
 _aim(Vector3(0,2.5,-20));await _frames(18);await _capture("01-native-entry")
 if architecture:
  var before:Dictionary=architecture.get_effect_evidence();await _frames(12);var running:Dictionary=architecture.get_effect_evidence()
  _record("rigid_fans_use_active_room_clock",running.fans==2 and running.air_budget==24 and running.fan_angles!=before.fan_angles and running.clock>before.clock,running)
  automatic_focus_resume=false;paused=true;var held:Dictionary=architecture.get_effect_evidence();await _frames(6)
  _record("pause_freezes_fan_clock_and_pose",architecture.get_effect_evidence().fan_angles==held.fan_angles and architecture.get_effect_evidence().clock==held.clock)
  room.reduced_motion=true;var reduced:Dictionary=architecture.get_effect_evidence()
  _record("paused_reduced_motion_stops_ventilation",reduced.air_stopped and reduced.fan_angles==held.fan_angles)
  room.reduced_motion=false;paused=false;automatic_focus_resume=true
  world.set_audio_muted(false);await _frames(3)
  _record("bounded_physical_hum_starts",architecture.get_effect_evidence().all_hum_started)
  world.set_audio_muted(true);await _frames(2)
  _record("mute_stops_added_physical_sfx",architecture.get_effect_evidence().all_silent)
 var walked:bool=await _walk_leg(Vector3(7.4,0,-10))
 _aim(Vector3(8.5,1.8,-10));await _frames(12);await _capture("02-actual-mirror-inspection")
 _record("public_walk_triggered_native_mirror_inspection",walked and room.mirror_inspected and room._presentation.inspection_count==1 and not room.gate_open)
 for target in [Vector3(8.0,0,-16.6),Vector3(4.0,2.4,-16.6),Vector3(0,2.4,-16.6)]:
  if not await _walk_leg(target):walked=false;break
 _aim(Vector3(0,3.0,-18));await _frames(8);await _capture("03-native-command-dais")
 _record("public_side_stair_reached_original_terminal",walked and player.get_nearest_interactable()==room._terminal_body,str(_pos()))
 var used:Dictionary=player.interact_with_nearest() if walked else {}
 await _frames(65)
 _record("two_condition_override_opened_physical_gate",used.get("success",false) and room.mirror_inspected and room.override_done and room.gate_open and room._gate_shape.disabled,used)
 if architecture:_record("cleared_network_stops_corona",architecture.get_effect_evidence().corona_active==0.0)
 for target in [Vector3(4.0,2.4,-16.6),Vector3(8.0,0,-16.6),Vector3(8.0,0,-27),Vector3(0,0,-34)]:
  if not await _walk_leg(target):walked=false;break
 _aim(Vector3(0,1.5,-36));await _frames(8);await _capture("04-open-physical-exit")
 var exited:bool=await _walk_leg(Vector3(0,0,-36.6),true) if walked else false
 _record("public_exit_advanced_saved_campaign",exited and campaign.current==5 and campaign.progress.completed==["specimen","archive","reactor","decon","mirror"] and not player.combat_available,str(_pos()))
 var source_unchanged:=true
 for name in original_hashes:source_unchanged=source_unchanged and original_hashes[name]==FileAccess.get_sha256(earned.path_join(name))
 _record("original_earned_source_unchanged",source_unchanged)
 report.scope="Actual earned after-decon restore;native player/camera/public movement and mirror/stair/terminal/gate/saved exit;muted visual proof;not full chapter/fun/audio/performance acceptance"
 _record("source_files_unchanged_during_native_run",source_manifest==_source_manifest())
 report.source_earned=earned;report.source_earned_hashes=original_hashes;report.renderer=RenderingServer.get_current_rendering_method();report.device=RenderingServer.get_video_adapter_name();report.tier="high;1280x720";report.source_hashes=source_manifest
 report.status="PASS_SCOPED_NATIVE_EARNED" if report.checks.all(func(row:Dictionary):return row.pass) else "FAIL"
 var file:=FileAccess.open(folder.path_join("review.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close();print("SURVEILLANCE_NATIVE ",report.status)
 world.queue_free()
 for i in 12:
  await process_frame
  if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw
 if RenderingServer.has_method("force_sync"):RenderingServer.call("force_sync")
 quit(0 if report.status!="FAIL" else 1)

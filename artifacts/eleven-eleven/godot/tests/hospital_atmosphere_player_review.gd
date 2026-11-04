extends "res://tests/stormworks_parkour_input_review.gd"

## Isolated real motor and ward presentation; full-campaign restore is separate.
func _record(label:String,passed:bool,detail:Variant=null)->void:
 report.checks.append({"check":label,"pass":passed,"detail":detail});print("HOSPITAL_PLAYER ",label," ",passed)
func _run()->void:
 var args:=OS.get_cmdline_user_args()
 if args.is_empty():quit(2);return
 var folder:String=args[0]
 if DirAccess.dir_exists_absolute(folder):quit(2);return
 DirAccess.make_dir_recursive_absolute(folder);capture_directory=folder.path_join("frames");DirAccess.make_dir_recursive_absolute(capture_directory)
 create_timer(180).timeout.connect(func():push_error("Hospital player watchdog");quit(1))
 root.size=Vector2i(1280,720);root.unfocusable=true;root.msaa_3d=Viewport.MSAA_4X
 world=Node3D.new();root.add_child(world)
 room=load("res://scenes/environment/hospital_bedside_room.tscn").instantiate();world.add_child(room)
 player=load("res://scenes/player/echo_player.tscn").instantiate();player.position=room.SAFE_ANCHOR_BEDSIDE+Vector3.UP*.1;world.add_child(player)
 player.finish_opening_recovery();player.set_gameplay_orbit(Vector3.ZERO);room.player=player
 player.player_camera.environment=room.get_node("HospitalWorldEnvironment").environment
 room.audio_muted=true
 await _frames(20)
 var atmosphere:Node=room.get_node_or_null("WardPresentation/WardPBRAtmosphere")
 _record("measured_pbr_bed_and_headwall",atmosphere!=null and atmosphere.get_effect_evidence().bed_present and atmosphere.has_node("MeasuredTripoHeadwall"))
 _record("one_explicit_awakening",room.wake_up_from_bed() and not room.wake_up_from_bed())
 _aim(Vector3(-1.6,1,-.2));await _frames(6);await _capture("01-native-bedside")
 var walked:=true
 for target in [Vector3(1.6,0,1.18),Vector3(1.6,0,-2.3)]:
  if not await _go_to(target):walked=false;break
 _aim(Vector3(0,1.8,-2.9));await _frames(8);await _capture("02-native-rain-window")
 _record("physical_walk_curtain_wake",walked and atmosphere.get_effect_evidence().peak_wake>.05,atmosphere.get_effect_evidence())
 var moving:Dictionary=atmosphere.get_effect_evidence();await _frames(6)
 _record("active_cloth_local_clock",atmosphere.get_effect_evidence().cloth_clock>moving.cloth_clock)
 automatic_focus_resume=false;paused=true
 var held:Dictionary=atmosphere.get_effect_evidence();await _frames(4)
 _record("pause_freezes_local_cloth",atmosphere.get_effect_evidence().cloth_clock==held.cloth_clock)
 room.audio_muted=false;room.audio_muted=true
 _record("paused_mute_immediate",atmosphere.get_effect_evidence().silent)
 paused=false;room.reduced_motion=true;held=atmosphere.get_effect_evidence();await _frames(5)
 _record("reduced_motion_holds_cloth_clock",atmosphere.get_effect_evidence().cloth_clock==held.cloth_clock)
 room.reduced_motion=false;room.audio_muted=false;await _frames(3)
 _record("unmuted_rain_starts",not atmosphere.get_effect_evidence().silent)
 room.visible=false;held=atmosphere.get_effect_evidence();await _frames(3)
 _record("hidden_ward_silent_and_clock_held",atmosphere.get_effect_evidence().silent and atmosphere.get_effect_evidence().clock==held.clock)
 room.visible=true;room.audio_muted=true
 if not await _go_to(Vector3(1.6,0,-1)):walked=false
 _aim(Vector3(3,1.65,-1));await _frames(6);await _capture("03-native-mirror")
 _record("mirror_public_interaction_available",walked and player.get_nearest_interactable()==room.get_node("VanityMirrorStation"))
 var result:Dictionary=player.interact_with_nearest()
 _record("mirror_public_interaction_accepted",result.get("success",false),result)
 _record("physical_route_retains_floor_and_camera",player.is_on_floor() and player.player_camera.current)
 var hashes:={}
 for name in ["scripts/environment/hospital_pbr_atmosphere.gd","scripts/environment/hospital_room_dressing.gd","scripts/environment/hospital_bedside_room.gd","shaders/ward_curtain.gdshader","shaders/ward_wet_glass.gdshader","assets/environments/hospital_cp45/hospital_bed_p2.glb","assets/environments/hospital_cp45/hospital_headwall_p2.glb","assets/environments/hospital_cp45/hospital_pleated_curtain.glb"]:hashes[name]=FileAccess.get_sha256("res://"+name)
 report.source_hashes=hashes;report.renderer=RenderingServer.get_current_rendering_method();report.device=RenderingServer.get_video_adapter_name();report.scope="Isolated actual Echo public movement/mirror and physical atmosphere1280x720;not full campaign restore,fun,audio listening or performance acceptance"
 report.status="PASS_SCOPED_NATIVE" if report.checks.all(func(row:Dictionary):return row.pass) else "FAIL"
 var f:=FileAccess.open(folder.path_join("review.json"),FileAccess.WRITE);f.store_string(JSON.stringify(report,"\t"));f.close()
 print("HOSPITAL_PLAYER ",report.status)
 world.queue_free()
 for i in 8:await process_frame
 quit(0 if report.status!="FAIL" else 1)

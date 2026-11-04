extends "res://tests/stormworks_parkour_input_review.gd"

## Actual native Echo and camera, one explicit isolated entry fixture. Public
## movement only thereafter. Does not establish earned or connected acceptance.
func _run()->void:
	var args:=OS.get_cmdline_user_args()
	if args.is_empty() or DisplayServer.get_name()=="headless":quit(2);return
	var folder:=args[0];DirAccess.make_dir_recursive_absolute(folder)
	capture_directory=folder
	root.size=Vector2i(1280,720);root.unfocusable=true
	automatic_focus_resume=false
	world=Node3D.new();root.add_child(world)
	room=load("res://scripts/environment/decontamination_quarantine_wing.gd").new();world.add_child(room)
	room.set_audio_muted(true)
	player=load("res://scenes/player/echo_player.tscn").instantiate()
	player.position=Vector3(0,.1,-2);world.add_child(player)
	player.finish_opening_recovery();room.player=player
	var manager:Node=root.get_node("HyperAnimeWorldManager")
	manager.attach_scene(world,player);manager.set_quality("high")
	await _frames(45)
	_aim(Vector3(0,1.5,-16));await _frames(15);await _capture("01-entry-player")
	report.checks.append({"check":"native_player_camera_and_no_combat","pass":root.get_camera_3d()==player.player_camera and player.is_on_floor() and not player.control_locked and not player.combat_available})
	var reached:=true
	for point in [Vector3(0,0,-5),Vector3(0,0,-8),Vector3(-2,0,-10.5),Vector3(-4,0,-12)]:
		if not await _go_to(point):reached=false;break
		await _capture("walk-%02d"%report.checks.size());report.checks.append({"check":"public_input_leg","pass":true,"position":str(_pos())})
	_aim(Vector3(-6.5,1.5,-16));await _frames(25);await _capture("02-pressure-vessel-player")
	report.checks.append({"check":"public_input_reached_pod_view","pass":reached and player.is_on_floor()})
	var moisture:Node=room.get_node_or_null("DeconTripoArchitecture/PrecisionSurfaceRefinement/ReactiveMoisture")
	if moisture:
		var effect:Dictionary=moisture.get_effect_evidence()
		report.checks.append({"check":"native_animation_contacts_reacted_with_water","pass":effect.wet_contacts>0 and effect.contact_connections==1 and effect.fade_out_transparent,"detail":effect})
		report.checks.append({"check":"catwalk_height_does_not_classify_as_floor_water","pass":not moisture.contains_water(room.to_global(Vector3(0,3.2,-8.7)))})
	room.reduced_motion=true;await _frames(3)
	var time:float=room._mist_time;await _frames(15)
	report.checks.append({"check":"reduced_motion_freezes_local_presentation","pass":is_equal_approx(time,room._mist_time)})
	if moisture:
		var effect:Dictionary=moisture.get_effect_evidence()
		report.checks.append({"check":"reactive_water_and_air_respect_reduced_motion","pass":not effect.motion and effect.ripple_slots==4 and effect.particle_nodes==8 and effect.particle_budget==96})
	await _capture("03-reduced-motion-player")
	report.scope="ISOLATED_NATIVE_PLAYER_AND_PUBLIC_INPUT;one initial entry fixture;not connected or earned chapter acceptance"
	report.renderer=RenderingServer.get_current_rendering_method();report.tier=manager.quality
	report.status="PASS_SCOPED_RENDERED" if report.checks.all(func(row:Dictionary):return row.pass) else "FAIL"
	report.source_hashes={}
	for p in ["res://scripts/environment/decon_tripo_architecture.gd","res://scripts/environment/decontamination_quarantine_wing.gd","res://assets/environments/decon_clinical/decon_pod_precision_pbr.glb"]:
		report.source_hashes[p]=FileAccess.get_sha256(p)
	if args.has("--decon-whole-v2-candidate") or args.has("--review-default-decon"):
		report.checks.append({"check":"whole_v2_measured_candidate_installed","pass":room.get_node("DeconTripoArchitecture").get_meta("source_revision","")=="whole-v2-refined-20261029"})
		for p in ["res://scripts/environment/decon_whole_v2_architecture.gd","res://assets/environments/decon_clinical/decon_whole_v2_static.glb","res://assets/environments/decon_clinical/decon_whole_v2_gate.glb","res://assets/environments/decon_clinical/decon_whole_v2_terminal.glb","res://assets/environments/decon_clinical/decon_whole_v2_basecolor.png","res://assets/environments/decon_clinical/decon_whole_v2_normal.png","res://assets/environments/decon_clinical/decon_whole_v2_orm.png"]:
			report.source_hashes[p]=FileAccess.get_sha256(p)
		for p in preload("res://scripts/environment/decon_precision_refinement.gd").evidence_paths():
			report.source_hashes[p]=FileAccess.get_sha256(p)
		report.status="PASS_SCOPED_RENDERED" if report.checks.all(func(row:Dictionary):return row.pass) else "FAIL"
	var file:=FileAccess.open(folder.path_join("review.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("DECON_NATIVE_PLAYER ",report.status)
	world.queue_free();await process_frame;quit(0 if report.status!="FAIL" else 1)


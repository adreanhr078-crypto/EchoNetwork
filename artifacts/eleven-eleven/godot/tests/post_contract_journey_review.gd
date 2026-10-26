extends "res://tests/full_chapter_journey_review.gd"

## Continue byte-for-byte from the actually earned eight-step pact profile.
## Reuse the connected driver's real confrontation/wish/breach/ward inputs.
func _run() -> void:
	_post_watchdog.call_deferred()
	root.unfocusable=true
	var args:=OS.get_cmdline_user_args()
	# Optional diagnostic framebuffer only; retain all selected tier effects.
	# This is never a change to the owner's window or graphics preferences.
	root.size=Vector2i(960,540) if args.has("--compact-framebuffer") else Vector2i(1280,720)
	if not _check(args.size()>=2,"Expected earned complete-contract profile and evidence folder"):return
	folder=args[1]+"/"
	DirAccess.make_dir_recursive_absolute(folder)
	var profile:="user://post_contract_%d/"%OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(profile)
	for file in ["opening.json","maintenance.json","route.json","campaign.json","preferences.cfg"]:
		if not _check(FileAccess.file_exists(args[0]+"/"+file) and DirAccess.copy_absolute(args[0]+"/"+file,profile+file)==OK,"Missing actual earned contract bytes: "+file):return
	main=load("res://scenes/native_journey.tscn").instantiate()
	main.native_checkpoint_path=profile+"opening.json"
	main.native_preferences_path=profile+"preferences.cfg"
	main.get_node("SystemJourneyPreview").checkpoint_path=profile+"maintenance.json"
	main.get_node("NativeJourneyController").checkpoint_path=profile+"route.json"
	main.get_node("NativeCampaignController").checkpoint_path=profile+"campaign.json"
	root.add_child(main)
	player=main.player
	player.set_process_unhandled_input(false)
	main.set_audio_muted(true)
	# The restored preferences may enable the real ward film. Match the
	# connected driver's explicit film branch rather than pressing a wake
	# decision that has not appeared yet underneath an active movie.
	main.set_reduced_motion(not args.has("--film"))
	for tick in 20:
		await process_frame
		_resume()
		await physics_frame
	campaign=main.get_node("NativeCampaignController")
	room=campaign.rooms[5]
	if not _check(campaign.current==5 and room.contract_done and not room.revenge_done and not room.wish_done and campaign.kinja.contacts==0,"Earned profile must start after explicit consent, before real combat/wish"):return
	if args.has("--camera-only"):
		if not await _review_melee_camera():return
		quit(0)
		return
	if not await _complete_campaign():return
	if not _snapshot_profile("complete"):return
	var paths:=["res://scripts/player/echo_player.gd","res://scripts/player/echo_v31_motion_adapter.gd","res://assets/animations/v31/attack_horizontal_cp45.res","res://assets/characters/echo_v31_short_jacket.glb","res://scripts/cinematics/pact_revenge_presentation.gd","res://scripts/systems/native_campaign_controller.gd","res://tests/full_chapter_journey_review.gd","res://tests/zero_encounter_route_input.gd","res://tests/post_contract_journey_review.gd"]
	var hashes:={}
	for path in paths:hashes[path]=FileAccess.get_sha256(path)
	for path in ["res://scripts/environment/dr_kinja_lab_room.gd","res://scripts/environment/clinical_lab_architecture.gd","res://shaders/clinical_stasis_display.gdshader","res://tests/lab_stasis_story_review.gd"]:
		hashes[path]=FileAccess.get_sha256(path)
	for path in ["res://scripts/environment/clinical_modular_perimeter.gd","res://assets/environments/lab_clinical_cp45/clinical_scanner_p2_4k.glb","res://shaders/clinical_architecture_surface.gdshader","res://assets/environments/lab_clinical_cp45/clinical_wall_p2_4k.glb","res://assets/environments/lab_clinical_cp45/clinical_service_frame_clean.glb"]:
		hashes[path]=FileAccess.get_sha256(path)
	for path in ["res://scripts/environment/lab_memory_cinema.gd","res://scripts/environment/memory_reflection_space.gd","res://shaders/memory_water.gdshader","res://assets/cinematics/memory-screens/city-high.ogv","res://assets/cinematics/memory-screens/friends-high.ogv"]:
		hashes[path]=FileAccess.get_sha256(path)
	var report:={"checks":checks,"display":DisplayServer.get_name(),"renderer":RenderingServer.get_current_rendering_method(),"route_retries":_route_retries,"source_profile":args[0],"source_hashes":hashes,"final_progress":campaign.progress,"scope":"Actually earned pact profile -> three real native cuts -> explicit revenge continuation -> sole wish -> physical breach -> ward input/mirror. No manufactured flags or player placement. Fine fingers/acting, final art, performance/devices/live receipts/package and fresh whole-chapter acceptance remain open."}
	var output:=FileAccess.open(folder+"review.json",FileAccess.WRITE)
	output.store_string(JSON.stringify(report,"\t"));output.close()
	print("POST_CONTRACT_JOURNEY ",JSON.stringify({"checks":checks,"renderer":report.renderer,"route_retries":_route_retries}))
	quit(0)

func _post_watchdog() -> void:
	await create_timer(180,true,false,true).timeout
	push_error("Post-contract player journey exceeded its bounded real-time window")
	quit(2)

func _review_melee_camera() -> bool:
	for point in [Vector3(3,0,-35),Vector3(3,0,-28.8),Vector3(0,0,-28.8)]:
		if not await _walk_local(point):return false
	var mask:int=player.camera_boom.collision_mask
	player.set_gameplay_orbit(Vector3.ZERO)
	for tick in 30:await physics_frame
	await _capture("camera-obstructed-before")
	var blocked_length:float=player.camera_boom.spring_length
	if not _check(blocked_length<1.0,"Camera regression fixture did not reproduce the close actor obstruction"):return false
	player.face_world_direction(campaign.kinja.global_position-player.global_position)
	player.apply_touch_camera_look(Vector2(1,0))
	var manual:Vector3=player.camera_target_rotation
	player.perform_attack()
	for tick in 5:await physics_frame
	if not _check(player.camera_target_rotation.is_equal_approx(manual),"Melee camera assistance overwrote deliberate public look"):return false
	player.request_dodge()
	for tick in 40:await physics_frame
	if not await _walk_local(Vector3(0,0,-28.8)):return false
	player.face_world_direction(campaign.kinja.global_position-player.global_position)
	player.set_gameplay_orbit(Vector3.ZERO)
	for tick in 30:await physics_frame
	player.perform_attack()
	for tick in 5:await physics_frame
	var safe_length:float=player.camera_boom.spring_length
	if not _check(safe_length>=2.3 and absf(angle_difference(player.camera_target_rotation.y,0.0))<=PI/2+.001,"Native attack failed to use the available readable clearance or rotated beyond the existing bound"):return false
	await _capture("camera-clear-after")
	player.apply_touch_camera_look(Vector2(20,0))
	var after:Vector3=player.camera_target_rotation
	for tick in 3:await physics_frame
	if not _check(player.camera_target_rotation.is_equal_approx(after) and player.camera_boom.collision_mask==mask,"Camera clearance retained orbit ownership or changed world collision masks"):return false
	player.request_dodge()
	for tick in 40:await physics_frame
	if not _check(campaign.kinja.contacts==0 and not room.revenge_done and not room.wish_done,"Canceled camera probes changed confrontation or wish state"):return false
	var report:={"checks":checks,"before_arm_m":blocked_length,"after_arm_m":safe_length,"manual_look_preserved":true,"collision_mask_unchanged":true,"kinja_contacts":campaign.kinja.contacts,"renderer":RenderingServer.get_current_rendering_method(),"pact_source_sha256":FileAccess.get_sha256("res://scripts/cinematics/pact_revenge_presentation.gd")}
	var output:=FileAccess.open(folder+"camera-review.json",FileAccess.WRITE)
	output.store_string(JSON.stringify(report,"\t"));output.close()
	print("MELEE_CAMERA_REVIEW ",JSON.stringify(report))
	return true

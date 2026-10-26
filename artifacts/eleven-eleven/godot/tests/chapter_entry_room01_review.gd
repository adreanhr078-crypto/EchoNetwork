extends "res://tests/opening_player_journey_review.gd"

var boot:Node
var reload_paths:Dictionary={}
func frames(count:int) -> void:
	for i in count:await process_frame
func click(button:Control) -> void:
	await frames(2)
	var center:=button.get_global_rect().get_center()
	for down in [true,false]:
		var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;event.position=center;event.global_position=center
		root.push_input(event,true);await frames(2)
func entry(kind:String) -> Node:
	if not is_instance_valid(boot):return null
	for node in boot.get_children():
		if node.get_script() and node.get_script().resource_path.ends_with(kind+".gd"):return node
	return null
func _run() -> void:
	if not OS.get_cmdline_user_args().has("--review-title"):
		push_error("Requires --review-title for isolated real Boot saves");quit(2);return
	root.unfocusable=true;root.size=Vector2i(1280,720);root.content_scale_size=root.size
	Engine.max_fps=60
	folder=ProjectSettings.globalize_path("res://../audits/evidence/chapter-cp45-20261020/stage06/entry-room01/")
	DirAccess.make_dir_recursive_absolute(folder)
	boot=load("res://scripts/boot.gd").new();root.add_child(boot);current_scene=boot
	await frames(4)
	var title=entry("title_entry")
	if not _check(title!=null and title.video.is_playing(),"Fresh real Boot opens the live title decoder"):return
	await _capture("00-title")
	await click(title.start_button)
	var cover=entry("cover_recovery")
	if not _check(cover!=null and cover.order.size()==6 and not cover.completed,"Title opens an unsolved six-piece cover"):return
	await _capture("01-unsolved-cover")
	# Public pointer swaps solve the real board, never a completion helper.
	for index in 6:
		if not is_instance_valid(cover):break
		if cover.order[index]!=index:
			var other:int=cover.order.find(index)
			await click(cover.tiles[index]);await click(cover.tiles[other])
	await frames(4)
	var film=entry("school_lab_opening")
	if not _check(film!=null and film.show_fracture and film.board_rect.has_area(),"Solved cover produces the connected fracture and new opening"):return
	await create_timer(2.0).timeout
	await _capture("02-fracture-school")
	for i in 1200:
		if film.entry_state.beat=="questions":break
		await process_frame
	if not _check(film.entry_state.beat=="questions" and film._questions.get_child_count()==3,"Natural school and laboratory stop at actual father input"):return
	await _capture("03-father-ar")
	await click(film._questions.get_child(1))
	if not _check(film.entry_state.beat=="reply_safety","Public safety question changes the live response"):return
	await click(film._questions.get_child(0))
	await click(film._language_button)
	await _capture("04-father-en")
	if not _check(film.language=="en" and film._questions.get_child(2).text=="I am ready.","Live father choices change language without selecting readiness"):return
	await click(film._questions.get_child(2))
	await create_timer(4.5).timeout
	if not _check(film._clock.visible and film._clock.text=="11:11","Experiment reaches a live11:11 after explicit readiness"):return
	await _capture("05-experiment")
	for i in 600:
		if current_scene!=boot:break
		await process_frame
	if not _check(current_scene!=boot and current_scene.has_node("NativeCampaignController"),"Natural sensory cut hands off to the existing connected chapter once"):return
	main=current_scene;player=main.player
	main.set_visual_quality("low");main.set_audio_muted(true)
	reload_paths={"opening":main.native_checkpoint_path,"preferences":main.native_preferences_path,"maintenance":main.get_node("SystemJourneyPreview").checkpoint_path,"route":main.get_node("NativeJourneyController").checkpoint_path,"campaign":main.get_node("NativeCampaignController").checkpoint_path}
	for i in 360:
		_resume();await physics_frame
		if not player.opening_recovery_active and not player.control_locked:break
	_drain_dialogue();await _frames(4)
	if not _check(not player.control_locked and player.player_camera.current and not main.companion.visible,"Waking returns actual camera/control without the follower"):return
	if not _check(main.presentation_language=="en" and not player.combat_available,"Entry preferences persist without a pre-pact power"):return
	# Keep the dialogue readable for its presentation capture, then finish via
	# the actual Continue button. A departing220ms fade is not a reading sample.
	var wake_dialogue=main.hud.find_child("DialogueOverlay",true,false)
	await create_timer(.3).timeout
	if wake_dialogue.is_active:
		wake_dialogue.finish_typing()
		await _capture("06-waking-dialogue")
		await click(wake_dialogue.continue_button)
	await create_timer(.25).timeout
	_drain_dialogue();await _frames(4)
	await _capture("06-waking")
	await _sample_profile("room01-waking-low")
	if not await _use_evidence("OpeningClock"):return
	if not _check(main.save_native_checkpoint_now(),"Save after the first clue uses existing persistence"):return
	main.queue_free();await frames(4)
	main=load("res://scenes/native_journey.tscn").instantiate()
	main.opening_transfer_presented=true;main.native_checkpoint_path=reload_paths.opening;main.native_preferences_path=reload_paths.preferences
	main.get_node("SystemJourneyPreview").checkpoint_path=reload_paths.maintenance
	main.get_node("NativeJourneyController").checkpoint_path=reload_paths.route
	main.get_node("NativeCampaignController").checkpoint_path=reload_paths.campaign
	root.add_child(main);current_scene=main;await frames(8);player=main.player
	main.set_visual_quality("low");main.set_audio_muted(true);_drain_dialogue();await _frames(3)
	if not _check(main.get_node("PrologueOrchestrator").clock_inspected and not main.get_node("PrologueOrchestrator").photo_inspected,"Cold scene reload retains the clue exactly without advancing the memory"):return
	if not _check(not player.control_locked and player.player_camera.current and not main.companion.visible,"Cold reload returns gameplay and keeps the companion disabled"):return
	if not await _use_evidence("OpeningPhotograph"):return
	await _capture("07-memory")
	if not _check(main.get_node("PrologueOrchestrator").opening_memory_recovered,"Actual photograph dialogue exposes the next environmental objective"):return
	var terminal:=main.find_child("SectorTerminal",true,false) as Node3D
	if not await _walk(terminal.global_position+Vector3(0,0,-1)):return
	player.interact_with_nearest()
	var puzzle=main.hud.find_child("TerminalHackPuzzle",true,false)
	if not _check(puzzle.is_open and player.control_locked,"Public terminal interaction owns input"):return
	puzzle.freq_slider.value=96;puzzle.close_puzzle()
	if not _check(not player.control_locked and player.player_camera.current,"Cancelling the tuner returns gameplay safely"):return
	player.interact_with_nearest()
	if not _check(is_equal_approx(puzzle.freq_slider.value,96),"Retry retains tuner work without granting completion"):return
	puzzle.freq_slider.value=111;puzzle.phase_slider.value=45;puzzle.harmonic_slider.value=7
	await _frames(12);await _capture("08-signal")
	if not _check(puzzle.is_solved and not main.get_node("PrologueOrchestrator").room_gate_open,"Signal alignment still requires the physical power circuit"):return
	await click(puzzle.proceed_btn)
	var conduit:=main.find_child("EnergyPowerConduit_A",true,false) as Node3D
	if not await _walk(Vector3(0,0,-3)):return
	if not await _walk(conduit.global_position+Vector3(1,0,0)):return
	if not _check(player.get_nearest_interactable()==conduit.get_node("InteractionArea"),"Environmental circuit is physically reachable without scan"):return
	player.interact_with_nearest()
	var breach=main.find_child("BlastGateBreachCinematic",true,false)
	for i in 360:
		_resume();await physics_frame
		if not breach._is_playing:break
	if not _check(main.get_node("PrologueOrchestrator").room_gate_open and not player._camera_suspended and player.player_camera.current,"Natural gate release returns the shared gameplay camera"):return
	if not _check(player.get_nearest_interactable()!=conduit.get_node("InteractionArea"),"Energized circuit clears its dead input target immediately"):return
	if not _check(main.get_node("OpeningAtmosphere")._exit_cue.visible,"Opened passage has a static architectural edge cue"):return
	await _capture("09-exit-open")
	await _sample_profile("room01-gate-low")
	if not await _walk(Vector3(0,0,-12)):return
	if not await _walk(Vector3(0,0,-15.2)):return
	_drain_dialogue();await _frames(5)
	if not _check(main.opening_web_handoff.reported_milestones.has("memory_scene_completed") and main.get_node("SystemJourneyPreview").room!=null,"First exit connects the next existing room by actual traversal"):return
	if not await _walk(Vector3(0,0,-18.7)):return
	if not _check(not player.combat_available and not player.contract_with_zero_sealed and not main.companion.visible,"Room01 completion grants neither a follower nor Zero's power"):return
	await _capture("10-first-exit")
	if not _check(main.save_native_checkpoint_now(),"First-exit progress saves through existing authority"):return
	var sources:Dictionary={}
	for path in ["res://scripts/boot.gd","res://scripts/main.gd","res://scripts/ui/school_lab_opening.gd","res://scripts/player/echo_player.gd","res://scripts/player/echo_v31_motion_adapter.gd","res://assets/animations/v31/run_cp45.res","res://assets/animations/v31/walk_cp45.res","res://scenes/native_journey.tscn"]:sources[path]=FileAccess.get_sha256(path)
	var report:Dictionary={"status":"PASS","checks":checks,"public_pointer_title_and_cover":true,"natural_opening":true,"cold_scene_reload_after_clock":true,"no_gameplay_teleport":true,"renderer":RenderingServer.get_current_rendering_method(),"adapter":RenderingServer.get_video_adapter_name(),"profiles":profile_phases,"source_hashes":sources,"independent_new_player_fun_review":"OPEN","stage14_release":"OPEN"}
	var file:=FileAccess.open(folder+"report.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("CHAPTER_ENTRY_ROOM01 PASS checks=",checks)
	main.queue_free();await frames(4);quit(0)

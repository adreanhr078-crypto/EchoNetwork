extends "res://tests/opening_player_journey_review.gd"

## Restores bytes earned by the complete public-input route, never manufactured
## campaign flags. Separate profiles preserve the owner's saves and each other.
const TrialInput = preload("res://tests/lab_memory_trial_input.gd")
var campaign: Node
var room: Node3D
var profile := ""

func _run() -> void:
	root.unfocusable = true
	root.size = Vector2i(1280,720)
	var args := OS.get_cmdline_user_args()
	var source: String = args[0] if not args.is_empty() else "cp37-earned-final"
	var version: String = args[1] if args.size()>1 else "earned-resume"
	folder = ProjectSettings.globalize_path("res://../audits/evidence/pre-tripo-20261018/cp37/route/"+version+"/")
	var mystery := args.has("--mystery-only")
	var lab_slice := args.has("--lab-only")
	if mystery: folder = ProjectSettings.globalize_path("res://../audits/evidence/chapter-cp45-20261020/stage08/resume/" + version + "/")
	if lab_slice: folder = ProjectSettings.globalize_path("res://../audits/evidence/chapter-cp45-20261020/stage09/" + version + "/")
	DirAccess.make_dir_recursive_absolute(folder)
	var stages: Array = ["before-trial"] if args.has("--trial-only") else ["before-trial","manifested","wish","complete"]
	if args.has("--ward-only"): stages=["complete"]
	if mystery: stages = ["after-specimen", "after-archive", "after-reactor", "after-decon", "after-mirror"]
	if lab_slice: stages = ["before-trial"]
	for stage in stages:
		profile = "user://earned_review_%s_%s/" % [OS.get_process_id(),stage]
		DirAccess.make_dir_recursive_absolute(profile)
		var earned: String = "res://../audits/evidence/pre-tripo-20261018/cp37/route/"+source+"/earned/"+stage+"/"
		if mystery: earned = "res://../audits/evidence/chapter-cp45-20261020/stage08/route/" + source + "/earned/" + stage + "/"
		if lab_slice: earned = "res://../audits/evidence/chapter-cp45-20261020/stage08/route/" + source + "/earned/after-mirror/"
		for file in ["opening.json","maintenance.json","route.json","campaign.json","preferences.cfg"]:
			if not _check(FileAccess.file_exists(earned+file) and DirAccess.copy_absolute(earned+file,profile+file)==OK,"Missing actual earned save "+earned+file): return
		main = load("res://scenes/native_journey.tscn").instantiate()
		main.native_checkpoint_path=profile+"opening.json"
		main.native_preferences_path=profile+"preferences.cfg"
		main.get_node("SystemJourneyPreview").checkpoint_path=profile+"maintenance.json"
		main.get_node("NativeJourneyController").checkpoint_path=profile+"route.json"
		main.get_node("NativeCampaignController").checkpoint_path=profile+"campaign.json"
		root.add_child(main)
		player=main.player
		# The virtual-input review owns the orbit, as the fresh-route driver does.
		# Desktop pointer input in another app must not contaminate its captures.
		player.set_process_unhandled_input(false)
		main.set_audio_muted(true)
		main.set_reduced_motion(args.has("--reduced"))
		if args.has("--english"): main.set_presentation_language("en")
		await _frames(20)
		campaign=main.get_node("NativeCampaignController")
		if not _check(campaign.active,"Earned route failed to activate campaign"): return
		if lab_slice:
			if not _check(campaign.current == 5 and campaign.progress.completed.size() == 5 and is_instance_valid(campaign.kinja) and campaign.kinja.get_parent() == campaign.rooms[5] and not campaign.kinja.active and not player.combat_available, "Earned mystery exit lost Kinja's pre-pact presence or granted early power"): return
			await _capture("lab-earned-entry")
		room = campaign.rooms[campaign.current] if mystery else (campaign.rooms[5] if stage != "complete" else campaign.hospital)
		if not _check(is_instance_valid(room),"Earned route lost current room"): return
		if mystery:
			if not await _review_mystery(earned, stages.find(stage) + 1): return
		elif stage=="before-trial":
			if not await _review_trial(): return
		elif stage=="manifested":
			if not _check(room.confrontation_done and not room.contract_done and not player.combat_available,"Manifested save implicitly accepted pact"): return
			await _frames(90)
			if not _check(not room.contract_done and not room.wish_done,"Time accepted an earned pact"): return
		elif stage=="wish":
			if not _check(room.wish_done and room.breach_open and campaign.hospital==null,"Earned wish lost physical exit or transferred automatically"): return
		else:
			if not _check(room.chapter_completed_done and campaign.progress.completed.size()==7 and not player.combat_available,"Earned completed ward failed to restore"): return
			if not await _review_ward(): return
		if lab_slice:
			if not _check(room.confrontation_done and not room.contract_done and not player.combat_available and main.save_native_checkpoint_now(), "Cannot seal the earned pre-pact laboratory checkpoint"): return
			var sealed_dir := folder + "earned/after-trial/"
			DirAccess.make_dir_recursive_absolute(sealed_dir)
			for file: String in ["opening.json", "maintenance.json", "route.json", "campaign.json", "preferences.cfg"]:
				if not _check(DirAccess.copy_absolute(profile + file, sealed_dir + file) == OK, "Cannot preserve earned laboratory profile: " + file): return
		await _capture("restored-"+stage)
		main.queue_free()
		for i in 5: await process_frame
	var hashes := {}
	for file in ["scripts/main.gd","scripts/cinematics/lab_memory_trial.gd","scripts/environment/dr_kinja_lab_room.gd","scripts/environment/kinja_rig_terminal.gd","scripts/systems/native_campaign_controller.gd","scripts/cinematics/pact_revenge_presentation.gd","shaders/lab_memory_abyss.gdshader","assets/characters/echo_v31_adopted_high.glb","assets/textures/lab-memory/shizuka-pdf041.webp","assets/textures/lab-memory/yuki-pdf041.webp","tests/earned_campaign_resume_review.gd","tests/lab_memory_trial_input.gd"]:
		hashes[file]=FileAccess.get_sha256("res://"+file)
	for file in ["scripts/ui/opening_memory_film.gd", "scripts/environment/memory_reflection_space.gd", "shaders/memory_water.gdshader", "assets/props/memory_stasis_frame_clean_v1.glb", "assets/cinematics/lab-memory-collapse-v1.ogv", "assets/cinematics/lab-memory-water-v1.ogg", "assets/cinematics/lab-memory-bottom-v1.webp"]:
		hashes[file] = FileAccess.get_sha256("res://"+file)
	for file in ["scripts/environment/hospital_bedside_room.gd","scripts/environment/hospital_bedside_foundation.gd","scripts/environment/hospital_room_dressing.gd","shaders/ward_floor.gdshader","shaders/ward_linen.gdshader","shaders/ward_rain_window.gdshader","assets/props/ward_bed_original_v1.glb"]:
		hashes[file] = FileAccess.get_sha256("res://"+file)
	for file in ["assets/props/ward_visitor_chair_v1.glb","assets/props/ward_vanity_v1.glb","scripts/systems/native_journey_controller.gd","tests/ward_objective_owner_review.gd"]:
		hashes[file] = FileAccess.get_sha256("res://"+file)
	var report:=FileAccess.open(folder+"earned-resume.json",FileAccess.WRITE)
	if mystery or lab_slice:
		for name: String in ["specimen_containment_wing", "memory_archive_wing", "core_reactor_room", "decontamination_quarantine_wing", "mirror_chamber_room"]:
			for path: String in ["scripts/environment/" + name + ".gd", "scenes/environment/" + name + ".tscn"]:
				hashes[path] = FileAccess.get_sha256("res://" + path)
		for path: String in ["scripts/systems/native_campaign_checkpoint.gd", "tests/opening_player_journey_review.gd", "tests/full_chapter_journey_review.gd"]:
			hashes[path] = FileAccess.get_sha256("res://" + path)
	for file in DirAccess.get_files_at("res://assets/characters"):
		if file.begins_with("zero_manifestation_idle_v1_") and file.ends_with(".import"):
			hashes["assets/characters/"+file]=FileAccess.get_sha256("res://assets/characters/"+file)
	report.store_string(JSON.stringify({"checks":checks,"display":DisplayServer.get_name(),"source_hashes":hashes,"stages":stages,"scope":"Actual earned save bytes; scoped resume and public-input trial; no account grant or independent human/fun/art/device acceptance"},"\t"))
	report.close()
	print("PASS earned-save resume checks=",checks,"; actual earned profile stages=",stages)
	quit(0)

func _review_mystery(earned: String, expected_count: int) -> bool:
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(earned + "campaign.json"))
	if not _check(campaign.current == expected_count and campaign.progress.completed == saved.completed, "Earned room order changed on restore"): return false
	for id: String in campaign.IDS:
		for flag: String in campaign.Checkpoint.FLAGS[id]:
			if not _check(campaign.progress.flags.get(id, {}).get(flag, false) == saved.flags.get(id, {}).get(flag, false), "Earned flag changed on restore: " + id + "/" + flag): return false
	for index in expected_count:
		var restored: Node3D = campaign.rooms[index]
		if not _check(restored.gate_open, "Completed mystery gate did not restore: " + campaign.IDS[index]): return false
		if index == 1 and not _check(restored.collected_shards.size() == 3 and restored.archive_decoded, "Archive lost earned memory shards"): return false
		if index == 4 and not _check(restored.mirror_inspected and restored.override_done, "Mirror lost separate inspection/override state"): return false
	var before: Dictionary = campaign.progress.duplicate(true)
	main.set_presentation_language("en")
	main.set_reduced_motion(true)
	main.set_audio_muted(true)
	paused = true
	for frame in 4: await process_frame
	if not _check(campaign.progress == before, "Paused settings mutated earned progression"): return false
	paused = false
	main.set_presentation_language("ar")
	main.set_reduced_motion(false)
	await _frames(60)
	if not _check(player.is_on_floor() and not player.control_locked and player.player_camera.current, "Earned safe landing did not restore playable camera/input"): return false
	if not _check(not player.contract_with_zero_sealed and not player.combat_available and not player.shadow_step_unlocked and not campaign.rooms[5].contract_done, "Restoring mystery granted early pact/powers"): return false
	if not _check(campaign.progress.completed == before.completed and main.save_native_checkpoint_now(), "Earned mystery save failed or advanced without crossing"): return false
	return true

func _review_ward() -> bool:
	await _capture("ward-presentation-before-walk")
	var face:=player.find_child("EchoFaceFill",true,false) as Light3D
	var shoulder:=player.find_child("EchoShoulderFill",true,false) as Light3D
	if not _check(face!=null and shoulder!=null and not face.visible and not shoulder.visible,"Facility presentation fills leaked into the ward"): return false
	for light: DirectionalLight3D in main.find_children("*","DirectionalLight3D",true,false):
		if not room.is_ancestor_of(light) and not _check(not light.is_visible_in_tree(),"Facility daylight leaked into the ward"): return false
	if not _check(room.get_node("WardDaylight").is_visible_in_tree() and room.get_node("WardPresentation").get_meta("linen_surfaces",0)==1,"Ward light or cloth source missing"): return false
	main.set_presentation_language("en")
	if not _check(room.get_node("WardExitSign").text.contains("WARD EXIT"),"Ward live English not applied"): return false
	main.set_presentation_language("ar")
	if not _check(room.get_node("WardExitSign").text.contains("خروج"),"Ward live Arabic not applied"): return false
	for point in [Vector3(1.6,0,1.18),Vector3(1.6,0,-1.0)]:
		if not await _walk(room.to_global(point)): return false
	if not _check(player.get_nearest_interactable()==room._mirror_station,"Actual earned ward mirror route blocked"): return false
	await _capture("ward-mirror-approach")
	var result: Dictionary=player.interact_with_nearest()
	if not _check(result.get("success",false) and campaign.progress.completed.size()==7,"Revisiting the mirror changed completed progression"): return false
	return true

func _review_trial() -> bool:
	var trial: Node=room.narrative_trial
	var dialogue: Node=main.hud.find_child("DialogueOverlay",true,false)
	var window: Node=main.hud.find_child("SystemWindow",true,false)
	if not _check(trial.phase=="dormant" and not room.confrontation_done and not player.contract_with_zero_sealed,"Interrupted trial did not restore atomically"): return false
	player.set_gameplay_orbit(Vector3.ZERO)
	for point in [Vector3(0,0,-9),Vector3(0,1.2,-14),Vector3(2.5,1.2,-14),Vector3(2.5,1.2,-18.4)]:
		if not await _walk_local(point): return false
	if not _check(player.get_nearest_interactable()==room._neural_terminal,"Restored neural console unavailable"): return false
	player.interact_with_nearest()
	if not _check(trial.phase=="recognition" and player.control_locked,"Recognition lacks input ownership"): return false
	await _frames(2)
	await _capture("father-framing")
	var recognition: Camera3D = trial._recognition_camera
	var head: Vector2 = recognition.unproject_position(campaign.kinja.global_position + Vector3.UP * 1.65)
	var head_top: Vector2 = recognition.unproject_position(campaign.kinja.global_position + Vector3.UP * 1.75)
	var head_bottom: Vector2 = recognition.unproject_position(campaign.kinja.global_position + Vector3.UP * 1.55)
	var view_size: Vector2 = recognition.get_viewport().get_visible_rect().size
	print("FATHER_FRAME head=", head, " face_span=", head_top.distance_to(head_bottom), " viewport=", view_size, " window=", root.size)
	if not _check(head.y > view_size.y * .18 and head.y < view_size.y * .43 and head.x > view_size.x * .3 and head.x < view_size.x * .7, "Father recognition face is outside the dialogue-safe upper framing"): return false
	if not _check(head_top.distance_to(head_bottom) > view_size.y * .12, "Father recognition face is too distant to read"): return false
	main.set_presentation_language("en")
	dialogue.finish_typing()
	if not _check(dialogue.full_text.contains("knew"),"Live dialogue language stale"): return false
	var original_state: Dictionary=room.get_state()
	room.restore_state(original_state)
	await _frames(3)
	if not _check(trial.phase=="dormant" and not dialogue.is_active and not player.control_locked and player.player_camera.current,"Rollback retained camera/input/dialogue"): return false
	if not _check(player.get_nearest_interactable()==room._neural_terminal,"Rollback within console area lost registration"): return false
	player.interact_with_nearest()
	await TrialInput.drain(self,main)
	if not _check(trial.phase=="memories" and not player.control_locked,"Dialogue handoff failed"): return false
	if not _check(not trial.inspect_memory("shizuka",player).get("success",false),"Remote memory inspection accepted"): return false
	for spec in [["shizuka",-4.5],["yuki",4.5]]:
		for point in [Vector3(2.5,1.2,-16.7),Vector3(spec[1],1.2,-16.7),Vector3(spec[1],1.2,-19.4)]:
			if not await _walk_local(point): return false
		if not _check(player.interact_with_nearest().get("success",false),"Earned route memory interaction failed"): return false
		if not _check(not trial.inspect_memory(spec[0],player).get("success",false),"Duplicate memory inspection accepted"): return false
		await TrialInput.drain(self,main)
	if not _check(trial.phase=="refusal" and window.visible and player.control_locked,"Refusal is not explicit/modal"): return false
	paused=true
	main.set_presentation_language("ar")
	main.set_reduced_motion(true)
	if not _check(room.reduced_motion and window.desc_lbl.text.contains("اختر"),"Paused settings failed to update live scene"): return false
	paused=false
	window.close_window()
	await _frames(5)
	if not _check(not room.confrontation_done and trial.phase=="refusal","Closing presentation answered refusal"): return false
	# Resume through the same neural console after accidental external dismissal.
	for point in [Vector3(4.5,1.2,-16.7),Vector3(2.5,1.2,-16.7),Vector3(2.5,1.2,-18.4)]:
		if not await _walk_local(point): return false
	player.interact_with_nearest()
	if not _check(window.visible and trial.phase=="refusal","Closed decision cannot be reopened"): return false
	window.stats_box.get_child(1).pressed.emit()
	await _frames(4)
	if not _check(trial.phase=="memories" and trial.memories.is_empty() and not player.control_locked,"Look again granted a story outcome or trapped controls"): return false
	# A real saved-state restore must invalidate every old window and callback.
	var old_generation: int=trial._generation
	room.restore_state(original_state)
	trial._answer_refusal("REFUSE_MEMORY_SACRIFICE",old_generation)
	trial._resist("REACH_FOR_LIGHT",old_generation)
	await _frames(5)
	if not _check(trial.phase=="dormant" and not room.confrontation_done and not window.visible,"Stale decision crossed rollback generation"): return false
	player.interact_with_nearest()
	if not await TrialInput.play(self,main,room,_walk_local,_capture,true): return _check(false,"Public-input route did not reach the cinematic")
	var old_insert: Node=trial.memory_insert
	var insert_generation: int=trial._generation
	if not _check(is_instance_valid(old_insert) and player.control_locked and not main.hud.visible and not room.confrontation_done,"Cinematic input/HUD ownership failed"): return false
	room.restore_state(original_state)
	# Simulate a late media completion from the removed instance, not a choice.
	old_insert.finished.emit()
	trial._memory_insert_finished(insert_generation)
	if not _check(not old_insert.video.is_playing() and not old_insert.ambient.playing,"Rollback did not stop media immediately"): return false
	await _frames(5)
	if not _check(trial.phase=="dormant" and not room.confrontation_done and not player.control_locked and main.hud.visible,"Late film callback crossed rollback or retained controls"): return false
	for point in [Vector3(4.5,1.2,-16.7),Vector3(2.5,1.2,-16.7),Vector3(2.5,1.2,-18.4)]:
		if not await _walk_local(point): return false
	player.interact_with_nearest()
	if not await TrialInput.play(self,main,room,_walk_local,_capture): return _check(false,"Complete restored trial failed")
	return _check(not room.contract_done and not player.combat_available,"Trial granted pact/power without consent")

func _walk_local(point: Vector3) -> bool:
	return await _walk(room.to_global(point))

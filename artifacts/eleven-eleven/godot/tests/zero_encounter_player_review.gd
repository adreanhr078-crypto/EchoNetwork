extends "res://tests/earned_campaign_resume_review.gd"

var pact: Node
var source_profile := ""
var reloads := 0
var acceptances := 0
var trace: Array = []
var power_inputs: Array = []

func _run() -> void:
	root.unfocusable = true
	root.size = Vector2i(1280, 720)
	var args := OS.get_cmdline_user_args()
	var version: String = args[0] if not args.is_empty() else "native"
	folder = ProjectSettings.globalize_path("res://../audits/evidence/chapter-cp45-20261020/stage10/" + version + "/")
	source_profile = ProjectSettings.globalize_path("res://../audits/evidence/chapter-cp45-20261020/stage09/sealed/earned/after-trial/")
	DirAccess.make_dir_recursive_absolute(folder)
	_watchdog.call_deferred()
	if args.has("--reveal-only"):
		source_profile = ProjectSettings.globalize_path("res://../audits/evidence/chapter-cp45-20261020/stage10/charged-gate-20261022/legendary-rendered/earned/accepted-integration/")
		if not await _load_fixture(true,"reveal-only"):return
		main.set_reduced_motion(false)
		pact._elapsed=0.0
		player.find_child("ZeroShadowWing",true,false).restart_cinematic_emergence()
		if not await _exercise_contract_reveal():return
		var reveal_hashes:={}
		for path:String in ["scripts/player/echo_contract_resonance.gd","scripts/player/zero_shadow_wing.gd","scripts/player/zero_eye_singularity.gd","scripts/cinematics/pact_revenge_presentation.gd","scripts/ui/system_window.gd","scripts/ui/system_signal_glass.gd","engine_visuals/shaders/contract_resonance.gdshader","shaders/zero_contract_iris.gdshader","shaders/zero_feather_detail.gdshader"]:
			reveal_hashes[path]=FileAccess.get_sha256("res://"+path)
		var reveal_report:=FileAccess.open(folder+"reveal-review.json",FileAccess.WRITE)
		reveal_report.store_string(JSON.stringify({"checks":checks,"renderer":RenderingServer.get_current_rendering_method(),"source_hashes":reveal_hashes,"scope":"Earned phase6, four actual camera shots, native iris/left hand, pause and Reduced Motion; final art/device acceptance remains open."},"\t"));reveal_report.close()
		print("PASS isolated earned contract reveal checks=",checks)
		quit(0)
		return
	if args.has("--power-only"):
		source_profile = ProjectSettings.globalize_path("res://../audits/evidence/chapter-cp45-20261020/stage10/diagnostic/earned/power-test/")
		if not await _load_fixture(true, "power-only"): return
		if not await _exercise_power(): return
		print("PASS isolated actual earned power-test checkpoint checks=", checks)
		quit(0)
		return
	if args.has("--defer-only"):
		source_profile = ProjectSettings.globalize_path("res://../audits/evidence/chapter-cp45-20261020/stage10/continuity/earned/deferred/")
		if not await _load_fixture(true, "defer-only"): return
		if not await _exercise_deferred_storage(pact._encounter_generation): return
		print("PASS isolated actual earned defer/storage checkpoint checks=", checks)
		quit(0)
		return
	if not await _load_fixture(true, "primary"): return
	for expected in 4:
		if not _pre_pact_step(expected): return
		await _capture("beat-%02d" % expected)
		if expected == 1:
			await _frames(100)
			if not _pre_pact_step(expected): return
		if expected == 2:
			var drag := InputEventScreenDrag.new()
			drag.position = Vector2(25, 240)
			drag.relative = Vector2(50, 5)
			Input.parse_input_event(drag)
			await _frames(3)
			if not _check(pact.encounter_look.length() > .01, "Public look input did not affect the owned camera"): return
			paused = true
			main.set_presentation_language("en")
			main.set_reduced_motion(true)
			if not _check(pact._encounter_language == "en" and pact.encounter_step == expected, "Paused settings advanced or failed to localize the encounter"): return
			paused = false
		if not await _save_reload("beat-%02d" % expected): return
		if not _pre_pact_step(expected): return
		if expected == 2:
			if not _check(pact.encounter_look.length() > .01 and main.reduced_motion and main.presentation_language == "en", "Look/settings did not survive actual reload"): return
			main.set_reduced_motion(false)
			main.set_presentation_language("ar")
		if not await _press(0): return
	if not await _questions(true): return
	if not _pre_pact_step(5): return
	if not await _save_reload("before-consent"): return
	pact.restore_presentation_clock(90)
	await _frames(100)
	if not _pre_pact_step(5): return
	if not await _press(0): return
	if not _check(room.contract_done and player.contract_with_zero_sealed and pact.encounter_step == 6 and not campaign.kinja.active and acceptances == 1, "Explicit consent did not commit exactly once before integration"): return
	await _capture("beat-06-integration")
	if not _check(is_instance_valid(pact._encounter_mark) and pact._encounter_mark.report.native_skin and (pact._encounter_mark.camera.current or pact._camera.current), "Integration did not inspect the actual stamped skin with an owned cinematic camera"): return
	if not await _exercise_contract_reveal():return
	if not await _save_reload("accepted-integration"): return
	if not _check(pact.encounter_step == 6 and room.contract_done and not campaign.kinja.active and acceptances == 1, "Accepted reload replayed consent or skipped integration"): return
	if not await _press(0): return
	if not _check(pact.encounter_step == 7 and player.player_camera.current and not player.control_locked and not campaign.kinja.active, "Power test did not return playable camera/input or enabled Kinja"): return
	if not await _save_reload("power-test"): return
	if not await _exercise_power(): return
	if not await _save_reload("complete"): return
	if not _check(pact.encounter_step == 8 and not pact.encounter_live and player.player_camera.current and not player.control_locked and player.get_node("ModelRoot").visible and not pact._zero.visible and acceptances == 1, "Completed encounter reopened, hid the body or duplicated acceptance on reload"): return
	if not await _load_fixture(true, "skip-defer-storage"): return
	pact._encounter_skip.pressed.emit()
	await _frames(4)
	if not _pre_pact_step(4) or not _check(pact.encounter_questions == 0, "Skip manufactured question answers"): return
	if not await _questions(false): return
	var stale: int = pact._encounter_generation
	if not await _press(1): return
	if not _check(pact.encounter_deferred and not pact.encounter_live and not player.control_locked and not player.combat_available, "Deferral retained controls or granted power"): return
	if not await _save_reload("deferred"): return
	if not await _exercise_deferred_storage(stale): return
	var report := FileAccess.open(folder + "review.json", FileAccess.WRITE)
	var hashes := {}
	for path: String in ["scripts/cinematics/pact_revenge_presentation.gd", "scripts/systems/native_campaign_controller.gd", "scripts/systems/native_campaign_checkpoint.gd", "scripts/environment/memory_reflection_space.gd", "scripts/cinematics/skin_mark_inspection_camera.gd", "tests/zero_encounter_player_review.gd", "assets/characters/echo_v31_adopted_high.glb", "assets/characters/echo_v31_short_jacket.glb", "scenes/characters/echo_v31_adopted.tscn", "scripts/player/echo_player.gd", "scripts/player/ghost_trail_spawner.gd", "engine_visuals/shaders/motion_echo.gdshader"]:
		hashes[path] = FileAccess.get_sha256("res://" + path)
	report.store_string(JSON.stringify({"checks": checks, "reloads": reloads, "acceptances": acceptances, "display": DisplayServer.get_name(), "trace": trace, "power_inputs":power_inputs,"source_hashes": hashes, "scope": "Actual earned profile, public UI/look/Iai and fresh-scene reloads. Negative stale/storage/camera probes are explicit. Not human/fun/art/device/whole-chapter acceptance."}, "\t"))
	report.close()
	print("PASS interactive Zero encounter checks=", checks, " actual reloads=", reloads, " explicit independent-profile acceptances=", acceptances)
	main.queue_free()
	for frame in 4: await process_frame
	quit(0)

func _load_fixture(seed: bool, branch := "") -> bool:
	if is_instance_valid(main):
		main.queue_free()
		for frame in 10: await process_frame
	if seed:
		profile = "user://zero_encounter_review_%d_%s/" % [OS.get_process_id(), branch]
		DirAccess.make_dir_recursive_absolute(profile)
		for file: String in ["opening.json", "maintenance.json", "route.json", "campaign.json", "preferences.cfg"]:
			if not _check(DirAccess.copy_absolute(source_profile + file, profile + file) == OK, "Missing actual earned source: " + file): return false
	main = load("res://scenes/native_journey.tscn").instantiate()
	main.native_checkpoint_path = profile + "opening.json"
	main.native_preferences_path = profile + "preferences.cfg"
	main.get_node("SystemJourneyPreview").checkpoint_path = profile + "maintenance.json"
	main.get_node("NativeJourneyController").checkpoint_path = profile + "route.json"
	main.get_node("NativeCampaignController").checkpoint_path = profile + "campaign.json"
	root.add_child(main)
	player = main.player
	player.set_process_unhandled_input(false)
	main.set_audio_muted(true)
	await _frames(20)
	campaign = main.get_node("NativeCampaignController")
	room = campaign.rooms[5]
	pact = room.story_presentation
	room.zero_contract_accepted.connect(func(): acceptances += 1)
	reloads += 1
	trace.append({"step": pact.encounter_step, "accepted": room.contract_done, "deferred": pact.encounter_deferred, "position": str(player.global_position)})
	print("ZERO_RELOAD ", reloads, " step=", pact.encounter_step, " accepted=", room.contract_done, " deferred=", pact.encounter_deferred)
	return _check(campaign.active and campaign.current == 5 and campaign.progress.completed.size() == 5, "Actual earned profile lost its room/order")

func _pre_pact_step(expected: int) -> bool:
	return _check(pact.encounter_live and pact.encounter_step == expected and player.get_node("ModelRoot").visible == (expected >= 3) and not room.contract_done and not player.contract_with_zero_sealed and not player.combat_available, "Unexpected, hidden-body or automatically accepted pre-pact step: " + str(expected))

func _encounter_window_visible() -> bool:
	var window: Node = main.hud.find_child("SystemWindow", true, false)
	return window.visible and window._modal

func _press(index: int) -> bool:
	var window: Node = main.hud.find_child("SystemWindow", true, false)
	if not _check(window.visible and window.stats_box.get_child_count() > index, "Expected public encounter button unavailable"): return false
	window.stats_box.get_child(index).pressed.emit()
	await _frames(4)
	return true

func _questions(reload_answers: bool) -> bool:
	if not _pre_pact_step(4): return false
	for index in 3:
		if not await _press(index): return false
		if not _check(pact.encounter_answer == index and bool(pact.encounter_questions & (1 << index)), "Question did not record its actual answer"): return false
		await _capture("question-%d" % index)
		if reload_answers and not await _save_reload("question-%d" % index): return false
		if not _check(pact.encounter_answer == index, "Actual reload lost the open answer"): return false
		if not await _press(0): return false
	if not _check(pact.encounter_questions == 7 and pact.encounter_answer == -1, "Question menu lost completed choices"): return false
	return await _press(3)

func _save_reload(label: String) -> bool:
	var before: Dictionary = pact.encounter_snapshot()
	if not _check(main.save_native_checkpoint_now(), "Earned encounter checkpoint write failed"): return false
	var destination := folder + "earned/" + label + "/"
	DirAccess.make_dir_recursive_absolute(destination)
	for file: String in ["opening.json", "maintenance.json", "route.json", "campaign.json", "preferences.cfg"]:
		if not _check(DirAccess.copy_absolute(profile + file, destination + file) == OK, "Cannot preserve actual encounter profile: " + label): return false
	if not await _load_fixture(false): return false
	return _check(pact.encounter_snapshot() == before, "Fresh scene did not restore the exact encounter cursor: " + label + " before=" + str(before) + " after=" + str(pact.encounter_snapshot()))

func _watchdog() -> void:
	await create_timer(240).timeout
	push_error("Interactive Zero review exceeded its bounded window")
	quit(2)

func _exercise_power() -> bool:
	var power_window: Node = main.hud.find_child("SystemWindow", true, false)
	if not _check(power_window._active_notice.is_empty() or power_window.current_type != power_window.WindowType.TASK_ASSIGNED, "A superseded laboratory task obscures the power test"): return false
	print("POWER_BEFORE step=", pact.encounter_step, " locked=", player.control_locked, " combat=", player.combat_available, " actor=", campaign.kinja.active, " attack_clip=", player.animation_player.has_animation("ATTACK_1"))
	var charged := not OS.get_cmdline_user_args().has("--tap-input")
	var actions: Array[String]=[]
	var observe := func(action: String): actions.append(action)
	player.combat_action_started.connect(observe)
	pact._encounter_power.button_down.emit()
	if charged:
		for frame in 120:
			if player.iai_charge>=.8:break
			if not _check(not campaign.kinja.active and pact.encounter_step==7,"Kinja activated while charging the tutorial action"):return false
			await physics_frame
		if not _check(player.is_charging_iai and player.iai_charge>=.8,"Public hold failed to accumulate a real charge"):return false
	print("POWER_CHARGE charging=", player.is_charging_iai, " amount=", player.iai_charge, " locked=", player.control_locked)
	var release_ratio: float=player.iai_charge
	print("POWER_CAMERA_BEFORE arm=",player.camera_boom.spring_length," capsule=",player.global_position," camera=",player.player_camera.global_position)
	pact._encounter_power.button_up.emit()
	await _frames(2)
	player.combat_action_started.disconnect(observe)
	if not _check(actions==["iai" if charged else "melee"] and pact._encounter_power_observed,"Tutorial release discarded charge or ignored the actual combat action: "+str(actions)):return false
	print("POWER_RELEASE observed=", pact._encounter_power_observed, " attack=", player.is_attacking, " locked=", player.control_locked)
	print("POWER_CAMERA_AFTER arm=",player.camera_boom.spring_length," capsule=",player.global_position," camera=",player.player_camera.global_position," boom=",player.camera_boom.global_position)
	var minimum_camera_arm:float=player.camera_boom.spring_length
	var diagnostic:=PhysicsShapeQueryParameters3D.new()
	diagnostic.shape=player.camera_boom.shape
	diagnostic.transform=player.camera_boom.global_transform
	diagnostic.collision_mask=player.camera_boom.collision_mask
	diagnostic.exclude=[player.get_rid()]
	for hit in player.get_world_3d().direct_space_state.intersect_shape(diagnostic,4):print("POWER_CAMERA_BLOCKER ",hit.collider.get_path())
	await _capture("beat-07-power-action")
	for frame in 240:
		if pact.encounter_step == 8: break
		await _frames(1)
		minimum_camera_arm=minf(minimum_camera_arm,player.camera_boom.spring_length)
	if not _check(minimum_camera_arm>=1.0,"Default power-test lane squeezed the camera into Echo: "+str(minimum_camera_arm)):return false
	var complete:=_check(pact.encounter_step == 8 and not pact.encounter_live and campaign.kinja.active and campaign.kinja.contacts == 0, "Real Iai test failed: step=" + str(pact.encounter_step) + " observed=" + str(pact._encounter_power_observed) + " attack=" + str(player.is_attacking) + " actor=" + str(campaign.kinja.active) + " contacts=" + str(campaign.kinja.contacts))
	if complete:
		var evidence:={"status":"PASS","charged_input":charged,"actual_release_ratio":release_ratio,"observed_actions":actions,"kinja_contacts":campaign.kinja.contacts,"step":pact.encounter_step,"control_locked":player.control_locked,"minimum_power_camera_arm_m":minimum_camera_arm}
		power_inputs.append(evidence)
		var file:=FileAccess.open(folder+"power-input.json",FileAccess.WRITE)
		file.store_string(JSON.stringify(evidence,"\t"));file.close()
	return complete

func _exercise_contract_reveal() -> bool:
	var wing:Node=player.find_child("ZeroShadowWing",true,false)
	var eye:Node=player.find_child("ZeroEyeSingularity",true,false)
	if not _check(wing and eye and wing.resonance.visible and eye.iris_uses_source_skin,"Accepted contract did not use actual skin iris/attached resonance"):return false
	var window:Node=main.hud.find_child("SystemWindow",true,false)
	var glass:StyleBoxFlat=window.panel.get_theme_stylebox("panel")
	if not _check(glass.bg_color.a<.85 and glass.bg_color.a>.55,"Narrative system glass lost its quiet translucent finish"):return false
	for shot in ["wing","eye","hand","portrait"]:
		var seen:=false
		for frame in 600:
			if pact.contract_cinematic_shot==shot and pact._camera.current and (shot!="wing" or wing.reveal>.55):
				seen=true;break
			await _frames(1)
		if not _check(seen and pact.encounter_step==6 and not campaign.kinja.active,"Contract reveal skipped a shot or advanced gameplay: "+shot):return false
		await _capture("contract-"+shot)
		if shot=="eye":
			print("IRIS active=",eye.is_singularity_active," visible=",eye.iris.is_visible_in_tree()," intensity=",eye.iris.material_override.get_shader_parameter("intensity")," closure=",eye.attachment.eyelid_closure()," patch=",eye.iris_surface_report)
			if not _check(eye.is_singularity_active and eye.iris.is_visible_in_tree(),"Accepted source iris overlay was hidden during its cinematic shot"):return false
			if OS.get_cmdline_user_args().has("--iris-depth-probe"):
				var original:Material=eye.iris.material_override
				for mode in ["depth","xray"]:
					pact._elapsed=2.0
					var shader:=Shader.new()
					shader.code="shader_type spatial; render_mode unshaded,cull_disabled"+(",depth_test_disabled" if mode=="xray" else "")+"; void fragment(){ ALBEDO=vec3(1.0,0.0,1.0); }"
					var probe:=ShaderMaterial.new();probe.shader=shader;eye.iris.material_override=probe
					await _capture("iris-probe-"+mode)
				eye.iris.material_override=original
				quit(0);return false
		if shot=="hand":
			var aura:MeshInstance3D=wing.resonance.hand_aura
			print("HAND_AURA visible=",aura.is_visible_in_tree()," world=",aura.global_transform," radius=",aura.mesh.radius," camera=",pact._camera.global_position," intensity=",aura.material_override.get_shader_parameter("intensity"))
		if shot=="wing":
			var clock:float=wing.local_time
			var presentation_time:float=pact._elapsed
			paused=true
			await _frames(8)
			if not _check(is_equal_approx(clock,wing.local_time) and is_equal_approx(presentation_time,pact._elapsed),"Pause advanced wing/cinematic clocks"):return false
			paused=false
	var rig:Skeleton3D=wing.attachment.skeleton
	var hand:Vector3=rig.to_global(rig.get_bone_global_pose(rig.find_bone("LeftHand")).origin)
	if not _check(wing.resonance.hand_aura.global_position.distance_to(hand)<.005,"Violet resonance followed the wrong hand or detached from actual animation"):return false
	main.set_reduced_motion(true)
	await _frames(4)
	if not _check(pact.contract_cinematic_shot=="mark" and pact._encounter_mark.camera.current and is_equal_approx(wing.reveal,1.0) and bool(wing.resonance.material.get_shader_parameter("reduced_motion")),"Reduced Motion retained moving contract cameras or unfolding/pulsing aura"):return false
	await _capture("contract-reduced-static")
	main.set_reduced_motion(false)
	return true

func _exercise_deferred_storage(stale: int) -> bool:
	var window: Node = main.hud.find_child("SystemWindow", true, false)
	print("DEFERRED_WINDOW visible=", window.visible, " modal=", window._modal, " encounter_live=", pact.encounter_live, " position=", room.to_local(player.global_position))
	if not _check(pact.encounter_deferred and not pact.encounter_live and not _encounter_window_visible() and not player.control_locked and player.player_camera.current and player.get_node("ModelRoot").visible, "Deferred reload opened consent or retained input/camera/body ownership"): return false
	if not _check(campaign._pending_story_decision.is_empty(),"Deferred reload retained a pending pact decision"):return false
	if not await _walk_local(Vector3(2.2, 0, -32)): return false
	if not _check(player.get_nearest_interactable() == room._contract_altar and player.interact_with_nearest().get("decision_requested", false), "Physical altar did not reopen the deferred encounter"): return false
	await _frames(4)
	if not _pre_pact_step(5): return false
	# A vanished previous camera must return the owned view to gameplay.
	pact._previous=null
	if not await _press(1):return false
	if not _check(player.player_camera.current and not player.control_locked and campaign._pending_story_decision.is_empty(),"Missing previous camera lost gameplay ownership after deferral"):return false
	if not _check(player.interact_with_nearest().get("decision_requested",false),"Deferral could not reopen after the camera fallback"):return false
	await _frames(4)
	if not _pre_pact_step(5):return false
	# Closing a non-current encounter must not steal another camera's lease.
	var foreign:=Camera3D.new()
	main.add_child(foreign);foreign.make_current()
	if not await _press(1):return false
	if not _check(foreign.current,"Closing encounter stole a foreign camera lease"):return false
	player.player_camera.make_current();foreign.queue_free()
	if not _check(player.interact_with_nearest().get("decision_requested",false),"Foreign-camera deferral prevented physical re-entry"):return false
	await _frames(4)
	if not _pre_pact_step(5):return false
	pact._choose_encounter("CONFIRM_ZERO_PACT", stale)
	if not _pre_pact_step(5): return false
	var prior := acceptances
	var real_path: String = campaign.checkpoint_path
	campaign.checkpoint_path = profile + "missing/campaign.json"
	if not await _press(0): return false
	if not _check(not room.contract_done and not player.combat_available and acceptances == prior, "Failed storage granted a pact or power"): return false
	campaign.checkpoint_path = real_path
	if not await _press(0): return false
	if not _check(room.contract_done and acceptances == prior + 1, "Storage recovery lost explicit consent"): return false
	campaign._accept_pact("CONFIRM_ZERO_PACT")
	return _check(acceptances == prior + 1, "Duplicate acceptance replayed the contract")

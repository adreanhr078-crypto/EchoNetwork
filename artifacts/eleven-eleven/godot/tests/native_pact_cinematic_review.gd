extends "res://tests/zero_encounter_player_review.gd"

## Actual explicit consent, native Pact72 skin and in-engine cinematic ownership.
## Earned profile bytes are copied; campaign decisions are public UI signals.
func _run() -> void:
	root.unfocusable=true
	root.size=Vector2i(1280,720)
	var args:=OS.get_cmdline_user_args()
	folder=args[0].trim_suffix("/")+"/"
	DirAccess.make_dir_recursive_absolute(folder)
	source_profile=ProjectSettings.globalize_path("res://../audits/evidence/chapter-cp45-20261020/stage11/native-attack-20261023/encounter-final/earned/before-consent/")
	_watchdog.call_deferred()
	if not await _load_fixture(true,"native-pact-cinematic"):return
	if not _check_trial_setup():return
	if not _check(_pre_pact_step(5) and player.rig_profile.id=="echo_school_mixamo_65","Unaccepted source must retain the normal school avatar"):return
	main.set_reduced_motion(false)
	if not await _press(0):return
	if not _check(pact.encounter_step==6 and room.contract_done and player.contract_with_zero_sealed and player.rig_profile.id=="echo_pact_mixamo_72" and acceptances==1,"Explicit acceptance must own the native Pact72 presentation"):return
	if not await _native_reveal():return
	if not await _save_reload("native-accepted-integration"):return
	if not _check_trial_setup():return
	if not _check(pact.encounter_step==6 and player.rig_profile.id=="echo_pact_mixamo_72" and acceptances==1,"Earned reload replayed or lost the native transformation"):return
	if not await _press(0):return
	if not _check(not player.is_attacking and not player.control_locked and player.player_camera.current,"Modal release manufactured a tutorial attack or retained camera ownership"):return
	if not await _exercise_power():return
	if not await _save_reload("native-power-complete"):return
	if not _check_trial_setup():return
	if not _check(pact.encounter_step==8 and not pact.encounter_live and not player.control_locked and player.player_camera.current and acceptances==1,"Native tutorial restore lost gameplay ownership"):return
	var report:={"status":"PASS","checks":checks,"acceptances":acceptances,"reloads":reloads,"trace":trace,"scope":"Actual explicit-consent UI/native Pact72 cinematic,source-attached aura,pause/Reduced Motion/save restore/public power release. Visual inspection and final art/contact/device acceptance remain separate."}
	var file:=FileAccess.open(folder+"review.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"));file.close()
	print("PASS NATIVE_PACT_CINEMATIC ",checks)
	quit(0)

func _check_trial_setup() -> bool:
	if not _check(is_instance_valid(room.narrative_trial._abyss), "Lab memory trial setup stopped before installing its overlay"):
		return false
	for pod in [room._shizuka_pod, room._yuki_pod]:
		var material: Material = pod.material_override
		var source := material as StandardMaterial3D
		if material is ShaderMaterial:
			source = material.get_meta("hyper_source", null) as StandardMaterial3D
		if not _check(is_instance_valid(source) and source.albedo_color.is_equal_approx(Color(.06,.14,.20,.17)),
			"Restored memory pod lost its authored transparent tint"):
			return false
	return true

func _native_reveal() -> bool:
	var avatar:Node=player.visual_root.get_node("EchoOpeningUniform")
	var legacy:Node=player.find_child("ZeroShadowWing",true,false)
	if not _check(is_instance_valid(avatar.resonance) and (not legacy or not legacy.is_visible_in_tree()),"Native contract reused the legacy wing/socket"):return false
	var seen:={}
	for tick in 360:
		await physics_frame
		var shot:String=pact.contract_cinematic_shot
		if shot in ["mark","wing","portrait","hand"] and not seen.has(shot):
			seen[shot]=true
			await _capture("native-contract-"+shot)
		if seen.size()==4:break
	if not _check(seen.size()==4 and pact.encounter_step==6 and not campaign.kinja.active,"Native contract skipped a cinematic shot or granted combat progression"):return false
	var rig:Skeleton3D=avatar.attachment.skeleton
	var hand:Vector3=rig.to_global(rig.get_bone_global_pose(rig.find_bone("mixamorig_LeftHand")).origin)
	if not _check(avatar.resonance.hand_aura.is_visible_in_tree() and avatar.resonance.hand_aura.global_position.distance_to(hand)<.005,"Native resonance left its actual animated hand"):return false
	var wing_time:float=avatar.wing_time
	var elapsed:float=pact._elapsed
	paused=true
	for frame in 8:await process_frame
	if not _check(is_equal_approx(wing_time,avatar.wing_time) and is_equal_approx(elapsed,pact._elapsed),"Pause advanced the native wing/cinematic clocks"):return false
	paused=false
	main.set_reduced_motion(true)
	for frame in 5:await physics_frame
	if not _check(pact.contract_cinematic_shot=="mark" and pact._encounter_mark.camera.current and is_equal_approx(avatar.wing_reveal,1.0) and bool(avatar.resonance.material.get_shader_parameter("reduced_motion")),"Reduced Motion lost its static native contract presentation"):return false
	await _capture("native-contract-reduced-static")
	main.set_reduced_motion(false)
	return true

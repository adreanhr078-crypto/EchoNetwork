extends "res://tests/archive_dressing_public_review.gd"

## Existing public04→05→06 route,with monotonic capture filenames and
## actual standard-motion High evidence. No relocation after its fixture.
var _watching_reactor:=false
var _reactor_retries:=0
func _capture()->void:
	shot=_samples.size()
	await super._capture()
	if not _watching_reactor:
		campaign.rooms[2].retry_requested.connect(func(_anchor:Vector3):_reactor_retries+=1)
		_watching_reactor=true
	_samples[-1].reactor_state=campaign.rooms[2].get_state()
	_samples[-1].campaign_current=campaign.current
func _finish_review()->void:
	var saved:Dictionary=Campaign.load_checkpoint(base+"_campaign.json")
	if not _check(saved.completed==["specimen","archive","reactor"],"Physical reactor exit did not save exactly three native room completions"):return
	if not _check(_specimen_retries==0 and _reactor_retries==0,"Public scanner/discharge approach incurred a retry"):return
	var reactor:Node3D=campaign.rooms[2]
	if not _check(reactor.breaker_a_done and reactor.breaker_b_done and reactor.bridge_extended and reactor.gate_open and reactor._gate_shape.disabled,"Native breakers/bridge/gate did not finish"):return
	if not _check(player.player_camera.current and not player.control_locked and not player.combat_available and player.is_on_floor(),"Reactor handoff lost camera/control/floor or granted early power"):return
	var hyper:Node=main.get_node("/root/HyperAnimeWorldManager")
	var reactor_profile_seen:=false;var archive_profile_seen:=false
	for sample in _samples:
		reactor_profile_seen=reactor_profile_seen or sample.hyper_preset=="reactor_containment"
		archive_profile_seen=archive_profile_seen or sample.hyper_preset=="archive_memory_vault"
	if not _check(reactor_profile_seen and archive_profile_seen,"Actual connected movement did not enter both shared room profiles"):return
	if not _check(hyper.preset==_samples[0].hyper_preset,"Physical reactor exit leaked its profile into the next conduit"):return
	for i in 180:
		if hyper._preset_tween==null or not hyper._preset_tween.is_valid():break
		_resume_capture_driver();await process_frame;await physics_frame
	if not _check(is_equal_approx(hyper.world_node.environment.volumetric_fog_density,_samples[0].world_fog_density),"Reactor profile did not finish restoring the actual preceding environment"):return
	var earned:=_evidence+"/earned";DirAccess.make_dir_recursive_absolute(earned)
	var hashes:={}
	for pair in [["_opening.json","opening.json"],["_maintenance.json","maintenance.json"],["_journey.json","route.json"],["_campaign.json","campaign.json"],["_prefs.cfg","preferences.cfg"]]:
		var source:String=base+pair[0];var target:String=earned+"/"+pair[1]
		if not _check(FileAccess.file_exists(source) and DirAccess.copy_absolute(source,target)==OK,"Preserve actual earned reactor profile:"+pair[1]):return
		hashes[pair[1]]=FileAccess.get_sha256(target)
	var result:={"checks":archive_checks,"saved_completion":saved.completed,"scanner_retries":_specimen_retries,"reactor_retries":_reactor_retries,"camera_current":player.player_camera.current,"control_locked":player.control_locked,"no_pre_pact_power":not player.combat_available,"solid_floor":player.is_on_floor(),"reactor_state":reactor.get_state(),"renderer":RenderingServer.get_current_rendering_method(),"tier":hyper.quality,"reduced_motion":main.reduced_motion,"framebuffer":[root.size.x,root.size.y],"public_samples":_samples,"earned_profile_hashes":hashes,"profile_after_exit":hyper.preset,"scope":"Validated security fixture then entirely public04/05/06 input:scanner/memories/stair/decoder/timed discharge/both physical breakers/bridge/exit;not fresh chapter,full memory/audio/performance/fun acceptance"}
	var f:=FileAccess.open(_evidence+"/connected-public-review.json",FileAccess.WRITE);f.store_string(JSON.stringify(result,"\t"));f.close()
	main.queue_free();for i in 5:await process_frame
	for suffix in ["_opening.json","_maintenance.json","_journey.json","_campaign.json","_prefs.cfg"]:
		for extra in ["",".bak",".tmp",".bak.tmp"]:
			if FileAccess.file_exists(base+suffix+extra):DirAccess.remove_absolute(base+suffix+extra)
	print("PASS REACTOR_PUBLIC_NATIVE_04_05_06 checks=",archive_checks," samples=",_samples.size()," retries=",_reactor_retries);quit(0)

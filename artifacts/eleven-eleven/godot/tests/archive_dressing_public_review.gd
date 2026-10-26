extends "res://tests/specimen_dressing_public_review.gd"

## Continue the proven specimen public pilot through actual archive pickups,
## stairs/catwalk,decoder and physical exit. No relocation after cold fixture.
var archive_checks:=0
func _capture()->void:
	await super._capture()
	if _samples.is_empty():return
	var hyper:Node=main.get_node("/root/HyperAnimeWorldManager")
	_samples[-1].hyper_preset=hyper.preset
	_samples[-1].world_fog_density=hyper.world_node.environment.volumetric_fog_density
	_samples[-1].reduced_motion=main.reduced_motion

func _check(ok:bool,label:String)->bool:
	archive_checks+=1
	return super._check(ok,label)

func _finish_review()->void:
	var saved:Dictionary=Campaign.load_checkpoint(base+"_campaign.json")
	if not _check(saved.completed==["specimen","archive"],"Physical room05 crossing persisted exactly two original rooms"):return
	if not _check(_specimen_retries==0,"Unmodified specimen approach incurred no retry"):return
	if not _check(player.player_camera.current and not player.control_locked and not player.combat_available,"Archive handoff retained camera/control/no early power"):return
	var archive:Node3D=campaign.rooms[1]
	if not _check(archive.collected_shards.size()==3 and archive.archive_decoded and archive.gate_open,"Archive native pickups/decoder/gate did not finish"):return
	var hyper:Node=main.get_node("/root/HyperAnimeWorldManager")
	var archive_profile_seen:=false
	for sample in _samples:archive_profile_seen=archive_profile_seen or sample.hyper_preset=="archive_memory_vault"
	if not _check(archive_profile_seen,"Actual archive traversal never applied its shared Hyper room identity"):return
	if not _check(hyper.preset==_samples[0].hyper_preset,"Archive exit leaked its style into the reactor conduit"):return
	for i in 180:
		if hyper._preset_tween==null or not hyper._preset_tween.is_valid():break
		_resume_capture_driver();await process_frame;await physics_frame
	if not _check(is_equal_approx(hyper.world_node.environment.volumetric_fog_density,_samples[0].world_fog_density),"Archive exit did not restore the prior environment after its real colour tween"):return
	var review:={"saved_completion":saved.completed,"scanner_retries":_specimen_retries,"archive_state":archive.get_state(),"camera_current":player.player_camera.current,"control_locked":player.control_locked,"no_pre_pact_power":not player.combat_available,"solid_floor":player.is_on_floor(),"renderer":RenderingServer.get_current_rendering_method(),"tier":main.get_node("/root/HyperAnimeWorldManager").quality,"framebuffer":[root.size.x,root.size.y],"public_samples":_samples,"focus_interruptions":focus_interruptions,"scope":"Validated security-completed fixture then public input through04 and05;3area pickups/native stair/upper walkway/decoder/physical thresholds;not fresh chapter,full memory playback,audio,art or fun acceptance."}
	review.checks=archive_checks
	review.reduced_motion=main.reduced_motion
	review.shared_hyper_preset_after_exit=hyper.preset
	var earned:=_evidence+"/earned";DirAccess.make_dir_recursive_absolute(earned)
	var profile_hashes:={}
	for pair in [["_opening.json","opening.json"],["_maintenance.json","maintenance.json"],["_journey.json","route.json"],["_campaign.json","campaign.json"],["_prefs.cfg","preferences.cfg"]]:
		var source:String=base+pair[0]
		if not FileAccess.file_exists(source):continue
		var target:String=earned+"/"+pair[1]
		if not _check(DirAccess.copy_absolute(source,target)==OK,"Preserve actual earned archive profile: "+pair[1]):return
		profile_hashes[pair[1]]=FileAccess.get_sha256(target)
	review.earned_profile_hashes=profile_hashes
	review.checks=archive_checks
	var out:=FileAccess.open(_evidence+"/connected-public-review.json",FileAccess.WRITE);out.store_string(JSON.stringify(review,"\t"));out.close()
	# Call the route owner's cleanup directly;the intermediate specimen-only
	# finalizer correctly requires one completion and is outside this scope.
	await _archive_cleanup()

func _archive_cleanup()->void:
	main.queue_free()
	for i in 5:await process_frame
	for suffix in ["_opening.json","_maintenance.json","_journey.json","_campaign.json","_prefs.cfg"]:
		for extra in ["",".bak",".tmp",".bak.tmp"]:
			if FileAccess.file_exists(base+suffix+extra):DirAccess.remove_absolute(base+suffix+extra)
	print("PASS ARCHIVE_PUBLIC_NATIVE_04_05 samples=",_samples.size()," retries=",_specimen_retries)
	quit(0)

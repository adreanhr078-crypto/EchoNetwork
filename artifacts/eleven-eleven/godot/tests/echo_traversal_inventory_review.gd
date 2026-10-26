extends SceneTree

## Read-only runtime diagnosis. Separate temporary save paths; no room jumps,
## bone writes, progression changes or clip injection.
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	root.unfocusable=true
	var profile:="user://traversal_inventory_%d/"%OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(profile)
	var main:Node=load("res://scenes/native_journey.tscn").instantiate()
	main.native_checkpoint_path=profile+"opening.json"
	main.native_preferences_path=profile+"preferences.cfg"
	main.get_node("SystemJourneyPreview").checkpoint_path=profile+"maintenance.json"
	main.get_node("NativeJourneyController").checkpoint_path=profile+"route.json"
	main.get_node("NativeCampaignController").checkpoint_path=profile+"campaign.json"
	root.add_child(main)
	main.set_audio_muted(true)
	for frame in 24:
		if paused:main.native_pause_menu.resume_button.pressed.emit()
		await process_frame
	var player:Node=main.player
	var animation:AnimationPlayer=player.animation_player
	var clips:={}
	for id in ["WALK","RUN","IDLE","preset_jump","PARKOUR_HANG","PARKOUR_CLIMB","PARKOUR_MANTLE","PARKOUR_VAULT","Braced_To_Free_Hang","Jump_To_Hang","CLIMB"]:
		clips[id]={"present":animation.has_animation(id)}
		if animation.has_animation(id):
			var motion:=animation.get_animation(id)
			clips[id].merge({"duration":motion.length,"tracks":motion.get_track_count()})
	var report:={"scope":"Read-only current V31 runtime clip availability, not art acceptance","clips":clips,"all_clip_names":animation.get_animation_list(),"current_anim":player.current_anim,"source_hashes":{}}
	for path in ["scripts/player/echo_player.gd","scripts/player/surface_traversal_motor.gd","scripts/player/echo_rig_profile.gd","scripts/player/mixamo_animation_bridge.gd","assets/characters/echo_v31_adopted_high.glb"]:
		report.source_hashes[path]=FileAccess.get_sha256("res://"+path)
	var args:=OS.get_cmdline_user_args()
	var folder:String=args[0] if not args.is_empty() else ProjectSettings.globalize_path("res://../audits/evidence/echo-parkour-cp40-20261019/")
	DirAccess.make_dir_recursive_absolute(folder)
	var file:=FileAccess.open(folder.path_join("current-runtime-inventory.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"));file.close()
	print("CURRENT_TRAVERSAL_INVENTORY ",JSON.stringify(clips))
	print("Inventory captured; absent clips remain an explicit quality gate")
	quit(0)

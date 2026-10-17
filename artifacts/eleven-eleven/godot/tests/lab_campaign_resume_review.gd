extends SceneTree

const Campaign=preload("res://scripts/systems/native_campaign_checkpoint.gd")
const Journey=preload("res://scripts/systems/native_journey_checkpoint.gd")
const Saves=preload("res://scripts/systems/save_manager.gd")
var failures:=0

func _initialize()->void:_run.call_deferred()
func check(ok:bool,message:String)->void:
	if not ok:
		failures+=1
		push_error(message)

func _run()->void:
	if OS.get_cmdline_user_args().has("--anchor-only"):
		var lab=load("res://scenes/environment/dr_kinja_lab_room.tscn").instantiate()
		root.add_child(lab)
		for i in 3:await physics_frame
		_check_anchor(lab)
		lab.queue_free()
		for i in 4:await process_frame
		quit(1 if failures else 0)
		return
	for stage in ["manifested","accepted","revenge"]:
		var base:String="user://lab_resume_%d_%s"%[OS.get_process_id(),stage]
		Saves.save_opening_checkpoint({"schema":Saves.OPENING_SCHEMA,"milestones":{"wake":true,"clock":true,"photo":true,"memory":true,"terminal":true,"conduit":true,"ending":true},"terminal":{"frequency":111.0,"phase":45.0,"harmonic":7.0}},base+"_opening.json")
		var file:=FileAccess.open(base+"_maintenance.json",FileAccess.WRITE)
		file.store_string(JSON.stringify({"schema":"echo-maintenance-preview-v1","stage":6}))
		file.close()
		Journey.save_checkpoint({"schema":Journey.SCHEMA,"completed":Journey.EVENTS,"security":{"gate_open":true,"scanner_trace":true,"service_trace":false}},base+"_journey.json")
		var progress:=Campaign.initial()
		for id in ["specimen","archive","reactor","decon","mirror"]:
			progress.flags[id]={}
			for key in Campaign.FLAGS[id]:progress.flags[id][key]=true
			progress=Campaign.advance(progress,id)
		progress.flags.lab={"confrontation_done":true,"contract_done":stage!="manifested","revenge_done":stage=="revenge","wish_done":false}
		check(Campaign.save_checkpoint(progress,base+"_campaign.json"),"Cannot create valid ordered lab resume fixture")
		var main=load("res://scenes/native_journey.tscn").instantiate()
		main.native_checkpoint_path=base+"_opening.json"
		main.native_preferences_path=base+"_prefs.cfg"
		main.get_node("SystemJourneyPreview").checkpoint_path=base+"_maintenance.json"
		main.get_node("NativeJourneyController").checkpoint_path=base+"_journey.json"
		main.get_node("NativeCampaignController").checkpoint_path=base+"_campaign.json"
		root.add_child(main)
		main.set_audio_muted(true)
		main.set_reduced_motion(false)
		for i in 12:await process_frame
		var controller=main.get_node("NativeCampaignController")
		var room=controller.rooms[5]
		var local:Vector3=room.to_local(main.player.global_position)
		check(local.distance_to(room.get_safe_anchor())<.5,"Restored "+stage+" missed safe anchor: actual="+str(local)+" target="+str(room.get_safe_anchor()))
		_check_anchor(room,main.player.get_rid())
		check(not room.story_presentation.active,"Restoring "+stage+" replayed an event camera insert")
		check(not room.wish_done and not room.breach_open,"Resume silently accepted a wish")
		check(main.player.combat_available==(stage=="accepted"),"Restored combat does not match explicit saved decisions")
		if stage!="revenge":check(is_instance_valid(controller.kinja),"Resume lost the pending-confrontation Kinja actor")
		if stage=="revenge":
			var window=main.hud.find_child("SystemWindow",true,false)
			check(window.visible and window.stats_box.get_child_count()==1 and main.player.control_locked,"Resume failed to re-present the pending explicit wish")
			check(not window.confirm_btn.visible,"Pending wish exposed a generic close control without an explicit decision")
		main.queue_free()
		for i in 5:await process_frame
		for suffix in ["_opening.json","_maintenance.json","_journey.json","_campaign.json","_prefs.cfg"]:
			for extra in ["",".bak",".tmp",".bak.tmp"]:
				if FileAccess.file_exists(base+suffix+extra):DirAccess.remove_absolute(base+suffix+extra)
	print("Lab campaign resume failures=",failures,"; real saved manifested/accepted/revenge states, qualified anchor, no event replay, explicit pending wish and combat authority")
	quit(1 if failures else 0)

func _check_anchor(room:Node3D,excluded:=RID())->void:
	var capsule:=CapsuleShape3D.new()
	capsule.radius=.4
	capsule.height=1.8
	var query:=PhysicsShapeQueryParameters3D.new()
	query.shape=capsule
	query.transform=Transform3D(Basis.IDENTITY,room.to_global(room.SAFE_ANCHOR_CONTRACT+Vector3.UP*.9))
	query.collision_mask=1
	if excluded.is_valid():query.exclude=[excluded]
	var hits:=room.get_world_3d().direct_space_state.intersect_shape(query)
	var paths:Array=[]
	for hit in hits:paths.append(str(hit.collider.get_path()))
	check(hits.is_empty(),"Contract respawn capsule intersects room geometry: "+str(paths))

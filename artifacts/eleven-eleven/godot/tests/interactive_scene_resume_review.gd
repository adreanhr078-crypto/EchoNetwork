extends SceneTree
const Campaign = preload("res://scripts/systems/native_campaign_checkpoint.gd")
const Journey = preload("res://scripts/systems/native_journey_checkpoint.gd")
const Saves = preload("res://scripts/systems/save_manager.gd")
var main: Node
var base: String
var checks := 0
var failures := 0
var folder := "res://../audits/evidence/chapter-cp45-20261020/stage03/"
func _initialize() -> void: _run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ",label)
func frames(count: int) -> void:
	for i in count: await process_frame
func load_scene() -> void:
	if is_instance_valid(main):
		main.queue_free()
		await frames(3)
	main = load("res://scenes/native_journey.tscn").instantiate()
	main.native_checkpoint_path=base+"opening.json"
	main.native_preferences_path=base+"prefs.cfg"
	main.get_node("SystemJourneyPreview").checkpoint_path=base+"maintenance.json"
	main.get_node("NativeJourneyController").checkpoint_path=base+"route.json"
	main.get_node("NativeCampaignController").checkpoint_path=base+"campaign.json"
	root.add_child(main)
	await frames(12)
	main.set_audio_muted(true)
func _run() -> void:
	root.unfocusable=true
	root.size=Vector2i(1280,720)
	folder=ProjectSettings.globalize_path(folder)
	DirAccess.make_dir_recursive_absolute(folder)
	base="user://interactive_resume_%d/"%OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(base)
	var opening: Dictionary={"schema":Saves.OPENING_SCHEMA,"milestones":{"wake":true,"clock":true,"photo":true,"memory":true,"terminal":true,"conduit":true,"ending":true},"terminal":{"frequency":111.0,"phase":45.0,"harmonic":7.0}}
	check(Saves.save_opening_checkpoint(opening,base+"opening.json"),"Isolated opening fixture")
	var file=FileAccess.open(base+"maintenance.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema":"echo-maintenance-preview-v1","stage":6}));file.close()
	check(Journey.save_checkpoint({"schema":Journey.SCHEMA,"completed":Journey.EVENTS,"security":{"gate_open":true,"scanner_trace":true,"service_trace":false}},base+"route.json"),"Isolated predecessor journey fixture")
	var progress:=Campaign.initial()
	for id in ["specimen","archive","reactor","decon","mirror"]:
		progress.flags[id]={}
		for key in Campaign.FLAGS[id]: progress.flags[id][key]=true
		progress=Campaign.advance(progress,id)
	progress.flags.lab={"confrontation_done":true,"contract_done":false,"revenge_done":false,"wish_done":false}
	check(Campaign.save_checkpoint(progress,base+"campaign.json"),"Old three-field checkpoint remains compatible")
	var corrupt:=progress.duplicate(true)
	corrupt.presentation={"beat":"accepted","elapsed":1.0}
	check(Campaign.validate(corrupt).is_empty(),"Presentation cursor cannot grant a missing pact")
	corrupt.presentation={"beat":"pact","elapsed":NAN}
	check(Campaign.validate(corrupt).is_empty(),"Nonfinite elapsed rejected")
	await load_scene()
	var campaign=main.get_node("NativeCampaignController")
	var lab=campaign.rooms[5]
	check(campaign.current==5 and not lab.contract_done,"Actual connected lab restores without power")
	campaign._show_pact()
	var window=campaign._window()
	var presentation=lab.story_presentation
	check(window.visible and window.stats_box.get_child_count()==2,"Existing decision retains explicit accept and defer")
	main.set_presentation_language("en")
	check(window.title_lbl.text=="Zero's pact" and window.stats_box.get_child(1).text=="Not yet","Pending decision translates live to EN")
	main.set_presentation_language("ar")
	check(window.title_lbl.text=="عقد زيرو" and window.stats_box.get_child(1).text=="ليس الآن","Pending decision translates live to AR")
	main.native_pause_menu.set_session_paused(true)
	var elapsed: float=presentation._elapsed
	await frames(3)
	check(is_equal_approx(elapsed,presentation._elapsed) and paused,"Pause freezes actual presentation clock")
	check(Campaign.load_checkpoint(base+"campaign.json").get("presentation",{}).get("beat","")=="pact","Pause stores non-authoritative pending decision")
	main.native_pause_menu.set_session_paused(false)
	presentation.finish(true)
	check(window.visible and not lab.contract_done and main.player.control_locked,"Skip cannot accept or release pending choice")
	main.set_reduced_motion(true)
	check(window.visible and not lab.contract_done and main.player.control_locked,"Reduced Motion preserves pending choice")
	check(main.save_native_checkpoint_now(),"Save at pending pact")
	await load_scene()
	campaign=main.get_node("NativeCampaignController");lab=campaign.rooms[5];window=campaign._window()
	check(window.visible and not lab.contract_done and main.player.control_locked,"Fresh scene load resumes the same undecided pact")
	window.stats_box.get_child(1).pressed.emit()
	await frames(3)
	check(not lab.contract_done and not main.player.combat_available and not main.player.control_locked,"Deferral returns control without power")
	check(main.save_native_checkpoint_now() and not Campaign.load_checkpoint(base+"campaign.json").has("presentation"),"Saved deferral clears the pending cursor")
	campaign._show_pact()
	var grants: Array=[0]
	lab.zero_contract_accepted.connect(func():grants[0]+=1)
	window.stats_box.get_child(0).pressed.emit()
	await frames(3)
	check(lab.contract_done and main.player.combat_available and grants[0]==1,"Only explicit acceptance grants local pact once")
	lab.accept_zero_contract()
	check(grants[0]==1,"Repeated acceptance is idempotent")
	check(main.save_native_checkpoint_now(),"Save after explicit acceptance")
	await load_scene()
	campaign=main.get_node("NativeCampaignController");lab=campaign.rooms[5]
	check(lab.contract_done and main.player.combat_available and campaign._pending_story_decision.is_empty(),"Post-acceptance resume returns earned gameplay without a second choice")
	check(not main.companion.visible,"All resume branches retain chapter companion policy")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(folder+"accepted-resume.png")
	var report: Dictionary={"status":"PASS" if failures==0 else "FAIL","checks":checks,"failures":failures,"renderer":DisplayServer.get_name(),"save_scope":"isolated local fixtures; no account receipt"}
	file=FileAccess.open(folder+"report.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("INTERACTIVE_RESUME_REVIEW ",JSON.stringify(report))
	main.queue_free();await frames(3)
	quit(1 if failures else 0)

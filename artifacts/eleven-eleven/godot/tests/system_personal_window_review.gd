extends "res://tests/earned_campaign_resume_review.gd"

## Art fixture in an actually earned ward. Windows present existing completed
## chapter facts; they cannot grant XP, items, a pact or any new campaign flag.
func _review_ward() -> bool:
	if not await super._review_ward(): return false
	var window:Node=main.hud.find_child("SystemWindow",true,false)
	var before:Dictionary=campaign.progress.duplicate(true)
	main.set_reduced_motion(not OS.get_cmdline_user_args().has("--cinematic"))
	window.queue_story_update("fixture:earned-memory:3","استعادة شظايا الذاكرة","Recover the memory fragments","اكتمل استرجاع الشظايا الثلاث.","All three memory fragments are recovered.",3,3)
	await _frames(24)
	await _capture("personal-task-ar")
	if not _check(not window._scroll.get_v_scroll_bar().visible,"Desktop task card has a stray clipping scrollbar"):return false
	if not _check(not player.control_locked and not window._modal,"Passive task display seized player controls"):return false
	if not await _walk(room.to_global(Vector3(1.6,0,1.18))):return false
	await _capture("personal-task-follow")
	window.close_window()
	await _frames(16)
	main.set_presentation_language("en")
	window.queue_story_update("fixture:earned-memory-en:3","استعادة شظايا الذاكرة","Recover the memory fragments","اكتمل استرجاع الشظايا الثلاث.","All three memory fragments are recovered.",3,3)
	await _frames(24)
	await _capture("personal-task-en")
	if not _check(window.header_lbl.get_line_count()==1,"English task header wraps its channel identifier onto another line"):return false
	window.close_window()
	await _frames(16)
	if OS.get_cmdline_user_args().has("--synthetic-xp"):
		# Explicit synthetic visual fixture, not a real account receipt.
		window.queue_experience_gain("synthetic-visual-receipt-001",40,120,160,300)
		await _frames(48)
		await _capture("synthetic-xp-en")
		window.close_window()
		await _frames(16)
	main.set_presentation_language("ar")
	var status_key:=InputEventKey.new()
	status_key.physical_keycode=KEY_I
	status_key.pressed=true
	Input.parse_input_event(status_key)
	await _frames(3)
	status_key=InputEventKey.new();status_key.physical_keycode=KEY_I;status_key.pressed=false;Input.parse_input_event(status_key)
	if not _check(window._status_view and not window._modal and not player.control_locked,"Physical I did not open a passive personal status panel"):return false
	await _frames(20)
	await _capture("personal-status-ar")
	if not _check(window.stats_box.get_child(0).text.contains(str(roundi(player.hp))),"Personal status does not read actual player HP"):return false
	main.set_presentation_language("en")
	await _frames(5)
	if not _check(window.title_lbl.text=="Echo status" and window.stats_box.get_child(2).text.contains("Objective:"),"Personal status failed live English"):return false
	await _capture("personal-status-en")
	main.toggle_personal_system()
	await _frames(16)
	main.set_presentation_language("ar")
	window.show_decision("أثر لا يختفي","الصورة وحدها لا تمنحك قوة. القرار لك.",[{"id":"review_only","text":"متابعة الفحص"}])
	await _frames(8)
	main.toggle_personal_system()
	if not _check(window._modal and not window._status_view and window.stats_box.get_child(0).text=="متابعة الفحص","Status shortcut replaced a real decision"):return false
	await _capture("personal-decision-ar")
	window.close_window()
	if not _check(campaign.progress==before,"UI fixture changed confirmed chapter state"): return false
	var hashes:={}
	for path in ["scripts/main.gd","scripts/ui/native_pause_menu.gd","scripts/ui/system_window.gd","scripts/ui/system_signal_glass.gd","scripts/ui/gameplay_hud.gd","scripts/systems/native_campaign_controller.gd","tests/system_personal_window_review.gd"]:
		hashes[path]=FileAccess.get_sha256("res://"+path)
	var output:=FileAccess.open(folder+"system-review.json",FileAccess.WRITE)
	output.store_string(JSON.stringify({"scope":"Actually earned completed ward, presentation fixture only, no grants; any XP shown is synthetic display data","synthetic_xp":OS.get_cmdline_user_args().has("--synthetic-xp"),"source_hashes":hashes},"\t"));output.close()
	return true

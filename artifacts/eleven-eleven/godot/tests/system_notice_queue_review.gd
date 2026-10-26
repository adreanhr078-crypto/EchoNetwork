extends SceneTree

## Synthetic display records only; no account, save, XP or player statistics.
var checks:=0
func _initialize() -> void: _run.call_deferred()
func _check(value: bool, label: String) -> bool:
	checks+=1
	if not value:push_error(label);quit(1)
	return value
func _frames(count:int) -> void:
	for i in count:await process_frame
func _run() -> void:
	root.size=Vector2i(844,390)
	var window:Control=load("res://scenes/ui/system_window.tscn").instantiate()
	root.add_child(window)
	window.reduced_motion=true
	var mute_before:=AudioServer.is_bus_mute(0)
	AudioServer.set_bus_mute(0,true)
	var choices:=[]
	window.decision_made.connect(func(id:String):choices.append(id))
	window.show_decision("قرار صريح","الاختيار لك",[{"id":"continue","text":"متابعة"}])
	if not _check(window.queue_story_update("story:archive:fragments:1","شظايا الأرشيف","Archive fragments","تم توثيق خطوة.","Progress recorded.",1,3),"Confirmed story record was not queued"):return
	if not _check(not window.queue_story_update("story:archive:fragments:1","مكرر","Duplicate","","",1,3),"Duplicate display record was replayed"):return
	await _frames(4)
	if not _check(window._modal and window.stats_box.get_child(0).text=="متابعة" and choices.is_empty(),"Passive notice replaced or accepted a decision"):return
	window.close_window()
	await _frames(4)
	if not _check(not window._modal and window.visible and window.current_type==window.WindowType.TASK_PROGRESS,"Queued partial progress claimed task completion or blocked movement"):return
	if not _check(not window.get_node("ClickShield").visible and window.panel.mouse_filter==Control.MOUSE_FILTER_IGNORE,"Passive record captures gameplay pointer input"):return
	if not _check(window._progress_bar.value==1 and window._progress_bar.max_value==3,"Story counter is not its committed value"):return
	window.set_presentation_language("en")
	if not _check(window.title_lbl.text=="Archive fragments" and window.header_lbl.text.contains("TASK PROGRESS"),"Queued record lost live language ownership"):return
	var remaining:float=window._notice_remaining
	paused=true
	await create_timer(.08,true).timeout
	if not _check(window._notice_remaining==remaining,"Pause consumed notice reading time"):return
	paused=false
	window.set_notice_suspended(true)
	await _frames(2)
	remaining=window._notice_remaining
	await _frames(3)
	if not _check(not window.panel.visible and window._notice_remaining==remaining,"Dialogue suspension hid but consumed a receipt"):return
	window.show_decision("Priority","Explicit choice",[{"id":"priority","text":"Continue"}])
	if not _check(window._modal and window.panel.visible and window._active_notice.is_empty(),"Modal did not preempt passive display safely"):return
	await create_timer(.08).timeout
	if not _check(window.visible and window.title_lbl.text=="Priority" and choices.is_empty(),"Old receipt timer closed or accepted a new decision"):return
	window.set_notice_suspended(false)
	window.close_window()
	await _frames(4)
	if not _check(window._active_notice.get("id")=="story:archive:fragments:1","Interrupted record was lost instead of resumed"):return
	window.close_window()
	await _frames(3)
	if not _check(not window.queue_experience_gain("bad",40,120,159,300) and not window.queue_experience_gain("overflow",40,280,320,300),"Inconsistent XP data was presented"):return
	if not _check(window.queue_experience_gain("synthetic-receipt-001",40,120,160,300),"Valid synthetic display data was rejected"):return
	await _frames(4)
	if not _check(window.current_type==window.WindowType.EXPERIENCE_GAIN and window._progress_bar.value==160 and window.desc_lbl.text=="+40 XP","XP display changed its supplied data"):return
	if not _check(not window._notice_audio.playing,"Muted receipt produced a cue"):return
	AudioServer.set_bus_mute(0,false)
	await _frames(3)
	if not _check(not window._notice_audio.playing,"Unmuting replayed an old receipt cue"):return
	if not _check(not window.queue_experience_gain("synthetic-receipt-001",40,120,160,300),"Duplicate XP record replayed"):return
	window.show_decision("Hold","No passive interruption",[{"id":"hold","text":"Continue"}])
	window.queue_story_update("story:archive:fragments:2","الشظايا","Fragments","","",2,3)
	window.queue_story_update("story:archive:fragments:3","الشظايا","Fragments","","",3,3)
	var fragment_records:Array=window._pending_notices.filter(func(event:Dictionary):return event.get("group","")=="story:archive:fragments")
	if not _check(fragment_records.size()==1 and fragment_records[0].to==3,"Rapid substeps were not coalesced to the latest confirmed count"):return
	window.queue_task_assigned("entered:archive","الأرشيف","Archive",""," ")
	window.queue_task_assigned("entered:reactor","المفاعل","Reactor",""," ")
	if not _check(window._pending_notices.filter(func(event:Dictionary):return event.type==window.WindowType.TASK_ASSIGNED).size()==1,"Obsolete room assignment remained queued"):return
	window._pending_notices.clear()
	window.show_level_up(2)
	window.show_reward_window("Queued fixture item")
	window.show_quest_update("Completed fixture","Next fixture")
	if not _check(window._modal and window.stats_box.get_child(0).text=="Continue" and window._pending_notices.size()==3,"Legacy level/reward/task messages replaced an explicit decision"):return
	window.close_window()
	await _frames(3)
	if not _check(window.current_type==window.WindowType.LEVEL_UP and window.stats_box.get_child_count()==0 and not window._modal,"Deferred level message did not resume passively"):return
	window.close_window()
	await _frames(3)
	if not _check(window.current_type==window.WindowType.REWARD and window.stats_box.get_child(0).text=="Queued fixture item","Deferred reward lost its supplied item"):return
	window.close_window()
	window._pending_notices.clear()
	await _frames(3)
	window.show_level_up(2)
	if not _check(window.stats_box.get_child_count()==0,"Level presentation invented HP or attack bonuses"):return
	window.show_reward_window("Confirmed fixture item")
	if not _check(window.stats_box.get_child_count()==1 and not window.stats_box.get_child(0).text.contains("DAMAGE"),"Reward presentation invented damage or skills"):return
	if not _check(not window._modal and not window.confirm_btn.visible and window.panel.mouse_filter==Control.MOUSE_FILTER_IGNORE,"Reward convenience display interrupts gameplay"):return
	window.close_window()
	window._pending_notices.clear()
	await _frames(3)
	window.queue_story_update("comfort:counter:1","شظايا","Fragments","","",1,3)
	await _frames(3)
	var entrance:int=window._window_generation
	if not _check(window._notice_remaining<=2.4 and not window._notice_audio.playing,"Minor progress is long or noisy"):return
	window.queue_story_update("comfort:counter:2","شظايا","Fragments","","",2,3)
	if not _check(window._window_generation==entrance and window._pending_notices.is_empty() and window._progress_bar.value==2,"Visible progress burst restarted the entrance or created a backlog"):return
	window.queue_story_update("comfort:counter:3","شظايا","Fragments","","",3,3)
	if not _check(window.current_type==window.WindowType.QUEST_COMPLETED and window._window_generation==entrance and window._pending_notices.is_empty(),"Completion did not upgrade the existing counter in place"):return
	window.show_level_up(3)
	if not _check(not window._modal and not window.confirm_btn.visible and window.panel.mouse_filter==Control.MOUSE_FILTER_IGNORE,"Level-up convenience display interrupts gameplay"):return
	window.close_window()
	window._pending_notices.clear()
	await _frames(3)
	window.queue_story_update("comfort:hidden:1","شظايا","Fragments","","",1,2)
	await _frames(3)
	window._notice_audio.stop()
	window.set_notice_suspended(true)
	await _frames(2)
	window.queue_story_update("comfort:hidden:2","شظايا","Fragments","","",2,2)
	if not _check(not window._notice_audio.playing and not window.panel.visible,"A coalesced completion sounded through a blocking dialogue"):return
	window.set_notice_suspended(false)
	await _frames(3)
	if not _check(window.current_type==window.WindowType.QUEST_COMPLETED and window._progress_bar.value==2 and not window._notice_audio.playing,"Resuming a hidden completion replayed audio or lost its counter"):return
	window.close_window()
	window._pending_notices.clear()
	await _frames(3)
	window.queue_task_assigned("old-lab-task", "المختبر", "Laboratory", "", "")
	await _frames(3)
	window.queue_experience_gain("kept-xp", 5, 0, 5, 100)
	window.dismiss_task_assignments()
	await _frames(3)
	if not _check(window.current_type == window.WindowType.EXPERIENCE_GAIN and window._active_notice.get("id") == "kept-xp", "Superseded task dismissal removed an earned notice"): return
	window.queue_task_assigned("queued-old-task", "المختبر", "Laboratory", "", "")
	window.dismiss_task_assignments()
	if not _check(window._pending_notices.is_empty() and window._active_notice.get("id") == "kept-xp", "Task dismissal changed the active receipt or retained an old task"): return
	AudioServer.set_bus_mute(0,mute_before)
	window.queue_free()
	await process_frame
	print("PASS personal system queue checks=",checks,"; synthetic display records only, no authority mutation")
	quit(0)

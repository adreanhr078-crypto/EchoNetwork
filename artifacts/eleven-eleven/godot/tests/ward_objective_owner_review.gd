extends "res://tests/earned_campaign_resume_review.gd"

## Restore an earned ward, then change language while paused. The old route
## owner must never replace the campaign objective with the security exit.
func _review_ward() -> bool:
	if not await super._review_ward(): return false
	if not _check(player.player_camera.far==16.0,"Ward retained the4km facility camera range"): return false
	paused = true
	main.set_presentation_language("en")
	if not _check(main.hud.quest_title.text == "EX-011" and main.hud.quest_desc.text.contains("chapter is complete"), "Paused language change replaced the ward objective with an earlier room"): return false
	campaign.native_owner.refresh_objective()
	if not _check(main.hud.quest_title.text == "EX-011", "Inactive security owner overwrote the active campaign objective"): return false
	main.set_presentation_language("ar")
	if not _check(main.hud.quest_title.text == "EX-011" and main.hud.quest_desc.text.contains("اكتمل"), "Paused Arabic change lost the ward objective"): return false
	paused = false
	await _frames(4)
	await _capture("ward-objective-live-language")
	# Presentation-only inspection from an already earned completed save. It
	# cannot serve as evidence of a fresh story grant or the first reveal.
	campaign._hospital_mark()
	await _frames(8)
	if not _check(is_instance_valid(campaign._mark_inspection), "Current skin inspection camera did not bind to the adopted avatar"): return false
	if not _check(campaign._mark_inspection.camera.far==16.0,"Skin inspection lost the ward camera range"): return false
	await _capture("ward-current-skin-inspection")
	main.hud.find_child("SystemWindow",true,false).close_window()
	await _frames(5)
	if not _check(player.player_camera.current and not player.control_locked, "Skin inspection did not return the earned ward controls"): return false
	if args_probe_far():
		var original_far: float=player.player_camera.far
		var comparison:=[]
		for far_distance in [original_far,16.0]:
			player.player_camera.far=far_distance
			await _frames(16)
			comparison.append({"far":far_distance,"draws":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)})
			await _capture("ward-far-%s"%far_distance)
		player.player_camera.far=original_far
		var report:=FileAccess.open(folder+"far-probe.json",FileAccess.WRITE)
		report.store_string(JSON.stringify(comparison,"\t"));report.close()
	if DisplayServer.get_name() != "headless":
		var samples: Array[float]=[]
		var previous:=Time.get_ticks_usec()
		for i in 240:
			await process_frame
			var now:=Time.get_ticks_usec()
			samples.append((now-previous)/1000.0)
			previous=now
		samples.sort()
		var profile:=FileAccess.open(folder+"ward-frame-profile.json",FileAccess.WRITE)
		profile.store_string(JSON.stringify({"samples":samples.size(),"p50_ms":samples[119],"p95_ms":samples[227],"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),"texture_bytes":Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED),"renderer":RenderingServer.get_current_rendering_method(),"scope":"Rendered developer-workstation frame intervals in earned ward; no GPU timer or device acceptance; normal clock, no fixed FPS"},"\t"))
		profile.close()
	return true

func args_probe_far() -> bool:
	return OS.get_cmdline_user_args().has("--far-probe")

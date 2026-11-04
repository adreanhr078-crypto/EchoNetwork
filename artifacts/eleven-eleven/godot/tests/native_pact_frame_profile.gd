extends "res://tests/zero_encounter_player_review.gd"

## Actual rendered wall intervals after source/shader warmup, not a GPU timer.
func _run() -> void:
	root.unfocusable=true
	root.size=Vector2i(1280,720)
	Engine.max_fps=0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	folder=OS.get_cmdline_user_args()[0].trim_suffix("/")+"/"
	DirAccess.make_dir_recursive_absolute(folder)
	source_profile=ProjectSettings.globalize_path("res://../audits/evidence/chapter-cp45-20261020/stage11/native-attack-20261023/encounter-final/earned/complete/")
	if not await _load_fixture(true,"frame-profile"):return
	if not _check(pact.encounter_step==8 and player.rig_profile.id=="echo_pact_mixamo_72","Performance source must be an earned native pact"):return
	var phases:={}
	var water:Node=main.find_child("MemoryReflectionSpace",true,false)
	var architecture:Node=main.find_child("ClinicalLabArchitecture",true,false)
	for tier in ["high","medium","low"]:
		main.set_visual_quality(tier)
		for frame in 120:await process_frame
		var intervals:Array[float]=[]
		var previous:=Time.get_ticks_usec()
		var draw_total:=0.0
		var updates_before:int=water.reflection_updates
		for frame in 240:
			await process_frame
			var current:=Time.get_ticks_usec()
			intervals.append((current-previous)/1000.0)
			previous=current
			draw_total+=Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		intervals.sort()
		var total:=0.0
		for interval in intervals:total+=interval
		phases[tier]={"frames":intervals.size(),"mean_ms":total/intervals.size(),"mean_fps":1000.0/(total/intervals.size()),"p50_ms":intervals[119],"p95_ms":intervals[227],"p99_ms":intervals[237],"max_ms":intervals.back(),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)}
		var shadows:=0
		for light in architecture.service_shadow_sources:
			if light.shadow_enabled:shadows+=1
		phases[tier].merge({"mean_draw_calls":draw_total/intervals.size(),"service_shadows":shadows,"focal_shadow":room._surgical_light.shadow_enabled,"reflection_updates":water.reflection_updates-updates_before,"water_screen_fraction":water.reflection_visible_fraction,"msaa":root.msaa_3d,"render_scale":root.scaling_3d_scale})
		await _capture("native-pact-"+tier)
		print("NATIVE_PACT_FRAME_PROFILE ",tier," ",JSON.stringify(phases[tier]))
	var report:={"status":"MEASURED","adapter":RenderingServer.get_video_adapter_name(),"driver_api":RenderingServer.get_video_adapter_api_version(),"renderer":RenderingServer.get_current_rendering_method(),"viewport":str(root.size),"vsync":"disabled","phases":phases,"scope":"One earned lab/Pact72 idle view;240 actual process wall intervals per tier after120warm frames. Separate screenshots;not GPU duration,resident VRAM,moving combat,wholechapter or device-family acceptance."}
	var file:=FileAccess.open(folder+"profile.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"));file.close()
	quit(0)

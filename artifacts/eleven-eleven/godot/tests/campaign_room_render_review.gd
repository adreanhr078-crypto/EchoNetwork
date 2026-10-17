extends SceneTree

## Current native room diagnosis. Validated cold fixture/spawn is explicit;
## these captures are composition/lighting evidence, never input completion.
const Campaign = preload("res://scripts/systems/native_campaign_checkpoint.gd")
const Journey = preload("res://scripts/systems/native_journey_checkpoint.gd")
const Saves = preload("res://scripts/systems/save_manager.gd")
var main: Node3D
var base := "user://campaign_render_%d" % OS.get_process_id()
var folder: String

func _initialize() -> void: _run.call_deferred()

func _frames(count: int) -> void:
	for frame in count:
		if paused: main.native_pause_menu.resume_button.pressed.emit()
		await process_frame
		await physics_frame

func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder+label+".png")

func _run() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("Room render diagnosis requires an actual display")
		quit(1)
		return
	root.unfocusable = true
	root.size = Vector2i(1280,720)
	var args := OS.get_cmdline_user_args()
	var id := args[0] if not args.is_empty() else "specimen"
	var ids := ["specimen","archive","reactor","decon","mirror","lab"]
	var index := ids.find(id)
	if index<0:
		push_error("Unknown scoped room")
		quit(1)
		return
	var label := args[1] if args.size()>1 and args[1].is_valid_identifier() else "diagnosis"
	folder = ProjectSettings.globalize_path("res://../audits/evidence/argon-production-20261014/room-"+id+"-"+label+"/")
	DirAccess.make_dir_recursive_absolute(folder)
	Saves.save_opening_checkpoint({"schema":Saves.OPENING_SCHEMA,"milestones":{"wake":true,"clock":true,"photo":true,"memory":true,"terminal":true,"conduit":true,"ending":true},"terminal":{"frequency":111.0,"phase":45.0,"harmonic":7.0}},base+"_opening.json")
	var maintenance := FileAccess.open(base+"_maintenance.json",FileAccess.WRITE)
	maintenance.store_string(JSON.stringify({"schema":"echo-maintenance-preview-v1","stage":7}))
	maintenance.close()
	Journey.save_checkpoint({"schema":Journey.SCHEMA,"completed":Journey.EVENTS,"security":{"gate_open":true,"scanner_trace":true,"service_trace":false}},base+"_route.json")
	var campaign := Campaign.initial()
	for prior in index:
		campaign.flags[ids[prior]] = {}
		for flag in Campaign.FLAGS[ids[prior]]: campaign.flags[ids[prior]][flag] = true
		campaign = Campaign.advance(campaign,ids[prior])
	Campaign.save_checkpoint(campaign,base+"_campaign.json")
	main = load("res://scenes/native_journey.tscn").instantiate()
	main.native_checkpoint_path = base+"_opening.json"
	main.native_preferences_path = base+"_preferences.cfg"
	main.get_node("SystemJourneyPreview").checkpoint_path = base+"_maintenance.json"
	main.get_node("NativeJourneyController").checkpoint_path = base+"_route.json"
	main.get_node("NativeCampaignController").checkpoint_path = base+"_campaign.json"
	root.add_child(main)
	await _frames(30)
	main.set_audio_muted(true)
	main.set_reduced_motion(not args.has("--standard"))
	var director = main.get_node("NativeCampaignController")
	var room: Node3D = director.rooms[index]
	var poses := [Vector3(-4,0.1,3),Vector3(-4,0.1,3),Vector3(0,-3.9,-5.5),Vector3(-5,0.1,-4),Vector3(7.2,0.1,-4),Vector3(0,0.1,-9)]
	if id=="decon" and args.has("--arches"): poses[index] = Vector3(0,0.1,-1.8)
	main.player.global_position = room.to_global(poses[index])
	main.player.velocity = Vector3.ZERO
	main.player.set_gameplay_orbit(Vector3(0.1,PI/2 if index<2 else 0,0))
	await _frames(40)
	await _capture("01-current-player-view")
	var lights := {}
	var fixtures = room.get_node_or_null("ServiceLighting")
	if fixtures:
		for light in fixtures.find_children("*","OmniLight3D",false,false):
			lights[light] = light.shadow_enabled
			light.shadow_enabled = false
	await _frames(30)
	await _capture("02-fixture-shadows-off")
	for light in lights: light.shadow_enabled = lights[light]
	await _frames(30)
	await _capture("03-restored")
	if args.has("--record") and id=="specimen":
		if not await _walk_local(room,Vector3(-8,0,3)): return
		if not await _walk_local(room,Vector3(-8,0,1.9)): return
		var station = room.get_node("Tank_ex_005/SpecimenRecordStation/InteractionArea")
		if main.player.get_nearest_interactable()!=station:
			push_error("Optional specimen record was not physically reachable")
			quit(1)
			return
		main.player.interact_with_nearest()
		await _frames(4)
		if not room.discoveries.has("ex_005") or room.terminal_read or room.gate_open or main.player.control_locked:
			push_error("Optional record changed mandatory progress or blocked player control")
			quit(1)
			return
		await _capture("04-actual-optional-record")
		print("PASS actual public optional specimen record; mandatory gate/terminal and movement unchanged")
	if args.has("--ex011") and id=="specimen":
		for point in [Vector3(-8,0,3),Vector3(-26,0,3),Vector3(-26,0,-10.4),Vector3(-27,0,-12.5)]:
			if not await _walk_local(room,point): return
		main.player.set_gameplay_orbit(Vector3(0.1,-PI/2,0))
		await _frames(12)
		await _capture("05-actual-ex011-terminal-view")
		if args.has("--gate"):
			if main.player.get_nearest_interactable()!=room or not main.player.interact_with_nearest().get("accepted",false):
				push_error("Actual containment terminal was not reachable: local="+str(room.to_local(main.player.global_position))+" nearest="+str(main.player.get_nearest_interactable())+" alert="+str(room._alert_timer))
				quit(1)
				return
			main.player.set_gameplay_orbit(Vector3(0.1,PI/2,0))
			await _frames(4)
			await _capture("06-actual-pneumatic-release")
			await _frames(8)
			await _capture("07-release-settling")
			if not room.gate_open or not room.terminal_read or room._air_motes.release_count!=1:
				push_error("Actual gate failed its single visual release")
				quit(1)
				return
			print("PASS actual terminal, EX011 view and idempotent pneumatic gate particles")
	if args.has("--profile"): await _profile(room)
	if args.has("--effects"):
		for frame in 48:
			await _frames(2)
			await _capture("fluid-%03d" % frame)
	var hashes := {}
	for path in ["res://scenes/native_journey.tscn","res://scenes/opening_web_room.tscn","res://scripts/systems/native_campaign_controller.gd","res://scripts/environment/room_service_lighting.gd","res://scripts/environment/"+director.FILES[index]+".gd","res://assets/characters/echo_v31_adopted_high.glb"]:
		hashes[path] = FileAccess.get_sha256(path)
	var file := FileAccess.open(folder+"diagnosis.json",FileAccess.WRITE)
	for path in ["res://tests/campaign_room_render_review.gd","res://scripts/environment/room_motes.gd","res://scripts/environment/specimen_record_station.gd","res://shaders/room_motes.gdshader","res://shaders/scanner_volumetric_cone.gdshader","res://shaders/specimen_fluid.gdshader","res://shaders/specimen_bubbles.gdshader"]:
		hashes[path] = FileAccess.get_sha256(path)
	file.store_string(JSON.stringify({"room":id,"fixture":"validated cold checkpoint and one explicit local spawn; no input or artistic acceptance","temporary_shadow_comparison_lights":lights.size(),"original_shadow_values_restored":true,"source_hashes":hashes},"\t"))
	main.queue_free()
	for frame in 4: await process_frame
	for name in ["_opening.json","_maintenance.json","_route.json","_campaign.json","_preferences.cfg"]:
		for suffix in ["",".bak",".tmp"]:
			if FileAccess.file_exists(base+name+suffix): DirAccess.remove_absolute(base+name+suffix)
	print("PASS current scoped room render diagnosis: ",id)
	quit(0)

func _walk_local(room: Node3D,point: Vector3) -> bool:
	var target := room.to_global(point)
	for frame in 900:
		if paused: main.native_pause_menu.resume_button.pressed.emit()
		var offset: Vector3 = target-main.player.global_position
		offset.y = 0
		if offset.length()<0.2:
			main.player.set_mobile_input_vector(Vector2.ZERO,false)
			await _frames(8)
			return true
		var forward: Vector3 = -main.player.player_camera.global_basis.z
		var right: Vector3 = main.player.player_camera.global_basis.x
		forward.y=0
		right.y=0
		var input := Vector2(offset.dot(right.normalized()),-offset.dot(forward.normalized())).normalized()
		main.player.set_mobile_input_vector(input*(1.0 if offset.length()>1.0 else 0.65),true)
		await physics_frame
	push_error("Optional record movement was blocked at "+str(main.player.global_position))
	quit(1)
	return false

func _profile(room: Node3D) -> void:
	var wall: Array[float] = []
	var draws: Array[float] = []
	var primitives: Array[float] = []
	var textures: Array[float] = []
	var previous := Time.get_ticks_usec()
	for frame in 240:
		if paused: main.native_pause_menu.resume_button.pressed.emit()
		await process_frame
		var now := Time.get_ticks_usec()
		wall.append(float(now-previous)/1000.0)
		previous = now
		draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		primitives.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
		textures.append(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED))
	var result := {"samples":240,"wall_frame_ms":_stats(wall),"draw_calls":_stats(draws),"primitives":_stats(primitives),"engine_texture_bytes":_stats(textures),"scope":"actual process-frame intervals in a current native room fixture; engine counters are not GPU time or resident VRAM; workstation acceptance OPEN"}
	var file := FileAccess.open(folder+"profile.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"\t"))

func _stats(values: Array[float]) -> Dictionary:
	values.sort()
	return {"p50":values[int((values.size()-1)*0.5)],"p95":values[int((values.size()-1)*0.95)],"p99":values[int((values.size()-1)*0.99)],"max":values[-1]}

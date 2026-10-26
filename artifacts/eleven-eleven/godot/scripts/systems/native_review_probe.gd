extends Node

## Opt-in review-only probe of the actual packed Boot and public player input.
## No production save, world relocation or progression helper is used.
var save_root := ""
var main: Node
var checks := 0

func _ready() -> void:
	main = get_parent()
	get_tree().root.unfocusable = true
	_run.call_deferred()

func _frames(count: int) -> void:
	for frame in count:
		if get_tree().paused: main.native_pause_menu.resume_button.pressed.emit()
		await get_tree().process_frame
		await get_tree().physics_frame

func _check(ok: bool, message: String) -> bool:
	checks += 1
	if not ok:
		push_error(message)
		get_tree().quit(1)
	return ok

func _walk(target: Vector3) -> bool:
	for frame in 900:
		if get_tree().paused: main.native_pause_menu.resume_button.pressed.emit()
		var offset: Vector3 = target-main.player.global_position
		offset.y = 0
		if offset.length()<0.2:
			main.player.set_mobile_input_vector(Vector2.ZERO,false)
			await _frames(8)
			return _check(main.player.is_on_floor(),"Packed player lost its ground support")
		var forward: Vector3 = -main.player.player_camera.global_basis.z
		var right: Vector3 = main.player.player_camera.global_basis.x
		forward.y = 0
		right.y = 0
		var input := Vector2(offset.dot(right.normalized()),-offset.dot(forward.normalized())).normalized()
		main.player.set_mobile_input_vector(input*(1.0 if offset.length()>1.0 else 0.65),true)
		await get_tree().physics_frame
	return _check(false,"Packed public movement could not reach the clue")

func _run() -> void:
	await _frames(8)
	main.set_audio_muted(true)
	main.set_reduced_motion(true)
	main.player.finish_opening_recovery()
	var dialogue = main.hud.find_child("DialogueOverlay",true,false)
	for frame in 30:
		if not dialogue.is_active: break
		dialogue.advance_dialogue()
		await _frames(1)
	if not _check(not dialogue.is_active,"Packed waking dialogue did not return controls"): return
	var clock = main.find_child("OpeningClock",true,false)
	if not await _walk(clock.global_position+Vector3(1,0,0)): return
	if not _check(main.player.get_nearest_interactable()==clock.get_node("InteractionArea"),"Packed clue proximity failed"): return
	main.player.interact_with_nearest()
	var inspector = main.opening_inspection
	if not _check(inspector.is_active and not clock.inspected and not main.player.get_node("ModelRoot").visible,"Packed preview ownership/visibility failed"): return
	await _frames(4)
	# Hidden release windows need not present a frame. Explicit functional-only
	# review skips the screenshot wait; rendered contact is a separate fixture.
	var capture_review:=DisplayServer.get_name()!="headless" and not OS.get_cmdline_user_args().has("--review-no-capture")
	print("PACKED_INSPECTION_REACHED capture=",capture_review)
	if capture_review:
		await RenderingServer.frame_post_draw
		var path := OS.get_executable_path().get_base_dir()+"/Standalone-Inspection.png"
		if not _check(get_viewport().get_texture().get_image().save_png(path)==OK,"Packed capture could not be saved"): return
	inspector.cancel_button.pressed.emit()
	if not _check(not clock.inspected and main.player.player_camera.current and main.player.get_node("ModelRoot").visible,"Packed cancellation failed to restore presentation"): return
	main.player.interact_with_nearest()
	inspector.confirm_button.pressed.emit()
	inspector.confirm_button.pressed.emit()
	if not _check(clock.inspected and inspector.confirmed_count==1 and main.player.player_camera.current,"Packed confirmation committed incorrectly"): return
	var photo = main.find_child("OpeningPhotograph",true,false)
	var trace_material: Material=photo.get_node("PhotoTrace").material_override
	var trace_texture: Texture2D
	if trace_material is StandardMaterial3D: trace_texture=trace_material.albedo_texture
	elif trace_material is ShaderMaterial: trace_texture=trace_material.get_shader_parameter("albedo_texture")
	if not _check(trace_texture!=null and clock.get_node("ClockFace/HeroClock/ClockBody").mesh!=null,"Packed hero/emulsion resources missing"): return
	if not _check(not main.player.combat_available and main.player.get_node("ModelRoot/EchoOpeningUniform").get_meta("owner_adopted_echo_v31",false),"Packed boot changed avatar or granted early combat"): return
	for asset in ["res://assets/textures/lab-memory/shizuka-pdf041.webp","res://assets/textures/lab-memory/yuki-pdf041.webp"]:
		var texture:=load(asset) as Texture2D
		if not _check(texture!=null and texture.get_width()==640,"Packed memory resource missing: "+asset): return
	if not _check(ResourceLoader.exists("res://scripts/systems/native_entry_gate.gd"),"Packed native entry client missing"): return
	for resource in ["res://assets/props/ward_bed_original_v1.glb","res://assets/textures/opening-cover.webp","res://assets/cinematics/opening-cover-poster.webp","res://assets/cinematics/opening-cover-v2.ogv","res://assets/cinematics/lab-memory-collapse-v1.ogv","res://assets/cinematics/lab-memory-water-v1.ogg","res://assets/cinematics/lab-memory-bottom-v1.webp","res://assets/props/memory_stasis_frame_clean_v1.glb"]:
		if not _check(load(resource)!=null,"Packed entry/memory resource missing: "+resource): return
	print("CONNECTED_CP24_STANDALONE_BOOT PASS actual packed Boot/public input/inspection/resource/save isolation; checks=",checks)
	for resource in ["res://assets/props/ward_visitor_chair_v1.glb","res://assets/props/ward_vanity_v1.glb"]:
		if not _check(load(resource)!=null,"Packed ward furniture derivative missing: "+resource): return
	print("CP38_PACKED_FURNITURE PASS chair/vanity resource dependencies; checks=",checks)
	var zero_color:=load("res://assets/characters/zero_manifestation_idle_v1_Color_b830dbdf-e0d3-48c1-af9a-545326ebb7e1.jpg") as Texture2D
	if not _check(zero_color!=null and zero_color.get_width()==8192,"Packed Zero lost its8K original colour resolution"): return
	if not _check(zero_color.get_image().is_compressed(),"Packed Zero colour is still uncompressed in VRAM"): return
	print("CP38_PACKED_VRAM PASS actual8K colour texture is GPU-compressed; checks=",checks)
	main.toggle_personal_system()
	await _frames(8)
	var personal=main.hud.find_child("SystemWindow",true,false)
	if not _check(personal._status_view and not personal._modal and not main.player.control_locked,"Packed personal status seized gameplay controls"):return
	if not _check(not personal._status_snapshot.pact_confirmed and personal.stats_box.get_child(0).text.contains(str(roundi(main.player.hp))),"Packed personal status invented power or lost actual HP"):return
	if not await _walk(main.player.global_position+Vector3(.55,0,0)):return
	if not _check(personal.visible and personal.panel.mouse_filter==Control.MOUSE_FILTER_IGNORE,"Packed moving personal status captured pointer input"):return
	main.toggle_personal_system()
	print("CP39_PACKED_PERSONAL_SYSTEM PASS actual status, pre-pact authority, passive movement and pointer; checks=",checks)
	if not _check(main.player.animation_player.has_animation("PARKOUR_HANG"),"Packed current V31 lost the qualified wall-support library"):return
	var hang:Animation=main.player.animation_player.get_animation("PARKOUR_HANG")
	if not _check(absf(hang.length-28.0/30)<0.0001 and hang.loop_mode==Animation.LOOP_NONE and hang.has_meta("wall_support_pose_seconds") and is_zero_approx(float(hang.get_meta("wall_support_pose_seconds"))),"Packed wall-support pose lost original timing or semantic guard"):return
	print("CP40_PACKED_BRACED_SUPPORT PASS actual current V31 library, original duration and wall-support guard; checks=",checks)
	if not _check(get_node("/root/HyperAnimeWorldManager").main==main and get_node("/root/KineticVFXOrchestrator").player==main.player,"Packed Hyper modules were not wired into actual main/player"):return
	if not _check(main.player.action_camera_rig!=null and main.player.action_camera_rig.external and is_equal_approx(main.player.base_fov,70.0),"Packed DynamicActionCameraRig missing or bypassed original camera collision ownership"):return
	print("CP41_PACKED_HYPER PASS autoloads, globals, actual player/camera and shader resources; checks=",checks)
	var atmosphere=main.get_node_or_null("MemoryAtmosphereDirector")
	if not _check(atmosphere!=null and atmosphere.rooms.has("opening"),"Packed moving memory integration missing"):return
	for resource in ["city-high.ogv","friends-high.ogv","reel-low.ogv","city.ogg","friends.ogg","reel.ogg","pipe-drip.ogg","city-poster.webp","friends-poster.webp"]:
		if not _check(load("res://assets/cinematics/memory-screens/"+resource)!=null,"Packed moving memory media missing: "+resource):return
	main.set_reduced_motion(false)
	await _frames(30)
	if not _check(atmosphere.sources.city.video.stream_position>0.05 and atmosphere.decoder_count()==1,"Packed shared moving memory failed to decode"):return
	var intact:MeshInstance3D=atmosphere.rooms.opening.screens[0].get_meta("surface")
	if not _check(intact.mesh is QuadMesh and atmosphere.rooms.opening.screens[0].get_child_count()==1,"Packed memory lost its intact frameless presentation"):return
	main.set_reduced_motion(true)
	await _frames(2)
	if not _check(atmosphere.sources.city.video.paused and not atmosphere.screen_audio.playing,"Packed memory ignored Reduced Motion/mute"):return
	print("CP42_PACKED_MEMORY PASS intact moving panes, shared decoding, media, Reduced Motion/mute; checks=",checks)
	var cape=main.player.get_node("ModelRoot/EchoOpeningUniform").find_child("EchoCapeMotion",true,false)
	if not _check(cape!=null and cape.configured and cape._chains.size()==5,"Packed V31 garment driver missing"):return
	var native_cover=load("res://scripts/ui/cover_recovery.gd")
	if not _check(native_cover.PIECE_COUNT==6 and native_cover.COLUMNS==2 and native_cover.ROWS==3,"Packed cover is not the Owner's six-piece opening"):return
	print("CP44_PACKED_CAPE_COVER PASS independent garment chains and six-piece entry; checks=",checks)
	for name in ["opening.json","preferences.cfg","maintenance.json","route.json","campaign.json"]:
		for suffix in ["",".bak",".tmp"]:
			if FileAccess.file_exists(save_root+name+suffix): DirAccess.remove_absolute(save_root+name+suffix)
	get_tree().quit(0)

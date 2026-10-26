extends SceneTree
func _initialize() -> void: _run.call_deferred()
func _check(ok: bool, label: String) -> bool:
	if not ok:
		push_error(label)
		quit(1)
	return ok
func _run() -> void:
	print("V31_REVIEW begin")
	var world := Node3D.new()
	root.add_child(world)
	var floor := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(8,0.2,8)
	collision.shape = box
	floor.position.y = -0.1
	floor.add_child(collision)
	world.add_child(floor)
	var player = load("res://scenes/player/echo_player.tscn").instantiate()
	print("V31_REVIEW instantiated")
	world.add_child(player)
	print("V31_REVIEW added")
	player.finish_opening_recovery()
	for unused in 20: await physics_frame
	print("V31_REVIEW physics advanced")
	if not _check(player.rig_profile.get("id") == "echo_v31_authored_68", "Actual default player must use adopted V31's 68-bone rig"): return
	var model = player.get_node("ModelRoot/EchoOpeningUniform")
	if not _check(model.get_meta("owner_adopted_echo_v31",false) and model.find_child("EchoV31BodyAndCoat",true,false) != null, "Actual default model must be V31, not a retained legacy visual"): return
	var identifier = player.get_node("ModelRoot")
	if not _check(not identifier.placement_report.is_empty() and identifier.placement_report.get("native_skin",false), "Adopted V31 must retain EX-011 as actual instance-local neck ink"): return
	if not _check(identifier.placement_report.get("collar_occlusion_checked",false) and identifier.placement_report.get("ink_pixels",0)>0, "V31 ink must fit complete lettering on visible skin after testing actual collar occlusion"): return
	var ap: AnimationPlayer = player.animation_player
	var cape: Node = model.find_child("EchoCapeMotion",true,false)
	if model.get_meta("short_jacket_variant",false):
		if not _check(cape==null,"Approved short jacket must not retain the long-skirt solver"):return
	elif not _check(cape != null and cape.configured and cape._chains.size()==5, "Long-coat V31 must use its five independent garment chains"): return
	# Isolate library playback from the live controller's valid idle selection.
	player.set_physics_process(false)
	for clip in ["IDLE","RUN","preset_jump"]:
		if not _check(ap.has_animation(clip), "Reviewed V31 motion missing: " + clip): return
		player.play_anim(clip,0)
		for unused in 4: await process_frame
		if not _check(ap.current_animation == clip, "V31 runtime motion alias did not actually play: " + clip): return
	player.set_physics_process(true)
	if not _check(player._hand_weapon_socket != null and player._hand_weapon_socket.bone_name == "RightHand" and player._hip_weapon_socket.bone_name == "Hips", "Built weapon sockets must follow V31's actual hand and pelvis"): return
	if not _check(not player.find_child("KatanaBlade",true,false).visible and not player.find_child("ShadowKatana",true,false).visible and not player._built_weapon_visuals_applied, "Protected opening must not show or allocate built blades before the existing unlock"): return
	player.set_combat_available(true) # Asset fixture; not an authored story decision.
	player.unsheath_weapon()
	await process_frame
	var standard = player.find_child("KatanaBlade",true,false)
	var shadow = player.find_child("ShadowKatana",true,false)
	if not _check(standard.has_node("TripoVisual") and shadow.get_node("BladeRoot").has_node("TripoVisual") and player._hip_weapon_mesh.has_node("TripoVisual"), "Built blade/scabbard models must be connected to actual player sockets"): return
	if not _check(standard.visible and not shadow.visible and not standard.get_node("Blade").visible, "Native built standard blade must replace only the prototype geometry"): return
	if not _check(standard.global_basis.get_scale().is_equal_approx(Vector3.ONE), "Built sword must retain measured metre scale beneath the scaled avatar"): return
	player.equip_shadow_katana()
	if not _check(shadow.visible and not standard.visible, "Existing equip action must show the built shadow blade"): return
	player.set_combat_available(false)
	if not _check(not standard.visible and not shadow.visible and not player._hip_weapon_mesh.visible, "Revoking combat must hide all built weapon visuals"): return
	world.queue_free()
	await process_frame
	print("PASS actual default adopted Echo V31, 68-bone identity, original CP17 motion playback, measured hand/pelvis sockets, built standard/shadow/scabbard assets, preserved unlock and revoke. Face/cape/Walk/attack art and device acceptance remain open.")
	quit(0)

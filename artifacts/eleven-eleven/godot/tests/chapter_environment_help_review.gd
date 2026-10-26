extends SceneTree

var checks := 0
var failures := 0
var main: Node
var folder := "res://../audits/evidence/chapter-cp45-20261020/stage02/"

func _initialize() -> void: _run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", label)
func frames(count: int) -> void:
	for i in count: await process_frame
func _run() -> void:
	root.unfocusable = true
	root.size = Vector2i(1280,720)
	folder = ProjectSettings.globalize_path(folder)
	DirAccess.make_dir_recursive_absolute(folder)
	main = load("res://scenes/native_journey.tscn").instantiate()
	var base := "user://chapter_help_%d/" % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(base)
	main.native_checkpoint_path = base + "opening.json"
	main.native_preferences_path = base + "prefs.cfg"
	main.get_node("SystemJourneyPreview").checkpoint_path = base + "maintenance.json"
	main.get_node("NativeJourneyController").checkpoint_path = base + "route.json"
	main.get_node("NativeCampaignController").checkpoint_path = base + "campaign.json"
	root.add_child(main)
	await frames(8)
	var pod = main.companion
	var touch = main.hud.find_child("MobileTouchControls",true,false)
	check(not pod.visible and not pod.is_processing(), "Chapter disables follower body and processing")
	check(not pod.searchlight.is_visible_in_tree(), "No follower spotlight")
	check(pod.follow_target == null and pod.aim_target == null, "No follower or aiming dependency")
	check(touch.scan_tapped.is_connected(main.show_environment_help) and not touch.scan_tapped.is_connected(pod.trigger_scan), "Touch dispatches help instead of tactical scan")
	var pulses := [0]
	pod.pulse_emitted.connect(func(): pulses[0] += 1)
	pod.trigger_scan()
	check(pod.scan_cooldown == 0 and pulses[0] == 0 and pod.aim_target == null, "Direct legacy scan cannot target, pulse or emit a cooldown")
	main.player.finish_opening_recovery()
	await frames(3)
	var dialogue = main.hud.find_child("DialogueOverlay",true,false)
	while dialogue.is_active: dialogue.advance_dialogue()
	await frames(3)
	for language in ["ar","en"]:
		main.set_presentation_language(language)
		check(touch.get_node("ActionCluster/ScanBtn/ActionCaption").text == ("مساعدة" if language == "ar" else "HELP"), "Live help label " + language)
		main.show_environment_help()
		check(not main.player.combat_available and not main.player.contract_with_zero_sealed, "Help grants no power " + language)
	var save: Dictionary = main.capture_native_checkpoint()
	check(main.save_native_checkpoint_now(), "Save without a companion dependency")
	check(main.restore_native_checkpoint(save), "Load without recreating the follower")
	check(not pod.visible and not pod.searchlight.visible and pod.follow_target == null, "Restore retains disabled companion")
	main.set_reduced_motion(true)
	check(not pod.visible and not main.player.combat_available, "Reduced Motion preserves chapter policy")
	paused = true
	pod.trigger_scan()
	check(pod.scan_cooldown == 0, "Paused direct scan remains disabled")
	paused = false
	main.set_reduced_motion(false)
	check(main.player.player_camera.current and not main.player.control_locked, "Restore returns gameplay camera and control")
	# Reversal is explicit and local; no source asset or save format is removed.
	pod.set_chapter_enabled(true)
	check(pod.visible and pod.is_processing() and pod.searchlight.visible, "Legacy mission can explicitly restore the companion")
	pod.set_chapter_enabled(false)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(folder + "no-follower.png")
	var report := {"status":"PASS" if failures == 0 else "FAIL", "checks":checks, "failures":failures, "renderer":DisplayServer.get_name(), "sources":{}}
	for path in ["res://scripts/main.gd","res://scripts/companion/floating_pod.gd","res://scripts/ui/mobile_touch_controls.gd","res://scripts/systems/native_campaign_controller.gd"]:
		report.sources[path] = FileAccess.get_sha256(path)
	var file := FileAccess.open(folder + "report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t")); file.close()
	print("ENVIRONMENT_HELP_REVIEW ", JSON.stringify(report))
	main.queue_free()
	await frames(2)
	quit(1 if failures else 0)

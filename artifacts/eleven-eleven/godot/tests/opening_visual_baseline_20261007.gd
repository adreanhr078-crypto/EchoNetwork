extends SceneTree

## Independent render-only capture. Runtime files remain untouched.
const OUTPUT := "res://../audits/evidence/"
var frame_metrics: Dictionary = {}

func _renderer_method() -> String:
	if RenderingServer.has_method("get_current_rendering_method"):
		return str(RenderingServer.call("get_current_rendering_method"))
	return "UNAVAILABLE_API"

func _init() -> void:
	call_deferred("_run")

func _shot(folder: String, name: String) -> void:
	for i in range(5): await process_frame
	await RenderingServer.frame_post_draw
	var path := folder + name + ".png"
	root.get_texture().get_image().save_png(path)
	frame_metrics[name] = {
		"visible_draw_calls": RenderingServer.viewport_get_render_info(root.get_viewport_rid(), RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME),
		"visible_primitives": RenderingServer.viewport_get_render_info(root.get_viewport_rid(), RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME),
		"visible_objects": RenderingServer.viewport_get_render_info(root.get_viewport_rid(), RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_OBJECTS_IN_FRAME),
		"total_draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"total_primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
	}
	print("CAPTURE ", path)

func _run() -> void:
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	var capture_tag := "opening_visual_baseline_20261007"
	var args := OS.get_cmdline_user_args()
	if not args.is_empty(): capture_tag = args[0].validate_filename()
	var folder := ProjectSettings.globalize_path(OUTPUT + capture_tag + "/")
	DirAccess.make_dir_recursive_absolute(folder)
	if args.has("renderer-only"):
		await process_frame
		await RenderingServer.frame_post_draw
		var method_file := FileAccess.open(folder + "renderer-method.json", FileAccess.WRITE)
		var renderer_report := {"rendering_method": _renderer_method(), "adapter": RenderingServer.get_video_adapter_name(), "viewport": str(root.size), "arguments": Array(OS.get_cmdline_args()), "scope": "One fresh native frame with identical render flags; no room recapture"}
		method_file.store_string(JSON.stringify(renderer_report, "\t"))
		method_file.close()
		print("RENDERER_METHOD ", JSON.stringify(renderer_report))
		quit(0)
		return
	var main = load("res://scenes/opening_native_room.tscn").instantiate()
	main.native_checkpoint_path = "user://opening_visual_baseline_20261007.json"
	main.native_preferences_path = "user://opening_visual_baseline_20261007.cfg"
	root.add_child(main)
	await process_frame
	main.set_audio_muted(true)
	var reduced_capture := args.size() < 2 or args[1] != "standard-motion"
	var representative := args.has("representative")
	main.set_reduced_motion(reduced_capture)
	var player: EchoPlayer = main.player
	player.finish_opening_recovery()
	main.native_pause_menu.set_session_paused(false)
	main.native_pause_menu.queue_free()
	main.native_pause_menu = null
	if main.hud: main.hud.visible = false
	for i in range(20): await physics_frame
	player.animation_player.stop()
	player.play_anim("IDLE", 0.0)
	player.animation_player.seek(0.0, true)
	player.animation_player.advance(0.0)
	player.animation_player.pause()
	player.set_physics_process(false)
	if not representative: await _shot(folder, "gameplay-back")
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.current = true
	var views := {
		"wide-from-door": [Vector3(0, 2.0, -14.5), Vector3(0, 2.0, 1.8), 63.0],
		"wide-from-rear": [Vector3(-4.4, 2.7, 5.8), Vector3(1.0, 2.0, -9.0), 69.0],
		"wide-from-left": [Vector3(-6.6, 1.85, -5.0), Vector3(3.0, 1.7, -4.0), 69.0],
		"clock-and-capsule": [Vector3(-4.0, 1.7, -0.6), Vector3(-1.8, 1.3, 2.0), 49.0],
		"observation-detail": [Vector3(4.7, 2.2, -3.0), Vector3(8.5, 2.9, -5.0), 60.0],
	}
	var report := {"views": {}, "adapter": RenderingServer.get_video_adapter_name(), "rendering_method": _renderer_method(), "lights": [], "mesh_count": main.find_children("*", "MeshInstance3D", true, false).size(), "player_position": str(player.global_position), "reduced_motion": reduced_capture}
	for name in views:
		if representative and name not in ["wide-from-door", "wide-from-rear", "observation-detail"]: continue
		var spec: Array = views[name]
		camera.fov = spec[2]
		camera.global_position = spec[0]
		camera.look_at(spec[1], Vector3.UP)
		report.views[name] = {"position": str(spec[0]), "target": str(spec[1]), "fov": spec[2]}
		await _shot(folder, name)
	report["frame_metrics"] = frame_metrics
	for light in main.find_children("*", "Light3D", true, false):
		report.lights.append({"path": str(main.get_path_to(light)), "energy": light.light_energy, "color": light.light_color.to_html(false), "shadow": light.shadow_enabled})
	var env: Environment = main.get_node("WorldEnvironment").environment
	report["environment"] = {"ambient_energy": env.ambient_light_energy, "ambient_color": env.ambient_light_color.to_html(false), "tonemap_exposure": env.tonemap_exposure, "ssr": env.ssr_enabled, "fog": env.fog_enabled, "glow": env.glow_enabled}
	var atmosphere: Node = main.get_node_or_null("OpeningAtmosphere")
	if atmosphere and atmosphere.has_method("diagnostics"):
		report["atmosphere"] = atmosphere.diagnostics()
	var file := FileAccess.open(folder + "baseline.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	main.queue_free()
	camera.queue_free()
	await process_frame
	for path in ["user://opening_visual_baseline_20261007.json", "user://opening_visual_baseline_20261007.cfg"]:
		for suffix in ["", ".bak", ".tmp"]:
			if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(path + suffix)
	quit(0)

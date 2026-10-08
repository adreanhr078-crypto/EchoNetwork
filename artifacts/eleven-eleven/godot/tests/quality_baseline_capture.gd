extends SceneTree

## Read-only baseline capture for the 2026-10-06 quality plan.
## 1) Echo turnaround under neutral light (front / side / three-quarter / back).
## 2) Same turnaround and wide/medium shots inside the real opening room.
## No avatar, rig, animation or scene edits are made; everything is captured from the live scenes.
const OUTPUT := "res://../audits/evidence/quality-baseline-20261006/"

func _init() -> void:
	call_deferred("_run")

func _shot(path: String) -> void:
	for i in range(4): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
	print("CAPTURE ", path)

func _aim(camera: Camera3D, target: Vector3, offset: Vector3, fov: float) -> void:
	camera.fov = fov
	camera.global_position = target + offset
	camera.look_at(target, Vector3.UP)

func _run() -> void:
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	var folder := ProjectSettings.globalize_path(OUTPUT)
	DirAccess.make_dir_recursive_absolute(folder)
	var main = load("res://scenes/opening_native_room.tscn").instantiate()
	main.native_checkpoint_path = "user://quality_baseline.json"
	main.native_preferences_path = "user://quality_baseline.cfg"
	root.add_child(main)
	await process_frame
	main.set_audio_muted(true)
	main.set_reduced_motion(true)
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
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.current = true
	var focus := player.global_position + Vector3(0, 1.0, 0)
	var forward: Vector3 = player.visual_root.global_basis.x
	forward.y = 0.0
	forward = forward.normalized()
	var left := Vector3.UP.cross(forward).normalized()
	print("MODEL_FORWARD ", forward)
	var views := {
		"front": forward * 2.6 + Vector3(0, 0.25, 0),
		"side_left": left * 2.6 + Vector3(0, 0.25, 0),
		"three_quarter": (forward + left).normalized() * 2.6 + Vector3(0, 0.35, 0),
		"back": -forward * 2.6 + Vector3(0, 0.25, 0),
		"face_close": forward * 0.85 + left * 0.15 + Vector3(0, 0.45, 0),
	}
	for name in views:
		var f := focus if name != "face_close" else player.global_position + Vector3(0, 1.5, 0)
		_aim(camera, f, views[name], 38.0 if name != "face_close" else 26.0)
		await _shot(folder + "room-%s.png" % name)
	var wide := {
		"wide_from_door": [Vector3(0, 1.6, -7.0), Vector3(0, 1.7, 3.0), 62.0],
		"wide_from_back": [Vector3(0, 2.1, 9.5), Vector3(0, 1.3, 0.0), 62.0],
		"wide_from_left": [Vector3(-7.0, 1.8, 0.0), Vector3(0, 1.3, 0.0), 62.0],
	}
	for name in wide:
		var spec: Array = wide[name]
		camera.fov = spec[2]
		camera.global_position = spec[0]
		camera.look_at(spec[1], Vector3.UP)
		await _shot(folder + "room-%s.png" % name)
	var report := {
		"player_position": [player.global_position.x, player.global_position.y, player.global_position.z],
		"renderer": ProjectSettings.get_setting("rendering/renderer/rendering_method"),
		"adapter": RenderingServer.get_video_adapter_name(),
		"lights": [],
	}
	for light in main.find_children("*", "Light3D", true, false):
		report.lights.append({"name": str(light.name), "class": light.get_class(), "energy": light.light_energy, "color": light.light_color.to_html(false), "shadow": light.shadow_enabled})
	var env: Environment = main.get_node("WorldEnvironment").environment
	report["environment"] = {"ambient_energy": env.ambient_light_energy, "ambient_color": env.ambient_light_color.to_html(false), "tonemap_exposure": env.tonemap_exposure, "glow": env.glow_enabled, "background": env.background_mode}
	report["mesh_count"] = main.find_children("*", "MeshInstance3D", true, false).size()
	var file := FileAccess.open(folder + "baseline.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	main.queue_free()
	await process_frame
	for path in ["user://quality_baseline.json", "user://quality_baseline.json.bak", "user://quality_baseline.cfg"]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	quit(0)

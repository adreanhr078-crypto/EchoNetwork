extends SceneTree

# Runtime discovery, not a claim that new features improve visual quality/FPS.
func _init() -> void:
	var report := {
		"engine": Engine.get_version_info(),
		"renderer": RenderingServer.get_current_rendering_method(),
		"classes": {}, "streaming_settings": {},
		"texture_streaming_singleton": Engine.has_singleton("TextureStreaming"),
	}
	for candidate in ["Trail3D", "AnimationNodeObservers", "BoneSpreader3D", "TextureStreaming"]:
		report.classes[candidate] = ClassDB.class_exists(candidate)
	for key in ["rendering/textures/streaming/enabled", "rendering/textures/streaming/memory_budget_mb", "rendering/textures/streaming/min_lod", "rendering/textures/streaming/max_lod"]:
		report.streaming_settings[key] = ProjectSettings.get_setting(key, null)
	print("GODOT_FEATURE_PROBE ", JSON.stringify(report))
	var output := "res://../audits/evidence/godot-48-migration-20261008/features-probe.json"
	var f := FileAccess.open(output, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(report, "\t"))
		f.close()
	var v := Engine.get_version_info()
	if v.major == 4 and v.minor == 8:
		print("PASS official Godot4.8 runtime probe; renderer/art/device gates remain separate")
		quit(0)
	else:
		push_error("Expected Godot4.8 for migration probe")
		quit(1)

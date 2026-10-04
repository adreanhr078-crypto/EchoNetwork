extends SceneTree

const Capture = preload("res://scripts/diagnostics/player_frame_capture.gd")
const STEM := "frame-capture-smoke"
var failures := 0
var created_stems: Array[String] = [STEM, STEM + "-actual"]

func _init() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _run() -> void:
	var stats := Capture.summarize(PackedInt64Array([10000, 20000, 50000, 120000]))
	_check(stats.count == 4 and stats.mean_ms == 50.0 and stats.p95_ms == 120.0 and stats.p99_ms == 120.0, "raw interval percentiles/mean incorrect")
	_check(stats.intervals_over_33_333_ms == 2 and stats.intervals_over_50_ms == 1 and stats.intervals_over_100_ms == 1, "hitch counts incorrect")
	_check(Capture.summarize(PackedInt64Array()).count == 0, "empty capture must not invent statistics")
	var capture := Capture.new()
	root.add_child(capture)
	capture.output_stem = STEM
	capture.duration_us = 20000
	capture.warmup_us = 15000
	_check(capture.start_capture(), "synthetic capture could not start")
	capture.set_process(false)
	capture.record_tick(1000000, false)
	capture.record_tick(1010000, false)
	capture.record_tick(1020000, false) # warmup boundary interval excluded
	capture.record_tick(1025000, false)
	capture.record_tick(1026000, true)
	capture.record_tick(9026000, false) # eight-second resume gap is excluded
	capture.record_tick(9036000, false)
	capture.record_tick(9046000, false)
	var report: Dictionary = capture.last_report
	_check(not capture.running and report.duration_complete and report.stop_reason == "duration_reached", "duration stop incorrect")
	_check(report.statistics.count == 3 and report.statistics.max_ms == 10.0 and report.excluded_callbacks == 1, "warmup/pause/resume exclusion incorrect")
	var raw := FileAccess.get_file_as_string(Capture.OUTPUT_DIR.path_join(STEM + ".csv"))
	_check(raw.split("\n", false).size() == 6 and not "8000000" in raw, "raw CSV lost samples or recorded resume gap")
	var persisted = JSON.parse_string(FileAccess.get_file_as_string(Capture.OUTPUT_DIR.path_join(STEM + ".json")))
	_check(persisted is Dictionary and persisted.statistics.count == 3, "summary not persisted")
	capture.output_stem = "../invalid"
	_check(not capture.start_capture(), "output traversal accepted")
	capture.output_stem = STEM
	capture.duration_us = Capture.DURATION_US + 1
	_check(not capture.start_capture(), "unbounded duration accepted")
	capture.queue_free()
	await process_frame
	# Exercise the actual native opening. Test saves/preferences remain isolated.
	var main = load("res://scenes/opening_native_room.tscn").instantiate()
	main.native_checkpoint_path = "user://frame_capture_smoke_save.json"
	main.native_preferences_path = "user://frame_capture_smoke_prefs.cfg"
	root.add_child(main)
	await process_frame
	var actual = main.get_node_or_null("PlayerFrameCapture")
	_check((actual != null) == Capture.requested(), "main opt-in guard incorrect")
	if actual:
		# Finish the initial startup file before starting our short test file.
		created_stems.append(actual.output_stem)
		actual.finish_capture("startup_smoke")
		actual.output_stem = STEM + "-actual"
		_check(actual.start_capture(), "actual-scene capture failed")
		await create_timer(0.08).timeout
		var before: int = actual.sample_count
		paused = true
		await create_timer(0.06, true).timeout
		_check(actual.sample_count == before, "paused opening contaminated samples")
		paused = false
		await create_timer(0.08).timeout
		actual.finish_capture("actual_scene_smoke")
		_check(actual.last_report.statistics.count == 0 and actual.sample_count > before and actual.excluded_callbacks > 0, "actual scene warmup/resume capture failed")
	main.queue_free()
	await process_frame
	for name in created_stems:
		for suffix in [".json", ".csv"]:
			DirAccess.remove_absolute(Capture.OUTPUT_DIR.path_join(name + suffix))
	for path in ["user://frame_capture_smoke_save.json", "user://frame_capture_smoke_prefs.cfg"]:
		DirAccess.remove_absolute(path)
	if failures == 0: print("PASS frame capture: raw percentiles/hitches, warmup boundary, pause/resume gap, bounded output/duration, actual opening opt-in")
	quit(0 if failures == 0 else 1)

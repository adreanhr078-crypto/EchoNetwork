extends Node
## Opt-in debug instrumentation. Intervals between process callbacks, not GPU
## presentation latency or proof that a player completed the required route.

const FLAG := "--echo-frame-capture"
const MAX_SAMPLES := 360000
const DURATION_US := 1200000000
const WARMUP_US := 20000000
const OUTPUT_DIR := "user://diagnostics"
var output_stem := "player-frames-%d-%d" % [int(Time.get_unix_time_from_system()), Time.get_ticks_usec()]
var duration_us := DURATION_US
var warmup_us := WARMUP_US
var running := false
var background := false
var active_us := 0
var measured_us := 0
var previous_us := 0
var excluded_callbacks := 0
var sample_count := 0
var intervals := PackedInt64Array()
var pending_lines := PackedStringArray()
var raw_file: FileAccess
var last_report: Dictionary = {}

static func requested() -> bool:
	return OS.is_debug_build() and (FLAG in OS.get_cmdline_user_args() or FLAG in OS.get_cmdline_args())

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)

func start_capture() -> bool:
	if running or not OS.is_debug_build(): return false
	if duration_us <= 0 or duration_us > DURATION_US or warmup_us < 0 or warmup_us > WARMUP_US: return false
	if output_stem.is_empty() or output_stem.get_file() != output_stem or ":" in output_stem or ".." in output_stem: return false
	if DirAccess.make_dir_recursive_absolute(OUTPUT_DIR) != OK: return false
	raw_file = FileAccess.open(OUTPUT_DIR.path_join(output_stem + ".csv"), FileAccess.WRITE)
	if raw_file == null: return false
	raw_file.store_string("active_elapsed_us,process_interval_us,warmup\n")
	active_us = 0
	measured_us = 0
	previous_us = 0
	excluded_callbacks = 0
	sample_count = 0
	intervals.clear()
	pending_lines.clear()
	last_report.clear()
	running = true
	set_process(true)
	return true

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		background = true
		previous_us = 0
	elif what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		background = false
		previous_us = 0

func _process(_delta: float) -> void:
	record_tick(Time.get_ticks_usec(), background or get_tree().paused)

func record_tick(now_us: int, excluded: bool) -> void:
	if not running: return
	if excluded:
		excluded_callbacks += 1
		previous_us = 0
		return
	if previous_us == 0:
		previous_us = now_us
		return
	var interval_us := now_us - previous_us
	previous_us = now_us
	if interval_us <= 0: return
	active_us += interval_us
	sample_count += 1
	# Exclude an interval straddling the warmup boundary in its entirety.
	var is_warmup := active_us - interval_us < warmup_us
	if not is_warmup:
		intervals.append(interval_us)
		measured_us += interval_us
	pending_lines.append("%d,%d,%d" % [active_us, interval_us, 1 if is_warmup else 0])
	if pending_lines.size() >= 512: _flush_batch()
	if measured_us >= duration_us:
		finish_capture("duration_reached")
	elif sample_count >= MAX_SAMPLES:
		finish_capture("sample_limit")

func _flush_batch() -> void:
	if raw_file == null or pending_lines.is_empty(): return
	raw_file.store_string("\n".join(pending_lines) + "\n")
	pending_lines.clear()

static func summarize(samples: PackedInt64Array) -> Dictionary:
	if samples.is_empty(): return {"count": 0}
	var sorted := samples.duplicate()
	sorted.sort()
	var total := 0
	var over_33 := 0
	var over_50 := 0
	var over_100 := 0
	for interval in samples:
		total += interval
		if interval > 33333: over_33 += 1
		if interval > 50000: over_50 += 1
		if interval > 100000: over_100 += 1
	return {"count": samples.size(), "mean_ms": float(total) / samples.size() / 1000.0,
		"p95_ms": sorted[maxi(0, ceili(samples.size() * 0.95) - 1)] / 1000.0,
		"p99_ms": sorted[maxi(0, ceili(samples.size() * 0.99) - 1)] / 1000.0,
		"max_ms": sorted[-1] / 1000.0, "intervals_over_33_333_ms": over_33,
		"intervals_over_50_ms": over_50, "intervals_over_100_ms": over_100}

func finish_capture(reason := "manual_stop") -> Dictionary:
	if not running: return last_report
	running = false
	set_process(false)
	_flush_batch()
	raw_file.flush()
	var raw_error := raw_file.get_error()
	raw_file.close()
	raw_file = null
	last_report = {"schema": 1, "status": "CAPTURED" if raw_error == OK else "WRITE_FAILED",
		"stop_reason": reason, "duration_complete": measured_us >= duration_us,
		"required_measured_seconds": duration_us / 1000000.0, "measured_active_seconds": measured_us / 1000000.0,
		"warmup_seconds": warmup_us / 1000000.0, "excluded_callbacks": excluded_callbacks,
		"sample_count_including_warmup": sample_count, "statistics": summarize(intervals),
		"scope": "Monotonic process callback intervals. Pause/background and resume gaps excluded. No GPU-present, input-latency, route-completion or physical-device acceptance claim.",
		"device": {"os": OS.get_name(), "model": OS.get_model_name(), "engine": Engine.get_version_info().string,
			"display_backend": DisplayServer.get_name(), "rendering_method": RenderingServer.get_current_rendering_method(),
			"rendering_driver": RenderingServer.get_current_rendering_driver_name(), "adapter": RenderingServer.get_video_adapter_name(),
			"viewport": str(get_viewport().get_visible_rect().size), "debug_build": OS.is_debug_build()},
		"raw_file": OUTPUT_DIR.path_join(output_stem + ".csv")}
	var report := FileAccess.open(OUTPUT_DIR.path_join(output_stem + ".json"), FileAccess.WRITE)
	if report != null:
		report.store_string(JSON.stringify(last_report, "\t") + "\n")
		report.close()
	else:
		last_report.status = "REPORT_WRITE_FAILED"
	return last_report

func _exit_tree() -> void:
	if running: finish_capture("scene_exit")

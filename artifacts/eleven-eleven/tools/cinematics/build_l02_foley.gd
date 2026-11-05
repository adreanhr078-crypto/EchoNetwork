extends SceneTree
## Offline SFX timing study driven by the measured closure, without story state.

const SYNTH = preload("res://scripts/audio/procedural_cinematic_audio.gd")
const SYNTH_PATH := "res://scripts/audio/procedural_cinematic_audio.gd"

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 3:
		_fail("Expected the cuff report, exact cuff GLB and output directory")
		return
	var report = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	if not report is Dictionary or report.get("status") != "PASS_BLENDER_CUFF_CONTACT" or report.get("cuff_glb_sha256") != FileAccess.get_sha256(args[1]):
		_fail("The measured report does not match the cuff asset")
		return
	var fps: int = report.get("fps", 0)
	var frames: Array = report.get("frames", [])
	if fps != 30 or frames.size() != 61:
		_fail("The reviewed L02 timing requires 61 sampled poses at 30 Hz")
		return
	var latch_frames := {}
	for side in ["LeftCuff", "RightCuff"]:
		for index in frames.size():
			var sample: Dictionary = frames[index]
			var hinge: Dictionary = sample.get(side, {})
			if sample.get("frame") != index or not hinge.has("hinge_angle_deg"):
				_fail("Incomplete measured cuff sequence")
				return
			if absf(hinge.hinge_angle_deg) < .0001:
				latch_frames[side] = index
				break
	if latch_frames.size() != 2 or latch_frames.LeftCuff >= latch_frames.RightCuff or latch_frames.RightCuff >= 60:
		_fail("Expected left and right closures in their measured order")
		return
	var onsets := [float(latch_frames.LeftCuff) / fps, float(latch_frames.RightCuff) / fps]
	var wav: AudioStreamWAV = SYNTH.create_physical_signal(2.0, onsets, 110237, .72)
	var first_sample := -1
	var peaks := [0.0, 0.0]
	var peak := 0.0
	for sample in wav.data.size() / 2:
		var amplitude := absf(float(wav.data.decode_s16(sample * 2)) / 32768.0)
		peak = maxf(peak, amplitude)
		var at := float(sample) / wav.mix_rate
		if amplitude > 0.0 and first_sample == -1:
			first_sample = sample
		for index in onsets.size():
			if at >= onsets[index] and at < onsets[index] + .09:
				peaks[index] = maxf(peaks[index], amplitude)
	var first_onset := float(first_sample) / wav.mix_rate
	if first_sample < 0 or first_onset < onsets[0] or first_onset - onsets[0] > .001 or minf(peaks[0], peaks[1]) < .02 or peak > .75:
		_fail("Latch waveform failed timing, level or headroom checks")
		return
	if DirAccess.make_dir_recursive_absolute(args[2]) != OK:
		_fail("Could not create the foley review directory")
		return
	var wave_path: String = args[2].path_join("L02-cuff-latch.wav")
	if wav.save_to_wav(wave_path) != OK:
		_fail("Could not write the latch PCM")
		return
	var output := FileAccess.open(args[2].path_join("foley.json"), FileAccess.WRITE)
	if not output:
		_fail("Could not write the foley timing evidence")
		return
	output.store_string(JSON.stringify({
		"status": "PASS_SCOPED_PCM_TIMING",
		"event": "L02",
		"audio_policy": SYNTH.AUDIO_POLICY,
		"scope": "Procedural physical latch study for editorial review. Listening and mix acceptance remain open.",
		"latch_frames_30hz": latch_frames,
		"onsets_seconds": onsets,
		"first_nonzero_seconds": first_onset,
		"window_peaks": peaks,
		"peak": peak,
		"mix_rate": wav.mix_rate,
		"wav_sha256": FileAccess.get_sha256(wave_path),
		"cuff_report_sha256": FileAccess.get_sha256(args[0]),
		"cuffs_sha256": FileAccess.get_sha256(args[1]),
		"synth_sha256": FileAccess.get_sha256(SYNTH_PATH),
		"tool_sha256": FileAccess.get_sha256(get_script().resource_path)
	}, "\t") + "\n")
	output.close()
	print("PASS L02 latch timing ", latch_frames, " / peak=", peak)
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)

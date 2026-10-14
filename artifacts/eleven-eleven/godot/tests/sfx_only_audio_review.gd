extends SceneTree

const Audio = preload("res://scripts/audio/procedural_cinematic_audio.gd")
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, label: String) -> void:
	if not condition: failures.append(label)

func inspect(label: String, stream: AudioStreamWAV) -> void:
	check(stream != null and not stream.data.is_empty(), label + ": actual PCM")
	if not stream: return
	var peak := 0
	var energy := 0.0
	var data := stream.data
	var count := data.size() / 2
	for i in count:
		var sample := data.decode_s16(i * 2)
		peak = maxi(peak, absi(sample))
		energy += float(sample) * sample
	check(peak > 100 and peak < 24000, label + ": audible headroom without clipped PCM")
	# Sustained tonal/chord notifications have periodic coherence across many
	# cycles. Physical noise cues must not recreate that old musical payload.
	var maximum_coherence := 0.0
	for lag in range(100, 650, 13):
		var cross := 0.0
		for i in range(lag, count):
			cross += float(data.decode_s16(i * 2)) * data.decode_s16((i - lag) * 2)
		maximum_coherence = maxf(maximum_coherence, absf(cross) / maxf(energy, 1.0))
	check(maximum_coherence < 0.20, label + ": no sustained periodic note/chord payload")

func _run() -> void:
	check(Audio.AUDIO_POLICY == "SFX_ONLY", "owner policy")
	var cues := {
		"air": Audio.create_abyss_drone(),
		"seal": Audio.create_covenant_chime(),
		"door": Audio.create_doorbell_chime(),
		"entry": Audio.create_konbini_chime(),
		"crystal-contact": Audio.create_shrine_crystal_bell(),
		"quest": Audio.create_quest_complete_fanfare(),
		"chest": Audio.create_chest_open_chime(3),
		"loot": Audio.create_loot_toast_chime(),
		"school": Audio.create_school_chime_bell(),
		"bond": Audio.create_bond_up_jingle(),
	}
	for label in cues: inspect(label, cues[label])
	check(cues.quest.data == Audio.create_quest_complete_fanfare().data, "repeatable cue without shared RNG mutation")
	check(Audio.create_heart_monitor_beep().data.size() > 0 and Audio.create_ecg_flatline().data.size() > 0, "functional medical alarms retained")
	print("SFX_ONLY_AUDIO_REVIEW ", JSON.stringify({"status": "PASS" if failures.is_empty() else "FAIL", "cues": cues.size(), "failures": failures, "scope": "Actual PCM, headroom and sustained-periodicity regression. Source design is non-musical; spectral checks do not decide religious permissibility or listening quality."}))
	quit(0 if failures.is_empty() else 2)

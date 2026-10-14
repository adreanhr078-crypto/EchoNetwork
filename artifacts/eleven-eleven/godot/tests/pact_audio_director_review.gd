extends SceneTree

const Director = preload("res://scripts/audio/pact_audio_director.gd")
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, label: String) -> void:
	if not condition: failures.append(label)

func _run() -> void:
	var audio := Director.new()
	root.add_child(audio)
	await process_frame
	check(audio._void.stream != Director.VOID_BED and audio._void.stream.loop, "private loop resource")
	audio.set_stage("accepted", false, false)
	check(audio.stage == "dormant" and audio.transient_count == 0, "no unsealed pact sound")
	audio.set_stage("manifested")
	audio._process(1.0)
	check(audio._void.playing and not audio._revenge.playing, "manifestation uses quiet bed")
	var normal := audio._void.volume_db
	audio.sync_preferences(false, 1.0, true)
	audio._process(1.0)
	check(audio._void.volume_db <= normal - 7.9, "decision dialogue ducking")
	audio.sync_preferences(false)
	audio.set_stage("accepted", false, true)
	check(audio.transient_count == 1, "one accepted cue")
	audio.set_stage("accepted", false, true)
	check(audio.transient_count == 1, "duplicate stage cannot replay seal")
	audio.set_stage("revenge", false, true)
	audio.contact_confirmed(1, true)
	audio.contact_confirmed(1, true)
	audio.contact_confirmed(99, true)
	audio.contact_confirmed(2, false)
	check(audio.transient_count == 2 and audio.last_contact == 1, "only confirmed distinct contact")
	audio.sync_preferences(true)
	audio.contact_confirmed(2, true)
	check(not audio._transient.playing and audio.last_contact == 2 and audio.transient_count == 2, "mute consumes cue without playback")
	audio.sync_preferences(false)
	audio.contact_confirmed(2, true)
	check(audio.transient_count == 2, "unmute does not replay contact")
	check(audio._void_db == -80.0 and audio._revenge_db == -80.0, "unmute starts envelopes from silence")
	audio._process(0.01)
	check(audio._revenge.volume_db < -70.0, "unmute fades from silence")
	audio.set_stage("stasis", true, true)
	check(audio.transient_count == 2 and not audio._transient.playing, "restore suppresses stasis transient")
	audio.sync_preferences(false, NAN)
	check(audio.volume == 0.0, "malformed preference silent")
	audio.sync_preferences(false, 2.0)
	check(audio.volume == 1.0, "volume clamp")
	audio.set_stage("revenge", false, true)
	audio._process(1.0)
	paused = true
	await create_timer(0.05, true).timeout
	check(audio._revenge.stream_paused, "tree pause pauses bed audio")
	audio.contact_confirmed(3, true)
	check(audio.transient_count == 2, "paused contact does not play")
	paused = false
	await process_frame
	audio.cancel()
	check(not audio._void.playing and not audio._revenge.playing and not audio._transient.playing, "cancel releases all players")
	audio.set_stage("stasis", false, true)
	var before_restore := audio.transient_count
	check(audio._transient.playing, "stasis cue active before restore")
	audio.sync_preferences(false, 0.5)
	check(absf(audio._transient.volume_db - (-10.0 + linear_to_db(0.5))) < 0.01, "live cue follows volume preference")
	audio.set_stage("stasis", true, true)
	check(not audio._transient.playing and audio.transient_count == before_restore, "same-stage restore cancels stale transient")
	audio.queue_free()
	await process_frame
	# Stopped playback handles retire on the audio server's next mix tick.
	await create_timer(0.12, true).timeout
	print("PACT_AUDIO_REVIEW ", JSON.stringify({"failures": failures, "status": "PASS" if failures.is_empty() else "FAIL", "scope": "Actual AudioStreamPlayers, preferences, contract gating, pause and event ownership; listening and device quality separate"}))
	quit(0 if failures.is_empty() else 2)

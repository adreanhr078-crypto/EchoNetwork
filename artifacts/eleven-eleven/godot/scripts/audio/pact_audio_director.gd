extends Node

## Presentation-only stems. Decisions, powers, contacts and progression belong
## to the existing room/controller. This node never emits a story event.
const VOID_BED = preload("res://assets/audio/pact/void_bed.ogg")
const REVENGE_BED = preload("res://assets/audio/pact/revenge_bed.ogg")
const SEAL = preload("res://assets/audio/pact/contract_seal.ogg")
const RELEASE = preload("res://assets/audio/pact/stasis_release.ogg")
const CONTACTS = [preload("res://assets/audio/pact/contact_1.ogg"),
	preload("res://assets/audio/pact/contact_2.ogg"),
	preload("res://assets/audio/pact/contact_3.ogg")]

var stage := "dormant"
var muted := false
var volume := 1.0
var decision_pending := false
var last_contact := 0
var transient_count := 0
var _void: AudioStreamPlayer
var _revenge: AudioStreamPlayer
var _transient: AudioStreamPlayer
var _void_db := -80.0
var _revenge_db := -80.0
var _cancelled := false

func _ready() -> void:
	_void = _player("VoidPressure", VOID_BED, true)
	_revenge = _player("RevengeHeartbeat", REVENGE_BED, true)
	_transient = _player("PactTransient", null, false)
	_transient.volume_db = -10.0

func _player(label: String, source: AudioStream, looped: bool) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = label
	player.volume_db = -80.0
	if source:
		# Per-instance loop state never mutates an imported/shared resource.
		player.stream = source.duplicate()
		if player.stream is AudioStreamOggVorbis:
			player.stream.loop = looped
	add_child(player)
	return player

func set_stage(value: String, restoring := false, contract_authorized := false) -> void:
	if value not in ["dormant", "manifested", "accepted", "revenge", "stasis"]:
		return
	if value in ["accepted", "revenge", "stasis"] and not contract_authorized:
		cancel()
		return
	var changed := stage != value
	stage = value
	_cancelled = false
	if restoring:
		stop_transients()
		return
	if not changed:
		return
	if value == "revenge":
		last_contact = 0
	if value == "accepted":
		_play_transient(SEAL)
	elif value == "stasis":
		_play_transient(RELEASE)
	elif value == "dormant":
		stop_transients()

func sync_preferences(is_muted: bool, input_volume := 1.0, is_deciding := false) -> void:
	muted = is_muted
	volume = clampf(input_volume, 0.0, 1.0) if is_finite(input_volume) else 0.0
	decision_pending = is_deciding
	if muted or volume <= 0.0:
		_void_db = -80.0
		_revenge_db = -80.0
		stop_transients()
		for player in [_void, _revenge]:
			if is_instance_valid(player):
				player.volume_db = -80.0
				player.stream_paused = true
	elif is_instance_valid(_transient):
		_transient.volume_db = -10.0 + linear_to_db(volume)

func contact_confirmed(number: int, contract_authorized := false) -> void:
	if stage not in ["accepted", "revenge"] or not contract_authorized or number < 1 or number > 3 or number <= last_contact:
		return
	stage = "revenge"
	# Consume the presentation event even if muted. Unmute must not replay it.
	last_contact = number
	_play_transient(CONTACTS[number - 1])

func _play_transient(stream: AudioStream) -> void:
	if muted or volume <= 0.0 or _cancelled or not is_inside_tree() or not _transient or get_tree().paused:
		return
	_transient.stream = stream
	_transient.volume_db = -10.0 + linear_to_db(volume)
	_transient.play()
	transient_count += 1

func stop_transients() -> void:
	if is_instance_valid(_transient):
		_transient.stop()

func cancel() -> void:
	_cancelled = true
	stage = "dormant"
	_void_db = -80.0
	_revenge_db = -80.0
	for player in [_void, _revenge, _transient]:
		if is_instance_valid(player):
			player.stop()
			player.volume_db = -80.0

func _process(delta: float) -> void:
	if muted or volume <= 0.0 or _cancelled:
		return
	var adjustment := linear_to_db(volume) - (8.0 if decision_pending else 0.0)
	var void_target := -19.0 + adjustment if stage in ["manifested", "accepted"] else -80.0
	var revenge_target := -18.0 + adjustment if stage == "revenge" else -80.0
	_void_db = move_toward(_void_db, void_target, delta * 65.0)
	_revenge_db = move_toward(_revenge_db, revenge_target, delta * 65.0)
	_mix_bed(_void, _void_db, void_target)
	_mix_bed(_revenge, _revenge_db, revenge_target)

func _mix_bed(player: AudioStreamPlayer, level: float, target: float) -> void:
	player.volume_db = level
	if target > -79.0:
		player.stream_paused = false
		if not player.playing:
			player.play()
	elif level <= -79.0:
		player.stop()

func _exit_tree() -> void:
	cancel()

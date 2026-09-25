class_name SpatialVoiceManager
extends Node3D

## AAA Spatial Japanese Audio & Environmental Acoustic Reverb System
## Coordinates 3D positional voice lines, anime action yells, and zone-based acoustic reverberation.

signal voice_played(voice_id: String, text_ja: String, text_en: String)
signal acoustic_zone_changed(zone: int, zone_name: String)

enum AcousticZone {
	TATAMI_ROOM,
	HOSPITAL_CORRIDOR,
	COASTAL_OUTDOOR
}

const ProceduralCinematicAudio = preload("res://scripts/audio/procedural_cinematic_audio.gd")

var current_zone: AcousticZone = AcousticZone.COASTAL_OUTDOOR
var voice_player_3d: AudioStreamPlayer3D = null

const VOICE_CATALOG: Dictionary = {
	"attack_haa": {
		"text_ja": "「はあっ！」",
		"text_en": "\"Haa!\"",
		"vocal_id": "haa",
		"category": "combat",
		"volume_db": 0.0
	},
	"attack_osoi": {
		"text_ja": "「遅い…」",
		"text_en": "\"Too slow...\"",
		"vocal_id": "osoi",
		"category": "combat",
		"volume_db": -2.0
	},
	"attack_kiero": {
		"text_ja": "「消えろ！」",
		"text_en": "\"Begone!\"",
		"vocal_id": "kiero",
		"category": "combat",
		"volume_db": 2.0
	},
	"dodge_mieta": {
		"text_ja": "「見えた…」",
		"text_en": "\"I saw through it...\"",
		"vocal_id": "mieta",
		"category": "combat",
		"volume_db": -1.5
	},
	"damage_ku": {
		"text_ja": "「くっ…」",
		"text_en": "\"Ku...!\"",
		"vocal_id": "ku",
		"category": "hurt",
		"volume_db": 1.0
	},
	"town_arrival": {
		"text_ja": "「ここが…湊霞か」",
		"text_en": "\"So this is... Minato-Kasumi.\"",
		"vocal_id": "osoi",
		"category": "narrative",
		"volume_db": -3.0
	},
	"kinga_whisper": {
		"text_ja": "「ゼロの器よ…目覚めよ」",
		"text_en": "\"Vessel of Zero... Awaken.\"",
		"vocal_id": "kiero",
		"category": "narrative",
		"volume_db": 0.5
	},
	"visceral_strike": {
		"text_ja": "「これで終わりだ！」",
		"text_en": "\"This ends now!\"",
		"vocal_id": "kiero",
		"category": "combat",
		"volume_db": 3.0
	},
	"idle_breeze": {
		"text_ja": "「潮風が…冷たくなってきた」",
		"text_en": "\"The sea breeze is growing colder...\"",
		"vocal_id": "osoi",
		"category": "idle",
		"volume_db": -2.5
	},
	"idle_sword": {
		"text_ja": "「刃に曇りはない」",
		"text_en": "\"My blade remains unclouded.\"",
		"vocal_id": "haa",
		"category": "idle",
		"volume_db": -2.0
	},
	"idle_memory": {
		"text_ja": "「雪…今どこにいるの？」",
		"text_en": "\"Yuki... where are you now?\"",
		"vocal_id": "mieta",
		"category": "idle",
		"volume_db": -2.0
	}
}

# Environmental acoustic reverb parameters
const REVERB_PRESETS: Dictionary = {
	AcousticZone.TATAMI_ROOM: {
		"name": "Tatami Living Chamber",
		"room_size": 0.22,
		"damping": 0.78,
		"decay_time": 0.35,
		"wet": 0.18,
		"dry": 0.82
	},
	AcousticZone.HOSPITAL_CORRIDOR: {
		"name": "Decompression Corridor",
		"room_size": 0.85,
		"damping": 0.18,
		"decay_time": 1.85,
		"wet": 0.42,
		"dry": 0.70
	},
	AcousticZone.COASTAL_OUTDOOR: {
		"name": "Minato-Kasumi Coastal Open Air",
		"room_size": 0.95,
		"damping": 0.50,
		"decay_time": 0.65,
		"wet": 0.12,
		"dry": 0.92
	}
}

var _cached_audio_streams: Dictionary = {}

func _ready() -> void:
	voice_player_3d = AudioStreamPlayer3D.new()
	voice_player_3d.name = "SpatialVoicePlayer3D"
	voice_player_3d.max_distance = 25.0
	voice_player_3d.unit_size = 3.5
	voice_player_3d.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	add_child(voice_player_3d)

	# Pre-cache voice stream WAVs
	for voice_key in VOICE_CATALOG.keys():
		var entry = VOICE_CATALOG[voice_key]
		_cached_audio_streams[voice_key] = ProceduralCinematicAudio.create_japanese_vocal(entry["vocal_id"])

func play_voice(voice_id: String, pos: Vector3 = Vector3.ZERO) -> Dictionary:
	if not VOICE_CATALOG.has(voice_id):
		return {"success": false, "reason": "unknown_voice_id"}

	var entry: Dictionary = VOICE_CATALOG[voice_id]
	var stream: AudioStreamWAV = _cached_audio_streams.get(voice_id)
	if not stream:
		stream = ProceduralCinematicAudio.create_japanese_vocal(entry["vocal_id"])
		_cached_audio_streams[voice_id] = stream

	if not voice_player_3d:
		voice_player_3d = AudioStreamPlayer3D.new()
		voice_player_3d.unit_size = 3.5
		voice_player_3d.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		add_child(voice_player_3d)

	if pos != Vector3.ZERO:
		voice_player_3d.position = pos
	else:
		voice_player_3d.position = Vector3.ZERO

	voice_player_3d.volume_db = entry["volume_db"]
	voice_player_3d.stream = stream
	if voice_player_3d.is_inside_tree():
		voice_player_3d.play()

	emit_signal("voice_played", voice_id, entry["text_ja"], entry["text_en"])
	return {
		"success": true,
		"voice_id": voice_id,
		"text_ja": entry["text_ja"],
		"text_en": entry["text_en"],
		"category": entry["category"]
	}

func set_acoustic_zone(zone: AcousticZone) -> void:
	current_zone = zone
	var preset: Dictionary = REVERB_PRESETS[zone]
	emit_signal("acoustic_zone_changed", zone, preset["name"])

func get_active_reverb_params() -> Dictionary:
	return REVERB_PRESETS.get(current_zone, REVERB_PRESETS[AcousticZone.COASTAL_OUTDOOR])

func get_voice_catalog() -> Dictionary:
	return VOICE_CATALOG

class_name ProceduralCinematicAudio
extends Node

## Procedural Cinematic Audio Synthesizer
## Synthesizes code-native 16-bit PCM soundscapes for medical monitors, neural shocks, abyssal drones, 
## AI voice acting formants, and reality simulation glitch waveforms.

static func generate_wav(samples: PackedFloat32Array, sample_rate: int = 22050) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false

	var byte_data := PackedByteArray()
	byte_data.resize(samples.size() * 2)

	for i in range(samples.size()):
		var s = clampf(samples[i], -1.0, 1.0)
		var int16_val = int(round(s * 32767.0))
		if int16_val < -32768: int16_val = -32768
		if int16_val > 32767: int16_val = 32767
		byte_data.encode_s16(i * 2, int16_val)

	wav.data = byte_data
	return wav

static func create_heart_monitor_beep() -> AudioStreamWAV:
	var sample_rate: int = 22050
	var duration: float = 0.12
	var total_samples: int = int(sample_rate * duration)
	var samples := PackedFloat32Array()
	samples.resize(total_samples)

	var freq: float = 920.0
	for i in range(total_samples):
		var t: float = float(i) / float(sample_rate)
		var env: float = 1.0 - (t / duration)
		var val: float = sin(TAU * freq * t) * env * 0.45
		samples[i] = val

	return generate_wav(samples, sample_rate)

static func create_neural_shock_sizzle() -> AudioStreamWAV:
	var sample_rate: int = 22050
	var duration: float = 0.45
	var total_samples: int = int(sample_rate * duration)
	var samples := PackedFloat32Array()
	samples.resize(total_samples)

	for i in range(total_samples):
		var t: float = float(i) / float(sample_rate)
		var env: float = 1.0 - (t / duration)
		var carrier: float = sin(TAU * (140.0 + sin(t * 120.0) * 80.0) * t)
		var noise: float = randf_range(-0.5, 0.5)
		samples[i] = (carrier * 0.6 + noise * 0.4) * env * 0.65

	return generate_wav(samples, sample_rate)

static func create_abyss_drone() -> AudioStreamWAV:
	var sample_rate: int = 22050
	var duration: float = 1.5
	var total_samples: int = int(sample_rate * duration)
	var samples := PackedFloat32Array()
	samples.resize(total_samples)

	for i in range(total_samples):
		var t: float = float(i) / float(sample_rate)
		var sub_bass: float = sin(TAU * 52.0 * t) * 0.6
		var harmonic: float = sin(TAU * 104.0 * t) * 0.25
		var heartbeat: float = 0.0
		var hb_t: float = fmod(t, 0.75)
		if hb_t < 0.12:
			heartbeat = sin(TAU * 45.0 * hb_t) * (1.0 - hb_t / 0.12) * 0.5
		samples[i] = (sub_bass + harmonic + heartbeat) * 0.7

	return generate_wav(samples, sample_rate)

static func create_covenant_chime() -> AudioStreamWAV:
	var sample_rate: int = 22050
	var duration: float = 1.2
	var total_samples: int = int(sample_rate * duration)
	var samples := PackedFloat32Array()
	samples.resize(total_samples)

	var chords = [440.0, 523.25, 659.25, 830.61] # A minor with sharp 7 (harmonic void)
	for i in range(total_samples):
		var t: float = float(i) / float(sample_rate)
		var env: float = exp(-t * 2.8)
		var mix: float = 0.0
		for freq in chords:
			mix += sin(TAU * freq * t) * 0.25
		samples[i] = mix * env * 0.8

	return generate_wav(samples, sample_rate)

## Synthesizes Dr. Kinga's cold cybernetic vocal formants
static func create_kinga_voice_line() -> AudioStreamWAV:
	var sample_rate: int = 22050
	var duration: float = 1.4
	var total_samples: int = int(sample_rate * duration)
	var samples := PackedFloat32Array()
	samples.resize(total_samples)

	var f0: float = 125.0 # Low male fundamental
	for i in range(total_samples):
		var t: float = float(i) / float(sample_rate)
		var env: float = sin(PI * t / duration)
		# Vowel formants /a/ & /o/
		var buzz: float = sin(TAU * f0 * t) + 0.5 * sin(TAU * f0 * 2.0 * t)
		var formant1: float = sin(TAU * 650.0 * t) * 0.4
		var formant2: float = sin(TAU * 1100.0 * t) * 0.3
		var vocoder_mod: float = sin(TAU * 45.0 * t) # Cybernetic modulation
		samples[i] = (buzz * 0.3 + (formant1 + formant2) * 0.5 + vocoder_mod * 0.2) * env * 0.75

	return generate_wav(samples, sample_rate)

## Synthesizes Zero's demonic abyssal shadow whisper
static func create_zero_whisper() -> AudioStreamWAV:
	var sample_rate: int = 22050
	var duration: float = 1.8
	var total_samples: int = int(sample_rate * duration)
	var samples := PackedFloat32Array()
	samples.resize(total_samples)

	for i in range(total_samples):
		var t: float = float(i) / float(sample_rate)
		var env: float = sin(PI * t / duration)
		var sub_drone: float = sin(TAU * 42.0 * t) * 0.5
		var sub_harm: float = sin(TAU * 84.0 * t) * 0.25
		var whisper_noise: float = randf_range(-0.35, 0.35) * sin(TAU * 2400.0 * t)
		samples[i] = (sub_drone + sub_harm + whisper_noise) * env * 0.8

	return generate_wav(samples, sample_rate)

## Synthesizes Echo's hysterical laughter / surge roar burst
static func create_echo_hysterical_laugh() -> AudioStreamWAV:
	var sample_rate: int = 22050
	var duration: float = 1.1
	var total_samples: int = int(sample_rate * duration)
	var samples := PackedFloat32Array()
	samples.resize(total_samples)

	for i in range(total_samples):
		var t: float = float(i) / float(sample_rate)
		var env: float = 1.0 - (t / duration)
		# Ascending pitch arpeggios
		var freq_sweep: float = 300.0 + pow(t / duration, 2.0) * 550.0 + sin(t * 30.0) * 40.0
		var raw_wave: float = sin(TAU * freq_sweep * t)
		# Cubic distortion
		var distorted: float = 1.5 * raw_wave - 0.5 * pow(raw_wave, 3.0)
		samples[i] = distorted * env * 0.7

	return generate_wav(samples, sample_rate)

## Synthesizes medical ECG continuous flatline alarm
static func create_ecg_flatline() -> AudioStreamWAV:
	var sample_rate: int = 22050
	var duration: float = 0.9
	var total_samples: int = int(sample_rate * duration)
	var samples := PackedFloat32Array()
	samples.resize(total_samples)

	var freq: float = 980.0
	for i in range(total_samples):
		var t: float = float(i) / float(sample_rate)
		var env: float = 0.85
		if t > 0.8: env = (0.9 - t) / 0.1 * 0.85
		samples[i] = sin(TAU * freq * t) * env * 0.5

	return generate_wav(samples, sample_rate)

## Synthesizes digital simulation glitch / bitcrush burst
static func create_reality_glitch_sfx() -> AudioStreamWAV:
	var sample_rate: int = 22050
	var duration: float = 0.35
	var total_samples: int = int(sample_rate * duration)
	var samples := PackedFloat32Array()
	samples.resize(total_samples)

	for i in range(total_samples):
		var t: float = float(i) / float(sample_rate)
		var env: float = 1.0 - (t / duration)
		# Step quantization / bitcrush simulation
		var stepped_freq: float = 180.0 + float(int(t * 24.0) % 5) * 220.0
		var square_val: float = 1.0 if sin(TAU * stepped_freq * t) >= 0.0 else -1.0
		var noise_spike: float = randf_range(-0.4, 0.4) if randf() < 0.15 else 0.0
		samples[i] = (square_val * 0.6 + noise_spike) * env * 0.65

	return generate_wav(samples, sample_rate)

## Synthesizes Japanese coastal ocean waves and sea breeze
static func create_ocean_coastal_breeze() -> AudioStreamWAV:
	var sample_rate: int = 22050
	var duration: float = 2.5
	var total_samples: int = int(sample_rate * duration)
	var samples := PackedFloat32Array()
	samples.resize(total_samples)

	for i in range(total_samples):
		var t: float = float(i) / float(sample_rate)
		# 0.4Hz wave swell cycle
		var wave_swell: float = sin(TAU * 0.4 * t) * 0.5 + 0.5
		var low_rumble: float = sin(TAU * 48.0 * t) * 0.35 * wave_swell
		var sea_spray: float = randf_range(-0.25, 0.25) * wave_swell
		var wind: float = sin(TAU * 120.0 * t) * 0.15 * (1.0 - wave_swell * 0.5)
		samples[i] = (low_rumble + sea_spray + wind) * 0.7

	return generate_wav(samples, sample_rate)

var audio_player: AudioStreamPlayer = null

func _ready() -> void:
	if not audio_player:
		audio_player = AudioStreamPlayer.new()
		add_child(audio_player)

func _can_play() -> bool:
	return is_inside_tree() and audio_player != null and audio_player.is_inside_tree()

func play_heart_beep() -> void:
	if not _can_play(): return
	audio_player.stream = create_heart_monitor_beep()
	audio_player.play()

func play_neural_shock() -> void:
	if not _can_play(): return
	audio_player.stream = create_neural_shock_sizzle()
	audio_player.play()

func play_abyss_ambience() -> void:
	if not _can_play(): return
	audio_player.stream = create_abyss_drone()
	audio_player.play()

func play_covenant_chime() -> void:
	if not _can_play(): return
	audio_player.stream = create_covenant_chime()
	audio_player.play()

func play_kinga_voice() -> void:
	if not _can_play(): return
	audio_player.stream = create_kinga_voice_line()
	audio_player.play()

func play_zero_whisper() -> void:
	if not _can_play(): return
	audio_player.stream = create_zero_whisper()
	audio_player.play()

func play_echo_laugh() -> void:
	if not _can_play(): return
	audio_player.stream = create_echo_hysterical_laugh()
	audio_player.play()

func play_ecg_flatline() -> void:
	if not _can_play(): return
	audio_player.stream = create_ecg_flatline()
	audio_player.play()

func play_reality_glitch() -> void:
	if not _can_play(): return
	audio_player.stream = create_reality_glitch_sfx()
	audio_player.play()

## Synthesizes classic Japanese residential two-tone doorbell chime (Ding-Dong)
static func create_doorbell_chime() -> AudioStreamWAV:
	var sample_rate: int = 22050
	var duration: float = 1.4
	var total_samples: int = int(sample_rate * duration)
	var samples := PackedFloat32Array()
	samples.resize(total_samples)

	var t_split: float = 0.55 # Transition between Ding (880Hz) and Dong (660Hz)
	for i in range(total_samples):
		var t: float = float(i) / float(sample_rate)
		var val: float = 0.0
		if t < t_split:
			var env: float = exp(-4.5 * t)
			val = (sin(TAU * 880.0 * t) * 0.7 + sin(TAU * 1760.0 * t) * 0.25) * env
		else:
			var t_local: float = t - t_split
			var env2: float = exp(-3.8 * t_local)
			val = (sin(TAU * 659.25 * t_local) * 0.75 + sin(TAU * 1318.5 * t_local) * 0.2) * env2
		samples[i] = val * 0.85

	return generate_wav(samples, sample_rate)

## Synthesizes Japanese vending machine coin drop & mechanical can dispense clunk
static func create_vending_clunk() -> AudioStreamWAV:
	var sample_rate: int = 22050
	var duration: float = 0.85
	var total_samples: int = int(sample_rate * duration)
	var samples := PackedFloat32Array()
	samples.resize(total_samples)

	for i in range(total_samples):
		var t: float = float(i) / float(sample_rate)
		var val: float = 0.0
		if t < 0.22:
			# Metallic coin clink & solenoid click
			var coin_env: float = exp(-18.0 * t)
			val = sin(TAU * 2400.0 * t) * coin_env * 0.5 + randf_range(-0.3, 0.3) * coin_env * 0.3
		elif t >= 0.22 and t < 0.65:
			# Heavy canned drink drop & mechanical impact thud
			var t_impact: float = t - 0.22
			var thud_env: float = exp(-9.0 * t_impact)
			var low_impact: float = sin(TAU * 85.0 * t_impact) * 0.75
			var metal_rattle: float = sin(TAU * 480.0 * t_impact) * 0.35 * exp(-16.0 * t_impact)
			val = (low_impact + metal_rattle) * thud_env
		samples[i] = val * 0.9

	return generate_wav(samples, sample_rate)

## Synthesizes refreshing drink consumption gulp & swallow
static func create_drink_gulp() -> AudioStreamWAV:
	var sample_rate: int = 22050
	var duration: float = 0.45
	var total_samples: int = int(sample_rate * duration)
	var samples := PackedFloat32Array()
	samples.resize(total_samples)

	for i in range(total_samples):
		var t: float = float(i) / float(sample_rate)
		var env: float = sin(PI * (t / duration))
		var sweep_freq: float = 320.0 - 140.0 * (t / duration)
		var fluid_tone: float = sin(TAU * sweep_freq * t) * 0.75
		var bubble_noise: float = randf_range(-0.2, 0.2) * (1.0 - t / duration)
		samples[i] = (fluid_tone + bubble_noise) * env * 0.8

	return generate_wav(samples, sample_rate)

## Synthesizes motorized automatic sliding glass door whoosh
static func create_sliding_door_whoosh() -> AudioStreamWAV:
	var sample_rate: int = 22050
	var duration: float = 0.9
	var total_samples: int = int(sample_rate * duration)
	var samples := PackedFloat32Array()
	samples.resize(total_samples)

	for i in range(total_samples):
		var t: float = float(i) / float(sample_rate)
		var env: float = sin(PI * (t / duration))
		var motor_hum: float = sin(TAU * 160.0 * t) * 0.3
		var roller_friction: float = randf_range(-0.35, 0.35) * (0.8 + 0.2 * sin(TAU * 12.0 * t))
		samples[i] = (motor_hum + roller_friction) * env * 0.65

	return generate_wav(samples, sample_rate)

func play_doorbell() -> void:
	if not _can_play(): return
	audio_player.stream = create_doorbell_chime()
	audio_player.play()

func play_vending_clunk() -> void:
	if not _can_play(): return
	audio_player.stream = create_vending_clunk()
	audio_player.play()

func play_drink_gulp() -> void:
	if not _can_play(): return
	audio_player.stream = create_drink_gulp()
	audio_player.play()

func play_sliding_door() -> void:
	if not _can_play(): return
	audio_player.stream = create_sliding_door_whoosh()
	audio_player.play()

## Synthesizes Japanese Konbini entrance chime melody
static func create_konbini_chime() -> AudioStreamWAV:
	var sample_rate: int = 22050
	var duration: float = 1.35
	var total_samples: int = int(sample_rate * duration)
	var samples := PackedFloat32Array()
	samples.resize(total_samples)

	# 6-note Japanese convenience store chime sequence: F#5 -> D#5 -> G#5 -> E5 -> B4 -> E5
	var note_freqs: Array[float] = [740.0, 622.25, 830.6, 659.25, 493.88, 659.25]
	var note_dur: float = 0.22

	for i in range(total_samples):
		var t: float = float(i) / float(sample_rate)
		var note_idx: int = clampi(int(t / note_dur), 0, note_freqs.size() - 1)
		var note_t: float = t - (note_idx * note_dur)
		var freq: float = note_freqs[note_idx]

		var env: float = exp(-6.5 * note_t)
		var fundamental: float = sin(TAU * freq * note_t) * 0.7
		var overtone: float = sin(TAU * freq * 2.0 * note_t) * 0.25 * exp(-12.0 * note_t)
		var val: float = (fundamental + overtone) * env * 0.8
		samples[i] = val

	return generate_wav(samples, sample_rate)

## Synthesizes barcode scanner beep and register drawer click
static func create_register_beep() -> AudioStreamWAV:
	var sample_rate: int = 22050
	var duration: float = 0.35
	var total_samples: int = int(sample_rate * duration)
	var samples := PackedFloat32Array()
	samples.resize(total_samples)

	for i in range(total_samples):
		var t: float = float(i) / float(sample_rate)
		var val: float = 0.0
		if t < 0.08:
			# Pure digital scanner chirp at 2400 Hz
			val = sin(TAU * 2400.0 * t) * 0.8
		elif t >= 0.1 and t < 0.32:
			# Mechanical drawer latch click
			var click_t: float = t - 0.1
			var env: float = exp(-22.0 * click_t)
			val = (sin(TAU * 340.0 * click_t) + randf_range(-0.4, 0.4)) * env * 0.6
		samples[i] = val

	return generate_wav(samples, sample_rate)

## Synthesizes organic food chewing and crisp snack crunch
static func create_food_crunch() -> AudioStreamWAV:
	var sample_rate: int = 22050
	var duration: float = 0.42
	var total_samples: int = int(sample_rate * duration)
	var samples := PackedFloat32Array()
	samples.resize(total_samples)

	for i in range(total_samples):
		var t: float = float(i) / float(sample_rate)
		# Dual crunch peaks at 0.0s and 0.18s
		var p1: float = max(0.0, 1.0 - (t / 0.15)) * exp(-14.0 * t)
		var p2: float = 0.0
		if t >= 0.16:
			var t2: float = t - 0.16
			p2 = max(0.0, 1.0 - (t2 / 0.18)) * exp(-12.0 * t2)

		var crackle: float = randf_range(-0.5, 0.5) * (p1 + p2)
		var formant: float = sin(TAU * 520.0 * t) * (p1 * 0.5 + p2 * 0.4)
		samples[i] = (crackle + formant) * 0.85

	return generate_wav(samples, sample_rate)

## Synthesizes Japanese neighborhood ambient backdrop (AC hum + coastal breeze)
static func create_neighborhood_ambience() -> AudioStreamWAV:
	var sample_rate: int = 22050
	var duration: float = 2.0
	var total_samples: int = int(sample_rate * duration)
	var samples := PackedFloat32Array()
	samples.resize(total_samples)

	for i in range(total_samples):
		var t: float = float(i) / float(sample_rate)
		# Subtle 60Hz/120Hz electrical AC outdoor unit drone
		var ac_hum: float = sin(TAU * 60.0 * t) * 0.12 + sin(TAU * 120.0 * t) * 0.08
		# Soft undulating coastal air drift
		var breeze: float = randf_range(-0.15, 0.15) * (0.6 + 0.4 * sin(TAU * 0.5 * t))
		samples[i] = (ac_hum + breeze) * 0.5

	return generate_wav(samples, sample_rate)

## Synthesizes TV CRT electronic static and broadcast hum
static func create_tv_static() -> AudioStreamWAV:
	var sample_rate: int = 22050
	var duration: float = 1.0
	var total_samples: int = int(sample_rate * duration)
	var samples := PackedFloat32Array()
	samples.resize(total_samples)

	for i in range(total_samples):
		var t: float = float(i) / float(sample_rate)
		var hum: float = sin(TAU * 60.0 * t) * 0.18 + sin(TAU * 120.0 * t) * 0.08
		var static_noise: float = randf_range(-0.35, 0.35) * (0.8 + 0.2 * sin(TAU * 24.0 * t))
		samples[i] = (hum + static_noise) * 0.75

	return generate_wav(samples, sample_rate)

## Synthesizes refrigerator door suction seal release
static func create_fridge_door_open() -> AudioStreamWAV:
	var sample_rate: int = 22050
	var duration: float = 0.45
	var total_samples: int = int(sample_rate * duration)
	var samples := PackedFloat32Array()
	samples.resize(total_samples)

	for i in range(total_samples):
		var t: float = float(i) / float(sample_rate)
		var suction_pop: float = sin(TAU * 110.0 * t) * exp(-28.0 * t) * 0.85
		var seal_hiss: float = randf_range(-0.3, 0.3) * exp(-16.0 * t) * 0.5
		var hinge_creak: float = sin(TAU * 380.0 * t) * (1.0 - exp(-8.0 * t)) * exp(-6.0 * t) * 0.35
		samples[i] = (suction_pop + seal_hiss + hinge_creak) * 0.8

	return generate_wav(samples, sample_rate)

## Synthesizes gas stove piezo spark click and blue flame ignition whoosh
static func create_gas_ignite() -> AudioStreamWAV:
	var sample_rate: int = 22050
	var duration: float = 0.65
	var total_samples: int = int(sample_rate * duration)
	var samples := PackedFloat32Array()
	samples.resize(total_samples)

	for i in range(total_samples):
		var t: float = float(i) / float(sample_rate)
		var val: float = 0.0
		# Three piezo click pulses at 0.0s, 0.08s, 0.16s
		for click_time in [0.0, 0.08, 0.16]:
			if t >= click_time and t < click_time + 0.03:
				var tc: float = t - click_time
				val += sin(TAU * 3800.0 * tc) * exp(-120.0 * tc) * 0.7
		# Gas ignition whoosh burst at 0.18s
		if t >= 0.18:
			var tw: float = t - 0.18
			var whoosh_env: float = sin(PI * clampf(tw / 0.4, 0.0, 1.0)) * exp(-5.0 * tw)
			var flame_low: float = sin(TAU * 95.0 * tw) * 0.5
			var flame_noise: float = randf_range(-0.4, 0.4) * 0.6
			val += (flame_low + flame_noise) * whoosh_env
		samples[i] = val * 0.85

	return generate_wav(samples, sample_rate)

## Synthesizes morning birds chirping and fresh dawn breeze
static func create_morning_birds() -> AudioStreamWAV:
	var sample_rate: int = 22050
	var duration: float = 1.6
	var total_samples: int = int(sample_rate * duration)
	var samples := PackedFloat32Array()
	samples.resize(total_samples)

	for i in range(total_samples):
		var t: float = float(i) / float(sample_rate)
		var bird: float = 0.0
		# Chirp 1 at 0.1s to 0.4s
		if t >= 0.1 and t < 0.4:
			var tb: float = t - 0.1
			var freq: float = 2800.0 + 900.0 * sin(TAU * 16.0 * tb)
			bird += sin(TAU * freq * tb) * sin(PI * (tb / 0.3)) * 0.65
		# Chirp 2 at 0.7s to 1.1s
		if t >= 0.7 and t < 1.1:
			var tb2: float = t - 0.7
			var freq2: float = 3200.0 - 600.0 * (tb2 / 0.4) + 400.0 * sin(TAU * 22.0 * tb2)
			bird += sin(TAU * freq2 * tb2) * sin(PI * (tb2 / 0.4)) * 0.55
		var breeze: float = randf_range(-0.1, 0.1) * 0.3
		samples[i] = bird + breeze

	return generate_wav(samples, sample_rate)

## Synthesizes classic Japanese Mamachari bicycle bell double-ding
static func create_bicycle_bell() -> AudioStreamWAV:
	var sample_rate: int = 22050
	var duration: float = 0.85
	var total_samples: int = int(sample_rate * duration)
	var samples := PackedFloat32Array()
	samples.resize(total_samples)

	for i in range(total_samples):
		var t: float = float(i) / float(sample_rate)
		var val: float = 0.0
		# Ding 1 at 0.0s (2650 Hz)
		if t < 0.6:
			var env1: float = exp(-9.0 * t)
			val += sin(TAU * 2650.0 * t) * env1 * 0.7
			val += sin(TAU * 5300.0 * t) * env1 * 0.25 * exp(-18.0 * t)
		# Ding 2 at 0.14s (3100 Hz)
		if t >= 0.14:
			var t2: float = t - 0.14
			var env2: float = exp(-10.0 * t2)
			val += sin(TAU * 3100.0 * t2) * env2 * 0.75
			val += sin(TAU * 6200.0 * t2) * env2 * 0.2 * exp(-20.0 * t2)
		samples[i] = val * 0.85

	return generate_wav(samples, sample_rate)

## Synthesizes 50cc 2-stroke Japanese scooter engine throttle & exhaust rev
static func create_engine_throttle() -> AudioStreamWAV:
	var sample_rate: int = 22050
	var duration: float = 0.95
	var total_samples: int = int(sample_rate * duration)
	var samples := PackedFloat32Array()
	samples.resize(total_samples)

	for i in range(total_samples):
		var t: float = float(i) / float(sample_rate)
		# Engine RPM sweep from 45Hz idle to 120Hz rev
		var rpm_freq: float = 45.0 + 75.0 * sin(PI * (t / duration))
		var cylinder_pulse: float = sin(TAU * rpm_freq * t) + 0.4 * sin(TAU * (rpm_freq * 2.0) * t)
		var exhaust_fizz: float = randf_range(-0.35, 0.35) * (0.5 + 0.5 * sin(TAU * rpm_freq * t))
		var env: float = 0.85 + 0.15 * sin(PI * (t / duration))
		samples[i] = (cylinder_pulse * 0.65 + exhaust_fizz * 0.35) * env * 0.85

	return generate_wav(samples, sample_rate)

## Synthesizes street skateboard polyurethane wheels rolling on asphalt
static func create_skateboard_roll() -> AudioStreamWAV:
	var sample_rate: int = 22050
	var duration: float = 0.85
	var total_samples: int = int(sample_rate * duration)
	var samples := PackedFloat32Array()
	samples.resize(total_samples)

	for i in range(total_samples):
		var t: float = float(i) / float(sample_rate)
		# Bearing hum at 220Hz + coarse surface wheel chatter
		var bearing_whine: float = sin(TAU * 220.0 * t) * 0.3
		var road_vibration: float = randf_range(-0.45, 0.45) * (0.7 + 0.3 * sin(TAU * 14.0 * t))
		samples[i] = (bearing_whine + road_vibration) * 0.75

	return generate_wav(samples, sample_rate)

## Synthesizes expressive Japanese voice formants for action combat (Haa, Osoi, Kiero, Mieta, Ku)
static func create_japanese_vocal(vocal_id: String = "haa") -> AudioStreamWAV:
	var sample_rate: int = 22050
	var duration: float = 0.38
	if vocal_id == "kiero": duration = 0.52
	elif vocal_id == "osoi": duration = 0.65
	elif vocal_id == "mieta": duration = 0.45
	elif vocal_id == "ku": duration = 0.22

	var total_samples: int = int(sample_rate * duration)
	var samples := PackedFloat32Array()
	samples.resize(total_samples)

	# Formant frequency parameters (Hz)
	var f0: float = 145.0 # Base pitch
	var f1: float = 800.0
	var f2: float = 1350.0
	var f3: float = 2600.0

	if vocal_id == "osoi":
		f0 = 125.0
		f1 = 520.0
		f2 = 950.0
		f3 = 2400.0
	elif vocal_id == "kiero":
		f0 = 165.0
		f1 = 400.0
		f2 = 2100.0
		f3 = 2800.0
	elif vocal_id == "mieta":
		f0 = 135.0
		f1 = 340.0
		f2 = 2250.0
		f3 = 2900.0
	elif vocal_id == "ku":
		f0 = 110.0
		f1 = 320.0
		f2 = 820.0
		f3 = 2200.0

	for i in range(total_samples):
		var t: float = float(i) / float(sample_rate)
		var env: float = sin(PI * (t / duration))
		# Pitch variation over duration
		var pitch: float = f0 * (1.0 + 0.15 * sin(PI * (t / duration)))
		# Vocal cord glottal pulse approximation
		var glottal: float = sin(TAU * pitch * t) + 0.5 * sin(TAU * (pitch * 2.0) * t) + 0.25 * sin(TAU * (pitch * 3.0) * t)
		# Resonant formant harmonic peaks
		var formant1: float = sin(TAU * f1 * t) * 0.45
		var formant2: float = sin(TAU * f2 * t) * 0.35
		var formant3: float = sin(TAU * f3 * t) * 0.20
		var breath: float = randf_range(-0.12, 0.12)
		samples[i] = (glottal * (formant1 + formant2 + formant3) + breath) * env * 0.9

	return generate_wav(samples, sample_rate)

## Synthesizes continuous coastal rainfall with asphalt spatter
static func create_coastal_rain() -> AudioStreamWAV:
	var sample_rate: int = 22050
	var duration: float = 1.8
	var total_samples: int = int(sample_rate * duration)
	var samples := PackedFloat32Array()
	samples.resize(total_samples)

	for i in range(total_samples):
		var t: float = float(i) / float(sample_rate)
		# Filtered pink noise + raindrop impacts
		var drop: float = 0.0
		if randf() < 0.012:
			drop = randf_range(0.2, 0.5) * exp(-((t * 100.0) - floor(t * 100.0)) * 12.0)
		var hiss: float = randf_range(-0.25, 0.25)
		samples[i] = (hiss + drop) * 0.65

	return generate_wav(samples, sample_rate)

## Synthesizes dynamic ocean surf swell and seawall wave break
static func create_ocean_waves() -> AudioStreamWAV:
	var sample_rate: int = 22050
	var duration: float = 2.4
	var total_samples: int = int(sample_rate * duration)
	var samples := PackedFloat32Array()
	samples.resize(total_samples)

	for i in range(total_samples):
		var t: float = float(i) / float(sample_rate)
		# Low frequency surge (50Hz) modulated by wave period
		var swell_env: float = sin(PI * (t / duration))
		var sub_surge: float = sin(TAU * 48.0 * t) * 0.45 + sin(TAU * 82.0 * t) * 0.25
		var foam_break: float = randf_range(-0.35, 0.35) * (swell_env * swell_env)
		samples[i] = (sub_surge + foam_break) * swell_env * 0.85

	return generate_wav(samples, sample_rate)





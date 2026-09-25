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

## Synthesizes sharp, resonant Katana parry / deflect clash (Sekiro style metallic ping)
static func create_katana_parry_clash() -> AudioStreamWAV:
	var sample_rate: int = 22050
	var duration: float = 0.42
	var total_samples: int = int(sample_rate * duration)
	var samples := PackedFloat32Array()
	samples.resize(total_samples)

	for i in range(total_samples):
		var t: float = float(i) / float(sample_rate)
		# Rapid initial metallic burst + long ringing harmonics
		var env_strike: float = exp(-t * 28.0)
		var env_ring: float = exp(-t * 8.5)
		
		var transient: float = randf_range(-0.6, 0.6) * env_strike
		var low_thud: float = sin(TAU * 140.0 * t) * env_strike * 0.45
		
		# Anharmonic high steel resonant frequencies
		var f1: float = sin(TAU * 2650.0 * t) * 0.4
		var f2: float = sin(TAU * 3820.0 * t) * 0.35
		var f3: float = sin(TAU * 5180.0 * t) * 0.25
		var f4: float = sin(TAU * 7200.0 * t) * 0.15
		
		samples[i] = transient + low_thud + (f1 + f2 + f3 + f4) * env_ring

	return generate_wav(samples, sample_rate)

## Synthesizes surface-aware footstep audio (concrete, metal, wood, water)
static func create_footstep(surface: String = "concrete", is_run: bool = false) -> AudioStreamWAV:
	var sample_rate: int = 22050
	var duration: float = 0.14 if surface == "water" else (0.11 if surface == "metal" else 0.08)
	var total_samples: int = int(sample_rate * duration)
	var samples := PackedFloat32Array()
	samples.resize(total_samples)

	var intensity: float = 1.25 if is_run else 0.95

	for i in range(total_samples):
		var t: float = float(i) / float(sample_rate)
		var env: float = exp(-t * (35.0 if surface != "metal" else 22.0))
		var val: float = 0.0

		match surface:
			"metal":
				var click: float = randf_range(-0.5, 0.5) * exp(-t * 60.0)
				var ping: float = (sin(TAU * 1650.0 * t) * 0.5 + sin(TAU * 3100.0 * t) * 0.3) * env
				val = click * 0.5 + ping * 0.6
			"wood":
				var tap: float = randf_range(-0.3, 0.3) * exp(-t * 50.0)
				var body: float = (sin(TAU * 240.0 * t) * 0.6 + sin(TAU * 380.0 * t) * 0.3) * env
				val = tap * 0.3 + body * 0.7
			"water":
				var squelch: float = sin(TAU * (320.0 - t * 1200.0) * t) * 0.4 * env
				var spray: float = randf_range(-0.4, 0.4) * exp(-t * 25.0)
				val = squelch * 0.5 + spray * 0.5
			_: # "concrete" / default
				var noise_burst: float = randf_range(-0.6, 0.6) * exp(-t * 55.0)
				var thud: float = sin(TAU * 175.0 * t) * env * 0.4
				val = noise_burst * 0.6 + thud * 0.4

		samples[i] = val * intensity

	return generate_wav(samples, sample_rate)

## Synthesizes serene, resonant Japanese Shinto / Buddhist shrine crystal bell chime (Suzu / Orin)
static func create_shrine_crystal_bell() -> AudioStreamWAV:
	var sample_rate: int = 22050
	var duration: float = 1.8
	var total_samples: int = int(sample_rate * duration)
	var samples := PackedFloat32Array()
	samples.resize(total_samples)

	for i in range(total_samples):
		var t: float = float(i) / float(sample_rate)
		# Strike transient + shimmering crystal resonance
		var env_strike: float = exp(-t * 22.0)
		var env_ring: float = exp(-t * 2.2)
		
		var strike: float = sin(TAU * 1320.0 * t) * env_strike * 0.3
		# Pure bell harmonic overtones (A6, E7, C#8, E8)
		var f1: float = sin(TAU * 1760.0 * t) * 0.45
		var f2: float = sin(TAU * 2640.0 * t) * 0.30
		var f3: float = sin(TAU * 3520.0 * t) * 0.18
		var f4: float = sin(TAU * 5280.0 * t) * 0.08
		
		# Slight tremolo shimmer
		var shimmer: float = 1.0 + 0.12 * sin(TAU * 5.5 * t)
		
		samples[i] = strike + (f1 + f2 + f3 + f4) * env_ring * shimmer * 0.65

	return generate_wav(samples, sample_rate)

## Synthesizes Genshin-tier ascending crystal arpeggio fanfare for quest and directive completions
static func create_quest_complete_fanfare() -> AudioStreamWAV:
	var sample_rate: int = 22050
	var duration: float = 1.75
	var total_samples: int = int(sample_rate * duration)
	var samples := PackedFloat32Array()
	samples.resize(total_samples)

	# Arpeggio note frequencies: C5 (523), E5 (659), G5 (784), B5 (988), D6 (1175), G6 (1568)
	var notes = [523.25, 659.25, 783.99, 987.77, 1174.66, 1567.98]
	var note_stagger: float = 0.12 # seconds between arpeggio notes

	for i in range(total_samples):
		var t: float = float(i) / float(sample_rate)
		var mix: float = 0.0

		for n_idx in range(notes.size()):
			var note_start: float = float(n_idx) * note_stagger
			if t >= note_start:
				var note_t: float = t - note_start
				var freq: float = notes[n_idx]
				var note_env: float = exp(-note_t * 2.8) * (1.0 - exp(-note_t * 80.0))
				# Sine fundamental + octave overtone + sparkle
				var fundamental: float = sin(TAU * freq * note_t) * 0.4
				var octave: float = sin(TAU * freq * 2.0 * note_t) * 0.2
				var sparkle: float = sin(TAU * freq * 4.0 * note_t) * 0.08
				mix += (fundamental + octave + sparkle) * note_env

		# Warm orchestral pad bass swell (C3 130.81 Hz, G3 196.0 Hz)
		var pad_env: float = sin(clampf(t / duration, 0.0, 1.0) * PI) * 0.28
		var pad: float = (sin(TAU * 130.81 * t) * 0.6 + sin(TAU * 196.0 * t) * 0.4) * pad_env

		samples[i] = mix * 0.65 + pad

	return generate_wav(samples, sample_rate)

## Synthesizes crisp katana blade sheathing click (Habaki metal lock into Saya)
static func create_blade_sheath_click() -> AudioStreamWAV:
	var sample_rate: int = 22050
	var duration: float = 0.26
	var total_samples: int = int(sample_rate * duration)
	var samples := PackedFloat32Array()
	samples.resize(total_samples)

	for i in range(total_samples):
		var t: float = float(i) / float(sample_rate)
		# Initial wood slide + snappy metallic lock + high steel chime
		var env_slide: float = exp(-t * 20.0) if t < 0.08 else 0.0
		var lock_t: float = maxf(0.0, t - 0.075)
		var env_lock: float = exp(-lock_t * 40.0)
		var env_ring: float = exp(-lock_t * 12.0)

		var slide_scrape: float = randf_range(-0.35, 0.35) * env_slide
		var lock_thud: float = sin(TAU * 340.0 * lock_t) * env_lock * 0.6
		var steel_ping: float = (sin(TAU * 2850.0 * lock_t) * 0.45 + sin(TAU * 4920.0 * lock_t) * 0.25) * env_ring

		samples[i] = slide_scrape + lock_thud + steel_ping

	return generate_wav(samples, sample_rate)

## Synthesizes tiered treasure chest unlatch and crystalline opening chime (Genshin Standard)
static func create_chest_open_chime(rarity: int = 0) -> AudioStreamWAV:
	var sample_rate: int = 22050
	var duration: float = 1.35 + float(rarity) * 0.25
	var total_samples: int = int(sample_rate * duration)
	var samples := PackedFloat32Array()
	samples.resize(total_samples)

	# Frequencies based on rarity: Common, Exquisite, Precious, Luxurious
	var chord_notes = [523.25, 659.25] # Common: C5, E5
	if rarity >= 1:
		chord_notes.append(783.99) # Exquisite: G5
	if rarity >= 2:
		chord_notes.append(987.77) # Precious: B5
	if rarity >= 3:
		chord_notes.append(1318.51) # Luxurious: E6

	for i in range(total_samples):
		var t: float = float(i) / float(sample_rate)

		# Initial mechanical unlatch & wood creak (first 0.12s)
		var unlatch: float = 0.0
		if t < 0.12:
			var click_env: float = exp(-t * 45.0)
			var creak: float = sin(TAU * 180.0 * t + sin(t * 300.0) * 10.0) * 0.4
			var click: float = randf_range(-0.5, 0.5) * click_env
			unlatch = (creak + click) * 0.7

		# Radiant crystal chime chime starting at 0.08s
		var chime_mix: float = 0.0
		if t >= 0.08:
			var chime_t: float = t - 0.08
			var chime_env: float = exp(-chime_t * (2.2 - float(rarity) * 0.25))
			var shimmer: float = 1.0 + 0.15 * sin(TAU * 7.0 * chime_t)
			for n_idx in range(chord_notes.size()):
				var f: float = chord_notes[n_idx]
				var stagger: float = float(n_idx) * 0.06
				if chime_t >= stagger:
					var note_t: float = chime_t - stagger
					var note_env: float = exp(-note_t * 2.5)
					chime_mix += (sin(TAU * f * note_t) * 0.35 + sin(TAU * f * 2.0 * note_t) * 0.15) * note_env * shimmer

		samples[i] = unlatch * 0.6 + chime_mix * 0.75

	return generate_wav(samples, sample_rate)

## Synthesizes continuous coastal rain ambience: soft rainfall hiss, droplet spatters & low rolling ocean surge
static func create_coastal_rain_ambience() -> AudioStreamWAV:
	var sample_rate: int = 22050
	var duration: float = 2.2
	var total_samples: int = int(sample_rate * duration)
	var samples := PackedFloat32Array()
	samples.resize(total_samples)

	var last_noise: float = 0.0
	for i in range(total_samples):
		var t: float = float(i) / float(sample_rate)

		# 1. Low-pass filtered pink/white noise for steady rainfall hiss
		var raw_noise: float = randf_range(-1.0, 1.0)
		last_noise = lerpf(last_noise, raw_noise, 0.22) # IIR single-pole lowpass filter
		var rain_hiss: float = last_noise * 0.42

		# 2. Random droplet pitter-patter clicks on asphalt/tetrapods
		var drop_click: float = 0.0
		if randf() < 0.012: # Random droplet strike
			var drop_freq: float = randf_range(1600.0, 3400.0)
			drop_click = sin(TAU * drop_freq * t) * randf_range(0.18, 0.45)

		# 3. Low coastal ocean roll & distant thunder murmur (42 Hz - 75 Hz)
		var sea_roll: float = (sin(TAU * 42.0 * t + sin(t * 1.5) * 2.0) * 0.5 + sin(TAU * 68.0 * t) * 0.3) * (0.25 + 0.15 * sin(TAU * 0.4 * t))

		samples[i] = rain_hiss + drop_click + sea_roll * 0.35

	return generate_wav(samples, sample_rate)

## Synthesizes water body entry splash with bubbling spray
static func create_water_splash_sfx() -> AudioStreamWAV:
	var sample_rate: int = 22050
	var duration: float = 0.55
	var total_samples: int = int(sample_rate * duration)
	var samples := PackedFloat32Array()
	samples.resize(total_samples)

	var last_noise: float = 0.0
	for i in range(total_samples):
		var t: float = float(i) / float(sample_rate)
		# Low impact plop
		var plop_env: float = exp(-t * 22.0)
		var plop: float = sin(TAU * maxf(60.0, 320.0 - t * 450.0) * t) * plop_env * 0.7
		# Foam and droplet spray
		var raw_noise: float = randf_range(-1.0, 1.0)
		last_noise = lerpf(last_noise, raw_noise, 0.3)
		var spray_env: float = sin(clampf(t / 0.4, 0.0, 1.0) * PI) * exp(-t * 6.0)
		var spray: float = last_noise * spray_env * 0.5
		# Droplet bubbles
		var bubble: float = 0.0
		if t >= 0.05 and t < 0.35:
			bubble = sin(TAU * (850.0 + 200.0 * sin(t * 50.0)) * t) * exp(-(t - 0.05) * 12.0) * 0.25
		samples[i] = plop + spray + bubble

	return generate_wav(samples, sample_rate)

## Synthesizes rhythmic breaststroke / swimming paddle water displacement
static func create_swim_stroke_sfx() -> AudioStreamWAV:
	var sample_rate: int = 22050
	var duration: float = 0.45
	var total_samples: int = int(sample_rate * duration)
	var samples := PackedFloat32Array()
	samples.resize(total_samples)

	var last_noise: float = 0.0
	for i in range(total_samples):
		var t: float = float(i) / float(sample_rate)
		var env: float = sin(clampf(t / duration, 0.0, 1.0) * PI)
		var raw_noise: float = randf_range(-1.0, 1.0)
		last_noise = lerpf(last_noise, raw_noise, 0.25)
		var churn: float = last_noise * env * 0.45
		var low_drag: float = sin(TAU * 110.0 * t) * env * 0.35
		samples[i] = churn + low_drag

	return generate_wav(samples, sample_rate)

## Synthesizes solid hand/foot stone grip scuff when scaling vertical walls
static func create_climb_grab_sfx() -> AudioStreamWAV:
	var sample_rate: int = 22050
	var duration: float = 0.22
	var total_samples: int = int(sample_rate * duration)
	var samples := PackedFloat32Array()
	samples.resize(total_samples)

	for i in range(total_samples):
		var t: float = float(i) / float(sample_rate)
		var env: float = exp(-t * 35.0)
		var scuff: float = randf_range(-0.5, 0.5) * env * 0.6
		var thud: float = sin(TAU * 160.0 * t) * env * 0.4
		samples[i] = scuff + thud

	return generate_wav(samples, sample_rate)

## Synthesizes visceral execution impact: sub-bass boom, metallic slice, and crystalline void shatter
static func create_visceral_execution_sfx() -> AudioStreamWAV:
	var sample_rate: int = 22050
	var duration: float = 0.85
	var total_samples: int = int(sample_rate * duration)
	var samples := PackedFloat32Array()
	samples.resize(total_samples)

	for i in range(total_samples):
		var t: float = float(i) / float(sample_rate)
		# Sub-bass heavy thump
		var sub_bass: float = sin(TAU * (48.0 - t * 18.0) * t) * exp(-t * 5.5) * 0.75
		# Blade slice whoosh
		var slice: float = sin(TAU * (820.0 - t * 450.0) * t) * exp(-t * 14.0) * 0.45
		# Glass/crystalline resonance shatter
		var glass: float = sin(TAU * 1760.0 * t) * exp(-t * 9.0) * 0.25 + sin(TAU * 2640.0 * t) * exp(-t * 12.0) * 0.15
		# Chaotic kinetic crunch
		var crunch: float = randf_range(-0.4, 0.4) * exp(-t * 22.0) * 0.35
		samples[i] = clampf(sub_bass + slice + glass + crunch, -1.0, 1.0)

	return generate_wav(samples, sample_rate)

## Synthesizes heavy hard-landing ground impact with dual-foot knee thud and grit friction
static func create_hard_landing_sfx() -> AudioStreamWAV:
	var sample_rate: int = 22050
	var duration: float = 0.38
	var total_samples: int = int(sample_rate * duration)
	var samples := PackedFloat32Array()
	samples.resize(total_samples)

	for i in range(total_samples):
		var t: float = float(i) / float(sample_rate)
		var env: float = exp(-t * 16.0)
		var ground_thud: float = sin(TAU * (75.0 - t * 25.0) * t) * env * 0.7
		var grit_scuff: float = randf_range(-0.35, 0.35) * exp(-t * 28.0) * 0.45
		samples[i] = clampf(ground_thud + grit_scuff, -1.0, 1.0)

	return generate_wav(samples, sample_rate)

## Synthesizes combat tumble / roll whoosh with ground cloth scuff
static func create_combat_roll_sfx() -> AudioStreamWAV:
	var sample_rate: int = 22050
	var duration: float = 0.42
	var total_samples: int = int(sample_rate * duration)
	var samples := PackedFloat32Array()
	samples.resize(total_samples)

	var last_val: float = 0.0
	for i in range(total_samples):
		var t: float = float(i) / float(sample_rate)
		var env: float = sin(clampf(t / duration, 0.0, 1.0) * PI)
		var raw: float = randf_range(-1.0, 1.0)
		last_val = lerpf(last_val, raw, 0.18)
		var whoosh: float = last_val * env * 0.55
		var friction: float = sin(TAU * 120.0 * t) * env * 0.25
		samples[i] = clampf(whoosh + friction, -1.0, 1.0)

	return generate_wav(samples, sample_rate)

## Synthesizes sword elemental infusion flare (Shadow / Radiant resonance)
static func create_sword_infusion_sfx() -> AudioStreamWAV:
	var sample_rate: int = 22050
	var duration: float = 0.65
	var total_samples: int = int(sample_rate * duration)
	var samples := PackedFloat32Array()
	samples.resize(total_samples)

	for i in range(total_samples):
		var t: float = float(i) / float(sample_rate)
		var env: float = exp(-t * 4.5)
		var fire_crackle: float = randf_range(-0.3, 0.3) * (1.0 + sin(t * 80.0) * 0.5) * env * 0.4
		var metallic_ring: float = sin(TAU * 880.0 * t) * env * 0.35 + sin(TAU * 1320.0 * t) * env * 0.2
		samples[i] = clampf(fire_crackle + metallic_ring, -1.0, 1.0)

	return generate_wav(samples, sample_rate)

## Synthesizes rewarding Loot Toast chime with crystalline bell arpeggio and coin clink
static func create_loot_toast_chime() -> AudioStreamWAV:
	var sample_rate: int = 22050
	var duration: float = 0.55
	var total_samples: int = int(sample_rate * duration)
	var samples := PackedFloat32Array()
	samples.resize(total_samples)

	# Ascending high crystal chords: E6 (1318 Hz), G#6 (1661 Hz), B6 (1975 Hz)
	var notes = [1318.5, 1661.2, 1975.5]
	for i in range(total_samples):
		var t: float = float(i) / float(sample_rate)
		var mix: float = 0.0
		for idx in range(notes.size()):
			var note_start: float = float(idx) * 0.065
			if t >= note_start:
				var note_t: float = t - note_start
				var env: float = exp(-note_t * 9.5)
				mix += sin(TAU * notes[idx] * note_t) * env * 0.3
		var coin_click: float = (randf_range(-0.3, 0.3) if t < 0.02 else 0.0)
		samples[i] = clampf(mix + coin_click, -1.0, 1.0)

	return generate_wav(samples, sample_rate)

## Synthesizes high-frequency compass sonar ping when tracking objectives
static func create_compass_ping_sfx() -> AudioStreamWAV:
	var sample_rate: int = 22050
	var duration: float = 0.28
	var total_samples: int = int(sample_rate * duration)
	var samples := PackedFloat32Array()
	samples.resize(total_samples)

	for i in range(total_samples):
		var t: float = float(i) / float(sample_rate)
		var env: float = exp(-t * 18.0)
		var ping: float = sin(TAU * 2400.0 * t) * env * 0.45
		samples[i] = clampf(ping, -1.0, 1.0)

	return generate_wav(samples, sample_rate)

## Synthesizes anime character quick-swap optical whoosh and tactical surge
static func create_character_swap_sfx() -> AudioStreamWAV:
	var sample_rate: int = 22050
	var duration: float = 0.42
	var total_samples: int = int(sample_rate * duration)
	var samples := PackedFloat32Array()
	samples.resize(total_samples)

	for i in range(total_samples):
		var t: float = float(i) / float(sample_rate)
		var env: float = sin(clampf(t / duration, 0.0, 1.0) * PI)
		var pitch_sweep: float = sin(TAU * (300.0 + t * 900.0) * t) * env * 0.55
		var energy_flash: float = randf_range(-0.25, 0.25) * exp(-t * 8.0) * 0.35
		samples[i] = clampf(pitch_sweep + energy_flash, -1.0, 1.0)

	return generate_wav(samples, sample_rate)

## Synthesizes catastrophic Ultimate Burst blast: sub-bass drop, void singularity suction, and screen-wide detonate
static func create_ultimate_burst_sfx() -> AudioStreamWAV:
	var sample_rate: int = 22050
	var duration: float = 1.15
	var total_samples: int = int(sample_rate * duration)
	var samples := PackedFloat32Array()
	samples.resize(total_samples)

	for i in range(total_samples):
		var t: float = float(i) / float(sample_rate)
		# Phase 1: Singularity suction / vacuum pitch rise
		var suction: float = 0.0
		if t < 0.35:
			var s_env: float = t / 0.35
			suction = sin(TAU * (120.0 + t * 800.0) * t) * s_env * 0.45
		# Phase 2: Cataclysmic detonation & bass wave
		var blast: float = 0.0
		if t >= 0.35:
			var b_t: float = t - 0.35
			var b_env: float = exp(-b_t * 4.2)
			var sub_bass: float = sin(TAU * (42.0 - b_t * 12.0) * b_t) * b_env * 0.85
			var roar: float = randf_range(-0.6, 0.6) * exp(-b_t * 12.0) * 0.55
			var choral: float = (sin(TAU * 523.25 * b_t) + sin(TAU * 659.25 * b_t)) * b_env * 0.25
			blast = sub_bass + roar + choral
		samples[i] = clampf(suction + blast, -1.0, 1.0)

	return generate_wav(samples, sample_rate)

## Synthesizes steaming hot Japanese ramen broth slurp and savory noodle savor
static func create_ramen_slurp_sfx() -> AudioStreamWAV:
	var sample_rate: int = 22050
	var duration: float = 0.55
	var total_samples: int = int(sample_rate * duration)
	var samples := PackedFloat32Array()
	samples.resize(total_samples)

	for i in range(total_samples):
		var t: float = float(i) / float(sample_rate)
		# Liquid suction and aspiration noise
		var liquid_noise: float = randf_range(-0.4, 0.4) * (1.0 + sin(TAU * 35.0 * t) * 0.4)
		var suction_env: float = sin(PI * clampf(t / duration, 0.0, 1.0))
		var broth_formant: float = sin(TAU * 650.0 * t) * 0.35 + sin(TAU * 1250.0 * t) * 0.2
		var bowl_clink: float = sin(TAU * 2200.0 * t) * exp(-t * 24.0) * 0.25 if t < 0.08 else 0.0
		samples[i] = clampf((liquid_noise * 0.6 + broth_formant * 0.4) * suction_env + bowl_clink, -1.0, 1.0)

	return generate_wav(samples, sample_rate)

## Synthesizes Japanese wooden sliding/hinged front entrance door latch click and smooth creak open
static func create_door_creak_open_sfx() -> AudioStreamWAV:
	var sample_rate: int = 22050
	var duration: float = 0.65
	var total_samples: int = int(sample_rate * duration)
	var samples := PackedFloat32Array()
	samples.resize(total_samples)

	for i in range(total_samples):
		var t: float = float(i) / float(sample_rate)
		# Latch unlock snap at 0.0s - 0.05s
		var latch: float = 0.0
		if t < 0.04:
			latch = sin(TAU * 1800.0 * t) * exp(-t * 80.0) * 0.65
		# Wood pivot friction and creak
		var wood_creak: float = 0.0
		if t >= 0.04:
			var tw: float = t - 0.04
			var creak_freq: float = 240.0 + 80.0 * sin(TAU * 6.0 * tw)
			var w_env: float = sin(PI * clampf(tw / 0.55, 0.0, 1.0)) * 0.5
			wood_creak = (sin(TAU * creak_freq * tw) + 0.3 * sin(TAU * (creak_freq * 2.2) * tw)) * w_env
			var wood_grain: float = randf_range(-0.15, 0.15) * w_env
			wood_creak += wood_grain
		samples[i] = clampf(latch + wood_creak, -1.0, 1.0)

	return generate_wav(samples, sample_rate)

## Synthesizes medical prescription pill bottle rattle and medicine tablet consumption
static func create_pill_bottle_rattle() -> AudioStreamWAV:
	var sample_rate: int = 22050
	var duration: float = 0.48
	var total_samples: int = int(sample_rate * duration)
	var samples := PackedFloat32Array()
	samples.resize(total_samples)

	for i in range(total_samples):
		var t: float = float(i) / float(sample_rate)
		var val: float = 0.0
		# Three plastic pill impacts at 0.05s, 0.14s, 0.22s
		for click_time in [0.05, 0.14, 0.22]:
			if t >= click_time and t < click_time + 0.04:
				var tc: float = t - click_time
				val += sin(TAU * 3200.0 * tc) * exp(-90.0 * tc) * 0.55
		# Cap snap at 0.30s
		if t >= 0.30 and t < 0.38:
			var tc2: float = t - 0.30
			val += sin(TAU * 1400.0 * tc2) * exp(-60.0 * tc2) * 0.6
	return generate_wav(samples, sample_rate)

## Synthesizes classic Westminster Japanese high school PA chime (Do-Mi-Re-Sol)
static func create_school_chime_bell() -> AudioStreamWAV:
	var sample_rate: int = 22050
	var duration: float = 1.6
	var total_samples: int = int(sample_rate * duration)
	var samples := PackedFloat32Array()
	samples.resize(total_samples)

	# F4 (349 Hz), A4 (440 Hz), G4 (392 Hz), C4 (261 Hz)
	var chimes = [
		{"freq": 349.23, "time": 0.05},
		{"freq": 440.00, "time": 0.42},
		{"freq": 392.00, "time": 0.80},
		{"freq": 261.63, "time": 1.18}
	]

	for i in range(total_samples):
		var t: float = float(i) / float(sample_rate)
		var mix: float = 0.0
		for bell in chimes:
			if t >= bell["time"]:
				var bt: float = t - bell["time"]
				var env: float = exp(-bt * 3.8)
				var tone: float = sin(TAU * bell["freq"] * bt) * env * 0.45
				var harmonic: float = sin(TAU * (bell["freq"] * 2.0) * bt) * env * 0.15
				mix += tone + harmonic
		samples[i] = clampf(mix, -1.0, 1.0)

	return generate_wav(samples, sample_rate)

## Synthesizes Japanese Geta-bako wooden/metal shoe locker click and slipper scuff
static func create_shoe_locker_click() -> AudioStreamWAV:
	var sample_rate: int = 22050
	var duration: float = 0.42
	var total_samples: int = int(sample_rate * duration)
	var samples := PackedFloat32Array()
	samples.resize(total_samples)

	for i in range(total_samples):
		var t: float = float(i) / float(sample_rate)
		# Locker latch snap at 0.0s
		var snap: float = (sin(TAU * 2600.0 * t) * exp(-t * 90.0) * 0.6 if t < 0.05 else 0.0)
		# Shoe scuff at 0.08s
		var scuff: float = 0.0
		if t >= 0.08 and t < 0.28:
			var st: float = t - 0.08
			scuff = randf_range(-0.35, 0.35) * sin(PI * (st / 0.2)) * 0.45
		# Door rebound tap at 0.26s
		var tap: float = 0.0
		if t >= 0.26:
			var tt: float = t - 0.26
			tap = sin(TAU * 880.0 * tt) * exp(-tt * 50.0) * 0.4
		samples[i] = clampf(snap + scuff + tap, -1.0, 1.0)

	return generate_wav(samples, sample_rate)

## Synthesizes high-altitude rooftop coastal breeze and chain-link fence rattle
static func create_rooftop_wind_sfx() -> AudioStreamWAV:
	var sample_rate: int = 22050
	var duration: float = 1.4
	var total_samples: int = int(sample_rate * duration)
	var samples := PackedFloat32Array()
	samples.resize(total_samples)

	for i in range(total_samples):
		var t: float = float(i) / float(sample_rate)
		var wind_mod: float = 0.5 + 0.5 * sin(TAU * 0.8 * t)
		var wind: float = randf_range(-0.3, 0.3) * wind_mod * 0.6
		var fence_ring: float = sin(TAU * 1420.0 * t) * (0.04 * sin(TAU * 3.5 * t))
	return generate_wav(samples, sample_rate)

## Synthesizes Japanese wooden bento box lid slide-off and bamboo chopsticks snap
static func create_bento_box_open_sfx() -> AudioStreamWAV:
	var sample_rate: int = 22050
	var duration: float = 0.52
	var total_samples: int = int(sample_rate * duration)
	var samples := PackedFloat32Array()
	samples.resize(total_samples)

	for i in range(total_samples):
		var t: float = float(i) / float(sample_rate)
		# Wooden lid friction slide at 0.0s - 0.22s
		var slide: float = 0.0
		if t < 0.25:
			var s_env: float = sin(PI * (t / 0.25))
			slide = randf_range(-0.3, 0.3) * s_env * 0.45 + sin(TAU * 420.0 * t) * s_env * 0.2
		# Chopsticks wooden snap clack at 0.28s
		var clack: float = 0.0
		if t >= 0.28 and t < 0.38:
			var ct: float = t - 0.28
			clack = sin(TAU * 2200.0 * ct) * exp(-ct * 70.0) * 0.65
		samples[i] = clampf(slide + clack, -1.0, 1.0)

	return generate_wav(samples, sample_rate)

## Synthesizes heartwarming Persona / Genshin-style social bond level-up fanfare
static func create_bond_up_jingle() -> AudioStreamWAV:
	var sample_rate: int = 22050
	var duration: float = 1.35
	var total_samples: int = int(sample_rate * duration)
	var samples := PackedFloat32Array()
	samples.resize(total_samples)

	# Bright ascending major pentatonic: C5 (523 Hz), E5 (659 Hz), G5 (784 Hz), A5 (880 Hz), C6 (1046 Hz)
	var notes = [
		{"freq": 523.25, "time": 0.05},
		{"freq": 659.25, "time": 0.22},
		{"freq": 783.99, "time": 0.39},
		{"freq": 880.00, "time": 0.56},
		{"freq": 1046.50, "time": 0.74}
	]

	for i in range(total_samples):
		var t: float = float(i) / float(sample_rate)
		var mix: float = 0.0
		for n in notes:
			if t >= n["time"]:
				var nt: float = t - n["time"]
				var env: float = exp(-nt * 4.5)
				var bell: float = sin(TAU * n["freq"] * nt) * env * 0.35
				var sparkle: float = sin(TAU * (n["freq"] * 2.0) * nt) * env * 0.15
				mix += bell + sparkle
		var glockenspiel_chime: float = sin(TAU * 2093.0 * t) * exp(-t * 2.5) * 0.2 if t >= 0.74 else 0.0
		samples[i] = clampf(mix + glockenspiel_chime, -1.0, 1.0)

	return generate_wav(samples, sample_rate)

## Synthesizes sharp Cryo / Cyan icy katana slash with crystal frost shatter
static func create_cryo_slash_sfx() -> AudioStreamWAV:
	var sample_rate: int = 22050
	var duration: float = 0.48
	var total_samples: int = int(sample_rate * duration)
	var samples := PackedFloat32Array()
	samples.resize(total_samples)

	for i in range(total_samples):
		var t: float = float(i) / float(sample_rate)
		# Fast air whoosh slice (1600Hz down to 240Hz)
		var freq: float = 1600.0 * exp(-t * 12.0) + 240.0
		var whoosh_env: float = sin(PI * clampf(t / 0.22, 0.0, 1.0))
		var whoosh: float = randf_range(-0.4, 0.4) * whoosh_env * 0.5 + sin(TAU * freq * t) * whoosh_env * 0.4

		# Crystalline frost shatter & freeze chime at 0.06s
		var frost: float = 0.0
		if t >= 0.06:
			var ft: float = t - 0.06
			var f_env: float = exp(-ft * 16.0)
			frost = (sin(TAU * 3420.0 * ft) + 0.5 * sin(TAU * 6840.0 * ft)) * f_env * 0.45

		samples[i] = clampf(whoosh + frost, -1.0, 1.0)

	return generate_wav(samples, sample_rate)

## Alias for backward compatibility
static func create_energy_blade_draw_sfx() -> AudioStreamWAV:
	return create_cryo_slash_sfx()

## Synthesizes crisp anime dialogue text typewriter blip / speech chirp
static func create_dialogue_speech_blip() -> AudioStreamWAV:
	var sample_rate: int = 22050
	var duration: float = 0.045
	var total_samples: int = int(sample_rate * duration)
	var samples := PackedFloat32Array()
	samples.resize(total_samples)

	for i in range(total_samples):
		var t: float = float(i) / float(sample_rate)
		var freq: float = 880.0 + 440.0 * exp(-t * 80.0)
		var env: float = sin(PI * (t / duration)) * exp(-t * 60.0)
		var click: float = sin(TAU * freq * t) * env * 0.4
		samples[i] = clampf(click, -1.0, 1.0)

	return generate_wav(samples, sample_rate)

## Synthesizes ominous Solo Leveling / Tokyo Ghoul shadow blink teleportation suction
static func create_shadow_blink_sfx() -> AudioStreamWAV:
	var sample_rate: int = 22050
	var duration: float = 0.55
	var total_samples: int = int(sample_rate * duration)
	var samples := PackedFloat32Array()
	samples.resize(total_samples)

	for i in range(total_samples):
		var t: float = float(i) / float(sample_rate)
		# Sub-bass void suction (80Hz dropping to 40Hz with reverse envelope)
		var sub_env: float = sin(PI * clampf(t / 0.45, 0.0, 1.0))
		var sub_bass: float = sin(TAU * (80.0 - 40.0 * (t / duration)) * t) * sub_env * 0.7
		# Ominous vacuum whoosh
		var whoosh: float = randf_range(-0.4, 0.4) * exp(-absf(t - 0.2) * 12.0) * 0.5
		# Sinister high harmonic ring at 0.18s
		var ring: float = 0.0
		if t >= 0.18:
			var rt: float = t - 0.18
			ring = sin(TAU * 1320.0 * rt) * exp(-rt * 10.0) * 0.35
		samples[i] = clampf(sub_bass + whoosh + ring, -1.0, 1.0)

	return generate_wav(samples, sample_rate)

## Synthesizes rare Dark Neural Fragment drop chime (abyssal crystal shimmer)
static func create_neural_fragment_drop_sfx() -> AudioStreamWAV:
	var sample_rate: int = 22050
	var duration: float = 0.95
	var total_samples: int = int(sample_rate * duration)
	var samples := PackedFloat32Array()
	samples.resize(total_samples)

	for i in range(total_samples):
		var t: float = float(i) / float(sample_rate)
		# Deep abyssal sub drone
		var drone: float = sin(TAU * 65.4 * t) * exp(-t * 2.5) * 0.4
		# Crystal overtone cluster (1864Hz, 2796Hz, 3728Hz)
		var c1: float = sin(TAU * 1864.6 * t) * exp(-t * 4.0) * 0.3
		var c2: float = sin(TAU * 2796.9 * t) * exp(-t * 5.5) * 0.2
		var c3: float = sin(TAU * 3729.3 * t) * exp(-t * 7.0) * 0.15
		# 528Hz Solfeggio shimmer
		var shimmer: float = sin(TAU * 528.0 * t) * (0.5 + 0.5 * sin(TAU * 8.0 * t)) * exp(-t * 3.0) * 0.25
		samples[i] = clampf(drone + c1 + c2 + c3 + shimmer, -1.0, 1.0)

	return generate_wav(samples, sample_rate)

## Synthesizes wet asphalt rain puddle footstep splash & spray
static func create_wet_surface_splash_sfx() -> AudioStreamWAV:
	var sample_rate: int = 22050
	var duration: float = 0.38
	var total_samples: int = int(sample_rate * duration)
	var samples := PackedFloat32Array()
	samples.resize(total_samples)

	for i in range(total_samples):
		var t: float = float(i) / float(sample_rate)
		# Low heel compression plop (140Hz)
		var plop: float = sin(TAU * 140.0 * t) * exp(-t * 35.0) * 0.6 if t < 0.1 else 0.0
		# Droplet spray noise with bandpass envelope
		var spray_env: float = sin(PI * clampf(t / 0.28, 0.0, 1.0)) * exp(-t * 8.0)
		var spray: float = randf_range(-0.4, 0.4) * spray_env * 0.5 + sin(TAU * 1800.0 * t) * spray_env * 0.2
		samples[i] = clampf(plop + spray, -1.0, 1.0)

	return generate_wav(samples, sample_rate)

## Synthesizes Japanese Gacha capsule dispenser mechanical clunk and plastic ball drop
static func create_gacha_capsule_drop_sfx() -> AudioStreamWAV:
	var sample_rate: int = 22050
	var duration: float = 0.65
	var total_samples: int = int(sample_rate * duration)
	var samples := PackedFloat32Array()
	samples.resize(total_samples)

	for i in range(total_samples):
		var t: float = float(i) / float(sample_rate)
		# 1. Coin slot slide & drop at 0.0s
		var coin: float = (sin(TAU * 3200.0 * t) * exp(-t * 80.0) * 0.5 if t < 0.08 else 0.0)
		# 2. Rotary crank ratcheting gear click at 0.12s
		var crank: float = 0.0
		if t >= 0.12 and t < 0.28:
			var ct: float = t - 0.12
			crank = sin(TAU * 640.0 * ct) * (0.5 + 0.5 * sin(TAU * 40.0 * ct)) * exp(-ct * 15.0) * 0.6
		# 3. Plastic capsule ball rolling out & landing clack at 0.35s
		var capsule: float = 0.0
		if t >= 0.35:
			var pt: float = t - 0.35
			capsule = (sin(TAU * 950.0 * pt) + 0.4 * sin(TAU * 1900.0 * pt)) * exp(-pt * 35.0) * 0.7
		samples[i] = clampf(coin + crank + capsule, -1.0, 1.0)

	return generate_wav(samples, sample_rate)

## Synthesizes wardrobe metallic zipper pull slide and cloth fabric rustle
static func create_wardrobe_zipper_sfx() -> AudioStreamWAV:
	var sample_rate: int = 22050
	var duration: float = 0.42
	var total_samples: int = int(sample_rate * duration)
	var samples := PackedFloat32Array()
	samples.resize(total_samples)

	for i in range(total_samples):
		var t: float = float(i) / float(sample_rate)
		# High frequency metallic zipper tooth buzz (1800Hz - 2400Hz frequency sweep)
		var zip_freq: float = 1800.0 + 600.0 * (t / duration)
		var zip_env: float = sin(PI * clampf(t / 0.35, 0.0, 1.0))
		var zipper: float = (sin(TAU * zip_freq * t) + 0.3 * randf_range(-1.0, 1.0)) * zip_env * 0.5
		# Cloth rustle tap at 0.32s
		var cloth: float = 0.0
		if t >= 0.32:
			var ct: float = t - 0.32
			cloth = randf_range(-0.35, 0.35) * exp(-ct * 30.0) * 0.4
		samples[i] = clampf(zipper + cloth, -1.0, 1.0)

	return generate_wav(samples, sample_rate)

## Phase 4 — Kei-Car horn / scooter beep SFX (380Hz bimodal ahoo beep)
static func create_vehicle_horn_sfx() -> AudioStream:
	var sample_rate: int = 22050
	var duration: float = 0.55
	var total_samples: int = int(sample_rate * duration)
	var samples := PackedFloat32Array()
	samples.resize(total_samples)
	for i in range(total_samples):
		var t: float = float(i) / float(sample_rate)
		var env: float = 1.0
		if t < 0.04:
			env = t / 0.04
		elif t > 0.48:
			env = (duration - t) / 0.07
		# Bimodal horn tone: 380Hz + 475Hz (perfect fifth)
		var tone: float = (sin(TAU * 380.0 * t) * 0.6 + sin(TAU * 475.0 * t) * 0.4) * env
		samples[i] = clampf(tone, -1.0, 1.0)
	return generate_wav(samples, sample_rate)

## Phase 4 — Scooter / motorcycle engine idle loop (80Hz fundamental + odd harmonics)
static func create_scooter_engine_sfx() -> AudioStream:
	var sample_rate: int = 22050
	var duration: float = 1.0   # 1s loop — pitch-shifted at runtime by engine_audio.pitch_scale
	var total_samples: int = int(sample_rate * duration)
	var samples := PackedFloat32Array()
	samples.resize(total_samples)
	for i in range(total_samples):
		var t: float = float(i) / float(sample_rate)
		# 80Hz fundamental + 3rd + 5th harmonics for 2-stroke character
		var engine: float = (
			sin(TAU * 80.0  * t) * 0.55 +
			sin(TAU * 240.0 * t) * 0.25 +
			sin(TAU * 400.0 * t) * 0.12 +
			randf_range(-0.06, 0.06)       # mechanical rattle
		)
		samples[i] = clampf(engine * 0.65, -1.0, 1.0)
	return generate_wav(samples, sample_rate)

## Phase 5 — Glass particle shatter SFX (burst of high-freq clicks)
static func create_glass_shatter_sfx() -> AudioStream:
	var sample_rate: int = 44100
	var duration: float = 0.65
	var total_samples: int = int(sample_rate * duration)
	var samples := PackedFloat32Array()
	samples.resize(total_samples)
	for i in range(total_samples):
		var t: float = float(i) / float(sample_rate)
		var impact: float = 0.0
		if t < 0.04:
			impact = randf_range(-1.0, 1.0) * exp(-t * 80.0)
		var tinkle: float = sin(TAU * 2800.0 * t + randf_range(0, TAU)) * exp(-t * 6.0) * 0.35
		var rattle: float = randf_range(-0.2, 0.2) * exp(-t * 12.0) * clampf(t / 0.04, 0.0, 1.0)
		samples[i] = clampf(impact + tinkle + rattle, -1.0, 1.0)
	return generate_wav(samples, sample_rate)

## Phase 5 — Spring bone hair sway SFX (soft swish on katana strike)
static func create_spring_hair_swish_sfx() -> AudioStream:
	var sample_rate: int = 22050
	var duration: float = 0.28
	var total_samples: int = int(sample_rate * duration)
	var samples := PackedFloat32Array()
	samples.resize(total_samples)
	for i in range(total_samples):
		var t: float = float(i) / float(sample_rate)
		var env: float = exp(-t * 14.0) * clampf(t / 0.02, 0.0, 1.0)
		var swish: float = randf_range(-0.5, 0.5) * env
		var tone: float = sin(TAU * 320.0 * t) * env * 0.15
		samples[i] = clampf(swish + tone, -1.0, 1.0)
	return generate_wav(samples, sample_rate)






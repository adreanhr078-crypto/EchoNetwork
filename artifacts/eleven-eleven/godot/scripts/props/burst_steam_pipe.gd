class_name BurstSteamPipe
extends StaticBody3D

## Genshin/BioShock-style Environmental Steam Hazard
## When struck by Echo's Katana, bursts into a high-pressure scalding steam plume
## that deals continuous damage to nearby enemies caught in the jet.

signal pipe_ruptured(pipe_pos: Vector3)

@export var is_ruptured: bool = false
@export var rupture_duration: float = 4.5

@onready var steam_particles: GPUParticles3D = $SteamJet if has_node("SteamJet") else null
@onready var hazard_area: Area3D = $HazardArea if has_node("HazardArea") else null
@onready var warning_light: OmniLight3D = $ValveLight if has_node("ValveLight") else null

var _rupture_timer: float = 0.0

func _ready() -> void:
	add_to_group("damageable")
	add_to_group("props")
	if steam_particles:
		steam_particles.emitting = false

func take_damage(_amount: float = 1.0, _hit_source_pos: Vector3 = Vector3.ZERO) -> void:
	if is_ruptured:
		return
	rupture_pipe()

func rupture_pipe() -> void:
	if is_ruptured:
		return
	is_ruptured = true
	_rupture_timer = rupture_duration
	emit_signal("pipe_ruptured", global_position)

	if steam_particles:
		steam_particles.emitting = true
	if warning_light:
		warning_light.light_color = Color(1.0, 0.2, 0.1, 1.0)
		warning_light.light_energy = 3.5

	# Audio hiss
	var audio_player := AudioStreamPlayer3D.new()
	add_child(audio_player)
	var sample_rate: float = 44100.0
	var duration: float = 0.8
	var num_samples: int = int(sample_rate * duration)
	var pcm_data := PackedByteArray()
	pcm_data.resize(num_samples * 2)
	for i in range(num_samples):
		var t: float = float(i) / sample_rate
		var env: float = (1.0 - (t / duration)) * minf(1.0, t * 20.0)
		var noise_val: float = (randf() * 2.0 - 1.0) * env
		var sample_val: int = int(clampf(noise_val, -1.0, 1.0) * 32767.0)
		var idx: int = i * 2
		pcm_data[idx] = sample_val & 0xFF
		pcm_data[idx + 1] = (sample_val >> 8) & 0xFF
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = int(sample_rate)
	stream.data = pcm_data
	audio_player.stream = stream
	audio_player.play()
	audio_player.finished.connect(audio_player.queue_free)

func _physics_process(delta: float) -> void:
	if not is_ruptured:
		return

	_rupture_timer -= delta
	if _rupture_timer <= 0.0:
		is_ruptured = false
		if steam_particles:
			steam_particles.emitting = false
		if warning_light:
			warning_light.light_color = Color(0.1, 0.8, 1.0, 1.0)
			warning_light.light_energy = 1.0
		return

	# Damage any enemies in hazard zone
	if hazard_area:
		for body in hazard_area.get_overlapping_bodies():
			if body.is_in_group("enemies") and body.has_method("take_damage"):
				body.take_damage(25.0 * delta, global_position)

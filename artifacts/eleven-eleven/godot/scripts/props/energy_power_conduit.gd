class_name EnergyPowerConduit
extends StaticBody3D

## Genshin-style Interactive Power Conduit
## Activates upon receiving a physical Katana strike, powering electrical circuits
## and unlocking hydraulic blast gates.

signal conduit_energized(conduit_node: Node)

@export var conduit_id: String = "conduit_a"
@export var is_energized: bool = false
@export var is_locked: bool = false

@onready var core_light: OmniLight3D = $CoreLight if has_node("CoreLight") else null
@onready var spark_particles: GPUParticles3D = $SparkParticles if has_node("SparkParticles") else null
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D if has_node("MeshInstance3D") else null

var _surge_tween: Tween = null

func _ready() -> void:
	add_to_group("damageable")
	add_to_group("conduits")
	_update_visuals()

func _update_visuals() -> void:
	if not core_light:
		core_light = find_child("CoreLight", true, false) as OmniLight3D
	if not spark_particles:
		spark_particles = find_child("SparkParticles", true, false) as GPUParticles3D

	if core_light:
		if is_energized:
			core_light.light_color = Color(0.0, 0.95, 1.0, 1.0) # Bright cyan
			core_light.light_energy = 3.6
		else:
			core_light.light_color = Color(1.0, 0.45, 0.08, 1.0) # Dormant amber
			core_light.light_energy = 0.9

	if spark_particles:
		spark_particles.emitting = is_energized

func get_interaction_prompt() -> String:
	return "شحن موصل الطاقة [E]" if not is_energized else "الموصل مشحون"

func interact(player: Node = null) -> void:
	if is_energized or is_locked:
		return
	var src_pos: Vector3 = player.global_position if (player and player.is_inside_tree()) else global_position
	energize(src_pos)

func take_damage(amount: float = 1.0, hit_source_pos: Vector3 = Vector3.ZERO) -> void:
	if is_energized or is_locked:
		return
	energize(hit_source_pos)

func energize(hit_source_pos: Vector3 = Vector3.ZERO) -> void:
	if is_energized:
		return
	is_energized = true
	_update_visuals()

	# Audio feedback: Synthesized electric surge
	var audio_player := AudioStreamPlayer3D.new()
	add_child(audio_player)
	var synth = load("res://scripts/audio/procedural_cinematic_audio.gd")
	if synth:
		# Synthesize high voltage surge
		var sample_rate: float = 44100.0
		var duration: float = 0.65
		var num_samples: int = int(sample_rate * duration)
		var pcm_data := PackedByteArray()
		pcm_data.resize(num_samples * 2)

		for i in range(num_samples):
			var t: float = float(i) / sample_rate
			var freq: float = lerpf(320.0, 1480.0, t / duration)
			var env: float = (1.0 - (t / duration)) * minf(1.0, t * 40.0)
			var wave: float = sin(2.0 * PI * freq * t) * 0.7 + sin(4.0 * PI * freq * t) * 0.3
			var sample_val: int = int(clampf(wave * env, -1.0, 1.0) * 32767.0)
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

	# Visual flash surge tween
	if core_light:
		if _surge_tween:
			_surge_tween.kill()
		_surge_tween = create_tween()
		_surge_tween.tween_property(core_light, "light_energy", 6.5, 0.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_surge_tween.tween_property(core_light, "light_energy", 3.2, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	emit_signal("conduit_energized", self)

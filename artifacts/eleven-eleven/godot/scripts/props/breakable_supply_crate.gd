class_name BreakableSupplyCrate
extends StaticBody3D

## Genshin-style Breakable Supply Crate
## Destructible prop that fractures when slashed by Echo's Katana, yielding Yen and recovery orbs.

signal crate_broken(crate_pos: Vector3)

@export var max_health: float = 1.0
var health: float = 1.0
var is_broken: bool = false

@onready var collision_shape: CollisionShape3D = $CollisionShape3D if has_node("CollisionShape3D") else null
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D if has_node("MeshInstance3D") else null

func _ready() -> void:
	add_to_group("damageable")
	add_to_group("props")
	health = max_health

func take_damage(amount: float = 1.0, hit_source_pos: Vector3 = Vector3.ZERO) -> void:
	if is_broken:
		return
	health -= amount
	if health <= 0.0:
		break_crate(hit_source_pos)

func break_crate(hit_source_pos: Vector3 = Vector3.ZERO) -> void:
	if is_broken:
		return
	is_broken = true
	emit_signal("crate_broken", global_position)

	# Disable collision immediately
	if collision_shape:
		collision_shape.set_deferred("disabled", true)

	# Audio crunch
	var audio_player := AudioStreamPlayer3D.new()
	var parent = get_parent()
	if parent:
		parent.add_child(audio_player)
		audio_player.global_position = global_position
		var sample_rate: float = 44100.0
		var duration: float = 0.35
		var num_samples: int = int(sample_rate * duration)
		var pcm_data := PackedByteArray()
		pcm_data.resize(num_samples * 2)
		for i in range(num_samples):
			var t: float = float(i) / sample_rate
			var env: float = exp(-t * 18.0)
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

	# Spawn splinter visual effects & Yen toast
	var impact_spawner = load("res://scripts/combat/impact_spawner.gd")
	if impact_spawner and parent:
		impact_spawner.spawn_impact_burst(parent, global_position, false)

	# Deliver 35 Yen economy loot to player
	var hud = parent.find_child("GameplayHUD", true, false) if parent else null
	if hud and hud.has_method("notify_loot_drop"):
		hud.notify_loot_drop("35 YEN", "SUPPLY CRATE RECOVERED", Color(1.0, 0.85, 0.2))

	var tree = get_tree() if is_inside_tree() else null
	if tree:
		var tween = tree.create_tween()
		if mesh_instance:
			tween.tween_property(mesh_instance, "scale", Vector3.ZERO, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tween.tween_callback(queue_free)
	else:
		queue_free()

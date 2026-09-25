class_name RogueAwakener
extends CharacterBody3D

## AAA Nocturnal Rogue Awakener AI (Solo Leveling / Tokyo Ghoul Urban Manhwa Style)
## Former subjects of Dr. Kinga's illicit neural singularity experiments who underwent
## partial Void awakenings. Stalks the narrow back-alleys of Minato-Kasumi at night (21:00 - 04:00).
## Features:
## - Crimson eye trails and dark void katana combat
## - Shadow Blink instant repositioning
## - Drops rare "Dark Neural Fragment" (Kinga's victim dossier) and Yen bounty upon defeat

signal state_changed(new_state: int)
signal shadow_blinked(from_pos: Vector3, to_pos: Vector3)
signal attack_executed(target: Node, damage: float)
signal staggered(duration: float)
signal defeated(killer: Node)
signal loot_dropped(loot_data: Dictionary)

const ProceduralCinematicAudio = preload("res://scripts/audio/procedural_cinematic_audio.gd")

enum State {
	PATROLLING,
	CHASING,
	ATTACKING,
	SHADOW_BLINKING,
	STAGGERED,
	DEFEATED
}

@export var awakener_id: String = "ROGUE_AWAKENER_01"
@export var display_name: String = "Rogue Awakener: Subject EX-007"
@export var current_state: State = State.PATROLLING
@export var max_hp: float = 320.0
@export var hp: float = 320.0
@export var attack_damage: float = 45.0
@export var move_speed: float = 4.5

var is_staggered: bool = false
var is_defeated: bool = false
var stagger_timer: float = 0.0

# Authoritative Nocturnal Spawn Window (21:00 - 04:00)
static func is_nocturnal_active(hour: int) -> bool:
	return hour >= 21 or hour < 4

func _ready() -> void:
	_setup_visual_avatar()

func _setup_visual_avatar() -> void:
	var avatar = find_child("AwakenerMesh", true, false)
	if not avatar:
		var mesh_inst := MeshInstance3D.new()
		mesh_inst.name = "AwakenerMesh"
		var capsule := CapsuleMesh.new()
		capsule.radius = 0.38
		capsule.height = 1.78
		mesh_inst.mesh = capsule
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.06, 0.04, 0.08, 1.0) # Obsidian shadow coat
		mat.roughness = 0.3
		mesh_inst.material_override = mat
		mesh_inst.position = Vector3(0, 0.89, 0)
		add_child(mesh_inst)

	# Glowing Crimson Eye Light / Trail
	var eye_light = find_child("CrimsonEyeGlow", true, false) as OmniLight3D
	if not eye_light:
		eye_light = OmniLight3D.new()
		eye_light.name = "CrimsonEyeGlow"
		eye_light.light_color = Color(0.95, 0.05, 0.15, 1.0)
		eye_light.light_energy = 3.5
		eye_light.omni_range = 3.0
		eye_light.position = Vector3(0, 1.55, 0.3)
		add_child(eye_light)


## Executes Shadow Blink teleportation to ambush or evade player
func shadow_blink(target_dest: Vector3) -> Dictionary:
	if is_defeated or is_staggered:
		return {"success": false, "reason": "Cannot blink while staggered or defeated"}

	var from_pos = global_position if is_inside_tree() else position
	current_state = State.SHADOW_BLINKING
	position = target_dest

	if is_inside_tree():
		var audio := AudioStreamPlayer.new()
		add_child(audio)
		audio.stream = ProceduralCinematicAudio.create_shadow_blink_sfx()
		audio.play()
		audio.finished.connect(func(): audio.queue_free())

	emit_signal("shadow_blinked", from_pos, target_dest)
	current_state = State.ATTACKING
	emit_signal("state_changed", current_state)

	return {
		"success": true,
		"skill_name": "Shadow Blink",
		"from_position": from_pos,
		"to_position": target_dest
	}

## Executes Void Katana Flurry attack against target
func execute_slash_attack(target: Node) -> Dictionary:
	if is_defeated or is_staggered:
		return {"success": false, "reason": "Cannot attack while staggered or defeated"}

	current_state = State.ATTACKING
	var dmg: float = attack_damage

	if target:
		if target.has_method("take_damage"):
			target.take_damage(dmg, self)
		elif "hp" in target:
			target.hp = maxf(0.0, target.hp - dmg)
			if target.has_signal("hp_changed"):
				target.emit_signal("hp_changed", target.hp, 200.0)

	emit_signal("attack_executed", target, dmg)

	return {
		"success": true,
		"skill_name": "Void Katana Flurry",
		"damage": dmg,
		"target_name": target.name if target else "Player"
	}

## Handles taking damage from Echo or companions (e.g. Yuki's Glacial Severance)
func take_damage(amount: float, attacker: Node = null) -> Dictionary:
	if is_defeated:
		return {"success": false, "already_defeated": true}

	hp = maxf(0.0, hp - amount)

	if hp <= 0.0:
		is_defeated = true
		current_state = State.DEFEATED
		emit_signal("state_changed", current_state)
		emit_signal("defeated", attacker)
		var loot = drop_loot(attacker)
		return {
			"damage_taken": amount,
			"remaining_hp": 0.0,
			"is_defeated": true,
			"loot": loot
		}

	return {
		"damage_taken": amount,
		"remaining_hp": hp,
		"is_defeated": false
	}

## Forces Awakener into Stagger window (upon parry or heavy counter)
func trigger_stagger(duration: float = 2.5) -> void:
	is_staggered = true
	stagger_timer = duration
	current_state = State.STAGGERED
	emit_signal("staggered", duration)
	emit_signal("state_changed", current_state)

## Awards rare Dark Neural Fragment lore drop and Yen currency bounty
func drop_loot(player: Node = null) -> Dictionary:
	var bounty_yen: int = 2500
	var item_id: String = "dark_neural_fragment"
	var item_name: String = "Dark Neural Fragment [EX-007 Dossier]"

	if player:
		if "wallet" in player and player.wallet != null:
			if player.wallet.has_method("earn_yen"):
				player.wallet.earn_yen(bounty_yen)
			elif player.wallet.has_method("add_yen"):
				player.wallet.add_yen(bounty_yen)

		if "inventory" in player and player.inventory != null:
			if player.inventory.has_method("add_item"):
				player.inventory.add_item(item_id, 1)

	if is_inside_tree():
		var audio := AudioStreamPlayer.new()
		add_child(audio)
		audio.stream = ProceduralCinematicAudio.create_neural_fragment_drop_sfx()
		audio.play()
		audio.finished.connect(func(): audio.queue_free())

	var loot_data: Dictionary = {
		"item_id": item_id,
		"item_name": item_name,
		"bounty_yen": bounty_yen,
		"lore_snippet": "Autopsy Dossier EX-007: Subject exhibited irreversible cognitive fragmentation following Kinga's dark stasis bath."
	}

	emit_signal("loot_dropped", loot_data)
	return loot_data

# ══════════════════════════════════════════════════════════════
# PHASE 4 — KAGUNE SHADOW TENDRIL SYSTEM (Tokyo Ghoul / Solo Leveling)
# ══════════════════════════════════════════════════════════════

## Kagune tendril runtime state
var _kagune_tendrils: Array[MeshInstance3D] = []
var _kagune_particles: GPUParticles3D = null
var _kagune_tip_lights: Array[OmniLight3D] = []
var _kagune_active: bool = false
var _tendril_time: float = 0.0

const TENDRIL_COUNT: int = 4
const TENDRIL_BASE_LENGTH: float = 1.6
const TENDRIL_WAVE_SPEED: float = 3.2
const TENDRIL_WAVE_AMP: float = 0.18

## Activates Kagune — call on combat entry or rage phase
func activate_kagune() -> void:
	if _kagune_active:
		return
	_kagune_active = true
	_spawn_kagune_tendrils()
	_spawn_void_particles()
	# Combat-state audio
	if is_inside_tree():
		var audio := AudioStreamPlayer.new()
		add_child(audio)
		audio.stream = ProceduralCinematicAudio.create_shadow_blink_sfx()
		audio.play()
		audio.volume_db = 4.0
		audio.finished.connect(func(): audio.queue_free())

## Spawns 4 organic tendril meshes radiating from the Awakener's back
func _spawn_kagune_tendrils() -> void:
	for i in range(TENDRIL_COUNT):
		var tendril := MeshInstance3D.new()
		tendril.name = "KaguneSegment_%d" % i
		var cyl := CylinderMesh.new()
		cyl.top_radius    = 0.025
		cyl.bottom_radius = 0.07
		cyl.height        = TENDRIL_BASE_LENGTH
		tendril.mesh = cyl

		var mat := StandardMaterial3D.new()
		mat.albedo_color   = Color(0.55, 0.02, 0.08, 0.9)   # Crimson-void
		mat.emission_enabled = true
		mat.emission        = Color(0.8, 0.05, 0.1, 1.0)
		mat.emission_energy_multiplier = 2.5
		mat.roughness       = 0.15
		mat.transparency    = BaseMaterial3D.TRANSPARENCY_ALPHA
		tendril.material_override = mat

		# Fan the tendrils symmetrically behind the back
		var angle_rad: float = (TAU / TENDRIL_COUNT) * i + PI / 4.0
		var base_x: float = cos(angle_rad) * 0.22
		var base_z: float = sin(angle_rad) * 0.22
		tendril.position = Vector3(base_x, 1.3, base_z - 0.1)
		tendril.rotation_degrees = Vector3(30.0 + i * 8.0, rad_to_deg(angle_rad), 0.0)

		add_child(tendril)
		_kagune_tendrils.append(tendril)

		# Glowing tip OmniLight
		var tip_light := OmniLight3D.new()
		tip_light.name = "KaguneLight_%d" % i
		tip_light.light_color  = Color(1.0, 0.08, 0.15, 1.0)
		tip_light.light_energy = 2.0
		tip_light.omni_range   = 1.5
		tip_light.position     = Vector3(base_x * 2.0, 1.3 + TENDRIL_BASE_LENGTH * 0.6, base_z * 2.0)
		add_child(tip_light)
		_kagune_tip_lights.append(tip_light)

## GPU void-particle emitter — dark spore cloud
func _spawn_void_particles() -> void:
	if _kagune_particles and is_instance_valid(_kagune_particles):
		return
	var gp := GPUParticles3D.new()
	gp.name = "KaguneVoidParticles"
	gp.amount           = 80
	gp.lifetime         = 1.4
	gp.emitting         = true
	gp.one_shot         = false
	gp.explosiveness    = 0.0
	gp.randomness       = 0.7
	gp.position         = Vector3(0, 1.2, -0.2)

	var pm := ParticleProcessMaterial.new()
	pm.direction        = Vector3(0, 1, 0)
	pm.spread           = 60.0
	pm.initial_velocity_min = 0.4
	pm.initial_velocity_max = 1.8
	pm.gravity          = Vector3(0, -0.3, 0)
	pm.color            = Color(0.55, 0.02, 0.08, 0.7)
	pm.scale_min        = 0.05
	pm.scale_max        = 0.15
	gp.process_material = pm

	# Simple quad mesh for particles
	var quad := QuadMesh.new()
	quad.size = Vector2(0.08, 0.08)
	gp.draw_pass_1 = quad

	add_child(gp)
	_kagune_particles = gp

## Sinusoidal cloth-physics tendril animation (called from _process)
func _update_kagune_animation(delta: float) -> void:
	if not _kagune_active:
		return
	_tendril_time += delta
	for i in range(_kagune_tendrils.size()):
		var tendril = _kagune_tendrils[i]
		if not is_instance_valid(tendril):
			continue
		# Sinusoidal bend in X and Z
		var phase_offset: float = (TAU / TENDRIL_COUNT) * i
		var wave_x: float = sin(_tendril_time * TENDRIL_WAVE_SPEED + phase_offset) * TENDRIL_WAVE_AMP
		var wave_z: float = cos(_tendril_time * TENDRIL_WAVE_SPEED * 0.7 + phase_offset) * TENDRIL_WAVE_AMP
		tendril.rotation.x += (wave_x - tendril.rotation.x) * delta * 4.0
		tendril.rotation.z += (wave_z - tendril.rotation.z) * delta * 4.0

	# Pulse the tip lights
	for light in _kagune_tip_lights:
		if is_instance_valid(light):
			light.light_energy = 2.0 + sin(_tendril_time * 4.0) * 0.8

## Override _process to drive Kagune cloth animation
func _process(delta: float) -> void:
	if is_staggered and stagger_timer > 0.0:
		stagger_timer = maxf(0.0, stagger_timer - delta)
		if stagger_timer <= 0.0:
			is_staggered = false
			current_state = State.PATROLLING
			emit_signal("state_changed", current_state)
	_update_kagune_animation(delta)

## Deactivates and frees all Kagune resources
func deactivate_kagune() -> void:
	_kagune_active = false
	for t in _kagune_tendrils:
		if is_instance_valid(t):
			if t.material_override != null:
				t.material_override = null
			t.queue_free()
	_kagune_tendrils.clear()
	for l in _kagune_tip_lights:
		if is_instance_valid(l):
			l.queue_free()
	_kagune_tip_lights.clear()
	if is_instance_valid(_kagune_particles):
		_kagune_particles.emitting = false
		_kagune_particles.queue_free()
	_kagune_particles = null

## Alley environmental effects — drain grate steam + flickering neon
static func spawn_alley_atmosphere(parent: Node, origin: Vector3) -> void:
	# Steam from drain grate
	var steam := GPUParticles3D.new()
	steam.name = "DrainGrateSteam"
	steam.amount        = 30
	steam.lifetime      = 2.2
	steam.emitting      = true
	steam.one_shot      = false
	steam.position      = origin + Vector3(0.6, 0.0, -0.4)
	var sp := ParticleProcessMaterial.new()
	sp.direction        = Vector3(0, 1, 0)
	sp.spread           = 18.0
	sp.initial_velocity_min = 0.2
	sp.initial_velocity_max = 0.8
	sp.gravity          = Vector3(0, 0.05, 0)
	sp.color            = Color(0.85, 0.88, 0.9, 0.25)
	sp.scale_min        = 0.12
	sp.scale_max        = 0.35
	steam.process_material = sp
	var sq := QuadMesh.new()
	sq.size = Vector2(0.15, 0.15)
	steam.draw_pass_1 = sq
	parent.add_child(steam)

	# Flickering neon OmniLight
	var neon := OmniLight3D.new()
	neon.name = "AlleyNeonFlicker"
	neon.light_color  = Color(0.2, 0.8, 1.0, 1.0)
	neon.light_energy = 1.8
	neon.omni_range   = 5.5
	neon.position     = origin + Vector3(-1.5, 3.2, 0.0)
	parent.add_child(neon)

# ──────────────────────────────────────────────────────────────
# Zero-leak teardown
func _exit_tree() -> void:
	deactivate_kagune()
	for child in get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.queue_free()

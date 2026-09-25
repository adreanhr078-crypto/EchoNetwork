class_name TeamSwapController
extends Node

## AAA Team Quick-Swap & Ultimate Elemental Burst System
## Genshin Impact / ZZZ-tier character switching and burst mechanics.
## Coordinates 3-character tactical roster, switch skill perks, energy gauge charging, and screen-wide Ultimate Bursts.

signal character_swapped(previous_slot: int, new_slot: int, character_data: Dictionary)
signal burst_energy_updated(slot: int, current_energy: float, max_energy: float)
signal burst_ready(slot: int, character_name: String)
signal ultimate_burst_executed(slot: int, character_name: String, damage: int)

const ProceduralCinematicAudio = preload("res://scripts/audio/procedural_cinematic_audio.gd")
const ImpactSpawner = preload("res://scripts/combat/impact_spawner.gd")

const SWAP_COOLDOWN_TIME: float = 1.0
const MAX_BURST_ENERGY: float = 100.0

const PARTY_ROSTER: Dictionary = {
	1: {
		"name": "Echo",
		"title": "Subject EX-011",
		"element": "VOID",
		"role": "Main DPS",
		"burst_name": "Void Execution: Severance",
		"burst_damage": 550,
		"avatar_color": Color(0.18, 0.02, 0.38, 1.0)
	},
	2: {
		"name": "Yuki Tachibana",
		"title": "Cryo Resonance Aegis",
		"element": "CYAN",
		"role": "Tactical Support",
		"burst_name": "Glacial Sanctuary: Polar Aurora",
		"burst_damage": 420,
		"avatar_color": Color(0.0, 0.94, 1.0, 1.0)
	},
	3: {
		"name": "Zero Persona",
		"title": "Shadow Monarch Singularity",
		"element": "SHADOW",
		"role": "Burst Nuke",
		"burst_name": "Abyssal Covenant: Event Horizon",
		"burst_damage": 720,
		"avatar_color": Color(0.85, 0.08, 0.25, 1.0)
	}
}

var active_slot: int = 1
var swap_cooldown: float = 0.0
var burst_energies: Dictionary = {
	1: 0.0,
	2: 0.0,
	3: 0.0
}

func _process(delta: float) -> void:
	if swap_cooldown > 0.0:
		swap_cooldown = maxf(0.0, swap_cooldown - delta)

## Returns metadata of the currently active roster character
func get_active_character() -> Dictionary:
	return PARTY_ROSTER.get(active_slot, PARTY_ROSTER[1])

## Swaps the active playable character to a new slot (1, 2, or 3)
func swap_to_slot(new_slot: int, player: Node = null, cine_director: Node = null) -> Dictionary:
	if new_slot == active_slot:
		return {"success": false, "reason": "already_active"}
	if not PARTY_ROSTER.has(new_slot):
		return {"success": false, "reason": "invalid_slot"}
	if swap_cooldown > 0.0:
		return {"success": false, "reason": "on_cooldown", "remaining": swap_cooldown}

	var prev_slot: int = active_slot
	active_slot = new_slot
	swap_cooldown = SWAP_COOLDOWN_TIME

	var char_data: Dictionary = PARTY_ROSTER[active_slot]

	# Tactical Switch Skill Perks
	if player:
		# Slot 1 (Echo): Restores +25 stamina and readies blade
		if active_slot == 1:
			if player.has_method("restore_stamina"):
				player.restore_stamina(25.0)
		# Slot 2 (Yuki): Heals +40 HP with frost sanctuary
		elif active_slot == 2:
			if "hp" in player:
				player.hp = minf(200.0, player.hp + 40.0)
				if player.has_signal("hp_changed"):
					player.emit_signal("hp_changed", player.hp, 200.0)
		# Slot 3 (Zero): Manifests monarch surge & awakens eye
		elif active_slot == 3:
			if player.has_method("set_zero_eye_active"):
				player.set_zero_eye_active(true, 1.8)

		# Optical FX & Screen Shake
		var p_pos = player.global_position if player.is_inside_tree() else player.position
		var parent = player.get_parent()
		if parent:
			ImpactSpawner.spawn_deflect_burst(parent, p_pos + Vector3(0, 1.0, 0))

	# Audio optical whoosh
	if is_inside_tree():
		var audio := AudioStreamPlayer.new()
		add_child(audio)
		audio.stream = ProceduralCinematicAudio.create_character_swap_sfx()
		audio.play()
		audio.finished.connect(func(): audio.queue_free())

	emit_signal("character_swapped", prev_slot, active_slot, char_data)
	return {
		"success": true,
		"previous_slot": prev_slot,
		"new_slot": active_slot,
		"character": char_data
	}

## Adds burst energy to a specific slot (or all active/inactive roster slots)
func add_burst_energy(amount: float, target_slot: int = -1) -> void:
	var slots_to_charge: Array = [target_slot] if target_slot in [1, 2, 3] else [1, 2, 3]
	for s in slots_to_charge:
		var old_energy: float = burst_energies.get(s, 0.0)
		var new_energy: float = minf(MAX_BURST_ENERGY, old_energy + amount)
		burst_energies[s] = new_energy
		emit_signal("burst_energy_updated", s, new_energy, MAX_BURST_ENERGY)
		if old_energy < MAX_BURST_ENERGY and new_energy >= MAX_BURST_ENERGY:
			var cname: String = PARTY_ROSTER[s]["name"]
			emit_signal("burst_ready", s, cname)

## Checks whether current active character has 100% burst energy ready
func can_execute_burst(slot: int = -1) -> bool:
	var check_slot: int = slot if slot in [1, 2, 3] else active_slot
	return burst_energies.get(check_slot, 0.0) >= MAX_BURST_ENERGY

## Executes the cinematic Ultimate Burst for the active character
func execute_ultimate_burst(player: Node, target: Node = null, cine_director: CineCameraDirector = null) -> Dictionary:
	if not can_execute_burst(active_slot):
		return {"success": false, "reason": "insufficient_energy"}

	# Consume burst energy
	burst_energies[active_slot] = 0.0
	emit_signal("burst_energy_updated", active_slot, 0.0, MAX_BURST_ENERGY)

	var char_data: Dictionary = PARTY_ROSTER[active_slot]
	var dmg: int = char_data["burst_damage"]

	# Cinematic Camera cut
	if cine_director:
		cine_director.preset_zero_awakening()
	elif player and player.get("player_camera"):
		var cam = player.get("player_camera") as Camera3D
		if cam:
			ImpactSpawner.trigger_screen_shake(cam, 0.45, 0.6)

	# Audio Synthesis Cataclysm
	if is_inside_tree():
		var audio := AudioStreamPlayer.new()
		add_child(audio)
		audio.stream = ProceduralCinematicAudio.create_ultimate_burst_sfx()
		audio.play()
		audio.finished.connect(func(): audio.queue_free())

	# Inflict massive burst damage on target or nearby enemies
	if target and target.has_method("take_damage"):
		var p_pos = player.global_position if player.is_inside_tree() else player.position
		target.take_damage(dmg, p_pos)
		if player.has_method("register_hit_landed"):
			player.register_hit_landed(dmg)

	emit_signal("ultimate_burst_executed", active_slot, char_data["name"], dmg)
	return {
		"success": true,
		"slot": active_slot,
		"character": char_data["name"],
		"burst_name": char_data["burst_name"],
		"damage": dmg
	}

func serialize() -> Dictionary:
	return {
		"active_slot": active_slot,
		"burst_energies": burst_energies.duplicate()
	}

func deserialize(data: Dictionary) -> void:
	if data.has("active_slot"):
		active_slot = data["active_slot"]
	if data.has("burst_energies"):
		burst_energies = data["burst_energies"].duplicate()

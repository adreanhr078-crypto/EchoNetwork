class_name CompanionBondManager
extends Node

## AAA Social Bond & Confidant Progression Engine (Persona / Genshin Style)
## Manages 1-10 Social Bond Tiers for Key Narrative Companions:
## - Yuki Tachibana (Glacial Vanguard, Cryo synergy & combat assist)
## - Shizuka (Psychological Anchor, bento sharing & trauma counseling)
## Provides tier progression, perk unlocking, serialization, and fanfare audio.

signal bond_points_added(char_id: String, added_points: int, total_points: int)
signal bond_level_up(char_id: String, new_level: int, perk_name: String)

const ProceduralCinematicAudio = preload("res://scripts/audio/procedural_cinematic_audio.gd")

const MAX_BOND_TIER: int = 10

# Bond point thresholds for Tiers 1 through 10
const TIER_THRESHOLDS: Array[int] = [
	0,    # Tier 1 (Initial acquaintance / classmate)
	100,  # Tier 2
	250,  # Tier 3
	450,  # Tier 4
	700,  # Tier 5 (Major Milestones: Glacial Vanguard / Psychological Anchor)
	1000, # Tier 6
	1350, # Tier 7
	1750, # Tier 8
	2200, # Tier 9
	2700  # Tier 10 (Max / Eternal Bond)
]

# Authored character perks awarded at key tiers
const CHARACTER_PERKS: Dictionary = {
	"YUKI": {
		1: "Quiet Observer",       # +5% Cryo resistance
		3: "Sparring Partner",      # +10% Stamina recovery
		5: "Glacial Vanguard",      # Combat assist damage +25%, Cooldown -20%
		7: "Polar Resonance",       # Frost slow & freeze duration +1.5s
		10: "Eternal Oath"          # Twin Glacial Cataclysm unlocked
	},
	"SHIZUKA": {
		1: "Classroom Smile",       # +10 Max Hunger & baseline calm
		3: "Handmade Bento",        # Bento box HP & energy healing +50%
		5: "Psychological Anchor",  # Reality Glitch growth -40%, Sanity loss halved
		7: "Calm Haven",            # Restores +25 HP per school class attended
		10: "Unshakable Sanctuary"  # Cheat-death survival once per day
	}
}

# Runtime bond state: { "YUKI": {"level": 1, "points": 0, "unlocked_perks": [...]}, ... }
var bond_data: Dictionary = {}

func _init() -> void:
	_init_default_bonds()

func _init_default_bonds() -> void:
	for char_id in ["YUKI", "SHIZUKA"]:
		if not bond_data.has(char_id):
			bond_data[char_id] = {
				"level": 1,
				"points": 0,
				"unlocked_perks": [CHARACTER_PERKS[char_id].get(1, "Bond Tier 1")]
			}

func get_bond_level(char_id: String) -> int:
	var key = char_id.to_upper()
	if bond_data.has(key):
		return bond_data[key].get("level", 1)
	return 1

func get_bond_points(char_id: String) -> int:
	var key = char_id.to_upper()
	if bond_data.has(key):
		return bond_data[key].get("points", 0)
	return 0

func get_active_perks(char_id: String) -> Array:
	var key = char_id.to_upper()
	if bond_data.has(key):
		return bond_data[key].get("unlocked_perks", [])
	return []

func has_perk(char_id: String, perk_name: String) -> bool:
	var perks = get_active_perks(char_id)
	for p in perks:
		if String(p).to_lower() == perk_name.to_lower():
			return true
	return false

## Awards bond experience points, checks tier promotion, unlocks perks & plays jingle
func add_bond_points(char_id: String, points: int) -> Dictionary:
	var key = char_id.to_upper()
	if not bond_data.has(key):
		_init_default_bonds()
	if not bond_data.has(key):
		return {"success": false, "error": "Unknown companion ID"}

	var cur_data: Dictionary = bond_data[key]
	var old_level: int = cur_data["level"]
	cur_data["points"] += points
	var total: int = cur_data["points"]

	var newly_unlocked_perks: Array[String] = []
	var leveled_up: bool = false

	# Calculate current level according to thresholds
	var target_level: int = old_level
	for tier_idx in range(TIER_THRESHOLDS.size()):
		var tier_num = tier_idx + 1
		if total >= TIER_THRESHOLDS[tier_idx]:
			if tier_num > target_level and tier_num <= MAX_BOND_TIER:
				target_level = tier_num

	if target_level > old_level:
		leveled_up = true
		for lvl in range(old_level + 1, target_level + 1):
			cur_data["level"] = lvl
			var perks_map: Dictionary = CHARACTER_PERKS.get(key, {})
			if perks_map.has(lvl):
				var perk: String = perks_map[lvl]
				if not cur_data["unlocked_perks"].has(perk):
					cur_data["unlocked_perks"].append(perk)
					newly_unlocked_perks.append(perk)
				emit_signal("bond_level_up", key, lvl, perk)
			else:
				emit_signal("bond_level_up", key, lvl, "Tier %d Affinity" % lvl)

		_play_bond_up_audio()

	emit_signal("bond_points_added", key, points, total)

	return {
		"success": true,
		"char_id": key,
		"points_added": points,
		"total_points": total,
		"old_level": old_level,
		"level": cur_data["level"],
		"leveled_up": leveled_up,
		"new_perks": newly_unlocked_perks,
		"all_perks": cur_data["unlocked_perks"]
	}

func _play_bond_up_audio() -> void:
	if is_inside_tree():
		var audio := AudioStreamPlayer.new()
		add_child(audio)
		audio.stream = ProceduralCinematicAudio.create_bond_up_jingle()
		audio.play()
		audio.finished.connect(func(): audio.queue_free())

## Serializes social bonds for persistence
func serialize() -> Dictionary:
	return {
		"bond_data": bond_data.duplicate(true)
	}

## Deserializes social bonds from save file
func deserialize(data: Dictionary) -> void:
	if data.has("bond_data"):
		bond_data = data["bond_data"].duplicate(true)
	_init_default_bonds()

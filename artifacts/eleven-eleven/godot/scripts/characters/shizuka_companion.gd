class_name ShizukaCompanion
extends CharacterBody3D

## AAA Narrative Companion: Shizuka (Class 2-B Emotional Anchor)
## Sits directly in front of Echo in Class 2-B (Row 3, Window).
## Provides:
## - Empathetic emotional support & psychological trauma counseling
## - Sharing homemade bento boxes (+100 Hunger, +50 HP, plays bento open SFX)
## - Suppresses Echo's Reality Glitches and restores sanity
## - Synergizes with CompanionBondManager (Tier 3 Handmade Bento & Tier 5 Psychological Anchor)

signal state_changed(new_state: int)
signal dialogue_spoken(speaker: String, text: String)
signal bento_shared(player: Node, meal_data: Dictionary)
signal trauma_counseled(player: Node, sanity_restored: float, glitch_suppressed: float)

const ProceduralCinematicAudio = preload("res://scripts/audio/procedural_cinematic_audio.gd")
const CompanionBondManagerScript = preload("res://scripts/systems/companion_bond_manager.gd")
const DynamicAIDialogueEngineScript = preload("res://scripts/systems/dynamic_ai_dialogue_engine.gd")


enum State {
	CLASSROOM_IDLE,
	ROOFTOP_LUNCH,
	FOLLOWING_PLAYER,
	RESTING
}

const DESK_POSITION: Vector3 = Vector3(-4.5, 3.8, 4.2)

@export var character_id: String = "SHIZUKA"
@export var character_name: String = "Shizuka"
@export var role: String = "Class 2-B Student / Emotional Anchor"
@export var current_state: State = State.CLASSROOM_IDLE

var following_target: Node3D = null
var bento_share_count: int = 0
var counseling_count: int = 0
var follow_speed: float = 3.8
var stop_distance: float = 2.0

func _init() -> void:
	position = DESK_POSITION

func _ready() -> void:
	_setup_visual_avatar()
	sit_at_desk()

func _setup_visual_avatar() -> void:
	var avatar = find_child("ShizukaAvatarMesh", true, false)
	if not avatar:
		var mesh_inst := MeshInstance3D.new()
		mesh_inst.name = "ShizukaAvatarMesh"
		var capsule := CapsuleMesh.new()
		capsule.radius = 0.33
		capsule.height = 1.60
		mesh_inst.mesh = capsule
		var mat := StandardMaterial3D.new()
		# Minato Academy cream cardigan with warm peach hairpin ribbon
		mat.albedo_color = Color(0.92, 0.82, 0.72, 1.0)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.55, 0.65, 1.0)
		mat.emission_energy_multiplier = 0.25
		mesh_inst.material_override = mat
		mesh_inst.position = Vector3(0, 0.8, 0)
		add_child(mesh_inst)

func _process(delta: float) -> void:
	if current_state == State.FOLLOWING_PLAYER and following_target and is_inside_tree():
		var target_pos = following_target.global_position
		var current_pos = global_position
		var dist = current_pos.distance_to(target_pos)
		if dist > stop_distance:
			var dir = (target_pos - current_pos).normalized()
			dir.y = 0.0
			velocity = dir * follow_speed
			move_and_slide()
		else:
			velocity = Vector3.ZERO

## Resets Shizuka to her authored desk position in Class 2-B
func sit_at_desk() -> void:
	current_state = State.CLASSROOM_IDLE
	position = DESK_POSITION
	following_target = null
	emit_signal("state_changed", current_state)

## Move to school rooftop for lunchtime bento sharing
func go_to_rooftop_lunch() -> void:
	current_state = State.ROOFTOP_LUNCH
	position = Vector3(0.0, 8.5, -6.5)
	emit_signal("state_changed", current_state)

## Starts following player
func start_following(target: Node3D) -> Dictionary:
	following_target = target
	current_state = State.FOLLOWING_PLAYER
	emit_signal("state_changed", current_state)
	return {
		"success": true,
		"state": "FOLLOWING_PLAYER",
		"target": target.name if target else "Unknown"
	}

## Stops following player
func stop_following() -> Dictionary:
	following_target = null
	current_state = State.CLASSROOM_IDLE
	emit_signal("state_changed", current_state)
	return {
		"success": true,
		"state": "CLASSROOM_IDLE"
	}

## Shares a lovingly prepared Japanese Bento Box with Echo
func share_homemade_bento(player: Node, bond_manager: CompanionBondManagerScript = null) -> Dictionary:
	bento_share_count += 1

	var has_handmade_bento_perk: bool = false
	if bond_manager:
		has_handmade_bento_perk = bond_manager.has_perk("SHIZUKA", "Handmade Bento")

	var hunger_restore: float = 100.0
	var hp_heal: float = 50.0
	var energy_restore: float = 30.0

	if has_handmade_bento_perk:
		hunger_restore = 150.0
		hp_heal = 75.0
		energy_restore = 45.0

	# Apply benefits to player
	if player:
		if "needs" in player and player.needs != null:
			if "hunger" in player.needs:
				player.needs.hunger = minf(100.0, player.needs.hunger + hunger_restore)
			if "energy" in player.needs:
				player.needs.energy = minf(100.0, player.needs.energy + energy_restore)

		if "hp" in player:
			player.hp = minf(200.0, player.hp + hp_heal)
			if player.has_signal("hp_changed"):
				player.emit_signal("hp_changed", player.hp, 200.0)

	# Play bento box opening SFX
	if is_inside_tree():
		var audio := AudioStreamPlayer.new()
		add_child(audio)
		audio.stream = ProceduralCinematicAudio.create_bento_box_open_sfx()
		audio.play()
		audio.finished.connect(func(): audio.queue_free())

	var meal_info: Dictionary = {
		"meal_name": "Shizuka's Special Tamagoyaki & Karaage Bento",
		"hunger_restored": hunger_restore,
		"hp_healed": hp_heal,
		"energy_restored": energy_restore,
		"perk_active": has_handmade_bento_perk,
		"share_count": bento_share_count
	}

	emit_signal("bento_shared", player, meal_info)
	return {
		"success": true,
		"meal": meal_info["meal_name"],
		"hunger_restored": hunger_restore,
		"hp_healed": hp_heal,
		"energy_restored": energy_restore,
		"dialogue": "Here, Echo! I made extra rolled omelette and sweet karaage today. Make sure you eat every bite!"
	}

## Provides psychological counseling to calm Echo's reality glitch and mental trauma
func provide_trauma_counseling(player: Node, bond_manager: CompanionBondManagerScript = null) -> Dictionary:
	counseling_count += 1

	var has_psych_anchor: bool = false
	if bond_manager:
		has_psych_anchor = bond_manager.has_perk("SHIZUKA", "Psychological Anchor")

	var sanity_boost: float = 40.0
	var glitch_reduction: float = 50.0

	if has_psych_anchor:
		sanity_boost = 60.0
		glitch_reduction = 75.0

	if player:
		if "sanity" in player:
			player.sanity = minf(100.0, player.sanity + sanity_boost)
		elif player.has_meta("sanity"):
			player.set_meta("sanity", minf(100.0, float(player.get_meta("sanity")) + sanity_boost))

		if "glitch_meter" in player:
			player.glitch_meter = maxf(0.0, player.glitch_meter - glitch_reduction)
		if "reality_glitch" in player:
			player.reality_glitch = maxf(0.0, player.reality_glitch - glitch_reduction)
		elif player.has_meta("reality_glitch"):
			player.set_meta("reality_glitch", maxf(0.0, float(player.get_meta("reality_glitch")) - glitch_reduction))

	emit_signal("trauma_counseled", player, sanity_boost, glitch_reduction)

	return {
		"success": true,
		"sanity_restored": sanity_boost,
		"glitch_suppressed": glitch_reduction,
		"psychological_anchor_active": has_psych_anchor,
		"counseling_count": counseling_count,
		"dialogue": "Take a deep breath, Echo. You're right here with me. Listen to the ocean wind. Ground yourself."
	}

## Context-rich empathetic dialogue lines adapting to social bond rank
func talk(bond_manager: CompanionBondManagerScript = null) -> Dictionary:
	var bond_tier: int = 1
	if bond_manager:
		bond_tier = bond_manager.get_bond_level("SHIZUKA")

	var line: String = ""
	if bond_tier <= 2:
		line = "Morning, Echo! Did you sleep okay? You looked a little exhausted when you walked into class."
	elif bond_tier <= 5:
		line = "Whenever the world starts feeling like cold numbers and static, just look at me. I'll always pull you back."
	else:
		line = "You don't have to carry the burden of the cataclysm alone, Echo. No matter what happens, you will always have a place to come home to."

	emit_signal("dialogue_spoken", character_name, line)
	return {
		"character": character_name,
		"bond_tier": bond_tier,
		"dialogue": line
	}

## Freeform dynamic conversational interaction powered by DynamicAIDialogueEngine
func chat_freeform(query: String, engine: DynamicAIDialogueEngineScript = null, context_data: Dictionary = {}) -> Dictionary:
	if not engine:
		engine = DynamicAIDialogueEngineScript.new()
	var res = engine.generate_response("SHIZUKA", query, context_data)
	emit_signal("dialogue_spoken", character_name, res.get("text", ""))
	return res


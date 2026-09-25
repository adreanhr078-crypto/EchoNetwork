class_name YukiCompanion
extends CharacterBody3D

## AAA Narrative Companion: Yuki Tachibana (Class 2-B Stoic Vanguard)
## Sits directly left of Echo in Class 2-B (Row 4, Aisle).
## Provides:
## - In-class companionship and observational dialogue
## - Dynamic follow AI across the school campus & town
## - Tactical Cryo / Cyan combat assist strikes with frost slow debuff
## - Synergizes with CompanionBondManager (Tier 5 Glacial Vanguard perk)

signal state_changed(new_state: int)
signal dialogue_spoken(speaker: String, text: String)
signal combat_assist_triggered(target: Node, damage: float, is_critical: bool)

const ProceduralCinematicAudio = preload("res://scripts/audio/procedural_cinematic_audio.gd")
const CompanionBondManagerScript = preload("res://scripts/systems/companion_bond_manager.gd")
const DynamicAIDialogueEngineScript = preload("res://scripts/systems/dynamic_ai_dialogue_engine.gd")

enum State {
	CLASSROOM_IDLE,
	FOLLOWING_PLAYER,
	COMBAT_ENGAGED
}

const DESK_POSITION: Vector3 = Vector3(-2.8, 3.8, 2.5)

@export var character_id: String = "YUKI"
@export var character_name: String = "Yuki Tachibana"
@export var role: String = "Class 2-B Student / Cryo Resonance Aegis"
@export var current_state: State = State.CLASSROOM_IDLE

var following_target: Node3D = null
var combat_assist_cooldown: float = 0.0
var base_assist_damage: float = 85.0
var follow_speed: float = 4.0
var stop_distance: float = 2.0

func _init() -> void:
	position = DESK_POSITION

func _ready() -> void:
	_setup_visual_avatar()
	sit_at_desk()

func _setup_visual_avatar() -> void:
	# Check if avatar mesh exists
	var avatar = find_child("YukiAvatarMesh", true, false)
	if not avatar:
		var mesh_inst := MeshInstance3D.new()
		mesh_inst.name = "YukiAvatarMesh"
		var capsule := CapsuleMesh.new()
		capsule.radius = 0.35
		capsule.height = 1.65
		mesh_inst.mesh = capsule
		var mat := StandardMaterial3D.new()
		# Minato Academy navy blazer with cyan icy scarf accents
		mat.albedo_color = Color(0.12, 0.22, 0.38, 1.0)
		mat.emission_enabled = true
		mat.emission = Color(0.0, 0.75, 0.95, 1.0)
		mat.emission_energy_multiplier = 0.35
		mesh_inst.material_override = mat
		mesh_inst.position = Vector3(0, 0.82, 0)
		add_child(mesh_inst)

func _process(delta: float) -> void:
	if combat_assist_cooldown > 0.0:
		combat_assist_cooldown = maxf(0.0, combat_assist_cooldown - delta)

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

## Resets Yuki to her authored desk position in Class 2-B
func sit_at_desk() -> void:
	current_state = State.CLASSROOM_IDLE
	position = DESK_POSITION
	following_target = null
	emit_signal("state_changed", current_state)

## Commands Yuki to follow player across campus or through Minato-Kasumi alleys
func start_following(target: Node3D) -> Dictionary:
	following_target = target
	current_state = State.FOLLOWING_PLAYER
	emit_signal("state_changed", current_state)
	return {
		"success": true,
		"state": "FOLLOWING_PLAYER",
		"target": target.name if target else "Unknown"
	}

## Disengages follow mode
func stop_following() -> Dictionary:
	following_target = null
	current_state = State.CLASSROOM_IDLE
	emit_signal("state_changed", current_state)
	return {
		"success": true,
		"state": "CLASSROOM_IDLE"
	}

## Executes Yuki's signature tactical Cryo assist strike ("Glacial Severance")
func execute_combat_assist(target: Node, bond_manager: CompanionBondManagerScript = null) -> Dictionary:
	if combat_assist_cooldown > 0.0:
		return {
			"success": false,
			"error": "Combat assist on cooldown",
			"remaining_cooldown": combat_assist_cooldown
		}

	var has_glacial_vanguard: bool = false
	var has_polar_resonance: bool = false
	if bond_manager:
		has_glacial_vanguard = bond_manager.has_perk("YUKI", "Glacial Vanguard")
		has_polar_resonance = bond_manager.has_perk("YUKI", "Polar Resonance")

	# Damage calculation
	var damage: float = base_assist_damage
	var cooldown_duration: float = 5.0
	if has_glacial_vanguard:
		damage *= 1.25 # +25% Glacial Vanguard boost
		cooldown_duration *= 0.8 # -20% cooldown

	combat_assist_cooldown = cooldown_duration

	var slow_duration: float = 3.0
	if has_polar_resonance:
		slow_duration += 1.5

	# Inflict damage on target
	if target:
		if target.has_method("take_damage"):
			target.take_damage(damage)
		elif "hp" in target:
			target.hp = maxf(0.0, target.hp - damage)
		elif target.has_meta("hp"):
			target.set_meta("hp", maxf(0.0, float(target.get_meta("hp")) - damage))

		if target.has_method("apply_frost_slow"):
			target.apply_frost_slow(0.40, slow_duration)
		elif "speed_multiplier" in target:
			target.speed_multiplier = 0.60

	# Play audio if in scene tree
	if is_inside_tree():
		var audio := AudioStreamPlayer.new()
		add_child(audio)
		audio.stream = ProceduralCinematicAudio.create_energy_blade_draw_sfx()
		audio.play()
		audio.finished.connect(func(): audio.queue_free())

	emit_signal("combat_assist_triggered", target, damage, has_glacial_vanguard)

	return {
		"success": true,
		"skill_name": "Glacial Severance",
		"damage": damage,
		"element": "CYAN_CRYO",
		"target_name": target.name if target else "Dummy",
		"slow_duration": slow_duration,
		"glacial_vanguard_active": has_glacial_vanguard,
		"cooldown_applied": combat_assist_cooldown
	}

## Context-rich dialogue lines adapting to social bond rank
func talk(bond_manager: CompanionBondManagerScript = null) -> Dictionary:
	var bond_tier: int = 1
	if bond_manager:
		bond_tier = bond_manager.get_bond_level("YUKI")

	var line: String = ""
	if bond_tier <= 2:
		line = "Echo. Don't stare out the window too long. Kinga's observers aren't the only ones watching us."
	elif bond_tier <= 5:
		line = "Your movements in combat are sharpening, Echo. When the time comes to strike back, I'm behind you."
	else:
		line = "I swore an oath. No matter what shadow Monarch singularity tries to pull you into the dark, I will stand between you and the abyss."

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
	var res = engine.generate_response("YUKI", query, context_data)
	emit_signal("dialogue_spoken", character_name, res.get("text", ""))
	return res


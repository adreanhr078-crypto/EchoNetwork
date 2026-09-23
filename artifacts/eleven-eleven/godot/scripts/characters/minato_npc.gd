class_name MinatoNPC
extends CharacterBody3D

signal spoke_with_player(npc_id: String, dialogue_line: String)

enum SchedulePhase {
	MORNING_SHIFT,
	AFTERNOON_STROLL,
	EVENING_COMMUTE,
	NIGHT_REST
}

@export var npc_id: String = "NPC_AOI_01"
@export var display_name: String = "Nurse Aoi Tanaka"
@export var role: String = "Hospital Outpatient Nurse"
@export var home_or_work_role: String = "Minato-Kasumi General Hospital"
@export var current_activity: String = "Finishing evening shift and heading home"
@export var schedule_phase: SchedulePhase = SchedulePhase.AFTERNOON_STROLL

@export var dialogue_lines: Array[String] = [
	"My shift at the clinic is finally over... You look pale, are you an outpatient?",
	"The coastal sea air always clears the mind after a double shift.",
	"Take care heading down the seawall, the wind picks up toward sundown."
]

const InteractableComponent = preload("res://scripts/interaction/interactable_component.gd")

enum FamiliarityTier {
	STRANGER,      # 0
	ACQUAINTANCE,  # 1-2
	REGULAR,       # 3-5
	FAMILIAR       # 6+
}

var talk_count: int = 0
var familiarity_tier: FamiliarityTier = FamiliarityTier.STRANGER
@onready var interactable = find_child("InteractableComponent", true, false)

func get_familiarity_name() -> String:
	match familiarity_tier:
		FamiliarityTier.STRANGER: return "Stranger"
		FamiliarityTier.ACQUAINTANCE: return "Acquaintance"
		FamiliarityTier.REGULAR: return "Regular"
		FamiliarityTier.FAMILIAR: return "Familiar"
	return "Stranger"

func _ready() -> void:
	if not interactable:
		interactable = find_child("InteractableComponent", true, false) as InteractableComponent
	if interactable:
		interactable.verb = InteractableComponent.InteractionVerb.TALK
		interactable.prompt_target_name = display_name

func get_schedule_info() -> Dictionary:
	var phase_name = "Afternoon Stroll"
	match schedule_phase:
		SchedulePhase.MORNING_SHIFT: phase_name = "08:00-16:00 Hospital Shift"
		SchedulePhase.AFTERNOON_STROLL: phase_name = "16:00-18:30 Coastal Walk"
		SchedulePhase.EVENING_COMMUTE: phase_name = "18:30-20:00 Tram Commute"
		SchedulePhase.NIGHT_REST: phase_name = "20:00+ Home"

	var cur_pos = global_position if is_inside_tree() else position
	return {
		"npc_id": npc_id,
		"name": display_name,
		"role": role,
		"workplace": home_or_work_role,
		"activity": current_activity,
		"phase": phase_name,
		"familiarity": get_familiarity_name(),
		"location": cur_pos
	}

func on_interacted(interactor: Node3D, verb: int) -> Dictionary:
	return talk_to_player(interactor)

func talk_to_player(interactor: Node3D = null) -> Dictionary:
	if dialogue_lines.is_empty():
		return {"npc_id": npc_id, "name": display_name, "dialogue": "..."}

	var line_idx = talk_count % dialogue_lines.size()
	var spoken_line = dialogue_lines[line_idx]
	talk_count += 1

	# Update familiarity tier
	if talk_count >= 6:
		familiarity_tier = FamiliarityTier.FAMILIAR
	elif talk_count >= 3:
		familiarity_tier = FamiliarityTier.REGULAR
	elif talk_count >= 1:
		familiarity_tier = FamiliarityTier.ACQUAINTANCE

	# Check for player needs contextual observation
	var needs_comment: String = ""
	if interactor and "needs" in interactor and interactor.needs != null:
		var n = interactor.needs
		if n.is_exhausted():
			needs_comment = "(Noticing your exhaustion) You look pale and unsteady... please rest soon."
		elif n.is_hungry():
			needs_comment = "(Hearing your stomach rumble) Kasumi Mart down the road has hot bento and onigiri."
		elif n.is_thirsty():
			needs_comment = "(Noticing your chapped lips) There's cold water at the vending machine right there."

	# Turn to face interactor smoothly if provided
	if interactor:
		var target_pos = interactor.global_position if interactor.is_inside_tree() else interactor.position
		var my_pos = global_position if is_inside_tree() else position
		var dir = (target_pos - my_pos).normalized()
		dir.y = 0.0
		if dir.length() > 0.01:
			rotation.y = atan2(dir.x, dir.z)

	emit_signal("spoke_with_player", npc_id, spoken_line)

	return {
		"npc_id": npc_id,
		"name": display_name,
		"role": role,
		"dialogue": spoken_line,
		"needs_comment": needs_comment,
		"talk_count": talk_count,
		"familiarity_tier": int(familiarity_tier),
		"familiarity": get_familiarity_name()
	}


class_name ResidentialHouse
extends Node3D

signal doorbell_rung(ring_count: int, response_text: String)

@export var household_id: String = "HOUSE_SATO_01"
@export var address: String = "Minato-Kasumi 2-Chome 4-1"
@export var resident_name: String = "Mika Sato"
@export var is_resident_home: bool = true

const InteractableComponent = preload("res://scripts/interaction/interactable_component.gd")

var ring_count: int = 0
var audio_player: AudioStreamPlayer3D = null

var household_manager: Object = null
var current_hour: int = 17

@onready var interactable = find_child("DoorbellInteractable", true, false)

const RESPONSES := [
	"Hello? Can I help you? ...Oh, are you an outpatient from the hospital down the road?",
	"Yes? If you're looking for Dr. Sato, he's at the clinic until six.",
	"Please stop ringing the bell! The baby is sleeping!",
	"... (Silence. No answer. The resident is ignoring the bell.)"
]

func _ready() -> void:
	if not audio_player:
		audio_player = AudioStreamPlayer3D.new()
		audio_player.max_distance = 15.0
		add_child(audio_player)
	
	if not interactable:
		interactable = find_child("DoorbellInteractable", true, false) as InteractableComponent
	if interactable:
		interactable.verb = InteractableComponent.InteractionVerb.RING
		interactable.prompt_target_name = resident_name + " Doorbell"

func on_interacted(interactor: Node3D, verb: int) -> Dictionary:
	return ring_doorbell(interactor)

func ring_doorbell(interactor: Node3D = null) -> Dictionary:
	ring_count += 1
	
	# Play chime
	if audio_player:
		audio_player.stream = ProceduralCinematicAudio.create_doorbell_chime()
		audio_player.play()

	var response_text: String = ""
	if household_manager and household_manager.has_method("ring_doorbell"):
		var mgr_res = household_manager.ring_doorbell(household_id, current_hour, interactor)
		response_text = mgr_res.get("response", "")
	elif not is_resident_home:
		response_text = "... (No answer. Nobody appears to be home.)"
	else:
		if ring_count == 1:
			response_text = RESPONSES[0]
		elif ring_count == 2:
			response_text = RESPONSES[1]
		elif ring_count == 3:
			response_text = RESPONSES[2]
		else:
			response_text = RESPONSES[3]


	emit_signal("doorbell_rung", ring_count, response_text)

	return {
		"household_id": household_id,
		"address": address,
		"resident_name": resident_name,
		"ring_count": ring_count,
		"response": response_text
	}

func reset_annoyance() -> void:
	ring_count = 0

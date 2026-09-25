class_name ResidentialHouse
extends Node3D

signal doorbell_rung(ring_count: int, response_text: String)
signal door_opened(resident_name: String, response_text: String)
signal door_closed()
signal hospitality_gift_awarded(item_name: String, amount: int)

@export var household_id: String = "HOUSE_SATO_01"
@export var address: String = "Minato-Kasumi 2-Chome 4-1"
@export var resident_name: String = "Mika Sato"
@export var is_resident_home: bool = true
@export var hospitality_enabled: bool = false

const InteractableComponent = preload("res://scripts/interaction/interactable_component.gd")
const ProceduralCinematicAudio = preload("res://scripts/audio/procedural_cinematic_audio.gd")

var ring_count: int = 0
var audio_player: AudioStreamPlayer3D = null
var door_pivot: Node3D = null
var is_door_open: bool = false
var hospitality_given: bool = false

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

	_setup_door_mesh()

	if not interactable:
		interactable = find_child("DoorbellInteractable", true, false) as InteractableComponent
	if interactable:
		interactable.verb = InteractableComponent.InteractionVerb.RING
		interactable.prompt_target_name = resident_name + " Doorbell"

func _setup_door_mesh() -> void:
	if not door_pivot:
		door_pivot = find_child("DoorPivot", true, false) as Node3D
		if not door_pivot:
			door_pivot = Node3D.new()
			door_pivot.name = "DoorPivot"
			door_pivot.position = Vector3(-0.45, 0.0, 0.0)
			add_child(door_pivot)

			var door_panel := MeshInstance3D.new()
			door_panel.name = "DoorPanelMesh"
			var box := BoxMesh.new()
			box.size = Vector3(0.9, 2.1, 0.06)
			door_panel.mesh = box
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0.24, 0.16, 0.10, 1.0) # Traditional stained cedar
			mat.roughness = 0.5
			door_panel.material_override = mat
			door_panel.position = Vector3(0.45, 1.05, 0.0)
			door_pivot.add_child(door_panel)

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
		if current_hour >= 22 or current_hour < 6:
			response_text = "Who is it at this ungodly hour?! The streets aren't safe at night, boy, go home!"
		elif ring_count == 1:
			response_text = RESPONSES[0]
		elif ring_count == 2:
			response_text = RESPONSES[1]
		elif ring_count == 3:
			response_text = RESPONSES[2]
		else:
			response_text = RESPONSES[3]

	emit_signal("doorbell_rung", ring_count, response_text)

	# If resident is home and not excessively annoyed, open the door to greet the player
	if is_resident_home and ring_count <= 2:
		open_door(interactor, response_text)

	return {
		"household_id": household_id,
		"address": address,
		"resident_name": resident_name,
		"ring_count": ring_count,
		"response": response_text,
		"door_opened": is_door_open
	}

func open_door(interactor: Node3D = null, custom_response: String = "") -> void:
	if is_door_open:
		return
	is_door_open = true
	_setup_door_mesh()

	if door_pivot:
		var tree := get_tree() if is_inside_tree() else null
		if tree:
			var tween := tree.create_tween()
			tween.tween_property(door_pivot, "rotation:y", deg_to_rad(-75.0), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		else:
			door_pivot.rotation.y = deg_to_rad(-75.0)

	# Play creak open audio
	if is_inside_tree():
		var audio := AudioStreamPlayer.new()
		add_child(audio)
		audio.stream = ProceduralCinematicAudio.create_door_creak_open_sfx()
		audio.play()
		audio.finished.connect(func(): audio.queue_free())

	var txt = custom_response if not custom_response.is_empty() else RESPONSES[0]
	emit_signal("door_opened", resident_name, txt)

	# Daytime Hospitality Gift: Neighbor offers onigiri on first cordial greeting if hospitality_enabled
	if hospitality_enabled and current_hour >= 9 and current_hour <= 18 and not hospitality_given:
		hospitality_given = true
		if interactor:
			var inv = interactor.get("inventory")
			if not inv and interactor.has_method("get_inventory"):
				inv = interactor.get_inventory()
			if inv and inv.has_method("add_item"):
				inv.add_item("onigiri", 1)
		emit_signal("hospitality_gift_awarded", "onigiri", 1)

func close_door() -> void:
	if not is_door_open:
		return
	is_door_open = false
	if door_pivot:
		var tree := get_tree() if is_inside_tree() else null
		if tree:
			var tween := tree.create_tween()
			tween.tween_property(door_pivot, "rotation:y", 0.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		else:
			door_pivot.rotation.y = 0.0
	emit_signal("door_closed")

func reset_annoyance() -> void:
	ring_count = 0
	hospitality_given = false
	close_door()

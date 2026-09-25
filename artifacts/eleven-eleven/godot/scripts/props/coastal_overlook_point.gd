class_name CoastalOverlookPoint
extends Node3D

## Minato-Kasumi Seawall Panoramic Overlook Point (Genshin / NieR Standard)
## Allows Echo to stand at the seawall railing, gaze out over the animated Gerstner ocean waves,
## and experience contemplative narrative resonance while restoring mental stability.

signal ocean_gazed(dialogue_lines: Array)

const InteractableComponent = preload("res://scripts/interaction/interactable_component.gd")
const ProceduralCinematicAudio = preload("res://scripts/audio/procedural_cinematic_audio.gd")

@export var overlook_name: String = "Pacific Ocean Horizon // 太平洋の水平線"
var gaze_count: int = 0
var is_gazing: bool = false
var interactable: InteractableComponent = null

func _ready() -> void:
	ensure_setup()

func ensure_setup() -> void:
	if interactable != null:
		return
	interactable = find_child("InteractableComponent", true, false)
	if not interactable:
		interactable = InteractableComponent.new()
		interactable.name = "InteractableComponent"
		interactable.verb = InteractableComponent.InteractionVerb.INSPECT
		interactable.prompt_target_name = "Pacific Ocean Horizon"
		interactable.interaction_range = 3.0
		add_child(interactable)
		
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(4.0, 2.0, 3.0)
		col.shape = shape
		interactable.add_child(col)

	if not interactable.interaction_requested.is_connected(_on_interaction):
		interactable.interaction_requested.connect(_on_interaction)

func _on_interaction(interactor: Node3D) -> void:
	trigger_ocean_gaze(interactor)

func trigger_ocean_gaze(interactor: Node3D) -> Dictionary:
	gaze_count += 1
	is_gazing = true

	# Restore mental energy / stamina on interactor
	if interactor and interactor.get("stamina") != null:
		var max_stam: float = 100.0
		if interactor.get("MAX_STAMINA") != null:
			max_stam = float(interactor.get("MAX_STAMINA"))
		interactor.stamina = minf(max_stam, interactor.stamina + 35.0)
		if interactor.has_signal("stamina_changed"):
			interactor.emit_signal("stamina_changed", interactor.stamina, max_stam)

	# Construct authentic contemplative dialogue lines
	var dialogue_lines: Array = [
		{
			"speaker": "ECHO",
			"speaker_color": Color(0.72, 0.85, 1.0, 1.0),
			"text": "The salt in the air... The stasis pod in Sector 11 was artificial, but this ocean has always been here."
		},
		{
			"speaker": "FLOATING POD",
			"speaker_color": Color(0.0, 0.94, 1.0, 1.0),
			"text": "Biometric sensor telemetry: neural stress decreased by 22%. Pacific wave frequency (0.18 Hz) harmonizing with synaptic pulse."
		},
		{
			"speaker": "ECHO",
			"speaker_color": Color(0.72, 0.85, 1.0, 1.0),
			"text": "Yuki and I used to sit on this very seawall after middle school exams. Her notebook... she left something at my house."
		}
	]

	emit_signal("ocean_gazed", dialogue_lines)

	return {
		"success": true,
		"gaze_count": gaze_count,
		"stamina_restored": 35.0,
		"dialogue": dialogue_lines
	}

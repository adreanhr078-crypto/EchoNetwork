class_name TownNoticeBoard
extends Node3D

## Minato-Kasumi Community Bulletin Board (Kairanban / 回覧板・掲示板)
## Displays local neighborhood news, security warnings regarding Sector 11, and Yuki's missing person notice.

signal notice_read(notice_id: String, title: String, content: String)

const InteractableComponent = preload("res://scripts/interaction/interactable_component.gd")

var interactable: InteractableComponent = null
var current_notice_index: int = 0

const NOTICES: Array = [
	{
		"id": "NOTICE_MISSING_YUKI",
		"title": "MISSING PERSON // 尋ね人 — TACHIBANA YUKI",
		"date": "September 18",
		"content": "Yuki Tachibana (Age 17, Kasumi High 3rd Year). Last seen near Minato 2-Chome seawall carrying a vintage 35mm camera and cyan hair ribbon. Please report any sighting to Kasumi Mart or Sato Residence."
	},
	{
		"id": "NOTICE_ANOMALOUS_POWER",
		"title": "MUNICIPAL ADVISORY // 夜間変電所異常",
		"date": "September 21",
		"content": "Sub-station 11 anomaly: Abnormal electromagnetic spikes and localized structural tremor recorded. Citizens are advised to avoid old industrial tunnels and report flickering sodium lamps."
	},
	{
		"id": "NOTICE_HIGH_TIDE",
		"title": "COASTAL WEATHER // 満潮注意報",
		"date": "September 24",
		"content": "Pacific spring tide warning: High waves anticipated along the Minato seawall promenade. Do not climb beyond the concrete tetra-pods after sunset."
	}
]

func _ready() -> void:
	ensure_setup()

func ensure_setup() -> void:
	if interactable != null:
		return
	interactable = find_child("InteractableComponent", true, false)
	if not interactable:
		interactable = InteractableComponent.new()
		interactable.name = "InteractableComponent"
		interactable.verb = InteractableComponent.InteractionVerb.READ
		interactable.prompt_target_name = "Town Bulletin Board // 掲示板"
		interactable.interaction_range = 2.6
		add_child(interactable)
		
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(2.5, 2.0, 1.5)
		col.shape = shape
		interactable.add_child(col)

	if not interactable.interaction_requested.is_connected(_on_interaction):
		interactable.interaction_requested.connect(_on_interaction)

func _on_interaction(_interactor: Node3D) -> void:
	read_next_notice()

func read_next_notice() -> Dictionary:
	var notice: Dictionary = NOTICES[current_notice_index]
	current_notice_index = (current_notice_index + 1) % NOTICES.size()
	
	emit_signal("notice_read", notice["id"], notice["title"], notice["content"])
	
	return notice

func get_notice_count() -> int:
	return NOTICES.size()

func get_notice_by_id(target_id: String) -> Dictionary:
	for n in NOTICES:
		if n["id"] == target_id:
			return n
	return {}

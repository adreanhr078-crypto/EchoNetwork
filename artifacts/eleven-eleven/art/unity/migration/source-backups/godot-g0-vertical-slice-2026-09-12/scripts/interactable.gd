extends Node3D

signal interacted(item: Node3D)

@export var display_name := "Interactable"
@export var kind := "clue"
var activated := false


func activate() -> void:
	if activated and kind != "door":
		return
	activated = true
	interacted.emit(self)


func set_active(value: bool) -> void:
	activated = value
	var marker := get_node_or_null("Marker") as MeshInstance3D
	if marker:
		marker.scale = Vector3.ONE * (1.18 if value else 1.0)


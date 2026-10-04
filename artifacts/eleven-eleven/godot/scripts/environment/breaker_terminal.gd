extends Node3D

## Breaker Terminal for Room 7 (Core Reactor & Power Station)
## Implements interactive interface for Circuit Breakers A & B.

var breaker_id: String = ""

func _ready() -> void:
	if has_meta("breaker_id"):
		breaker_id = get_meta("breaker_id")

func trigger_interaction(_interactor: Node = null) -> Dictionary:
	var room := get_parent()
	if room and room.has_method("activate_breaker"):
		return room.activate_breaker(breaker_id)
	return {"success": false, "reason": "no_room_parent"}

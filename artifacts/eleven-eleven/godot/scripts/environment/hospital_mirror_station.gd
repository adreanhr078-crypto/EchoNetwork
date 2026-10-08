extends StaticBody3D

## Interactive Vanity & Washbasin Mirror Station for Room 12 (Hospital Bedside Room)
## Implements the standardized interactive contract for neck mark inspection and Chapter 1 climax.

signal player_entered_range(player: Node3D)
signal player_exited_range(player: Node3D)

var room: Node3D
var inspected := false

var _interaction_area: Area3D
var _area_shape: CollisionShape3D

func _ready() -> void:
	room = get_parent()
	set_meta("interaction_label_ar","المرآة")
	set_meta("interaction_label_en","Mirror")
	_setup_interaction_area()

func get_interaction_verb(language:String) -> String:
	return "افحص عنقك" if language=="ar" else "Inspect your neck"

func _setup_interaction_area() -> void:
	_interaction_area = Area3D.new()
	_interaction_area.name = "InteractionArea"
	_interaction_area.collision_layer = 0
	_interaction_area.collision_mask = 1 # Actual EchoPlayer collision layer
	
	_area_shape = CollisionShape3D.new()
	_area_shape.name = "AreaCollisionShape3D"
	var sphere := SphereShape3D.new()
	sphere.radius = 1.8
	_area_shape.shape = sphere
	
	_interaction_area.add_child(_area_shape)
	add_child(_interaction_area)
	
	_interaction_area.body_entered.connect(_on_body_entered)
	_interaction_area.body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node3D) -> void:
	if body.has_method("register_nearby_interactable"):
		body.register_nearby_interactable(self)
	player_entered_range.emit(body)

func _on_body_exited(body: Node3D) -> void:
	if body.has_method("unregister_nearby_interactable"):
		body.unregister_nearby_interactable(self)
	player_exited_range.emit(body)

func trigger_interaction(interactor: Node = null) -> Dictionary:
	if room and room.has_method("execute_mirror_inspection"):
		var result: Dictionary = room.execute_mirror_inspection(interactor)
		inspected = result.get("success", false)
		return result
	
	inspected = true
	return {
		"success": true,
		"mark_revealed": true,
		"label": "EX-011",
		"message": "Neck inspection reveals cold micro-laser mark EX-011"
	}

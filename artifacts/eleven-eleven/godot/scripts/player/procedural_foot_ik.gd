class_name ProceduralFootIK
extends Node3D

## Boots a skeleton modifier for foot contacts on the animated leg bones.
## Physics queries happen here because this child runs after Echo's movement step.

const FootGroundingModifier = preload("res://scripts/player/foot_grounding_modifier.gd")

@export var enabled: bool = false
@export_flags_3d_physics var ground_collision_mask: int = 1

var left_ray: RayCast3D = RayCast3D.new()
var right_ray: RayCast3D = RayCast3D.new()
var _modifier: Node

func _ready() -> void:
	if enabled:
		call_deferred("_attach_modifier")

func _physics_process(delta: float) -> void:
	if enabled and is_instance_valid(_modifier):
		_modifier.call("update_foot_contacts", delta)

func _attach_modifier() -> void:
	var player := get_parent() as CharacterBody3D
	if not player:
		return
	var skeleton := player.find_child("Skeleton3D", true, false) as Skeleton3D
	if not skeleton:
		return
	for child in skeleton.get_children():
		if child.get_script() == FootGroundingModifier:
			_modifier = child
			_modifier.call("configure", player, ground_collision_mask)
			return
	_modifier = FootGroundingModifier.new()
	_modifier.name = "FootGroundingModifier"
	_modifier.call("configure", player, ground_collision_mask)
	skeleton.add_child(_modifier)

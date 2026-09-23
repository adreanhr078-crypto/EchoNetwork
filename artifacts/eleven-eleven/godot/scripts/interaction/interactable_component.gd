class_name InteractableComponent
extends Area3D

enum InteractionVerb {
	TALK,
	RING,
	BUY,
	DRINK,
	INSPECT,
	OPEN,
	ENTER,
	RIDE,
	CLEAN,
	REST,
	IGNITE
}

signal interaction_requested(interactor: Node3D)
signal interaction_executed(interactor: Node3D, verb: int)
signal focused()
signal unfocused()

@export var verb: InteractionVerb = InteractionVerb.INSPECT
@export var prompt_target_name: String = "Object"
@export var interaction_range: float = 2.4
@export var is_enabled: bool = true

var is_focused: bool = false
var current_interactor: Node3D = null

func _ready() -> void:
	# Ensure collision layer for interaction queries (layer 8 / bit 7)
	collision_layer = 128
	collision_mask = 1 # Player layer
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func get_verb_string() -> String:
	match verb:
		InteractionVerb.TALK: return "TALK"
		InteractionVerb.RING: return "RING DOORBELL"
		InteractionVerb.BUY: return "BUY"
		InteractionVerb.DRINK: return "DRINK"
		InteractionVerb.INSPECT: return "INSPECT"
		InteractionVerb.OPEN: return "OPEN"
		InteractionVerb.ENTER: return "ENTER"
		InteractionVerb.RIDE: return "RIDE"
		InteractionVerb.CLEAN: return "CLEAN"
		InteractionVerb.REST: return "REST / SLEEP"
		InteractionVerb.IGNITE: return "IGNITE"
		_: return "INTERACT"


func get_full_prompt() -> String:
	return "[E] " + get_verb_string() + " — " + prompt_target_name

func trigger_interaction(interactor: Node3D) -> Dictionary:
	if not is_enabled:
		return {"success": false, "reason": "disabled"}
	
	emit_signal("interaction_requested", interactor)
	emit_signal("interaction_executed", interactor, verb)
	
	var parent = get_parent()
	var result_data = {}
	if parent and parent.has_method("on_interacted"):
		result_data = parent.on_interacted(interactor, verb)
	
	return {"success": true, "verb": verb, "target": prompt_target_name, "data": result_data}

func _on_body_entered(body: Node3D) -> void:
	if not is_enabled:
		return
	if body.is_in_group("player") or body.name == "EchoPlayer" or body.has_method("perform_attack"):
		current_interactor = body
		is_focused = true
		emit_signal("focused")
		if body.has_method("register_nearby_interactable"):
			body.register_nearby_interactable(self)

func _on_body_exited(body: Node3D) -> void:
	if body == current_interactor:
		is_focused = false
		current_interactor = null
		emit_signal("unfocused")
		if body.has_method("unregister_nearby_interactable"):
			body.unregister_nearby_interactable(self)

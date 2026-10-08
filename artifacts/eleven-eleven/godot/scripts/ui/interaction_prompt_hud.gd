class_name InteractionPromptHUD
extends Control

const InteractableComponent = preload("res://scripts/interaction/interactable_component.gd")

@onready var prompt_panel: Panel = $PromptPanel if has_node("PromptPanel") else null
@onready var prompt_label: Label = $PromptPanel/PromptLabel if has_node("PromptPanel/PromptLabel") else null

var current_interactable: Node = null
var presentation_language := "ar"
var touch_mode := false

func set_presentation_language(language: String) -> void:
	presentation_language = language
	layout_direction = Control.LAYOUT_DIRECTION_RTL if language == "ar" else Control.LAYOUT_DIRECTION_LTR
	if visible and is_instance_valid(current_interactable): show_prompt(current_interactable)

func _ready() -> void:
	visible = false

func show_prompt(interactable: Node) -> void:
	current_interactable = interactable
	if not prompt_panel:
		prompt_panel = find_child("PromptPanel", true, false) as Panel
	if not prompt_label:
		prompt_label = find_child("PromptLabel", true, false) as Label
	
	if prompt_label and interactable:
		var verb := "تفاعل" if presentation_language == "ar" else "Interact"
		var target_name := String(interactable.get_meta("interaction_label_" + presentation_language, "لوحة التحكم" if presentation_language == "ar" else "Control panel"))
		if interactable.has_method("get_interaction_verb"):
			verb=interactable.get_interaction_verb(presentation_language)
		elif interactable.has_method("get_verb_string"):
			verb = interactable.get_verb_string()
		if interactable is InteractableComponent:
			if presentation_language == "ar":
				verb = "افحص" if interactable.verb == InteractableComponent.InteractionVerb.INSPECT else "تفاعل"
			target_name = interactable.prompt_target_name
		var key := ("المس" if presentation_language == "ar" else "Tap") if touch_mode else "E"
		prompt_label.text = "[%s] %s · %s" % [key, verb, target_name]
	
	visible = true

func hide_prompt() -> void:
	current_interactable = null
	visible = false

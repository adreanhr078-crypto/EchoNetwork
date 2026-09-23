class_name InteractionPromptHUD
extends Control

const InteractableComponent = preload("res://scripts/interaction/interactable_component.gd")

@onready var prompt_panel: Panel = $PromptPanel if has_node("PromptPanel") else null
@onready var prompt_label: Label = $PromptPanel/PromptLabel if has_node("PromptPanel/PromptLabel") else null

var current_interactable: Node = null

func _ready() -> void:
	visible = false

func show_prompt(interactable: Node) -> void:
	current_interactable = interactable
	if not prompt_panel:
		prompt_panel = find_child("PromptPanel", true, false) as Panel
	if not prompt_label:
		prompt_label = find_child("PromptLabel", true, false) as Label
	
	if prompt_label and interactable:
		prompt_label.text = interactable.get_full_prompt()
	
	visible = true

func hide_prompt() -> void:
	current_interactable = null
	visible = false

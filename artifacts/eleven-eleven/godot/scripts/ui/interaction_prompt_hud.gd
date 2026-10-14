class_name InteractionPromptHUD
extends Control

const InteractableComponent = preload("res://scripts/interaction/interactable_component.gd")

@onready var prompt_panel: Panel = $PromptPanel if has_node("PromptPanel") else null
@onready var prompt_label: Label = $PromptPanel/PromptLabel if has_node("PromptPanel/PromptLabel") else null

var current_interactable: Node = null
var presentation_language := "ar"
var touch_mode := false
var _transition: Tween
var _presentation_revision := 0
var reduced_motion := false:
	set(value):
		reduced_motion = value
		if value and is_node_ready():
			_cancel_transition()
			visible = is_instance_valid(current_interactable)
			modulate.a = 1.0 if visible else 0.0

func _cancel_transition() -> void:
	_presentation_revision += 1
	if _transition and _transition.is_valid(): _transition.kill()

func _finish_departure(revision: int) -> void:
	if revision == _presentation_revision and not is_instance_valid(current_interactable): visible = false

func set_presentation_language(language: String) -> void:
	presentation_language = language
	layout_direction = Control.LAYOUT_DIRECTION_RTL if language == "ar" else Control.LAYOUT_DIRECTION_LTR
	if visible and is_instance_valid(current_interactable): show_prompt(current_interactable)

func _ready() -> void:
	visible = false

func show_prompt(interactable: Node) -> void:
	if not is_instance_valid(interactable):
		hide_prompt()
		return
	var new_target := current_interactable != interactable or not visible
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
	if new_target:
		_cancel_transition()
		modulate.a = 1.0 if reduced_motion else 0.0
		if not reduced_motion:
			_transition = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			_transition.tween_property(self, "modulate:a", 1.0, 0.16)

func hide_prompt() -> void:
	if current_interactable == null: return
	current_interactable = null
	_cancel_transition()
	if reduced_motion:
		visible = false
	else:
		_transition = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_transition.tween_property(self, "modulate:a", 0.0, 0.12)
		_transition.finished.connect(_finish_departure.bind(_presentation_revision))

extends StaticBody3D

## Zero Contract Altar for Room 10/11 (Dr. Kinja's Lab & Zero Contract Chamber)
## Implements interactive interface for accepting Zero's shadow contract.
var verb := InteractableComponent.InteractionVerb.TALK
var prompt_target_name := "أثر معتم"
var presentation_language := "ar"

func _ready() -> void:
	set_presentation_language(presentation_language)

func set_presentation_language(language: String) -> void:
	presentation_language="ar" if language=="ar" else "en"
	var revealed: bool=get_parent()!=null and get_parent().get("confrontation_done")==true
	prompt_target_name=("زيرو" if presentation_language=="ar" else "Zero") if revealed else ("أثر معتم" if presentation_language=="ar" else "Dark trace")
	set_meta("interaction_label_ar","عقد زيرو" if revealed else "أثر معتم")
	set_meta("interaction_label_en","Zero's pact" if revealed else "Dark trace")

func get_interaction_verb(language: String) -> String:
	return "واجهه" if language=="ar" else "Confront"

func get_verb_string() -> String:
	return "واجه زيرو" if presentation_language=="ar" else "Confront Zero"

func trigger_interaction(_interactor: Node = null) -> Dictionary:
	var room := get_parent()
	if room and room.has_method("request_contract_decision"):
		return room.request_contract_decision()
	return {"success": false, "reason": "no_room_parent"}

extends Node3D
class_name OpeningEvidence

signal evidence_inspected(evidence_id: String)

@export_enum("clock", "photo") var evidence_id := "clock"
var inspected := false

func _ready() -> void:
	$ClockFace.visible = evidence_id == "clock"
	$ClockHands.visible = evidence_id == "clock"
	$PhotoFrame.visible = evidence_id == "photo"
	$PhotoTrace.visible = evidence_id == "photo"
	$EvidenceLabel.text = "11:11" if evidence_id == "clock" else "// 11 //"
	$InteractionArea.prompt_target_name = "11:11 CLOCK" if evidence_id == "clock" else "TORN PHOTOGRAPH"

func on_interacted(_interactor: Node3D, _verb: int) -> Dictionary:
	if inspected:
		return {"inspected": false}
	inspected = true
	$InteractionArea.is_enabled = false
	var interactor = $InteractionArea.current_interactor
	if interactor and interactor.has_method("unregister_nearby_interactable"):
		interactor.unregister_nearby_interactable($InteractionArea)
	evidence_inspected.emit(evidence_id)
	return {"inspected": true, "evidenceId": evidence_id}

class_name HospitalEgressHatch
extends Node3D

signal hatch_investigated()
signal hatch_unlocked()
signal hatch_breached()

enum HatchState {
	LOCKED_SEALED,
	ANOMALY_EXPOSED,
	BREACHED_OPEN
}

var current_state: HatchState = HatchState.LOCKED_SEALED

@onready var lock_light: OmniLight3D = find_child("LockLight", true, false) as OmniLight3D
@onready var hatch_door: Node3D = find_child("HatchDoor", true, false) as Node3D
@onready var interaction_area: Area3D = find_child("InteractionArea", true, false) as Area3D

func _ready() -> void:
	_update_visuals()
	if interaction_area:
		interaction_area.body_entered.connect(_on_body_entered)

func _update_visuals() -> void:
	if not lock_light:
		return
	match current_state:
		HatchState.LOCKED_SEALED:
			lock_light.light_color = Color(1.0, 0.1, 0.2, 1.0)
			lock_light.light_energy = 2.0
		HatchState.ANOMALY_EXPOSED:
			lock_light.light_color = Color(0.1, 0.9, 1.0, 1.0)
			lock_light.light_energy = 3.5
		HatchState.BREACHED_OPEN:
			lock_light.light_color = Color(0.2, 1.0, 0.4, 1.0)
			lock_light.light_energy = 4.0

func expose_simulation_anomaly() -> void:
	current_state = HatchState.ANOMALY_EXPOSED
	_update_visuals()
	emit_signal("hatch_unlocked")

func breach_hatch() -> void:
	if current_state == HatchState.BREACHED_OPEN:
		return
	current_state = HatchState.BREACHED_OPEN
	_update_visuals()
	if hatch_door:
		var tree = get_tree() if is_inside_tree() else null
		if tree:
			var tween = tree.create_tween()
			tween.tween_property(hatch_door, "position:y", hatch_door.position.y + 2.2, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		else:
			hatch_door.position.y += 2.2
	emit_signal("hatch_breached")

func _on_body_entered(body: Node) -> void:
	if body is EchoPlayer:
		emit_signal("hatch_investigated")
		if current_state == HatchState.ANOMALY_EXPOSED:
			breach_hatch()

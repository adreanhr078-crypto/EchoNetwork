extends Node3D
## Review-only pressure band on the floor of the existing Room 01.

signal crossing_finished(result: Dictionary)

const ENTRY_Z := -12.5
const EXIT_Z := -13.9
const RETRY_Z := -11.8
const VALVE_POS := Vector3(2.8, 0.8, -11.9)
const HIGH_SECONDS := 3.6
const LOW_SECONDS := 2.8
const VENT_SECONDS := 5.5
const WHEEL = preload("res://assets/environments/maintenance_stormworks/stormworks_precision_wheel_v1.glb")

var player: EchoPlayer
var arabic := true
var elapsed := 0.0
var vent_remaining := 0.0
var attempts := 0
var failures := 0
var successful_route := ""
var _first_choice := ""
var _first_choice_seconds := 0.0
var _valve_uses := 0
var valve: InteractableComponent
var _in_band := false
var _used_valve := false
var _status: Label3D
var _floor_material: ShaderMaterial
var _displayed_state := ""

func _ready() -> void:
	_status = _world_label(Vector3(0, 2.55, ENTRY_Z), 0.0045)
	_floor_material = ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded;
uniform vec4 tint : source_color;
void fragment() { ALBEDO = tint.rgb; }
"""
	_floor_material.shader = shader
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(17.5, 0.08)
	for z in [ENTRY_Z, EXIT_Z]:
		var boundary := MeshInstance3D.new()
		boundary.mesh = mesh
		boundary.material_override = _floor_material
		boundary.position = Vector3(0, 0.03, z)
		add_child(boundary)
	var wheel := WHEEL.instantiate() as Node3D
	wheel.position = VALVE_POS
	add_child(wheel)
	var valve_label := _world_label(VALVE_POS + Vector3.UP * 1.05, 0.0032)
	valve_label.text = "صمام تنفيس" if arabic else "VENT VALVE"
	valve = InteractableComponent.new()
	valve.verb = InteractableComponent.InteractionVerb.OPEN
	valve.prompt_target_name = valve_label.text
	valve.set_meta("interaction_verb_ar", "نفّس الضغط")
	valve.set_meta("interaction_verb_en", "Vent pressure")
	valve.position = VALVE_POS
	var trigger := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.05
	trigger.shape = sphere
	valve.add_child(trigger)
	valve.interaction_requested.connect(_open_valve)
	add_child(valve)
	_update_readout(false)

func _world_label(at: Vector3, scale_per_pixel: float) -> Label3D:
	var label := Label3D.new()
	label.position = at
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.pixel_size = scale_per_pixel
	label.font_size = 36
	label.outline_size = 9
	add_child(label)
	return label

func can_cross() -> bool:
	return vent_remaining > 0.0 or fposmod(elapsed, HIGH_SECONDS + LOW_SECONDS) >= HIGH_SECONDS

func _open_valve(interactor: Node3D) -> void:
	if interactor != player or valve.current_interactor != player or vent_remaining > 0.0:
		return
	vent_remaining = VENT_SECONDS
	_valve_uses += 1
	_record_first_choice("valve")
	valve.is_enabled = false
	_update_readout(false)

func _record_first_choice(choice: String) -> void:
	if _first_choice.is_empty():
		_first_choice = choice
		_first_choice_seconds = elapsed

func _physics_process(delta: float) -> void:
	elapsed += delta
	vent_remaining = maxf(0.0, vent_remaining - delta)
	valve.is_enabled = vent_remaining == 0.0
	var z := player.global_position.z
	if z > ENTRY_Z:
		_in_band = false
		_update_readout(false)
		return
	if not _in_band:
		_in_band = true
		_used_valve = vent_remaining > 0.0
		attempts += 1
		_record_first_choice("cross")
	if not can_cross():
		failures += 1
		_in_band = false
		player.velocity = Vector3.ZERO
		player.global_position = Vector3(player.global_position.x, 0.05, RETRY_Z)
		player.reset_physics_interpolation()
		_update_readout(true)
	elif z <= EXIT_Z:
		successful_route = "valve" if _used_valve else "timing"
		valve.is_enabled = false
		_update_readout(false)
		set_physics_process(false)
		crossing_finished.emit({
			"route": successful_route,
			"attempts": attempts,
			"failures": failures,
			"valve_uses": _valve_uses,
			"first_choice": _first_choice,
			"first_choice_seconds": snappedf(_first_choice_seconds, 0.001),
			"completed_seconds": snappedf(elapsed, 0.001)
		})
	else:
		_update_readout(false)

func _update_readout(failed: bool) -> void:
	var state := "high"
	var hint := "ضغط مرتفع • انتظر أو افتح الصمام" if arabic else "HIGH PRESSURE • WAIT OR VENT"
	var tint := Color(1, 0.65, 0.42)
	if not successful_route.is_empty():
		state = "clear"
		hint = "الممر مفتوح" if arabic else "PASSAGE CLEAR"
		tint = Color(0.67, 1, 0.83)
	elif can_cross():
		state = "vented" if vent_remaining > 0.0 else "low"
		if vent_remaining > 0.0:
			hint = "تم التنفيس • اعبر الآن" if arabic else "VENTED • CROSS NOW"
		else:
			hint = "ضغط منخفض • اعبر الآن" if arabic else "LOW PRESSURE • CROSS NOW"
		tint = Color(0.67, 1, 0.83)
	elif failed or _displayed_state == "retry":
		state = "retry"
		hint = "الممر آمن هنا • انتظر انخفاض الضغط" if arabic else "SAFE HERE • WAIT FOR LOW PRESSURE"
	if state != _displayed_state:
		_displayed_state = state
		_status.text = hint
		_status.modulate = tint
		_floor_material.set_shader_parameter("tint", tint)

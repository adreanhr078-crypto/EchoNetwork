extends Node3D
## Optional course prototype. Air acceleration and its cue share the same clock.

const CALM_SECONDS := 2.25
const GUST_SECONDS := 1.25
const JUMP_LEAD_SECONDS := .85
const FORCE_MPS2 := 4.6
const ZONE := AABB(Vector3(-4.65, 1.15, -7.65), Vector3(3.3, 3.35, 2.25))

var player: EchoPlayer
var eligible: Callable
var arabic := true
var elapsed := 0.0
var applied_ticks := 0
var gust_active: bool:
	get:
		return _phase_seconds() >= CALM_SECONDS
var _cue: Label3D
var _cue_state := ""

func _ready() -> void:
	process_physics_priority = -10
	_cue = Label3D.new()
	_cue.position = Vector3(-2.45, 3.75, -6.28)
	_cue.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_cue.pixel_size = .0036
	_cue.font_size = 36
	_cue.outline_size = 8
	add_child(_cue)
	_refresh_cue()

func _physics_process(delta: float) -> void:
	var enabled: bool = not eligible.is_valid() or eligible.call()
	_cue.visible = enabled
	if not enabled:
		return
	elapsed += delta
	_refresh_cue()
	if not gust_active or player.is_on_floor() or player.control_locked or player.traversal.is_climbing() or player.surface_motor.hanging:
		return
	if not ZONE.has_point(to_local(player.global_position)):
		return
	player.velocity += global_basis.x.normalized() * (FORCE_MPS2 * delta)
	applied_ticks += 1

func _phase_seconds() -> float:
	return fposmod(elapsed, CALM_SECONDS + GUST_SECONDS)

func _refresh_cue() -> void:
	var phase := _phase_seconds()
	var state := "gust" if phase >= CALM_SECONDS else ("wait" if phase >= CALM_SECONDS - JUMP_LEAD_SECONDS else "calm")
	if state == _cue_state:
		return
	_cue_state = state
	if state == "gust":
		_cue.text = "ريح تدفع يمينًا • انتظر هدوءها" if arabic else "CROSSWIND RIGHT → WAIT FOR CALM"
		_cue.modulate = Color(1.0, .69, .43)
	elif state == "wait":
		_cue.text = "هبة قريبة • تمهّل" if arabic else "GUST APPROACHING • WAIT"
		_cue.modulate = Color(1.0, .86, .57)
	else:
		_cue.text = "الريح هادئة • اقفز" if arabic else "CALM • JUMP"
		_cue.modulate = Color(.68, 1.0, .86)

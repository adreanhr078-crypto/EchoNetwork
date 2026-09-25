class_name EchoFacialController
extends Node

## 11.11 Echo Facial Expression & Auto-Blink Controller
## Drives facial blend shapes (Blink_L, Blink_R, Brow_Frown, Mouth_Grimace)
## with natural randomized blinking, combat focus, and visceral damage reactions.

@export var mesh_instance_path: NodePath
var mesh_instance: MeshInstance3D = null

var blink_timer: float = 3.5
var next_blink_interval: float = 3.2
var is_blinking: bool = false
var blink_tween: Tween = null
var expression_tween: Tween = null

var current_focus: float = 0.0
var current_grimace: float = 0.0

func _ready() -> void:
	if mesh_instance_path and not mesh_instance:
		mesh_instance = get_node_or_null(mesh_instance_path) as MeshInstance3D
	if not mesh_instance:
		_find_mesh_instance(get_parent())
	_reset_blink_timer()

func _find_mesh_instance(node: Node) -> void:
	if not node:
		return
	if node is MeshInstance3D and node.mesh and node.mesh.get_blend_shape_count() > 0:
		mesh_instance = node
		return
	for child in node.get_children():
		_find_mesh_instance(child)
		if mesh_instance:
			return

func _process(delta: float) -> void:
	if not mesh_instance:
		return
	
	blink_timer -= delta
	if blink_timer <= 0.0 and not is_blinking:
		trigger_blink()

func _reset_blink_timer() -> void:
	blink_timer = randf_range(2.8, 5.0)

func trigger_blink(duration: float = 0.14) -> void:
	if not mesh_instance:
		return
	is_blinking = true
	if blink_tween and blink_tween.is_running():
		blink_tween.kill()
		
	var close_time: float = duration * 0.42
	var open_time: float = duration * 0.58
	
	blink_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	blink_tween.tween_method(func(v: float):
		_set_shape("Blink_L", v)
		_set_shape("Blink_R", v)
	, 0.0, 1.0, close_time)
	
	blink_tween.tween_method(func(v: float):
		_set_shape("Blink_L", v)
		_set_shape("Blink_R", v)
	, 1.0, 0.0, open_time)
	
	blink_tween.finished.connect(func():
		is_blinking = false
		# 18% chance of immediate natural double-blink
		if randf() < 0.18:
			blink_timer = 0.12
		else:
			_reset_blink_timer()
	)

func set_combat_focus(focus_amount: float, duration: float = 0.25) -> void:
	if not mesh_instance:
		return
	var target = clampf(focus_amount, 0.0, 1.0)
	if expression_tween and expression_tween.is_running():
		expression_tween.kill()
	expression_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	expression_tween.tween_method(func(v: float):
		current_focus = v
		_set_shape("Brow_Frown", v)
	, current_focus, target, duration)

func trigger_damage_grimace(intensity: float = 0.85, duration: float = 0.35) -> void:
	if not mesh_instance:
		return
	var tween = create_tween().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_method(func(v: float):
		current_grimace = v
		_set_shape("Mouth_Grimace", v)
		_set_shape("Blink_L", minf(1.0, v * 0.7))
		_set_shape("Blink_R", minf(1.0, v * 0.7))
	, 0.0, intensity, 0.06)
	
	tween.tween_method(func(v: float):
		current_grimace = v
		_set_shape("Mouth_Grimace", v)
		if not is_blinking:
			_set_shape("Blink_L", minf(1.0, v * 0.7))
			_set_shape("Blink_R", minf(1.0, v * 0.7))
	, intensity, 0.0, duration - 0.06)

func _set_shape(shape_name: String, weight: float) -> void:
	if not mesh_instance or not mesh_instance.mesh:
		return
	var idx = mesh_instance.find_blend_shape_by_name(shape_name)
	if idx >= 0:
		mesh_instance.set_blend_shape_value(idx, clampf(weight, 0.0, 1.0))

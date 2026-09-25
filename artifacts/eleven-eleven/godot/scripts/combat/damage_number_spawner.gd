class_name DamageNumberSpawner
extends Node

## 3D Pop-Up Floating Damage Numbers (Genshin / ZZZ Style Billboard Typography)
## Renders crisp dynamic floating numbers in 3D world space with upward velocity,
## spring punch scale, and distinctive color coding (Ivory Normal, Radiant Crimson Crit, Cyan Deflect).

static func spawn_number(parent: Node, world_pos: Vector3, damage: int, is_crit: bool = false, is_deflect: bool = false) -> void:
	if not parent or not parent.is_inside_tree():
		return

	var label := Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.render_priority = 10
	label.fixed_size = true
	label.pixel_size = 0.0035

	if is_deflect:
		label.text = "DEFLECT!"
		label.modulate = Color(0.0, 0.95, 1.0, 1.0)
		label.outline_modulate = Color(0.0, 0.2, 0.4, 1.0)
		label.font_size = 38
		label.outline_size = 8
	elif is_crit:
		label.text = str(damage) + " ✦"
		label.modulate = Color(1.0, 0.15, 0.28, 1.0)
		label.outline_modulate = Color(0.35, 0.05, 0.05, 1.0)
		label.font_size = 46
		label.outline_size = 10
	else:
		label.text = str(damage)
		label.modulate = Color(0.96, 0.96, 0.98, 1.0)
		label.outline_modulate = Color(0.08, 0.10, 0.14, 1.0)
		label.font_size = 34
		label.outline_size = 6

	# Slight random horizontal spread for multi-hit clarity
	var spawn_pos: Vector3 = world_pos + Vector3(randf_range(-0.25, 0.25), randf_range(0.1, 0.3), randf_range(-0.25, 0.25))
	label.position = spawn_pos
	label.scale = Vector3(0.1, 0.1, 0.1)

	parent.add_child(label)

	var tree := parent.get_tree()
	if not tree:
		return

	var tween := tree.create_tween().set_parallel(true)
	
	# Scale punch (0.1 -> 1.3 -> 1.0)
	tween.tween_property(label, "scale", Vector3(1.3, 1.3, 1.3), 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(label, "scale", Vector3(1.0, 1.0, 1.0), 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	# Float upward with slight damping
	var target_y: float = spawn_pos.y + (1.2 if is_crit else 0.85)
	tween.tween_property(label, "position:y", target_y, 0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# Fade out near end of life
	tween.chain().tween_property(label, "modulate:a", 0.0, 0.25).set_delay(0.2)
	tween.chain().tween_callback(func():
		if is_instance_valid(label):
			label.queue_free()
	)

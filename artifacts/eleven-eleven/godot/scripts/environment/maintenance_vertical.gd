extends Node3D

## Runtime physics adapter for the portable Blender room; no story authority.
func _ready() -> void:
	var spec = JSON.parse_string(FileAccess.get_file_as_string("res://assets/environments/maintenance_collision_v1.json"))
	if not spec is Dictionary or spec.get("schema") != "echo-maintenance-collision-v1":
		push_error("Maintenance collision contract unavailable")
		return
	for row in spec.bodies:
		var body := StaticBody3D.new()
		body.name = row.name
		body.position = Vector3(row.position[0], row.position[1], row.position[2])
		var shape := BoxShape3D.new()
		shape.size = Vector3(row.size[0], row.size[1], row.size[2])
		var collider := CollisionShape3D.new()
		collider.shape = shape
		body.add_child(collider)
		add_child(body)
		if row.climbable: body.add_to_group("climbable")
	for position in [Vector3(-3, 4.8, -2), Vector3(1, 6.3, -6), Vector3(4, 6.8, -10)]:
		var light := OmniLight3D.new()
		light.position = position
		light.light_color = Color(0.72, 0.83, 1)
		light.light_energy = 1.6
		light.omni_range = 8.0
		add_child(light)
	var animation := find_child("AnimationPlayer", true, false) as AnimationPlayer
	if animation:
		# A still rest pose is valid for reduced motion; director owns playback.
		animation.stop()

func set_reduced_motion(reduced: bool) -> void:
	var animation := find_child("AnimationPlayer", true, false) as AnimationPlayer
	if not animation: return
	for clip in animation.get_animation_list():
		if "Maintenance_Signal_Cycle" in clip:
			if reduced:
				animation.play(clip)
				animation.seek(0, true)
				animation.stop()
			else:
				animation.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
				animation.play(clip)
			break

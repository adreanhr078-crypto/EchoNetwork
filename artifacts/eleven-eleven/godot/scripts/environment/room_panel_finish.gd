extends RefCounted
## Opt-in opaque material finish for the reviewed 04–07 meshes only.
const SHADER = preload("res://shaders/room_panel_finish.gdshader")
const ENVIRONMENT_LAYER := 1 << 18

static func material(color: Color, pitch := Vector2(2.4,1.2), metal := 0.22, roughness := 0.6) -> ShaderMaterial:
	var result := ShaderMaterial.new()
	result.shader = SHADER
	result.set_shader_parameter("base_color",color)
	result.set_shader_parameter("panel_pitch",pitch)
	result.set_shader_parameter("metal",metal)
	result.set_shader_parameter("base_roughness",roughness)
	return result

static func apply(room: Node3D, prefixes: Array[String], finish: Material) -> void:
	for body in room.get_children():
		var selected := false
		for prefix in prefixes:
			if String(body.name).begins_with(prefix): selected = true; break
		if not selected: continue
		var visuals: Array = [body] if body is MeshInstance3D else body.get_children()
		for visual in visuals:
			if not visual is MeshInstance3D: continue
			# Preserve functional lamps, emissive status strips and custom effects.
			var prior = visual.get_active_material(0)
			if prior is StandardMaterial3D and not prior.emission_enabled:
				visual.material_override = finish

static func environment_fill(room: Node3D, label: String, point: Vector3, color: Color, energy: float, radius: float) -> OmniLight3D:
	for mesh in room.find_children("*","MeshInstance3D",true,false): mesh.layers |= ENVIRONMENT_LAYER
	for mesh in room.find_children("*","MultiMeshInstance3D",true,false): mesh.layers |= ENVIRONMENT_LAYER
	var fill := OmniLight3D.new()
	fill.name = label
	fill.position = point
	fill.light_color = color
	fill.light_energy = energy
	fill.omni_range = radius
	fill.light_cull_mask = ENVIRONMENT_LAYER
	fill.shadow_enabled = false
	room.add_child(fill)
	return fill

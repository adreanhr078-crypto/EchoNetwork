class_name ShaderApplicator
extends RefCounted

static func apply_cel_shader(root_node: Node, shader: Shader, albedo_col: Color, rim_col: Color, shadow_col: Color, rim_pow: float = 3.2, rim_int: float = 0.85, outline_shader: Shader = null) -> void:
	if not root_node or not shader:
		return
	_recursive_apply(root_node, shader, albedo_col, rim_col, shadow_col, rim_pow, rim_int, outline_shader)

static func apply_outline(root_node: Node, outline_shader: Shader, outline_width: float = 1.35) -> void:
	if not root_node or not outline_shader:
		return
	_recursive_outline(root_node, outline_shader, outline_width)

static func _recursive_outline(node: Node, outline_shader: Shader, outline_width: float) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh:
			for surface_index in mi.mesh.get_surface_count():
				var source_material := mi.get_active_material(surface_index)
				if source_material:
					var preserved_material := source_material.duplicate(true)
					if preserved_material is StandardMaterial3D:
						var anime_material := preserved_material as StandardMaterial3D
						anime_material.metallic = minf(anime_material.metallic, 0.28)
						anime_material.roughness = maxf(anime_material.roughness, 0.5)
					var outline_material := ShaderMaterial.new()
					outline_material.shader = outline_shader
					outline_material.set_shader_parameter("outline_color", Color(0.025, 0.035, 0.055, 1.0))
					outline_material.set_shader_parameter("outline_width", outline_width)
					preserved_material.next_pass = outline_material
					mi.set_surface_override_material(surface_index, preserved_material)
	for child in node.get_children():
		_recursive_outline(child, outline_shader, outline_width)

static func _recursive_apply(node: Node, shader: Shader, albedo_col: Color, rim_col: Color, shadow_col: Color, rim_pow: float, rim_int: float, outline_shader: Shader) -> void:
	if node is MeshInstance3D:
		var mi: MeshInstance3D = node as MeshInstance3D
		if mi.mesh:
			for surface_index in mi.mesh.get_surface_count():
				var source_material := mi.get_active_material(surface_index)
				var mat := _make_stylized_material(source_material, shader, albedo_col, rim_col, shadow_col, rim_pow, rim_int, outline_shader)
				mi.set_surface_override_material(surface_index, mat)
	for child in node.get_children():
		_recursive_apply(child, shader, albedo_col, rim_col, shadow_col, rim_pow, rim_int, outline_shader)

static func _make_stylized_material(source_material: Material, shader: Shader, albedo_tint: Color, rim_col: Color, shadow_col: Color, rim_pow: float, rim_int: float, outline_shader: Shader) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("albedo_color", albedo_tint)
	mat.set_shader_parameter("rim_color", rim_col)
	mat.set_shader_parameter("shadow_color", shadow_col)
	mat.set_shader_parameter("rim_power", rim_pow)
	mat.set_shader_parameter("rim_intensity", rim_int)
	if source_material is StandardMaterial3D:
		var source := source_material as StandardMaterial3D
		mat.set_shader_parameter("albedo_color", albedo_tint * source.albedo_color)
		mat.set_shader_parameter("albedo_texture", source.albedo_texture)
		mat.set_shader_parameter("roughness", source.roughness)
		mat.set_shader_parameter("metallic", source.metallic)
		if source.normal_enabled and source.normal_texture:
			mat.set_shader_parameter("normal_texture", source.normal_texture)
			mat.set_shader_parameter("normal_depth", source.normal_scale)
			mat.set_shader_parameter("use_normal_texture", true)
		if source.emission_enabled:
			mat.set_shader_parameter("emissive_color", source.emission)
			mat.set_shader_parameter("emissive_intensity", source.emission_energy_multiplier)
	if outline_shader:
		var outline_mat := ShaderMaterial.new()
		outline_mat.shader = outline_shader
		outline_mat.set_shader_parameter("outline_color", Color(0.05, 0.06, 0.08, 1.0))
		outline_mat.set_shader_parameter("outline_width", 2.2)
		mat.next_pass = outline_mat
	return mat

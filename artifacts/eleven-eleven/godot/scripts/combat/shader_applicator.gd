class_name ShaderApplicator
extends RefCounted

## 11.11 Production Anime Cel Shading & Ink Outline Applicator
## Enforces Genshin-tier anime aesthetic in Compatibility (GLES3/OpenGL) mode:
## - Preserves high-resolution authored PBR albedo textures
## - Native DIFFUSE_TOON + SPECULAR_TOON lighting ramps
## - Rim lighting highlights for distinct silhouette separation
## - GPU hardware-skinned inverted hull ink outlines (CULL_FRONT + grow)

static func apply_cel_shader(root_node: Node, shader: Shader, albedo_col: Color, rim_col: Color, shadow_col: Color, rim_pow: float = 3.2, rim_int: float = 0.85, outline_shader: Shader = null) -> void:
	if not root_node or not shader:
		return
	_recursive_apply(root_node, shader, albedo_col, rim_col, shadow_col, rim_pow, rim_int, outline_shader)

static func apply_outline(root_node: Node, _outline_shader: Shader = null, outline_width: float = 1.35) -> void:
	if not root_node:
		return
	_recursive_outline(root_node, outline_width)

static func _recursive_outline(node: Node, outline_width: float) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh:
			for surface_index in mi.mesh.get_surface_count():
				var source_material := mi.get_active_material(surface_index)
				if source_material:
					var preserved_material := source_material.duplicate(true)
					if preserved_material is StandardMaterial3D:
						var anime_material := preserved_material as StandardMaterial3D
						anime_material.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
						anime_material.specular_mode = BaseMaterial3D.SPECULAR_TOON
						anime_material.rim_enabled = true
						anime_material.rim = 0.55
						anime_material.rim_tint = 0.45
						anime_material.metallic = 0.0
						anime_material.roughness = 0.65

						# Built-in Godot GPU-skinned inverted hull ink outline
						var outline_mat := StandardMaterial3D.new()
						outline_mat.cull_mode = BaseMaterial3D.CULL_FRONT
						outline_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
						outline_mat.albedo_color = Color(0.03, 0.04, 0.06, 1.0)
						outline_mat.grow = true
						outline_mat.grow_amount = 0.0022 * outline_width
						anime_material.next_pass = outline_mat

						mi.set_surface_override_material(surface_index, anime_material)
	for child in node.get_children():
		_recursive_outline(child, outline_width)

static func _recursive_apply(node: Node, shader: Shader, albedo_col: Color, rim_col: Color, shadow_col: Color, rim_pow: float, rim_int: float, outline_shader: Shader) -> void:
	if node is MeshInstance3D:
		var mi: MeshInstance3D = node as MeshInstance3D
		if mi.mesh:
			for surface_index in mi.mesh.get_surface_count():
				var source_material := mi.get_active_material(surface_index)
				var mat := _make_stylized_material(source_material, shader, albedo_col, rim_col, shadow_col, rim_pow, rim_int, outline_shader, mi.name)
				mi.set_surface_override_material(surface_index, mat)
	for child in node.get_children():
		_recursive_apply(child, shader, albedo_col, rim_col, shadow_col, rim_pow, rim_int, outline_shader)

static func _make_stylized_material(source_material: Material, shader: Shader, albedo_tint: Color, rim_col: Color, shadow_col: Color, rim_pow: float, rim_int: float, outline_shader: Shader, mesh_name: String = "") -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("albedo_color", albedo_tint)
	mat.set_shader_parameter("rim_color", rim_col)
	mat.set_shader_parameter("shadow_color", shadow_col)
	mat.set_shader_parameter("rim_power", rim_pow)
	mat.set_shader_parameter("rim_intensity", rim_int)
	if source_material is BaseMaterial3D:
		var source := source_material as BaseMaterial3D
		var final_albedo := albedo_tint
		if source.albedo_texture != null:
			final_albedo = albedo_tint
		else:
			final_albedo = albedo_tint * source.albedo_color
		mat.set_shader_parameter("albedo_color", final_albedo)
		mat.set_shader_parameter("albedo_texture", source.albedo_texture)
		mat.set_shader_parameter("roughness", source.roughness)
		mat.set_shader_parameter("metallic", minf(source.metallic, 0.1))
		if source.normal_enabled and source.normal_texture:
			mat.set_shader_parameter("normal_texture", source.normal_texture)
			mat.set_shader_parameter("normal_depth", source.normal_scale)
			mat.set_shader_parameter("use_normal_texture", true)
		if source.emission_enabled:
			mat.set_shader_parameter("emissive_color", source.emission)
			mat.set_shader_parameter("emissive_intensity", source.emission_energy_multiplier)
	mat.set_shader_parameter("use_sss", true)
	mat.set_shader_parameter("sss_color", Color(0.96, 0.45, 0.40, 1.0))
	mat.set_shader_parameter("sss_intensity", 0.70)
	var lower_name := mesh_name.to_lower()
	if lower_name.contains("hair"):
		mat.set_shader_parameter("is_hair", true)
		mat.set_shader_parameter("hair_specular_color", Color(1.0, 0.96, 0.88, 1.0))
		mat.set_shader_parameter("hair_specular_power", 42.0)
	elif lower_name.contains("face") or lower_name.contains("head") or lower_name.contains("eye") or lower_name.contains("skin"):
		mat.set_shader_parameter("is_face", true)
	if outline_shader:
		var outline_mat := ShaderMaterial.new()
		outline_mat.shader = outline_shader
		outline_mat.set_shader_parameter("outline_color", Color(0.05, 0.06, 0.08, 1.0))
		outline_mat.set_shader_parameter("outline_width", 2.2)
		mat.next_pass = outline_mat
	return mat

class_name ShaderApplicator
extends RefCounted

static func apply_cel_shader(root_node: Node, shader: Shader, albedo_col: Color, rim_col: Color, shadow_col: Color, rim_pow: float = 3.2, rim_int: float = 0.85, outline_shader: Shader = null) -> void:
	if not root_node or not shader:
		return
	
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("albedo_color", albedo_col)
	mat.set_shader_parameter("rim_color", rim_col)
	mat.set_shader_parameter("shadow_color", shadow_col)
	mat.set_shader_parameter("rim_power", rim_pow)
	mat.set_shader_parameter("rim_intensity", rim_int)

	if outline_shader:
		var outline_mat := ShaderMaterial.new()
		outline_mat.shader = outline_shader
		outline_mat.set_shader_parameter("outline_color", Color(0.05, 0.06, 0.08, 1.0))
		outline_mat.set_shader_parameter("outline_width", 2.2)
		mat.next_pass = outline_mat
	
	_recursive_apply(root_node, mat)

static func _recursive_apply(node: Node, mat: Material) -> void:
	if node is MeshInstance3D:
		var mi: MeshInstance3D = node as MeshInstance3D
		mi.material_override = mat
	for child in node.get_children():
		_recursive_apply(child, mat)

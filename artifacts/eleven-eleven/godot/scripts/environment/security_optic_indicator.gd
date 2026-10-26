extends MeshInstance3D
## Presentation follows the real threat lamp,with no independent clock/state.
var lamp:Light3D
func _process(_delta:float)->void:
	if is_instance_valid(lamp):
		(material_override as ShaderMaterial).set_shader_parameter("indicator_color",lamp.light_color)

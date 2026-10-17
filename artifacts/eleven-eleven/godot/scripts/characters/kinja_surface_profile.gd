extends RefCounted

## Kinja-only material finish using the existing local cel shader.
## Lighting study: Nilo public MIT example; no upstream source is copied.
const Materials=preload("res://scripts/combat/shader_applicator.gd")
const Cel=preload("res://shaders/anime_cel.gdshader")

static func apply(root:Node)->int:
	var changed:=0
	if root is MeshInstance3D and root.mesh:
		for surface in root.mesh.get_surface_count():
			var source:Material=root.get_active_material(surface)
			if not source is BaseMaterial3D:continue
			var base:=source as BaseMaterial3D
			# Preserve unsupported authored AO/alpha materials until mapped explicitly.
			if base.ao_enabled or base.transparency!=BaseMaterial3D.TRANSPARENCY_DISABLED:continue
			# Preserve the shared imported material and the exact authored maps.
			var mat:=Materials._make_stylized_material(base,Cel,Color.WHITE,Color(.46,.38,.52),Color(.42,.43,.52),3.2,.08,null,String(root.name),1.0,.04)
			mat.resource_name="KinjaSurfaceProfile"
			mat.set_shader_parameter("normalize_light_response",true)
			mat.set_shader_parameter("diffuse_light_ceiling",.65)
			mat.set_shader_parameter("specular_light_ceiling",.08)
			mat.set_shader_parameter("use_sss",false)
			mat.set_shader_parameter("use_two_tone_face",false)
			mat.set_shader_parameter("specular_color",Color(.18,.18,.18))
			mat.set_shader_parameter("metallic",base.metallic)
			mat.set_shader_parameter("metallic_limit",.1)
			if base.roughness_texture:
				mat.set_shader_parameter("roughness_texture",base.roughness_texture)
				mat.set_shader_parameter("roughness_channel",Materials._texture_channel(base.roughness_texture_channel))
				mat.set_shader_parameter("use_roughness_texture",true)
			if base.metallic_texture:
				mat.set_shader_parameter("metallic_texture",base.metallic_texture)
				mat.set_shader_parameter("metallic_channel",Materials._texture_channel(base.metallic_texture_channel))
				mat.set_shader_parameter("use_metallic_texture",true)
			root.set_surface_override_material(surface,mat)
			changed+=1
	for child in root.get_children():changed+=apply(child)
	return changed

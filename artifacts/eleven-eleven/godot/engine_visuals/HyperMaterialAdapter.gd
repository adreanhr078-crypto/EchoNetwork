extends RefCounted

const MASTER = preload("res://engine_visuals/shaders/hyper_anime_uber.gdshader")
var _default_source := StandardMaterial3D.new()
var cache: Dictionary = {}
var variants: Dictionary = {}
var sources: Dictionary = {}
var states: Dictionary = {}
var converted := 0

func convert_tree(node: Node) -> void:
	if node is MeshInstance3D: convert_mesh(node as MeshInstance3D)
	for child in node.get_children(): convert_tree(child)

func convert_mesh(mesh: MeshInstance3D) -> void:
	if not mesh.mesh: return
	if mesh.material_override is StandardMaterial3D:
		mesh.material_override = convert_material(mesh.material_override)
	for surface in mesh.mesh.get_surface_count():
		if not mesh.material_override and not mesh.get_surface_override_material(surface) and not mesh.mesh.surface_get_material(surface):
			mesh.set_surface_override_material(surface,convert_material(_default_source))
			continue
		var material := mesh.get_active_material(surface)
		if material is StandardMaterial3D: mesh.set_surface_override_material(surface,convert_material(material))
	if mesh.material_overlay is StandardMaterial3D: mesh.material_overlay = convert_material(mesh.material_overlay)

func channel(index: int) -> Vector4:
	if index == 4: return Vector4(0.333333,0.333333,0.333333,0.0)
	var value := Vector4.ZERO
	value[clampi(index,0,3)] = 1.0
	return value

func convert_material(source: StandardMaterial3D) -> ShaderMaterial:
	var id := source.get_instance_id()
	if cache.has(id): return cache[id]
	var material := ShaderMaterial.new()
	var transparent := source.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA or source.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
	var cutout := source.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR or source.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_HASH
	var unshaded := source.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED
	var key := str([source.cull_mode,source.transparency,unshaded,source.blend_mode,source.no_depth_test])
	if not variants.has(key):
		var modes := "cull_back"
		if source.cull_mode == BaseMaterial3D.CULL_DISABLED: modes = "cull_disabled"
		elif source.cull_mode == BaseMaterial3D.CULL_FRONT: modes = "cull_front"
		if source.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS: modes += ", depth_prepass_alpha"
		if unshaded: modes += ", unshaded"
		if source.no_depth_test: modes += ", depth_test_disabled"
		if source.blend_mode == BaseMaterial3D.BLEND_MODE_ADD: modes += ", blend_add"
		elif source.blend_mode == BaseMaterial3D.BLEND_MODE_SUB: modes += ", blend_sub"
		elif source.blend_mode == BaseMaterial3D.BLEND_MODE_MUL: modes += ", blend_mul"
		var code := MASTER.code.replace("render_mode cull_back;","render_mode "+modes+";")
		if transparent: code = code.replace("if (alpha_cutout &&", "ALPHA = tex.a * albedo_color.a;\n    if (alpha_cutout &&")
		var shader := Shader.new()
		shader.code = code
		variants[key] = shader
	material.shader = variants[key]
	material.set_meta("hyper_source",source)
	material.resource_name = "Hyper_" + source.resource_name
	material.render_priority = source.render_priority
	material.next_pass = source.next_pass
	material.set_shader_parameter("albedo_color",source.albedo_color)
	material.set_shader_parameter("albedo_texture",source.albedo_texture)
	material.set_shader_parameter("uv_scale",source.uv1_scale)
	material.set_shader_parameter("uv_offset",source.uv1_offset)
	material.set_shader_parameter("vertex_color_enabled",source.vertex_color_use_as_albedo)
	material.set_shader_parameter("alpha_cutout",cutout)
	material.set_shader_parameter("alpha_threshold",source.alpha_scissor_threshold)
	material.set_shader_parameter("normalize_light_response",true)
	material.set_shader_parameter("use_sss",false)
	material.set_shader_parameter("use_two_tone_face",false)
	material.set_shader_parameter("shadow_color",Color(0.40,0.32,0.62))
	material.set_shader_parameter("rim_intensity",0.035)
	material.set_shader_parameter("backlight_intensity",0.05)
	material.set_shader_parameter("roughness",source.roughness)
	material.set_shader_parameter("metallic",source.metallic)
	material.set_shader_parameter("normal_texture",source.normal_texture)
	material.set_shader_parameter("use_normal_texture",source.normal_enabled and source.normal_texture!=null)
	material.set_shader_parameter("normal_depth",source.normal_scale)
	material.set_shader_parameter("roughness_texture",source.roughness_texture)
	material.set_shader_parameter("roughness_channel",channel(source.roughness_texture_channel))
	material.set_shader_parameter("use_roughness_texture",source.roughness_texture!=null)
	material.set_shader_parameter("metallic_texture",source.metallic_texture)
	material.set_shader_parameter("metallic_channel",channel(source.metallic_texture_channel))
	material.set_shader_parameter("use_metallic_texture",source.metallic_texture!=null)
	material.set_shader_parameter("ao_texture",source.ao_texture)
	material.set_shader_parameter("ao_channel",channel(source.ao_texture_channel))
	material.set_shader_parameter("use_ao_texture",source.ao_enabled and source.ao_texture!=null)
	if source.emission_enabled:
		material.set_shader_parameter("emissive_color",source.emission)
		material.set_shader_parameter("emissive_intensity",source.emission_energy_multiplier)
		material.set_shader_parameter("emission_texture",source.emission_texture)
		material.set_shader_parameter("use_emission_texture",source.emission_texture!=null)
	cache[id] = material
	sources[id] = source
	converted += 1
	return material

static func set_signal_color(material: Material, color: Color, emissive: bool=false) -> void:
	var property := "emission" if emissive else "albedo_color"
	if material is StandardMaterial3D:
		material.set(property,color)
	elif material is ShaderMaterial:
		var source: StandardMaterial3D=material.get_meta("hyper_source",null)
		if source: source.set(property,color)
		material.set_shader_parameter("emissive_color" if emissive else "albedo_color",color)

func sync_animated_values() -> void:
	# Several room controllers animate their retained source material. Keep
	# those signal colors/alpha/emission live after the shader conversion.
	for id in sources:
		var source: StandardMaterial3D = sources[id]
		var material: ShaderMaterial = cache[id]
		var state := [source.albedo_color,source.roughness,source.metallic,source.emission_enabled,source.emission,source.emission_energy_multiplier,source.uv1_scale,source.uv1_offset]
		if states.has(id) and states[id]==state: continue
		states[id]=state
		material.set_shader_parameter("albedo_color",source.albedo_color)
		material.set_shader_parameter("roughness",source.roughness)
		material.set_shader_parameter("metallic",source.metallic)
		material.set_shader_parameter("uv_scale",source.uv1_scale)
		material.set_shader_parameter("uv_offset",source.uv1_offset)
		if source.emission_enabled:
			material.set_shader_parameter("emissive_color",source.emission)
			material.set_shader_parameter("emissive_intensity",source.emission_energy_multiplier)
		else:
			material.set_shader_parameter("emissive_intensity",0.0)

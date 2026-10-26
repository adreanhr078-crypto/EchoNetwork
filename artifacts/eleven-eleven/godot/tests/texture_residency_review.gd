extends "res://tests/ward_objective_owner_review.gd"

## Diagnostic only. Attribute scene-referenced texture residency before choosing
## derivatives; file size and an unused large source are not runtime evidence.
var _textures := {}
var _materials := {}

func _material(material: Material, owner_path: String) -> void:
	if material == null or _materials.has(material.get_instance_id()): return
	_materials[material.get_instance_id()] = true
	for property in material.get_property_list():
		if property.type != TYPE_OBJECT: continue
		var texture = material.get(property.name)
		if texture is Texture2D: _texture(texture, owner_path+":"+String(property.name))
	if material is ShaderMaterial and material.shader:
		for uniform in material.shader.get_shader_uniform_list():
			var texture = material.get_shader_parameter(uniform.name)
			if texture is Texture2D: _texture(texture, owner_path+":"+String(uniform.name))
	_material(material.next_pass, owner_path+":next_pass")

func _texture(texture: Texture2D, owner_path: String) -> void:
	var key := texture.get_rid().get_id()
	if not _textures.has(key):
		_textures[key] = {"path":texture.resource_path,"width":texture.get_width(),"height":texture.get_height(),"owners":[]}
	_textures[key].owners.append(owner_path)

func _scan(node: Node) -> void:
	if node is GeometryInstance3D: _material(node.material_override, String(node.get_path()))
	if node is MeshInstance3D and node.mesh:
		for surface in node.mesh.get_surface_count():
			_material(node.get_active_material(surface),String(node.get_path())+":surface"+str(surface))
	for child in node.get_children(): _scan(child)

func _review_ward() -> bool:
	if not await super._review_ward(): return false
	_scan(main)
	var rows := _textures.values()
	rows.sort_custom(func(a,b): return a.width*a.height>b.width*b.height)
	var output := FileAccess.open(folder+"scene-textures.json",FileAccess.WRITE)
	output.store_string(JSON.stringify({"texture_monitor_bytes":Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED),"scope":"Textures referenced by scene material graph, including hidden geometry. Sizes are not measured per-texture VRAM.","textures":rows},"\t"));output.close()
	for row in rows.slice(0,15): print("SCENE_TEXTURE ",JSON.stringify(row))
	return true

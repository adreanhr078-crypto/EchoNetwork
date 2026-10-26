extends "res://tests/post_contract_journey_review.gd"

## Read-only material provenance on an actual earned native profile.
func _review_melee_camera()->bool:
	main.set_visual_quality("high")
	for tick in 5:await process_frame
	var records:=[]
	for label in ["EchoSignalConsole_Static_Graphite","EchoSignalConsole_Static_Titanium","MemoryScreenRearCasing","ScannerCeramicIdentificationLip"]:
		var mesh:MeshInstance3D=room.find_child(label,true,false) as MeshInstance3D
		if not _check(mesh!=null,"Missing material diagnosis target: "+label):return false
		var material:Material=mesh.get_active_material(0)
		var record:Dictionary={"node":String(mesh.get_path()),"class":material.get_class(),"override":mesh.material_override!=null,"source_metadata":material.has_meta("hyper_source")}
		if material is ShaderMaterial:
			record.shader=material.shader.resource_path
			for key in ["base_color","shadow_color","minimum_roughness"]:record[key]=str(material.get_shader_parameter(key))
		if material is StandardMaterial3D:record.albedo=str(material.albedo_color)
		records.append(record)
	var output:=FileAccess.open(folder+"material-state.json",FileAccess.WRITE)
	output.store_string(JSON.stringify({"targets":records,"scope":"Read-only diagnosis;no final art or gameplay acceptance."},"\t"));output.close()
	print("LAB_MATERIAL_STATE ",JSON.stringify(records))
	return true

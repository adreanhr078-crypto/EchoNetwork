extends "res://tests/lab_rebuild_views_review.gd"

## Visual-only comparison in the actual earned lab. Production stays on its
## current perimeter until the candidate passes native art/player review.
const CANDIDATE_PATH="res://assets/environments/lab_clinical_cp45/clinical_modular_perimeter.glb"

func _review_melee_camera()->bool:
	var architecture:Node=main.find_child("ClinicalLabArchitecture",true,false)
	var previous:Node=architecture.get_node("MeasuredTripoClinicalPerimeter")
	var progress_before:=JSON.stringify(campaign.progress)
	previous.queue_free()
	for tick in 3:await process_frame
	var candidate:Node3D=load(CANDIDATE_PATH).instantiate()
	candidate.name="ClinicalModularPerimeterCandidate"
	architecture.add_child(candidate)
	var world:Node=root.get_node("HyperAnimeWorldManager")
	world.adapter.convert_tree(candidate)
	var surfaces:=0
	var wall_material:ShaderMaterial
	for mesh in candidate.find_children("*","MeshInstance3D",true,false):
		var relative:Transform3D=candidate.global_transform.affine_inverse()*mesh.global_transform
		var bounds:AABB=relative*mesh.get_aabb()
		if mesh.name=="ClinicalCleanWestWall" and not _check(bounds.size.x<.21 and bounds.end.x< -15.95,"West cladding rotation/clearance failed"):return false
		if mesh.name=="ClinicalCleanEastWall" and not _check(bounds.size.x<.21 and bounds.position.x>15.95,"East cladding rotation/clearance failed"):return false
		if mesh.name=="ClinicalCleanNorthWall" and not _check(bounds.size.z<.21 and bounds.end.z< -39.95,"North cladding rotation/clearance failed"):return false
		if mesh.name=="ClinicalCleanSouthWall" and not _check(bounds.size.z<.21 and bounds.position.z> -.03,"South cladding rotation/clearance failed"):return false
		for surface in mesh.mesh.get_surface_count():
			surfaces+=1
			var adapted:Material=mesh.get_active_material(surface)
			var source:StandardMaterial3D=adapted.get_meta("hyper_source") if adapted and adapted.has_meta("hyper_source") else null
			if not _check(source!=null,"Candidate lost a source material during shared conversion"):return false
			var finish:ShaderMaterial=architecture._architectural_finish(source)
			finish.set_shader_parameter("minimum_roughness",.45)
			finish.set_shader_parameter("clean_clinical_coating",false)
			mesh.set_surface_override_material(surface,finish)
			if source.resource_name=="ClinicalTripoWallPBR4K":wall_material=finish
	main.set_visual_quality("high")
	if not _check(wall_material!=null and wall_material.get_shader_parameter("has_normal_map") and wall_material.get_shader_parameter("has_roughness_map") and wall_material.get_shader_parameter("has_metallic_map"),"Candidate lost its real source PBR bindings"):return false
	if not await super._review_melee_camera():return false
	if not _check(progress_before==JSON.stringify(campaign.progress),"Visual candidate changed earned progression"):return false
	var report:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(folder+"review.json"))
	report["candidate_only"]=true
	report["candidate_surfaces"]=surfaces
	report["source_hashes"][CANDIDATE_PATH]=FileAccess.get_sha256(CANDIDATE_PATH)
	report["source_hashes"]["res://tests/lab_modular_candidate_review.gd"]=FileAccess.get_sha256("res://tests/lab_modular_candidate_review.gd")
	report["scope"]="Four actual native High views of a visual-only modular candidate in an earned lab. Original collision,clock,gate,film,characters and progression retained. No final art,player-route or performance acceptance."
	var output:=FileAccess.open(folder+"candidate-review.json",FileAccess.WRITE)
	output.store_string(JSON.stringify(report,"\t"));output.close()
	print("LAB_MODULAR_CANDIDATE ",checks," surfaces=",surfaces)
	return true

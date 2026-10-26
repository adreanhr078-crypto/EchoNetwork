extends "res://tests/post_contract_journey_review.gd"

## Earned-state art diagnostic only. No progression or source asset edits.
func _review_melee_camera() -> bool:
	for point in [Vector3(3,0,-35),Vector3(3,0,-28.8),Vector3(0,0,-28.8)]:
		if not await _walk_local(point):return false
	player.set_gameplay_orbit(Vector3.ZERO)
	for tick in 30:await physics_frame
	player.face_world_direction(campaign.kinja.global_position-player.global_position)
	player.perform_attack()
	for tick in 5:await physics_frame
	player.request_dodge()
	for tick in 45:await physics_frame
	# Fixed art camera only: dodge changes the live orbit's obstruction. Use
	# an identical framing for both material candidates, not gameplay proof.
	var review_camera:=Camera3D.new()
	room.add_child(review_camera)
	review_camera.position=Vector3(5.0,2.3,-30.0)
	review_camera.environment=player.player_camera.environment
	review_camera.look_at(room.to_global(Vector3(0,1.2,-28.0)))
	review_camera.make_current()
	for tick in 8:await process_frame
	await _capture("baseline")
	var world:Node=root.get_node("HyperAnimeWorldManager")
	var env:Environment=player.player_camera.environment if player.player_camera.environment else world.environment
	var lights:=[]
	for light in main.find_children("*","Light3D",true,false):
		if light is DirectionalLight3D or light.global_position.distance_to(player.global_position)<25:
			lights.append({"path":str(main.get_path_to(light)),"color":str(light.light_color),"energy":light.light_energy,"position":str(light.global_position),"visible":light.is_visible_in_tree()})
	var walls:=[]
	for name in ["Floor","NorthWallWest","WestWall"]:
		var body:Node=room.get_node_or_null(name)
		if not body:continue
		for mesh in body.find_children("*","MeshInstance3D",true,false):
			var mat:Material=mesh.get_active_material(0)
			if mat is ShaderMaterial:
				walls.append({"name":name,"color":str(mat.get_shader_parameter("albedo_color")),"shadow":str(mat.get_shader_parameter("shadow_color")),"emission":str(mat.get_shader_parameter("emissive_color")),"rim":str(mat.get_shader_parameter("rim_intensity"))})
	var report:={"scope":"Diagnostic earned actual room only; no runtime art change or approval","renderer":RenderingServer.get_current_rendering_method(),"environment":{"ambient":str(env.ambient_light_color),"energy":env.ambient_light_energy,"exposure":env.tonemap_exposure,"saturation":env.adjustment_saturation,"contrast":env.adjustment_contrast},"lights":lights,"wall_materials":walls}
	var output:=FileAccess.open(folder+"diagnosis.json",FileAccess.WRITE)
	report["source_hashes"]={"adapter":FileAccess.get_sha256("res://engine_visuals/HyperMaterialAdapter.gd"),"lab":FileAccess.get_sha256("res://scripts/environment/dr_kinja_lab_room.gd")}
	output.store_string(JSON.stringify(report,"\t"));output.close()
	if OS.get_cmdline_user_args().has("--candidate"):
		for name in ["Floor","Ceiling","WestWall","EastWall","SouthWallWest","SouthWallEast","SouthLintel","NorthWallWest","NorthWallEast","NorthLintel"]:
			var body:Node=room.get_node_or_null(name)
			if not body:continue
			for mesh in body.find_children("*","MeshInstance3D",true,false):
				var mat:Material=mesh.get_active_material(0)
				if mat is ShaderMaterial:mat.set_shader_parameter("shadow_color",Color(.52,.54,.60))
		for tick in 8:await process_frame
		await _capture("candidate")
		var previous_grade:float=env.adjustment_saturation
		env.adjustment_saturation=1.0
		for tick in 8:await process_frame
		await _capture("neutral-grade")
		env.adjustment_saturation=previous_grade
		env.fog_enabled=false
		env.volumetric_fog_enabled=false
		if is_instance_valid(world.height_fog):world.height_fog.hide()
		for tick in 8:await process_frame
		await _capture("no-fog")
		for name in ["Floor","Ceiling","WestWall","EastWall","SouthWallWest","SouthWallEast","SouthLintel","NorthWallWest","NorthWallEast","NorthLintel"]:
			var body:Node=room.get_node_or_null(name)
			if not body:continue
			for mesh in body.find_children("*","MeshInstance3D",true,false):
				var mat:Material=mesh.get_active_material(0)
				if mat is ShaderMaterial:mat.set_shader_parameter("ambient_lift",.25)
		for tick in 8:await process_frame
		await _capture("surface-fill")
	return _check(campaign.kinja.contacts==0 and not room.wish_done,"Art diagnostic advanced progression")

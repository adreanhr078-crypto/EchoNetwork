extends SceneTree

## Isolated raw-GLB inspection; no runtime resource or collision is replaced.
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	root.unfocusable=true
	root.size=Vector2i(960,720)
	var args:=OS.get_cmdline_user_args()
	if args.size()<2: push_error("Provide raw GLB and output folder");quit(1);return
	DirAccess.make_dir_recursive_absolute(args[1])
	var doc:=GLTFDocument.new()
	var state:=GLTFState.new()
	if doc.append_from_file(args[0],state)!=OK: push_error("Cannot parse raw GLB");quit(1);return
	var model:=doc.generate_scene(state)
	root.add_child(model)
	await process_frame
	var bounds:=AABB()
	var found:=false
	var tris:=0
	var verts:=0
	var surfaces:=0
	var texture_sizes:=[]
	var mesh_nodes: Array[Node] = model.find_children("*","MeshInstance3D",true,false)
	if model is MeshInstance3D: mesh_nodes.push_front(model)
	for mesh: MeshInstance3D in mesh_nodes:
		var box: AABB=model.global_transform.affine_inverse()*mesh.global_transform*mesh.get_aabb()
		bounds=bounds.merge(box) if found else box
		found=true
		for surface in mesh.mesh.get_surface_count():
			surfaces+=1
			var arrays:=mesh.mesh.surface_get_arrays(surface)
			verts+=arrays[Mesh.ARRAY_VERTEX].size()
			tris+=arrays[Mesh.ARRAY_INDEX].size()/3 if arrays[Mesh.ARRAY_INDEX]!=null else arrays[Mesh.ARRAY_VERTEX].size()/3
			var material:=mesh.get_active_material(surface) as StandardMaterial3D
			if material and material.albedo_texture: texture_sizes.append(str(material.albedo_texture.get_size()))
			if material and args.has("--clean-material"):
				var clean: StandardMaterial3D=material.duplicate()
				clean.roughness_texture=null
				clean.metallic_texture=null
				clean.roughness=.72
				clean.metallic=.25
				clean.normal_enabled=false
				clean.albedo_color=Color(.32,.38,.43)
				mesh.set_surface_override_material(surface,clean)
	print("RAW_CANDIDATE found=",found," triangles=",tris," surfaces=",surfaces," bounds=",bounds)
	if not found or bounds.size.y<=0 or tris>30000: push_error("Unqualified source bounds/triangle count");quit(1);return
	var target_height := 2.6
	for arg in args:
		if arg.begins_with("--target-height="):
			var value := arg.trim_prefix("--target-height=")
			if not value.is_valid_float() or not is_finite(value.to_float()) or value.to_float()<=0.05:
				push_error("Invalid physical review height");quit(1);return
			target_height = value.to_float()
	var factor:=target_height/bounds.size.y
	model.scale*=factor
	model.position-=Vector3(bounds.get_center().x,bounds.position.y,bounds.get_center().z)*factor
	var world:=WorldEnvironment.new()
	world.environment=Environment.new()
	world.environment.background_mode=Environment.BG_COLOR
	world.environment.background_color=Color(.035,.045,.06)
	world.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color=Color(.72,.8,.95)
	world.environment.ambient_light_energy=.7
	root.add_child(world)
	var sun:=DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-30,-35,0)
	sun.light_energy=1.7
	root.add_child(sun)
	var fill:=OmniLight3D.new()
	fill.position=Vector3(-3,2,1)
	fill.light_energy=1.3
	fill.omni_range=10
	root.add_child(fill)
	var floor:=MeshInstance3D.new()
	floor.mesh=PlaneMesh.new()
	floor.mesh.size=Vector2(7,7)
	var mat:=StandardMaterial3D.new()
	mat.albedo_color=Color(.08,.09,.11)
	floor.material_override=mat
	root.add_child(floor)
	var camera:=Camera3D.new()
	camera.fov=39
	root.add_child(camera)
	camera.make_current()
	var distance := maxf(3.8,bounds.size.length()*factor*1.6)
	var target := Vector3(0,target_height*.5,0)
	for spec in [["front",Vector3(0,target.y+.4,distance)],["side",Vector3(distance,target.y+.4,0)],["back",Vector3(0,target.y+.4,-distance)],["three-quarter",Vector3(distance*.72,target.y+1.3,distance*.72)]]:
		camera.position=spec[1]
		camera.look_at(target)
		for i in 5: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(args[1]+"/"+spec[0]+".png")
	var report:=FileAccess.open(args[1]+"/inspection.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"raw_file":args[0],"sha256":FileAccess.get_sha256(args[0]),"triangles":tris,"vertices":verts,"surfaces":surfaces,"raw_bounds":str(bounds),"target_height":target_height,"scale_factor":factor,"scaled_bounds":str(bounds.size*factor),"texture_sizes":texture_sizes,"scope":"Isolated four-view candidate, not room integration or artistic acceptance"},"\t"))
	report.close()
	print("PASS raw static candidate inspection: triangles=",tris," surfaces=",surfaces," textures=",texture_sizes," bounds=",bounds)
	quit(0)

extends SceneTree

## Snapshot every native collider/trigger, anchors and mechanism before art.
## Comparing snapshots cannot establish actual traversal or visual acceptance.
func _initialize()->void:_run.call_deferred()
func _run()->void:
	var args:=OS.get_cmdline_user_args();var out:String=args[0]
	root.unfocusable=true
	if not args.has("--baseline") and DisplayServer.get_name()=="headless":
		push_error("Geometry transform readback requires the real renderer;Dummy headless returns identity MultiMesh transforms")
		quit(2);return
	DirAccess.make_dir_recursive_absolute(out)
	var room:Node3D=load("res://scenes/environment/core_reactor_room.tscn").instantiate()
	root.add_child(room);room.set_physics_process(false);room.set_process(false)
	for i in 4:await process_frame;await physics_frame
	var rows:=[]
	for col in room.find_children("*","CollisionShape3D",true,false):
		var body:CollisionObject3D=col.get_parent()
		var row:={"path":str(room.get_path_to(col)),"shape":col.shape.get_class(),"transform":str(col.transform),"body_transform":str(body.transform),"disabled":col.disabled,"layer":body.collision_layer,"mask":body.collision_mask,"body_type":body.get_class(),"climbable":body.is_in_group("climbable")}
		if col.shape is BoxShape3D:row.size=str(col.shape.size)
		if col.shape is CylinderShape3D:row.radius=col.shape.radius;row.height=col.shape.height
		if col.shape is SphereShape3D:row.radius=col.shape.radius
		if col.shape is ConvexPolygonShape3D:row.points=str(col.shape.points)
		rows.append(row)
	var current:={"colliders":rows,"state":room.get_state(),"core_transform":str(room.get_node("ReactorCore").transform),"hazard_times":[room.TELEGRAPH_TIME,room.DISCHARGE_TIME,room.SAFE_TIME],"anchors":[str(room.SAFE_ANCHOR_ALPHA),str(room.SAFE_ANCHOR_BETA),str(room.SAFE_ANCHOR_GAMMA)]}
	var before:String=out.path_join("native-contract-before.json")
	if args.has("--baseline"):
		if FileAccess.file_exists(before):push_error("Refusing to overwrite native reactor baseline");quit(2);return
		_write(before,current)
	else:
		var same:bool=JSON.parse_string(FileAccess.get_file_as_string(before))==JSON.parse_string(JSON.stringify(current))
		if not same:push_error("Reactor native route/trigger/mechanism contract changed");quit(1);return
		var kit:Node3D=room.get_node_or_null("ReactorMechanicalDressing")
		if kit==null or not kit.find_children("*","CollisionObject3D",true,false).is_empty():push_error("Reactor dressing missing or added new physics authority");quit(1);return
		# Real triangle rays through all14 native vent centres catch a half-bay
		# rotated cage even though its collision snapshot would still pass.
		var core:Node3D=room.get_node("ReactorCore")
		var blocked:=0
		for bay in 14:
			var angle:float=-PI+TAU*(bay+.5)/14.0
			var radial:=Vector3(cos(angle),0,sin(angle))
			var from:Vector3=core.position+Vector3(0,-5.825,0)+radial*4.2
			var to:Vector3=core.position+Vector3(0,-5.825,0)+radial*5.25
			for name in ["FourteenContainmentStaves","EightyFourServiceClamps"]:
				var batch:MultiMeshInstance3D=kit.get_node(name)
				var faces:PackedVector3Array=batch.multimesh.mesh.get_faces()
				for index in batch.multimesh.instance_count:
					var inverse:Transform3D=batch.multimesh.get_instance_transform(index).affine_inverse()
					var a:Vector3=inverse*from;var b:Vector3=inverse*to
					for triangle in range(0,faces.size(),3):
						if Geometry3D.segment_intersects_triangle(a,b,faces[triangle],faces[triangle+1],faces[triangle+2])!=null:blocked+=1;break
		if blocked!=0:push_error("Manufactured cage occluded original emitter bays");quit(1);return
		var grating_decks:=0
		var deck_parts:=room.find_children("MeasuredWalkableGrating","MultiMeshInstance3D",true,false)
		deck_parts.append_array(room.find_children("NativeEnvelopeAmberEdgeNosings","MultiMeshInstance3D",true,false))
		for batch in deck_parts:
			var body:Node3D=batch.get_parent();var shape:CollisionShape3D
			for child in body.get_children():
				if child is CollisionShape3D:shape=child;break
			var box:BoxShape3D=shape.shape
			var bounds:=AABB(-box.size*.5,box.size)
			for index in batch.multimesh.instance_count:
				var actual:AABB=batch.multimesh.get_instance_transform(index)*batch.multimesh.mesh.get_aabb()
				if not bounds.grow(.001).encloses(actual):push_error("Grating crossed native walking envelope: %s[%d] actual=%s native=%s source=%s"%[body.name,index,actual,bounds,batch.multimesh.mesh.get_aabb()]);quit(1);return
			if batch.name=="MeasuredWalkableGrating":grating_decks+=1
		for index in 3:
			var ring:MeshInstance3D=core.get_node("PlasmaRing_%d"%index)
			if not is_equal_approx(ring.mesh.inner_radius,4.78) or not is_equal_approx(ring.mesh.outer_radius,4.98) or not ring.position.is_equal_approx(Vector3(0,-4+index*3.5,0)):
				push_error("Native plasma ring radii or placement changed");quit(1);return
		var crown:Mesh=kit.get_node("MeasuredFullDetailReactorCrown").multimesh.mesh
		var triangles:int=crown.surface_get_array_index_len(0)/3
		if triangles!=196054 or crown.get_surface_count()!=1:push_error("Full-detail crown topology was silently changed");quit(1);return
		var finish:ShaderMaterial=crown.surface_get_material(0);var maps:={}
		for key in ["color","normal","roughness","metallic"]:
			var texture:Texture2D=finish.get_shader_parameter(key+"_map")
			if not finish.get_shader_parameter("has_"+key+"_map") or texture.get_width()!=4096 or texture.get_height()!=4096:push_error("Crown lost actual4K PBR:"+key);quit(1);return
			maps[key]=[texture.get_width(),texture.get_height()]
		var lods:Variant=RenderingServer.mesh_get_surface(crown.get_rid(),0).get("lods",[])
		if lods.size()==0:push_error("Full-detail crown has no native generated mesh LODs");quit(1);return
		_write(out.path_join("native-contract-review.json"),{"unchanged":same,"native_colliders":rows.size(),"renderer":RenderingServer.get_current_rendering_method(),"state":current,"kit_has_no_physics":true,"native_vent_rays":14,"blocked_vent_rays":blocked,"grating_decks_in_original_envelopes":grating_decks,"measured_wall_tiles":kit.get_meta("measured_reactor_cladding_tiles"),"crown":{"triangles":triangles,"maps":maps,"native_lod_levels":lods.size(),"roughness_channel":str(finish.get_shader_parameter("roughness_channel")),"metallic_channel":str(finish.get_shader_parameter("metallic_channel"))},"scope":"Realrenderer mechanism/trigger/solid equality and actual geometry rays/deck envelopes/meshLODs/maps;actual player/art/performance are separate"})
	room.queue_free();for i in 4:await process_frame
	print("PASS REACTOR_NATIVE_CONTRACT colliders=",rows.size());quit(0)
func _write(path:String,data:Dictionary)->void:
	var f:=FileAccess.open(path,FileAccess.WRITE);f.store_string(JSON.stringify(data,"\t"));f.close()

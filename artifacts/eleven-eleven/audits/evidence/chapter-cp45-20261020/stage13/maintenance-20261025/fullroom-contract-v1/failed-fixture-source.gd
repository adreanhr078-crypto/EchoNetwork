extends SceneTree

## Exact native solids/triggers and climb cues remain the authority.
func _initialize()->void:_run.call_deferred()
func _run()->void:
	var args:=OS.get_cmdline_user_args();var folder:String=args[0]
	DirAccess.make_dir_recursive_absolute(folder)
	root.unfocusable=true
	var room:Node3D=load("res://scenes/environment/maintenance_vertical.tscn").instantiate()
	root.add_child(room);room.set_process(false);room.set_physics_process(false)
	for i in 4:await physics_frame;await process_frame
	var rows:=[]
	for col in room.find_children("*","CollisionShape3D",true,false):
		var body:CollisionObject3D=col.get_parent()
		var row:={"path":str(room.get_path_to(col)),"shape":col.shape.get_class(),"shape_transform":str(col.transform),"body_transform":str(body.transform),"layer":body.collision_layer,"mask":body.collision_mask,"disabled":col.disabled,"climbable":body.is_in_group("climbable")}
		if col.shape is BoxShape3D:row.size=str(col.shape.size)
		if col.shape is SphereShape3D:row.radius=col.shape.radius
		rows.append(row)
	var cues:=[]
	for visual in room.find_children("Climb*","MeshInstance3D",true,false):
		cues.append({"path":str(room.get_path_to(visual)),"transform":str(visual.transform),"aabb":str(visual.mesh.get_aabb())})
	var actual:={"colliders":rows,"cues":cues,"closed_gate":str(room._gate.transform),"closed_valve":str(room._valve.transform),"interaction":str(room.service_interaction.transform),"native_spec_sha256":FileAccess.get_sha256("res://assets/environments/maintenance_collision_v1.json")}
	var baseline:=folder.path_join("native-contract-before.json")
	if args.has("--baseline"):
		if FileAccess.file_exists(baseline):push_error("Preserve existing baseline");quit(2);return
		_write(baseline,actual)
	else:
		if JSON.parse_string(FileAccess.get_file_as_string(baseline))!=JSON.parse_string(JSON.stringify(actual)):
			push_error("Maintenance physics/climbcues/gate/valve/interaction changed");quit(1);return
		var kit:Node3D=room.get_node("MaintenanceMechanicalDressing")
		if not kit.find_children("*","CollisionObject3D",true,false).is_empty():push_error("Mechanical dressing introduced physics authority");quit(1);return
		if DisplayServer.get_name()=="headless":push_error("Measured MultiMesh transform proof needs real renderer");quit(2);return
		var wall_tiles:=0
		for batch in kit.find_children("MeasuredMaintenanceWall_*","MultiMeshInstance3D",false,false):
			var native:AABB=batch.get_meta("native_wall_volume")
			for i in batch.multimesh.instance_count:
				if not native.grow(.001).encloses(batch.multimesh.get_instance_transform(i)*batch.multimesh.mesh.get_aabb()):push_error("Cladding escaped old wall volume");quit(1);return
			wall_tiles+=batch.multimesh.instance_count
		var modules:=0;var triangles:=0;var lod_levels:={}
		if kit.has_node("MeasuredFullPressureBay"):
			var contract:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/environments/maintenance_cp45/maintenance_measured_fullroom_contract.json"))
			if FileAccess.get_sha256("res://assets/environments/maintenance_cp45/maintenance_measured_fullroom_pbr4k.glb")!=contract.asset_sha256:push_error("Measured prefab source hash mismatch");quit(1);return
			for part in contract.parts:
				var visual:MeshInstance3D=kit.get_node("MeasuredFullPressureBay").find_child(part.part,true,false)
				if visual==null:push_error("Missing measured fullroom module:"+part.part);quit(1);return
				var lo:Array=part.native_target_box[0];var hi:Array=part.native_target_box[1]
				var minimum:=Vector3(lo[0],lo[1],lo[2]);var maximum:=Vector3(hi[0],hi[1],hi[2])
				var expected:=AABB(minimum,maximum-minimum)
				var actual:AABB=(room.global_transform.affine_inverse()*visual.global_transform)*visual.mesh.get_aabb()
				if not expected.grow(.002).encloses(actual):push_error("Prefab module crossed measured native volume:"+part.part+str(actual));quit(1);return
				for surface in visual.mesh.get_surface_count():
					var material:ShaderMaterial=visual.get_active_material(surface)
					for channel in ["color","normal","roughness","metallic"]:
						var texture:Texture2D=material.get_shader_parameter(channel+"_map")
						if texture==null or texture.get_width()!=4096 or texture.get_height()!=4096:push_error("Prefab lost actual4K PBR:"+channel);quit(1);return
					triangles+=visual.mesh.surface_get_array_index_len(surface)/3
					lod_levels[part.part]=RenderingServer.mesh_get_surface(visual.mesh.get_rid(),surface).get("lods",[]).size()
				modules+=1
			if modules!=12 or triangles!=1553260:push_error("Measured prefab topology changed");quit(1);return
		_write(folder.path_join("native-contract-review.json"),{"unchanged":true,"native_colliders":rows.size(),"climb_cues":cues.size(),"measured_wall_tiles":wall_tiles,"fullroom_modules":modules,"fullroom_triangles":triangles,"all_maps_4k":modules>0,"module_native_lod_levels":lod_levels,"renderer":RenderingServer.get_current_rendering_method(),"scope":"Native solid/trigger/cue/valve equality and measured fullroom module boxes/maps/topology;not movement/art/fun acceptance"})
	room.queue_free();for i in 4:await process_frame
	print("PASS MAINTENANCE_NATIVE_CONTRACT colliders=",rows.size()," climbcues=",cues.size());quit(0)
func _write(path:String,data:Dictionary)->void:
	var f:=FileAccess.open(path,FileAccess.WRITE);f.store_string(JSON.stringify(data,"\t"));f.close()

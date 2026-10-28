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
		var modules:=0;var triangles:=0;var visible_modules:=0;var visible_triangles:=0;var lod_levels:={}
		if kit.has_node("MeasuredFullPressureBay"):
			var contract:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/environments/maintenance_cp45/maintenance_measured_fullroom_contract.json"))
			if FileAccess.get_sha256("res://assets/environments/maintenance_cp45/maintenance_measured_fullroom_pbr4k.glb")!=contract.asset_sha256:push_error("Measured prefab source hash mismatch");quit(1);return
			for part in contract.parts:
				var visual:MeshInstance3D=kit.get_node("MeasuredFullPressureBay").find_child(part.part,true,false)
				if visual==null:push_error("Missing measured fullroom module:"+part.part);quit(1);return
				var lo:Array=part.native_target_box[0];var hi:Array=part.native_target_box[1]
				var minimum:=Vector3(lo[0],lo[1],lo[2]);var maximum:=Vector3(hi[0],hi[1],hi[2])
				var expected:=AABB(minimum,maximum-minimum)
				var module_bounds:AABB=(room.global_transform.affine_inverse()*visual.global_transform)*visual.mesh.get_aabb()
				if not expected.grow(.002).encloses(module_bounds):push_error("Prefab module crossed measured native volume:"+part.part+str(module_bounds));quit(1);return
				for surface in visual.mesh.get_surface_count():
					var material:ShaderMaterial=visual.get_active_material(surface)
					for channel in ["color","normal","roughness","metallic"]:
						var texture:Texture2D=material.get_shader_parameter(channel+"_map")
						if texture==null or texture.get_width()!=4096 or texture.get_height()!=4096:push_error("Prefab lost actual4K PBR:"+channel);quit(1);return
					triangles+=visual.mesh.surface_get_array_index_len(surface)/3
					if visual.is_visible_in_tree():visible_triangles+=visual.mesh.surface_get_array_index_len(surface)/3
					lod_levels[part.part]=RenderingServer.mesh_get_surface(visual.mesh.get_rid(),surface).get("lods",[]).size()
				modules+=1
				if visual.is_visible_in_tree():visible_modules+=1
			if modules!=12 or triangles!=1553260:push_error("Measured prefab topology changed");quit(1);return
		var precision:bool=kit.get_meta("precision_architecture",false)
		var precision_supported_instances:=0;var original_visual_header_instances:=0;var pbr_all_4k:=true
		var shaft_modules:=0;var roof_cassettes:=0;var climb_cleats:=0
		if precision:
			if kit.has_node("MeasuredFullPressureBay") or wall_tiles!=40:push_error("Precision build loaded rejected source skins or missed native walls");quit(1);return
			var cassette_review:=_primary_cassette_review(room,kit)
			if cassette_review.is_empty():quit(1);return
			_write(folder.path_join("primary-cassette-review.json"),cassette_review)
			for draw in kit.find_children("*","MultiMeshInstance3D",true,false):
				var key:=""
				for candidate_key in ["native_climb_volume","native_wall_volume","native_floor_volume","original_visual_header_volume"]:
					if draw.has_meta(candidate_key):key=candidate_key;break
				if key.is_empty():continue
				var native:AABB=draw.get_meta(key)
				for index in draw.multimesh.instance_count:
					if not native.grow(.002).encloses(draw.multimesh.get_instance_transform(index)*draw.multimesh.mesh.get_aabb()):push_error("Precision hardware crossed original solid:"+str(draw.name));quit(1);return
					if key=="original_visual_header_volume":original_visual_header_instances+=1
					else:precision_supported_instances+=1
				if String(draw.name).begins_with("MeasuredMaintenanceWall_"):
					for surface in draw.multimesh.mesh.get_surface_count():
						var material:ShaderMaterial=draw.multimesh.mesh.surface_get_material(surface)
						for channel in ["color","normal","roughness","metallic"]:
							var texture:Texture2D=material.get_shader_parameter(channel+"_map")
							pbr_all_4k=pbr_all_4k and texture!=null and texture.get_width()==4096 and texture.get_height()==4096
			if not pbr_all_4k:push_error("Precision walls lost actual4K PBR maps");quit(1);return
			for draw in kit.find_children("*","MultiMeshInstance3D",true,false):
				for key in ["nonwalkable_shaft_volume","nonwalkable_roof_volume","clearance_attachment_volume"]:
					if not draw.has_meta(key):continue
					var envelope:AABB=draw.get_meta(key)
					for index in draw.multimesh.instance_count:
						var bounds:AABB=draw.multimesh.get_instance_transform(index)*draw.multimesh.mesh.get_aabb()
						if not envelope.grow(.002).encloses(bounds):push_error("Architectural support escaped measured envelope:"+str(draw.name));quit(1);return
						if key=="nonwalkable_shaft_volume":
							if bounds.end.y>.002:push_error("Shaft extension entered the above-floor route");quit(1);return
							shaft_modules+=1
						elif key=="nonwalkable_roof_volume":
							if bounds.position.y<10.49:push_error("Roof entered reachable play volume");quit(1);return
							roof_cassettes+=1
						else:
							var gap:float=draw.get_meta("untraversable_native_clearance")
							if gap<=0 or gap>=.3:push_error("Climb attachment claims a traversable side clearance");quit(1);return
							climb_cleats+=1
			if shaft_modules!=56 or roof_cassettes!=15 or climb_cleats!=3:push_error("Incomplete shaft/roof/native wall attachments");quit(1);return
			var bearing:MultiMeshInstance3D=kit.get_node("SecondClimbContinuousBearingBeam")
			var beam:AABB=bearing.get_meta("bearing_native_and_untraversable_volume")
			var climb:AABB=bearing.get_meta("source_climb_volume")
			var right:Node3D=room.get_node("COLL_RightBoundary")
			var right_size:Vector3=right.get_child(0).shape.size
			var clearance:float=right.position.x-right_size.x*.5-climb.end.x
			if clearance<=0 or clearance>=.3 or beam.position.x<climb.position.x or beam.end.x>right.position.x-right_size.x*.5+.013 or beam.position.y<climb.position.y or beam.end.y>climb.end.y or beam.position.z<climb.position.z or beam.end.z>climb.end.z:push_error("Bearing beam entered a new traversable volume");quit(1);return
			if not beam.grow(.002).encloses(bearing.multimesh.get_instance_transform(0)*bearing.multimesh.mesh.get_aabb()):push_error("Bearing mesh escaped its measured union");quit(1);return
			var suspension:MultiMeshInstance3D=kit.get_node("CeilingTaskFixtureSuspension")
			for index in suspension.multimesh.instance_count:
				var bounds:AABB=suspension.multimesh.get_instance_transform(index)*suspension.multimesh.mesh.get_aabb()
				if bounds.position.y<8.96 or bounds.end.y>10.512:push_error("Fixture suspension crossed reachable route or native ceiling");quit(1);return
		var supports:Array[AABB]=[]
		for label in ["COLL_UpperRest","COLL_GapLanding","COLL_FinalRest","COLL_ExitDeck","COLL_ServiceVestibule"]:
			var body:Node3D=room.get_node(label);var size:Vector3=body.get_child(0).shape.size
			supports.append(AABB(body.position-size*.5,size))
		var deck_shapes:=0;var grating_batches:=0;var grating_bars:=0
		for visual in kit.find_children("*","MeshInstance3D",true,false):
			var label:String=visual.get_meta("design_label","")
			if not label.begins_with("Deck") and not label.begins_with("GratingCrossTie") and not label.begins_with("MeasuredDeckBacking_"):continue
			var bounds:AABB=(room.global_transform.affine_inverse()*visual.global_transform)*visual.mesh.get_aabb()
			if not _supported(bounds,supports):push_error("New deck hardware crossed unchanged native support:"+label);quit(1);return
			deck_shapes+=1
		for draw in kit.find_children("MeasuredDeckGrating_*","MultiMeshInstance3D",false,false):
			grating_batches+=1
			for index in draw.multimesh.instance_count:
				var bounds:AABB=draw.multimesh.get_instance_transform(index)*draw.multimesh.mesh.get_aabb()
				if not _supported(bounds,supports):push_error("New grating crosses actual native support");quit(1);return
				grating_bars+=1
		if grating_batches!=5 or grating_bars<300:push_error("Missing native platform grating");quit(1);return
		if kit.has_node("MeasuredActualSecurityPortalBackSkins"):push_error("Isolated maintenance acquired unsupported adjacent-room cladding");quit(1);return
		var rear:MultiMeshInstance3D=kit.get_node("MeasuredRearBulkheadWithNativeAperture")
		var rear_native:AABB=rear.get_meta("native_solid_volume")
		for index in rear.multimesh.instance_count:
			if not rear_native.grow(.002).encloses(rear.multimesh.get_instance_transform(index)*rear.multimesh.mesh.get_aabb()):push_error("Rear panel escaped original farwall volume");quit(1);return
		var rear_material:ShaderMaterial=rear.multimesh.mesh.surface_get_material(0)
		if rear_material.get_shader_parameter("campaign_aperture")==true:push_error("Isolated rear skin opened without campaign owner");quit(1);return
		room.presentation.open_campaign_aperture();room.presentation.open_campaign_aperture()
		if rear_material.get_shader_parameter("campaign_aperture")!=true or rear_material.get_shader_parameter("aperture_min")!=Vector3(-.9,5.2,-14.78) or rear_material.get_shader_parameter("aperture_max")!=Vector3(.9,8.6,-14.22):push_error("PBR rear skin ignored native aperture owner/bounds");quit(1);return
		if room.presentation.find_children("CampaignAperture*","MeshInstance3D",false,false).size()!=3:push_error("Rear skin duplicated aperture lining");quit(1);return
		_write(folder.path_join("native-contract-review.json"),{"unchanged":true,"native_colliders":rows.size(),"climb_cues":cues.size(),"measured_wall_tiles":wall_tiles,"fullroom_modules":modules,"fullroom_triangles":triangles,"visible_fullroom_modules":visible_modules,"visible_fullroom_triangles":visible_triangles,"native_supported_deck_shapes":deck_shapes,"native_supported_grating_batches":grating_batches,"native_supported_grating_bars":grating_bars,"isolated_adjacent_portal_skins_absent":true,"native_rear_panels":rear.multimesh.instance_count,"native_rear_aperture_owner_verified":true,"all_maps_4k":pbr_all_4k if precision else modules>0,"nonwalkable_shaft_modules":shaft_modules,"unreachable_roof_cassettes":roof_cassettes,"nontraversable_clearance_climb_cleats":climb_cleats,"precision_architecture":precision,"precision_original_solid_supported_instances":precision_supported_instances,"original_authored_visual_header_supported_instances":original_visual_header_instances,"generated_source_candidate":"REFERENCE_ONLY_NATIVE_ART_REFINE" if precision else "candidate","module_native_lod_levels":lod_levels,"renderer":RenderingServer.get_current_rendering_method(),"scope":"Native solid/trigger/cue/valve equality and measured fullroom module boxes/maps/topology;not movement/art/fun acceptance"})
	room.queue_free();for i in 4:await process_frame
	print("PASS MAINTENANCE_NATIVE_CONTRACT colliders=",rows.size()," climbcues=",cues.size());quit(0)
func _write(path:String,data:Dictionary)->void:
	var f:=FileAccess.open(path,FileAccess.WRITE);f.store_string(JSON.stringify(data,"\t"));f.close()

func _primary_cassette_review(room:Node3D,kit:Node3D)->Dictionary:
	var path:="res://assets/environments/maintenance_cp45/maintenance_primary_cassette_contract.json"
	var contract:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	if FileAccess.get_sha256("res://assets/environments/maintenance_cp45/maintenance_primary_cassette_pbr4k.glb")!=contract.asset_sha256:push_error("Primary cassette source hash changed");return {}
	if kit.has_node("PrecisionClosedClimbCase_COLL_CLIMB_FirstWall") or kit.has_node("NativeFirstGripContactInset"):push_error("Superseded first-case finish covers the Tripo cassette");return {}
	var assembly:Node3D=kit.get_node("MeasuredPrimaryTripoCassette")
	var body:StaticBody3D=room.get_node("COLL_CLIMB_FirstWall")
	var size:Vector3=body.get_child(0).shape.size
	var native:=AABB(body.position-size*.5,size)
	var triangles:=0;var maps:=[];var lods:=[];var volumes:=[]
	var meshes:=assembly.find_children("*","MeshInstance3D",true,false)
	if meshes.size()!=1 or not assembly.is_visible_in_tree():push_error("Primary cassette is missing or hidden");return {}
	for visual:MeshInstance3D in meshes:
		var bounds:AABB=(room.global_transform.affine_inverse()*visual.global_transform)*visual.mesh.get_aabb()
		if not native.grow(.002).encloses(bounds) or not bounds.size.is_equal_approx(Vector3(4.998,3.398,.498)):push_error("Primary cassette no longer fits its original solid:"+str(bounds));return {}
		volumes.append(str(bounds))
		for surface in visual.mesh.get_surface_count():
			triangles+=visual.mesh.surface_get_array_index_len(surface)/3
			var material:ShaderMaterial=visual.get_active_material(surface)
			if not material.has_meta("pbr_source"):push_error("Primary cassette lost its PBR source");return {}
			for channel in ["color_map","normal_map","roughness_map","metallic_map"]:
				var texture:Texture2D=material.get_shader_parameter(channel)
				if texture==null or texture.get_width()!=4096 or texture.get_height()!=4096:push_error("Primary cassette lost actual 4K map:"+channel);return {}
				maps.append({"channel":channel,"size":[texture.get_width(),texture.get_height()]})
			lods.append(RenderingServer.mesh_get_surface(visual.mesh.get_rid(),surface).get("lods",[]).size())
	if triangles!=1943923:push_error("Primary cassette highest-detail topology changed");return {}
	return {"status":"PASS","source_sha256":contract.asset_sha256,"triangles_lod0":triangles,"mesh_count":meshes.size(),"bounds_room":volumes,"PBR":maps,"LOD_levels":lods,"native_contact_and_cues":"Compared to preserved baseline by enclosing contract test","scope":"Actual renderer, source hash, full static component envelope, 4K channels and retained LOD0. Not public movement, room art or device performance acceptance."}

func _supported(bounds:AABB,supports:Array[AABB])->bool:
	for support in supports:
		if support.grow(.002).encloses(bounds):return true
	return false

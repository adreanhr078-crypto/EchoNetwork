extends SceneTree

## Before/after native solids and state; no synthetic progression or actor.
func _initialize()->void:_run.call_deferred()
func _run()->void:
	var args:=OS.get_cmdline_user_args();var out:String=args[0]
	var room:Node3D=load("res://scenes/environment/memory_archive_wing.tscn").instantiate();root.add_child(room)
	for i in 4:await process_frame;await physics_frame
	var rows:=[]
	for col in room.find_children("*","CollisionShape3D",true,false):
		var row:={"path":str(room.get_path_to(col)),"transform":str(col.transform),"parent_transform":str((col.get_parent() as Node3D).transform),"disabled":col.disabled,"class":col.shape.get_class(),"layer":col.get_parent().collision_layer,"mask":col.get_parent().collision_mask}
		if col.shape is BoxShape3D:row.size=str(col.shape.size)
		if col.shape is ConvexPolygonShape3D:row.points=str(col.shape.points)
		row.climbable=col.get_parent().is_in_group("climbable")
		if col.shape is SphereShape3D:row.radius=col.shape.radius
		if col.shape is CylinderShape3D:row.radius=col.shape.radius;row.height=col.shape.height
		rows.append(row)
	var current:={"colliders":rows,"state":room.get_state(),"core_position":str(room._core_pillar.position),"core_height":room._core_pillar.mesh.height,"shards":room._shard_nodes.keys(),"anchors":[str(room.SAFE_ANCHOR_ENTRY),str(room.SAFE_ANCHOR_CENTER),str(room.SAFE_ANCHOR_CATWALK)]}
	var before:=out+"/native-contract-before-v2.json"
	if args.has("--baseline"):
		if FileAccess.file_exists(before):push_error("Refusing to overwrite archive baseline");quit(2);return
		_write(before,current)
	else:
		var same:bool=JSON.parse_string(FileAccess.get_file_as_string(before))==JSON.parse_string(JSON.stringify(current))
		if not same:push_error("Archive native contract changed");quit(1);return
		var presentation:={}
		if args.has("--complete"):
			var kit:Node3D=room.get_node("ArchiveMechanicalDressing")
			if not kit.find_children("*","CollisionObject3D",true,false).is_empty():push_error("Presentation introduced new physics/interaction authority");quit(1);return
			var core:MultiMeshInstance3D=kit.get_node_or_null("MeasuredArchiveProjectorBase")
			if core==null:push_error("Full-detail archive core failed to import/install");quit(1);return
			var mesh:Mesh=core.multimesh.mesh
			var indices:int=mesh.surface_get_array_index_len(0)
			if indices/3!=195893:push_error("Original195893-triangle hero was silently reduced");quit(1);return
			var bounds:AABB=core.multimesh.get_instance_transform(0)*mesh.get_aabb()
			if bounds.size.y>1.001 or bounds.size.x>5.601 or bounds.size.z>5.601:push_error("Hero exceeds original native core envelope");quit(1);return
			var finish:ShaderMaterial=mesh.surface_get_material(0)
			var sizes:={}
			for key in ["color","normal","roughness","metallic"]:
				if not finish.get_shader_parameter("has_"+key+"_map"):push_error("Missing actual hero PBR map:"+key);quit(1);return
				var texture:Texture2D=finish.get_shader_parameter(key+"_map")
				if texture.get_width()!=4096 or texture.get_height()!=4096:push_error("Source4K hero map reduced:"+key);quit(1);return
				sizes[key]=[texture.get_width(),texture.get_height()]
			var surface:Dictionary=RenderingServer.mesh_get_surface(mesh.get_rid(),0)
			var lods:Variant=surface.get("lods",[])
			presentation={"triangles":indices/3,"surfaces":mesh.get_surface_count(),"bounds":str(bounds),"maps":sizes,"lod_levels":lods.size(),"roughness_channel":str(finish.get_shader_parameter("roughness_channel")),"metallic_channel":str(finish.get_shader_parameter("metallic_channel")),"cladding_tiles":kit.get_meta("measured_archive_cladding_tiles"),"new_collision_objects":0}
		_write(out+"/native-contract-review.json",{"unchanged":same,"current":current,"presentation":presentation,"scope":"Native isolated solids/state/core/shards/anchors and actual imported hero/maps/LODs only;not player/art acceptance"})
	room.queue_free();for i in 3:await process_frame
	print("ARCHIVE_NATIVE_CONTRACT colliders=",rows.size()," unchanged");quit(0)
func _write(path:String,data:Dictionary)->void:
	var f:=FileAccess.open(path,FileAccess.WRITE);f.store_string(JSON.stringify(data,"\t"));f.close()

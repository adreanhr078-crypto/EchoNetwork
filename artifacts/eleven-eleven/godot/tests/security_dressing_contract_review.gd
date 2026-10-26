extends SceneTree

## Original security physics/state contract. No actor, rewards or route grant.
func _initialize()->void:_run.call_deferred()
func _run()->void:
	var args:=OS.get_cmdline_user_args()
	if args.is_empty():push_error("Absolute evidence folder required");quit(2);return
	var out:String=args[0];DirAccess.make_dir_recursive_absolute(out)
	var room:Node3D=load("res://scenes/environment/security_checkpoint_room.tscn").instantiate();root.add_child(room)
	for i in 4:await process_frame;await physics_frame
	var rows:=[]
	for col in room.find_children("*","CollisionShape3D",true,false):
		var row:={"path":str(room.get_path_to(col)),"transform":str(col.transform),"parent_transform":str((col.get_parent() as Node3D).transform),"disabled":col.disabled,"class":col.shape.get_class(),"layer":col.get_parent().collision_layer,"mask":col.get_parent().collision_mask}
		if col.shape is BoxShape3D:row.size=str(col.shape.size)
		if col.shape is SphereShape3D:row.radius=col.shape.radius
		if col.shape is CylinderShape3D:row.radius=col.shape.radius;row.height=col.shape.height
		rows.append(row)
	var field:MeshInstance3D=room._scanner.get_node("AuthoredScannerField")
	var current:={"colliders":rows,"state":room.get_state(),"beam_range":room._lamp.spot_range,"beam_angle":room._lamp.spot_angle,"field_height":field.mesh.height,"field_radius":field.mesh.bottom_radius}
	var before:=out+"/native-contract-before.json"
	if args.has("--baseline"):
		if FileAccess.file_exists(before):push_error("Baseline exists;refusing replacement");quit(2);return
		_write(before,current)
	else:
		var prior:Variant=JSON.parse_string(FileAccess.get_file_as_string(before))
		# Normalize JSON numeric types on both sides before comparing.
		var same:bool=prior==JSON.parse_string(JSON.stringify(current))
		_write(out+"/native-contract-review.json",{"unchanged":same,"current":current,"source_hash":FileAccess.get_sha256("res://scripts/environment/security_checkpoint_room.gd"),"scope":"Original isolated security colliders/state/cone preserved;not public input or art acceptance."})
		if not same:push_error("Security native physics/state contract changed");quit(1);return
	room.queue_free();for i in 4:await process_frame
	print("SECURITY_NATIVE_CONTRACT colliders=",rows.size()," unchanged")
	quit(0)

func _write(path:String,data:Dictionary)->void:
	var file:=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(data,"\t"));file.close()

extends SceneTree

## Compare presentation-only changes against a captured native physics/state
## contract. Isolated room; this does not claim an earned chapter journey.
var failures:Array[String]=[]
var checks:=0
var room:Node3D

func _initialize()->void:_run.call_deferred()

func _check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)

func _run()->void:
	var args:=OS.get_cmdline_user_args()
	if args.size()<1:push_error("Absolute evidence folder required");quit(2);return
	var folder:String=args[0]
	DirAccess.make_dir_recursive_absolute(folder)
	room=load("res://scenes/environment/specimen_containment_wing.tscn").instantiate()
	root.add_child(room)
	for i in 8:await process_frame;await physics_frame
	var solids:=[]
	for shape in room.find_children("*","CollisionShape3D",true,false):
		var resource:Shape3D=shape.shape
		var row:={"path":String(room.get_path_to(shape)),"transform":str(shape.global_transform),"disabled":shape.disabled,"shape":resource.get_class(),"layer":shape.get_parent().collision_layer,"mask":shape.get_parent().collision_mask}
		if resource is BoxShape3D:row.size=str(resource.size)
		if resource is CylinderShape3D:row.radius=resource.radius;row.height=resource.height
		if resource is SphereShape3D:row.radius=resource.radius
		solids.append(row)
	var contract:={"solids":solids,"initial_state":room.get_state(),"tank_configs":room._specimen_tanks,"scanner_speed":room._scanner_sweep_speed,"alert_grace":room.ALERT_GRACE_TIME,"anchors":[str(room.SAFE_ANCHOR_ENTRY),str(room.SAFE_ANCHOR_MIDPOINT),str(room.SAFE_ANCHOR_TERMINAL)]}
	var baseline:=folder+"/native-contract-before.json"
	if args.has("--baseline"):
		if FileAccess.file_exists(baseline):push_error("Refusing to replace baseline");quit(2);return
		_write(baseline,contract)
	else:
		var prior=JSON.parse_string(FileAccess.get_file_as_string(baseline))
		_check(prior!=null,"Native baseline exists")
		if prior:
			for key in contract:_check(_same(prior[key],contract[key]),"Native contract unchanged: "+key)
		_check(room._cover_plinths.size()==5,"Four cover solids and privacy baffle preserved")
		_check(room._specimen_tanks.size()==6,"Six original specimen records preserved")
		var kit:Node3D=room.get_node("SpecimenMechanicalDressing")
		var filter:MultiMeshInstance3D=kit.get_node("FourNativeVolumeBiofilters")
		_check(filter.multimesh.instance_count==4,"Four shared biological filter instances")
		_check(filter.multimesh.mesh.get_aabb().size.is_equal_approx(Vector3(2.2,1.8,1.4)),"Filter mesh fits original native cover volume")
		var finish:ShaderMaterial=filter.multimesh.mesh.surface_get_material(0)
		_check(finish!=null and finish.shader.resource_path=="res://shaders/clinical_architecture_surface.gdshader","Actual filter uses authored architectural ShaderMaterial")
		if finish:
			for key in ["color","normal","roughness","metallic"]:
				_check(finish.get_shader_parameter("has_"+key+"_map"),"Preserved actual PBR map: "+key)
			var color_map:Texture2D=finish.get_shader_parameter("color_map")
			var normal_map:Texture2D=finish.get_shader_parameter("normal_map")
			_check(color_map.get_width()==4096 and normal_map.get_width()==2048,"Genuine source4096 colour and2048 normal retained")
		_check(kit.find_children("*","CollisionObject3D",true,false).is_empty(),"Dressing has no new collision or interaction authority")
		_check(kit.get_node("TwelveMeasuredSealCaps").multimesh.instance_count==12,"Twelve shared native-footprint tank caps")
		_check(kit.get_node("CeilingCableTrays").multimesh.instance_count==16,"Sixteen measured cable tray modules")
		_check(kit.get_node("TwelveMeasuredSealCaps").multimesh.mesh.get_aabb().size.is_equal_approx(Vector3(2.5,.3,2.5)),"Machined tank caps fit original solid footprint")
		_check(room._scanner_optics!=null and room._scanner_head.has_node("NativeScannerOptic"),"Original scanner owns its readable physical optic")
		_check(room._terminal_body.find_child("NativeReadoutSurface",true,false)!=null,"Native terminal has readable fitted instrument surface")
		var glass:MeshInstance3D=room.get_node("Tank_ex_011").get_child(0)
		_check(glass.material_override is ShaderMaterial and glass.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,"Reserved tank glass retains transparent shadow-free physical presentation")
		var ex011:MeshInstance3D=room.get_node("Tank_ex_011").get_child(1)
		_check(is_equal_approx(ex011.mesh.height,.75) and is_equal_approx(ex011.position.y,-1.4),"EX011 remains partly drained at native datum")
		var before:float=room._fluid_time
		paused=true
		for i in 8:await process_frame
		_check(is_equal_approx(before,room._fluid_time),"Pause freezes fluid clock")
		paused=false;room.reduced_motion=true
		before=room._fluid_time
		for i in 8:await process_frame
		_check(is_equal_approx(before,room._fluid_time) and not room._bubble_batch.visible,"Reduced Motion freezes presentation and hides bubbles")
		var sweep:float=room._scanner_sweep_angle
		for i in 8:await physics_frame
		_check(room._scanner_sweep_angle>sweep,"Reduced Motion retains playable scanner timing")
		room.audio_muted=true
		var result:Dictionary=room.request_terminal_access()
		for i in 12:await process_frame;await physics_frame
		_check(result.get("accepted",false) and room.gate_open and room.terminal_read,"Native terminal authority preserved")
		_check(room._gate_shape.disabled,"Reduced Motion opens original physical gate")
		var saved:Dictionary=room.get_state()
		room.request_terminal_access()
		_check(room.discoveries.count("ex_011_log")==1,"Repeated terminal keeps one discovery")
		_check(room.restore_state(saved),"Existing save contract accepts native earned state")
		_check(not room._gate_release_sound.playing,"Mute retains silent visual release")
		_write(folder+"/dressing-contract-review.json",{"checks":checks,"failures":failures,"contract":contract,"room_sha256":FileAccess.get_sha256("res://scripts/environment/specimen_containment_wing.gd"),"scope":"Isolated native room physics/state/accessibility contract, not earned public journey or art approval."})
	room.queue_free()
	for i in 4:await process_frame
	print("SPECIMEN_DRESSING_CONTRACT checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)

func _write(path:String,value:Dictionary)->void:
	var file:=FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify(value,"\t"));file.close()

func _same(a:Variant,b:Variant)->bool:
	# JSON numbers deserialize as floats. Compare values recursively rather
	# than treating serialized 1 and 1.0 as a physical/state regression.
	if (a is float or a is int) and (b is float or b is int):return is_equal_approx(float(a),float(b))
	if a is Dictionary and b is Dictionary:
		if a.size()!=b.size():return false
		for key in a:
			if not b.has(key) or not _same(a[key],b[key]):return false
		return true
	if a is Array and b is Array:
		if a.size()!=b.size():return false
		for i in a.size():
			if not _same(a[i],b[i]):return false
		return true
	return a==b

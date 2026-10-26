extends RefCounted

## Precision reconstruction after the generated full-room native art REFINE.
## It preserves all source assets and uses their design,not their warped skins.
const KIT=preload("res://scripts/environment/specimen_mechanical_dressing.gd")
const PBR=preload("res://scripts/environment/archive_mechanical_dressing.gd")
const WALL=preload("res://assets/environments/lab_clinical_cp45/clinical_wall_p2_4k.glb")
const TRIM=preload("res://assets/environments/specimen_cp45/specimen_trim_unit.glb")

static func build(room:Node3D,root:Node3D,spec:Dictionary)->void:
	var steel:=KIT._finish(Color(.30,.325,.315),.35,.60)
	var edge:=KIT._finish(Color(.42,.445,.42),.42,.54)
	var dark:=KIT._finish(Color(.17,.19,.185),.24,.65)
	var copper:=KIT._finish(Color(.38,.245,.12),.39,.59)
	var trim:Mesh=KIT._mesh(TRIM)
	_walls(room,root)
	_climb_cases(root,spec,trim,steel,edge,copper)
	_entry_floor(root,spec,trim,dark)
	_service_seal(room,root,trim,steel,edge)
	_overhead(root,trim,dark)

static func _walls(room:Node3D,root:Node3D)->void:
	var mesh:Mesh=PBR._pbr_mesh(WALL,room)
	for surface in mesh.get_surface_count():
		var finish:ShaderMaterial=mesh.surface_get_material(surface)
		finish.set_shader_parameter("base_color",Color(.56,.58,.55))
		finish.set_shader_parameter("texture_saturation",.20)
		finish.set_shader_parameter("metalness",.18)
		finish.set_shader_parameter("minimum_roughness",.59)
	var backing:=BoxMesh.new();backing.size=Vector3.ONE;backing.material=KIT._finish(Color(.15,.17,.16),.15,.7)
	var backs:Array[Transform3D]=[]
	for name in ["COLL_LeftBoundary","COLL_RightBoundary"]:
		var body:Node3D=room.get_node(name);var size:Vector3=body.get_child(0).shape.size
		var native:=AABB(body.position-size*.5,size);var left:bool=name=="COLL_LeftBoundary"
		var normal:=Vector3.RIGHT if left else Vector3.LEFT
		var rotation:=Basis(Vector3.UP,PI*.5 if left else -PI*.5)
		var columns:int=ceili(size.z/3);var rows:int=ceili(size.y/3)
		var span:float=size.z/columns;var height:float=size.y/rows
		var placements:Array[Transform3D]=[]
		for column in columns:
			for row in rows:
				var point:Vector3=body.position+normal*.05+rotation.x*(-size.z*.5+(column+.5)*span)
				point.y=body.position.y-size.y*.5+row*height+.006
				var placement:=Transform3D(rotation*Basis.from_scale(Vector3((span-.012)/3,(height-.012)/3,.90)),point)
				assert(native.grow(.001).encloses(placement*mesh.get_aabb()),"Precision wall crossed original solid")
				placements.append(placement)
		var draw:=KIT._batch(root,"MeasuredMaintenanceWall_"+name,mesh,placements);draw.set_meta("native_wall_volume",native)
		backs.append(KIT._sized(body.position-normal*.10,Vector3(.012,size.y-.004,size.z-.004)))
		_pressure_pipes(root,body,normal,native)
	KIT._batch(root,"ContinuousPrecisionWallJointBackings",backing,backs)

static func _pressure_pipes(root:Node3D,body:Node3D,normal:Vector3,native:AABB)->void:
	var pipe:=CylinderMesh.new();pipe.top_radius=.032;pipe.bottom_radius=.032;pipe.height=1;pipe.radial_segments=32
	var clamp:=CylinderMesh.new();clamp.top_radius=.043;clamp.bottom_radius=.043;clamp.height=.065;clamp.radial_segments=32
	var pipes:Array[Transform3D]=[];var clamps:Array[Transform3D]=[]
	var x:float=body.position.x+normal.x*(native.size.x*.5-.045)
	for z in [-2.9,-7.4,-11.9]:
		pipes.append(Transform3D(Basis.from_scale(Vector3(1,8.8,1)),Vector3(x,4.9,z)))
		for y in [1.5,3.8,6.1,8.4]:clamps.append(Transform3D(Basis.IDENTITY,Vector3(x,y,z)))
	var draw:=KIT._batch(root,"PrecisionCopperPressureLines_"+str(body.name),pipe,pipes);draw.material_override=KIT._finish(Color(.38,.245,.12),.42,.58);draw.set_meta("native_wall_volume",native)
	draw=KIT._batch(root,"PrecisionMachinedPipeCollars_"+str(body.name),clamp,clamps);draw.material_override=KIT._finish(Color(.22,.245,.23),.5,.55);draw.set_meta("native_wall_volume",native)

static func _climb_cases(root:Node3D,spec:Dictionary,trim:Mesh,steel:Material,edge:Material,copper:Material)->void:
	var mesh:Mesh=trim.duplicate();for surface in mesh.get_surface_count():mesh.surface_set_material(surface,steel)
	var frame:Mesh=trim.duplicate();for surface in frame.get_surface_count():frame.surface_set_material(surface,edge)
	var bolt:Mesh=trim.duplicate();for surface in bolt.get_surface_count():bolt.surface_set_material(surface,copper)
	for row in spec.bodies:
		if not String(row.name).begins_with("COLL_CLIMB_"):continue
		var p:=Vector3(row.position[0],row.position[1],row.position[2]);var size:=Vector3(row.size[0],row.size[1],row.size[2]);var native:=AABB(p-size*.5,size)
		var draw:=KIT._batch(root,"PrecisionClosedClimbCase_"+row.name,mesh,[KIT._sized(p,size-Vector3(.016,.012,.05))]);draw.set_meta("native_climb_volume",native)
		var placements:Array[Transform3D]=[];var screws:Array[Transform3D]=[]
		var z:float=p.z+size.z*.5-.023
		for x in [-size.x*.5+.05,size.x*.5-.05]:placements.append(KIT._sized(Vector3(p.x+x,p.y,z),Vector3(.075,size.y-.04,.036)))
		for y in [-size.y*.5+.05,size.y*.5-.05]:placements.append(KIT._sized(Vector3(p.x,p.y+y,z),Vector3(size.x-.04,.075,.036)))
		for x in [-size.x*.5+.14,size.x*.5-.14]:
			for y in [-size.y*.5+.18,0,size.y*.5-.18]:screws.append(KIT._sized(Vector3(p.x+x,p.y+y,z),Vector3(.035,.035,.027)))
		draw=KIT._batch(root,"PrecisionClimbFrame_"+row.name,frame,placements);draw.set_meta("native_climb_volume",native)
		draw=KIT._batch(root,"PrecisionCaptiveClimbFasteners_"+row.name,bolt,screws);draw.set_meta("native_climb_volume",native)

static func _entry_floor(root:Node3D,spec:Dictionary,trim:Mesh,material:Material)->void:
	var row:Dictionary
	for candidate in spec.bodies:
		if candidate.name=="COLL_EntryFloor":row=candidate
	var p:=Vector3(row.position[0],row.position[1],row.position[2]);var size:=Vector3(row.size[0],row.size[1],row.size[2]);var native:=AABB(p-size*.5,size)
	var mesh:Mesh=trim.duplicate();for surface in mesh.get_surface_count():mesh.surface_set_material(surface,material)
	var placements:Array[Transform3D]=[]
	for x in 4:
		for z in 4:placements.append(KIT._sized(Vector3(p.x-size.x*.5+(x+.5)*size.x/4,p.y,p.z-size.z*.5+(z+.5)*size.z/4),Vector3(size.x/4-.012,size.y-.002,size.z/4-.012)))
	var draw:=KIT._batch(root,"PrecisionEntryFloorPanels",mesh,placements);draw.set_meta("native_floor_volume",native)

static func _service_seal(room:Node3D,root:Node3D,trim:Mesh,steel:Material,edge:Material)->void:
	var mesh:Mesh=trim.duplicate();for surface in mesh.get_surface_count():mesh.surface_set_material(surface,steel)
	# Each old side gap is.625m;the native capsule is.8m wide. These fixed
	# gasket adapters seal that already non-traversable clearance without a
	# new collider or any change to the1.75m moving door/control/socket.
	var placements:Array[Transform3D]=[]
	for x in [-1.20,1.20]:placements.append(KIT._sized(Vector3(x,6.4,-12.79),Vector3(.62,2.2,.56)))
	placements.append(KIT._sized(Vector3(0,7.69,-12.74),Vector3(3.02,.36,.46)))
	var draw:=KIT._batch(root,"PrecisionFixedDoorGasketAdapters",mesh,placements);draw.set_meta("old_side_gap_width",.625)
	var signal:=StandardMaterial3D.new();signal.albedo_color=Color(.1,.35,.38);signal.emission_enabled=true;signal.emission=Color(.10,.58,.66);signal.emission_energy_multiplier=.4
	for x in [-.9,.9]:_box(root,"PrecisionDoorJambSignal",Vector3(x,6.36,-12.495),Vector3(.016,1.84,.012),signal)
	for x in [-.18,.18]:
		for y in [.25,1.75]:_box(room._gate,"NativeDoorStiffenerCaptiveEnd",Vector3(x,y,.094),Vector3(.035,.045,.022),edge)

static func _overhead(root:Node3D,trim:Mesh,material:Material)->void:
	var mesh:Mesh=trim.duplicate();for surface in mesh.get_surface_count():mesh.surface_set_material(surface,material)
	var placements:Array[Transform3D]=[]
	for z in [-2.5,-6.5,-10.5]:
		for y in [9.78,10.32]:placements.append(KIT._sized(Vector3(.5,y,z),Vector3(9.32,.12,.20)))
		for i in 5:
			var a:=Vector3(-4.1+i*1.84,9.84 if i%2==0 else 10.26,z);var b:=Vector3(a.x+1.84,10.26 if i%2==0 else 9.84,z);var direction:Vector3=b-a
			placements.append(Transform3D(Basis.looking_at(direction.normalized(),Vector3.UP)*Basis.from_scale(Vector3(.055,.065,direction.length())),(a+b)*.5))
	KIT._batch(root,"PrecisionUpperServiceTrusses",mesh,placements)

static func _box(root:Node3D,label:String,point:Vector3,size:Vector3,material:Material)->void:
	var mesh:=BoxMesh.new();mesh.size=size;var visual:=MeshInstance3D.new();visual.name=label;visual.mesh=mesh;visual.material_override=material;visual.position=point;visual.layers|=KIT.ENVIRONMENT_LAYER;root.add_child(visual)

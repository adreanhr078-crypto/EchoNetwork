extends RefCounted

## Manufactured room skin. Original pressure task,grips,hand contact,gate,
## collision contract and source animation retain their existing owners.
const KIT=preload("res://scripts/environment/specimen_mechanical_dressing.gd")
const PBR=preload("res://scripts/environment/archive_mechanical_dressing.gd")
const WALL=preload("res://assets/environments/lab_clinical_cp45/clinical_wall_p2_4k.glb")
const TRIM=preload("res://assets/environments/specimen_cp45/specimen_trim_unit.glb")
const TRAY=preload("res://assets/environments/specimen_cp45/specimen_ceiling_tray.glb")

static func install(room:Node3D)->void:
	if room.has_node("MaintenanceMechanicalDressing"):return
	if ResourceLoader.exists("res://scripts/environment/maintenance_precision_architecture.gd"):
		preload("res://scripts/environment/maintenance_fullroom_dressing.gd").install(room)
		return
	var root:=Node3D.new();root.name="MaintenanceMechanicalDressing";room.add_child(root)
	var trim:Mesh=KIT._mesh(TRIM)
	for surface in trim.get_surface_count():trim.surface_set_material(surface,KIT._finish(Color(.40,.45,.47),.52,.43))
	_shell(room,root)
	_deck_hardware(room,root,trim)
	_pressure_hardware(room,root,trim)
	var overhead:Array[Transform3D]=[]
	for z in [-2.5,-6.5,-10.5]:
		for y in [9.75,10.35]:overhead.append(KIT._sized(Vector3(.5,y,z),Vector3(9.3,.13,.22)))
		for i in 5:
			var a:=Vector3(-4.1+i*1.84,9.8 if i%2==0 else 10.3,z)
			var b:=Vector3(a.x+1.84,10.3 if i%2==0 else 9.8,z)
			var direction:Vector3=b-a
			overhead.append(Transform3D(Basis.looking_at(direction.normalized(),Vector3.UP)*Basis.from_scale(Vector3(.055,.07,direction.length())),(a+b)*.5))
	KIT._batch(root,"MeasuredUpperServiceJoists",trim,overhead)
	var trays:Array[Transform3D]=[]
	for x in [-3.5,4.5]:
		for i in 5:trays.append(Transform3D(Basis.IDENTITY,Vector3(x,10.05,-1.0-i*2.7)))
	KIT._batch(root,"PairedMaintenanceCableTrays",KIT._mesh(TRAY),trays)

static func _shell(room:Node3D,root:Node3D)->void:
	var mesh:Mesh=PBR._pbr_mesh(WALL,room)
	for surface in mesh.get_surface_count():
		var finish:ShaderMaterial=mesh.surface_get_material(surface)
		finish.set_shader_parameter("base_color",Color(.58,.60,.59))
		finish.set_shader_parameter("texture_saturation",.45)
		finish.set_shader_parameter("metalness",.17)
		finish.set_shader_parameter("minimum_roughness",.59)
	var backing:=BoxMesh.new();backing.size=Vector3.ONE;backing.material=KIT._finish(Color(.12,.16,.19),.12,.72)
	var backs:Array[Transform3D]=[]
	for name in ["COLL_LeftBoundary","COLL_RightBoundary"]:
		var body:Node3D=room.get_node(name);var size:Vector3=body.get_child(0).shape.size
		var native:=AABB(body.position-size*.5,size)
		var left:bool=name=="COLL_LeftBoundary"
		var normal:=Vector3.RIGHT if left else Vector3.LEFT
		var rotation:=Basis(Vector3.UP,PI*.5 if left else -PI*.5)
		var columns:int=ceili(size.z/3);var rows:int=ceili(size.y/3)
		var span:float=size.z/columns;var height:float=size.y/rows
		var placements:Array[Transform3D]=[]
		for column in columns:
			for row in rows:
				var point:Vector3=body.position+normal*.10+rotation.x*(-size.z*.5+(column+.5)*span)
				point.y=body.position.y-size.y*.5+row*height+.006
				var placement:=Transform3D(rotation*Basis.from_scale(Vector3((span-.012)/3,(height-.012)/3,.90)),point)
				assert(native.grow(.001).encloses(placement*mesh.get_aabb()),"Maintenance panel crossed original wall")
				placements.append(placement)
		var batch:=KIT._batch(root,"MeasuredMaintenanceWall_"+name,mesh,placements)
		batch.set_meta("native_wall_volume",native)
		backs.append(KIT._sized(body.position-normal*.10,Vector3(.012,size.y-.004,size.z-.004)))
	KIT._batch(root,"ContinuousWallJointBackings",backing,backs)
	# Imported side/back/roof boundaries share one source mesh. Opt out only
	# the two replaced side skins,keeping all farwall/exit-aperture ownership.
	for material in room.presentation._boundary_finishes:
		material.set_shader_parameter("cladding_room_inverse",room.global_transform.affine_inverse())
		material.set_shader_parameter("measured_side_cladding",true)

static func _deck_hardware(room:Node3D,root:Node3D,trim:Mesh)->void:
	var edges:Array[Transform3D]=[];var fasteners:Array[Transform3D]=[]
	# Everything stays inside the existing20/40cm platform support. Never
	# add a raised obstacle,extend a landing or alter a climb face/rung/lip.
	for name in ["COLL_UpperRest","COLL_GapLanding","COLL_FinalRest","COLL_ExitDeck","COLL_ServiceVestibule"]:
		var body:Node3D=room.get_node(name);var size:Vector3=body.get_child(0).shape.size
		for side in [-1.0,1.0]:
			edges.append(KIT._sized(body.position+Vector3(side*(size.x*.5-.045),0,0),Vector3(.06,size.y-.04,size.z-.03)))
			edges.append(KIT._sized(body.position+Vector3(0,0,side*(size.z*.5-.045)),Vector3(size.x-.03,size.y-.04,.06)))
		for x in [-size.x*.5+.12,size.x*.5-.12]:
			for z in [-size.z*.5+.12,size.z*.5-.12]:
				fasteners.append(KIT._sized(body.position+Vector3(x,size.y*.5-.015,z),Vector3(.07,.018,.07)))
	KIT._batch(root,"OriginalPlatformEdgeExtrusions",trim,edges)
	KIT._batch(root,"RecessedDeckFasteners",trim,fasteners)

static func _pressure_hardware(room:Node3D,root:Node3D,trim:Mesh)->void:
	var fittings:Array[Transform3D]=[]
	# Gauge rim sits behind the original animated needle/ticks and caption.
	var bezel:=TorusMesh.new();bezel.inner_radius=.255;bezel.outer_radius=.285;bezel.rings=80;bezel.ring_segments=12
	bezel.material=KIT._finish(Color(.55,.58,.57),.62,.34)
	KIT._batch(root,"MachinedNativePressureGaugeBezel",bezel,[Transform3D(Basis(Vector3.RIGHT,PI*.5),Vector3(1.88,6.95,-12.465))])
	# Mounting plate is behind the original wheel hand socket. A full clear
	# 0.43m radius around the rotating handwheel remains entirely untouched.
	for x in [.78,1.72]:
		fittings.append(KIT._sized(Vector3(x,6.35,-12.65),Vector3(.055,.96,.07)))
	for y in [5.87,6.83]:fittings.append(KIT._sized(Vector3(1.25,y,-12.65),Vector3(.995,.055,.07)))
	# Coupled bands explain the eight preexisting pressure pipes;their bore,
	# silhouette and room-local animation remain as authored.
	for x in [-4.09,5.09]:
		for z in [-3.5,-5.95,-8.4,-10.85]:
			for y in [1.55,4.15,6.95]:
				fittings.append(KIT._sized(Vector3(x,y,z),Vector3(.18,.09,.18)))
	KIT._batch(root,"PressureWheelMountAndPipeBands",trim,fittings)

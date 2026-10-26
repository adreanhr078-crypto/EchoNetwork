extends RefCounted

## Manufactured visual architecture within the existing measured reactor.
## No triggers,colliders,progression,time source or interactive authority.
const KIT=preload("res://scripts/environment/specimen_mechanical_dressing.gd")
const ARCHIVE_KIT=preload("res://scripts/environment/archive_mechanical_dressing.gd")
const TRIM=preload("res://assets/environments/specimen_cp45/specimen_trim_unit.glb")
const TRAY=preload("res://assets/environments/specimen_cp45/specimen_ceiling_tray.glb")
const WALL=preload("res://assets/environments/lab_clinical_cp45/clinical_wall_p2_4k.glb")
const CROWN=preload("res://assets/environments/reactor_cp45/reactor_crown_pbr4k.glb")

static func install(room:Node3D)->void:
	if room.has_node("ReactorMechanicalDressing"):return
	var root:=Node3D.new();root.name="ReactorMechanicalDressing";room.add_child(root)
	var trim:Mesh=KIT._mesh(TRIM)
	for surface in trim.get_surface_count():trim.surface_set_material(surface,KIT._finish(Color(.47,.49,.49),.58,.36))
	_shell(room,root)
	_core_cage(room,root,trim)
	_decks(room,trim)
	_platform_hangers(root,trim)
	_cooling_services(room,root)
	_structural_services(room,root,trim)
	for ring in room.get_node("ReactorCore").find_children("PlasmaRing_*","MeshInstance3D",false,false):
		# Preserve radii,position,material and native clock;round the tube silhouette.
		ring.mesh.rings=256;ring.mesh.ring_segments=24
	var trays:Array[Transform3D]=[]
	for x in [-11.0,11.0]:
		for i in 12:trays.append(Transform3D(Basis.IDENTITY,Vector3(x,5.72,-5.5-float(i)*3)))
	KIT._batch(root,"PairedReactorCeilingTrays",KIT._mesh(TRAY),trays)
	# Existing functional lights and native emitter phases retain ownership.
	# A neutral task light reveals metal without painting the whole room blue.
	for light in room.get_node("ServiceLighting").find_children("*","OmniLight3D",false,false):
		light.light_color=Color(.96,.98,1);light.light_energy=1.65
	for console in [room._breaker_a_console,room._breaker_b_console]:_console_finish(console,room)
	room._core_shell_material.set_shader_parameter("body_color",Color(.30,.32,.33))
	room._core_shell_material.set_shader_parameter("joint_color",Color(.085,.10,.12))
	room._core_shell_material.set_shader_parameter("finish_grain",KIT.GRAIN)
	room._core_shell_material.set_shader_parameter("has_finish_grain",true)

static func _shell(room:Node3D,root:Node3D)->void:
	var mesh:Mesh=ARCHIVE_KIT._pbr_mesh(WALL,room)
	var plain:=KIT._finish(Color(.29,.31,.32),.18,.65)
	for surface in mesh.get_surface_count():
		var finish:ShaderMaterial=mesh.surface_get_material(surface)
		finish.set_shader_parameter("base_color",Color(.43,.44,.43))
		finish.set_shader_parameter("texture_saturation",.35)
		finish.set_shader_parameter("metalness",.22)
		finish.set_shader_parameter("minimum_roughness",.58)
	for child in room.get_node("Ceiling").get_children():
		if child is MeshInstance3D:child.material_override=plain
	var total:=0
	for name in ["WestWall","EastWall","SouthWallWest","SouthWallEast","SouthUnderPortal","SouthLintel","NorthWallWest","NorthWallEast","NorthUnderGate","NorthLintel"]:
		var body:Node3D=room.get_node(name)
		var shape:BoxShape3D=body.get_node("CollisionShape3D").shape
		var size:Vector3=shape.size;var along_x:bool=size.x>size.z
		var span:float=size.x if along_x else size.z
		var normal:Vector3;var yaw:float
		if name=="WestWall":normal=Vector3.RIGHT;yaw=PI*.5
		elif name=="EastWall":normal=Vector3.LEFT;yaw=-PI*.5
		elif name.begins_with("South"):normal=Vector3.FORWARD;yaw=PI
		else:normal=Vector3.BACK;yaw=0
		var rotation:=Basis(Vector3.UP,yaw)
		var columns:int=ceili(span/3);var rows:int=ceili(size.y/3)
		var width:float=span/columns;var height:float=size.y/rows
		var original_bounds:=AABB(body.position-size*.5,size)
		var placements:Array[Transform3D]=[]
		for column in columns:
			for row in rows:
				var point:Vector3=body.position+normal*.15+rotation.x*(-span*.5+(column+.5)*width)
				point.y=body.position.y-size.y*.5+row*height+.006
				var placement:=Transform3D(rotation*Basis.from_scale(Vector3((width-.012)/3,(height-.012)/3,.90)),point)
				assert(original_bounds.grow(.001).encloses(placement*mesh.get_aabb()),"Reactor wall tile crossed native portal or hull: "+name)
				placements.append(placement)
		for visual in body.get_children():
			if visual is MeshInstance3D:
				visual.material_override=plain;visual.position=-normal*.23
				if along_x:visual.scale.z=.05
				else:visual.scale.x=.05
		var batch:=KIT._batch(root,"MeasuredReactorCladding_"+name,mesh,placements)
		batch.set_meta("original_wall_volume",original_bounds);total+=placements.size()
	root.set_meta("measured_reactor_cladding_tiles",total)

static func _core_cage(room:Node3D,root:Node3D,trim:Mesh)->void:
	var core:Node3D=room.get_node("ReactorCore")
	var staves:Array[Transform3D]=[];var clamps:Array[Transform3D]=[]
	# 14 native shader vent bays remain open between the real cage staves.
	# Entire rigid cage stays within the existing4.8m collision cylinder.
	for i in 14:
		var angle:float=TAU*float(i)/14-PI
		# Match atan(z,x) in the native housing shader. Using sin/cos in
		# the opposite order shifts14bays by HALF a cell and masks emitters.
		var radial:=Vector3(cos(angle),0,sin(angle))
		var rotation:=Basis(Vector3.UP,PI*.5-angle)
		staves.append(Transform3D(rotation*Basis.from_scale(Vector3(.18,13.55,.26)),core.position+radial*4.64))
		for row in 6:
			var point:Vector3=core.position+radial*4.60+Vector3(0,-5.825+row*2.35,0)
			clamps.append(Transform3D(rotation*Basis.from_scale(Vector3(.34,.26,.30)),point))
	KIT._batch(root,"FourteenContainmentStaves",trim,staves)
	KIT._batch(root,"EightyFourServiceClamps",trim,clamps)
	var hoop:=TorusMesh.new();hoop.inner_radius=4.48;hoop.outer_radius=4.76;hoop.rings=112;hoop.ring_segments=12
	hoop.material=KIT._finish(Color(.29,.32,.33),.58,.40)
	var hoops:Array[Transform3D]=[]
	for y in [-6.65,-4.0,-.5,3.0]:hoops.append(Transform3D(Basis.IDENTITY,core.position+Vector3(0,y,0)))
	KIT._batch(root,"RigidPlasmaMountingHoops",hoop,hoops)
	var crown:Mesh=ARCHIVE_KIT._pbr_mesh(CROWN,room)
	for surface in crown.get_surface_count():
		var finish:ShaderMaterial=crown.surface_get_material(surface)
		finish.set_shader_parameter("texture_saturation",.55)
		finish.set_shader_parameter("minimum_roughness",.42)
	KIT._batch(root,"MeasuredFullDetailReactorCrown",crown,[Transform3D(Basis.IDENTITY,core.position+Vector3(0,6.4,0))])
	root.set_meta("native_emitter_bays_unobstructed",14)

static func _decks(room:Node3D,trim:Mesh)->void:
	var finish:=KIT._finish(Color(.30,.33,.34),.34,.60)
	var names:=["EntryBalconyDeck","WestPlatform","EastPlatform","HydraulicBridge","ExitGantryDeck","EntryServiceLink","WestServiceAscent","WestServiceLanding","SouthCircuitWalkway","EastCircuitWalkway","BridgeAccessRamp","BridgeAccessLanding","ExitBridgeLink"]
	for name in names:
		var body:Node3D=room.get_node(name)
		# Native support ramps have engine-assigned shape names. Read the
		# existing direct shape without renaming it or missing eight ramps.
		var collision:CollisionShape3D
		for child in body.get_children():
			if child is CollisionShape3D:collision=child;break
		var grating:bool=collision!=null and collision.shape is BoxShape3D
		for visual in body.get_children():
			if visual is MeshInstance3D:
				if grating:visual.hide()
				else:visual.material_override=finish
		if not grating:continue
		var size:Vector3=collision.shape.size
		var placements:Array[Transform3D]=[]
		for z in [-size.z*.5+.055,size.z*.5-.055]:placements.append(KIT._sized(Vector3(0,size.y*.5-.065,z),Vector3(size.x-.02,.10,.09)))
		for x in [-size.x*.5+.055,size.x*.5-.055]:placements.append(KIT._sized(Vector3(x,size.y*.5-.065,0),Vector3(.09,.10,size.z-.02)))
		KIT._batch(body,"NativeDeckMachinedEdges",trim,placements)
		var bars:Array[Transform3D]=[]
		var count:int=ceili(size.z/.18)
		for i in count:
			var z:float=-size.z*.5+(i+.5)*size.z/count
			bars.append(KIT._sized(Vector3(0,size.y*.5-.04,z),Vector3(size.x-.02,.08,.065)))
		var stringers:int=ceili(size.x/.85)
		for i in stringers+1:
			var x:float=-size.x*.5+.055+(size.x-.11)*float(i)/stringers
			bars.append(KIT._sized(Vector3(x,size.y*.5-.11,0),Vector3(.055,.08,size.z-.02)))
		KIT._batch(body,"MeasuredWalkableGrating",trim,bars)
	for rail in room.find_children("*Rail*","StaticBody3D",true,false):
		for visual in rail.get_children():
			if visual is MeshInstance3D:visual.material_override=KIT._finish(Color(.38,.41,.42),.40,.55)
	for visual in room._gate.get_children():
		if visual is MeshInstance3D:visual.material_override=KIT._finish(Color(.26,.28,.29),.36,.56)

static func _platform_hangers(root:Node3D,trim:Mesh)->void:
	var placements:Array[Transform3D]=[]
	# Support ties stay over the abyss just OUTSIDE each old deck footprint.
	# They cannot become an invisible obstacle inside its playable corridor.
	for centre in [Vector3(-11,-2,-16),Vector3(11,-2,-28)]:
		for x in [-3.08,3.08]:
			for z in [-4.08,4.08]:
				placements.append(KIT._sized(centre+Vector3(x,3.935,z),Vector3(.10,8.13,.10)))
				placements.append(KIT._sized(centre+Vector3(x,8.05,z),Vector3(.18,.10,.18)))
		for z in [-3.97,3.97]:placements.append(KIT._sized(centre+Vector3(0,-.15,z),Vector3(6.28,.18,.30)))
	KIT._batch(root,"PlatformSuspensionTiesOutsideDeck",trim,placements)

static func _console_finish(console:Node3D,room:Node3D)->void:
	var original:Node3D=room.SIGNAL_CONSOLE_PROP.instantiate()
	var model:Node3D=console.get_node("Prop")
	for source in original.find_children("*","MeshInstance3D",true,false):
		var live:MeshInstance3D=model.get_node(original.get_path_to(source))
		for surface in source.mesh.get_surface_count():
			var prior:StandardMaterial3D=source.get_active_material(surface)
			if prior.resource_name.ends_with("Titanium"):live.set_surface_override_material(surface,KIT._finish(Color(.57,.59,.59),.38,.48))
			elif prior.resource_name.ends_with("Graphite"):live.set_surface_override_material(surface,KIT._finish(Color(.30,.34,.38),.26,.52))
	original.free()
	var mount:Node3D=model.find_child("EchoSignalConsole_ScreenMount",true,false)
	assert(mount!=null,"Authored reactor console screen mount missing")
	var readout:=preload("res://scripts/environment/reactor_breaker_readout.gd").new()
	readout.name="NativeReactorCircuitReadout";readout.reactor=room
	readout.instrument=0 if console==room._breaker_a_console else 1
	var face:=QuadMesh.new();face.size=Vector2(1.10,.59);readout.mesh=face
	readout.position=Vector3(0,0,.081);readout.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var finish:=ShaderMaterial.new();finish.shader=preload("res://shaders/reactor_breaker_readout.gdshader")
	readout.material_override=finish;mount.add_child(readout);readout.sync_state()

static func sync_readouts(room:Node3D)->void:
	# Restore/pause/inactive rooms must show state before their next process
	# frame. Called by the existing native beacon owner;never changes truth.
	for console in [room._breaker_a_console,room._breaker_b_console]:
		if not is_instance_valid(console):continue
		var readout:Node=console.find_child("NativeReactorCircuitReadout",true,false)
		if readout!=null:readout.sync_state()

static func _cooling_services(room:Node3D,root:Node3D)->void:
	# Reuse the accepted manufactured filtration module as ordinary facility
	# cooling hardware. Wall mounting over the abyss keeps every native path,
	# platform,console and climbable conduit free;there is no new interaction.
	var mesh:Mesh=KIT._mesh(KIT.FILTER,room)
	for surface in mesh.get_surface_count():
		var material:ShaderMaterial=mesh.surface_get_material(surface)
		var color:Color=material.get_shader_parameter("base_color")
		material.set_shader_parameter("base_color",color*Color(.55,.57,.60))
		material.set_shader_parameter("texture_saturation",.35)
		material.set_shader_parameter("minimum_roughness",.55)
	var source:AABB=mesh.get_aabb()
	var bottom_centre:Vector3=source.position+source.size*.5
	bottom_centre.y=source.position.y
	var banks:Array[Transform3D]=[]
	var pipes:Array[Transform3D]=[];var elbows:Array[Transform3D]=[]
	for side in [-1.0,1.0]:
		var rotation:=Basis(Vector3.UP,-side*PI*.5)
		# Recess the service body inside the existing solid wall. Its face
		# projects only4cm:the old player/camera wall remains its real barrier.
		var basis:Basis=rotation*Basis.from_scale(Vector3(2.8,2.8,.38)/source.size)
		for index in 2:
			var z:float=-14.0 if index==0 else -30.0
			var position:=Vector3(side*18.15,-2.2,z)
			var placement:=Transform3D(basis,position-basis*bottom_centre)
			var bounds:AABB=placement*source
			assert(bounds.position.x>=-18.501 and bounds.end.x<=18.501,"Cooling bank crossed native hull")
			assert(bounds.end.x<-17.95 or bounds.position.x>17.95,"Cooling bank projected outside the existing wall barrier")
			banks.append(placement)
			var level:float=-4.35-float(index)
			var route:=[Vector3(side*17.95,-2.18,z),Vector3(side*17.95,level,z),Vector3(side*6.2,level,z),Vector3(side*6.2,level,-22),Vector3(side*4.65,level,-22)]
			for point in route:elbows.append(Transform3D(Basis.IDENTITY,point))
			for i in route.size()-1:
				var direction:Vector3=route[i+1]-route[i]
				var orientation:=Basis(Quaternion(Vector3.UP,direction.normalized()))
				pipes.append(Transform3D(orientation*Basis.from_scale(Vector3(1,direction.length(),1)),(route[i]+route[i+1])*.5))
	KIT._batch(root,"FourWallMountedCoolingBanks",mesh,banks)
	var finish:=KIT._finish(Color(.43,.32,.23),.62,.35)
	var pipe:=CylinderMesh.new();pipe.top_radius=.11;pipe.bottom_radius=.11;pipe.height=1;pipe.radial_segments=24;pipe.rings=1;pipe.material=finish
	KIT._batch(root,"UnderRouteCoolingConnections",pipe,pipes)
	var elbow:=SphereMesh.new();elbow.radius=.13;elbow.height=.26;elbow.radial_segments=20;elbow.rings=10;elbow.material=finish
	KIT._batch(root,"SealedCoolingCouplings",elbow,elbows)
	# Real pressure flanges terminate the service runs on the cage. Their
	# bodies are below the routes;no apparent tube passes through a plasma ring.
	var flange:=CylinderMesh.new();flange.top_radius=.24;flange.bottom_radius=.24;flange.height=.12;flange.radial_segments=40
	flange.material=KIT._finish(Color(.42,.44,.45),.62,.35)
	var collars:Array[Transform3D]=[];var bolts:Array[Transform3D]=[]
	for side in [-1.0,1.0]:
		for level in [-4.35,-5.35]:
			collars.append(Transform3D(Basis(Vector3.FORWARD,PI*.5),Vector3(side*4.82,level,-22)))
			for i in 8:
				var angle:float=TAU*float(i)/8
				bolts.append(KIT._sized(Vector3(side*4.89,level+sin(angle)*.19,-22+cos(angle)*.19),Vector3(.045,.045,.045)))
	KIT._batch(root,"FourCoolingPressureFlanges",flange,collars)
	var bolt:=BoxMesh.new();bolt.size=Vector3.ONE;bolt.material=flange.material
	KIT._batch(root,"ThirtyTwoFlangeFasteners",bolt,bolts)

static func _structural_services(room:Node3D,root:Node3D,trim:Mesh)->void:
	var structure:Array[Transform3D]=[]
	# Four real ceiling trusses sit above every reachable deck and the crown.
	# Chords meet the old solid walls;webs explain the suspension load path.
	for z in [-8.0,-16.0,-28.0,-36.0]:
		for y in [4.95,5.70]:structure.append(KIT._sized(Vector3(0,y,z),Vector3(35.9,.18,.30)))
		for x in [-17.84,17.84]:structure.append(KIT._sized(Vector3(x,5.32,z),Vector3(.28,.90,.65)))
		for i in 12:
			var x:float=-17.7+float(i)*2.95
			var a:=Vector3(x,4.99 if i%2==0 else 5.66,z)
			var b:=Vector3(x+2.95,5.66 if i%2==0 else 4.99,z)
			var direction:Vector3=b-a
			structure.append(Transform3D(Basis.looking_at(direction.normalized(),Vector3.UP)*Basis.from_scale(Vector3(.075,.10,direction.length())),(a+b)*.5))
	# A wall belt separates the lower containment well from the service level.
	# Its inner face is within4cm of the original solid wall barrier.
	for side in [-1.0,1.0]:
		structure.append(KIT._sized(Vector3(side*17.98,-2.55,-22),Vector3(.08,.32,43.8)))
		for z in [-8.0,-16.0,-28.0,-36.0]:
			structure.append(KIT._sized(Vector3(side*17.98,-2.55,z),Vector3(.08,.50,.52)))
	KIT._batch(root,"CeilingTrussesAndServiceLevelBelt",trim,structure)
	# Slightly warmer alloy separates a safe deck edge from the dark well.
	# All nosings remain inside the original continuous deck support volume.
	var marker:=BoxMesh.new();marker.size=Vector3.ONE
	marker.material=KIT._finish(Color(.58,.44,.20),.32,.49)
	for name in ["WestPlatform","EastPlatform","HydraulicBridge","ExitBridgeLink"]:
		var body:Node3D=room.get_node(name);var shape:CollisionShape3D
		for child in body.get_children():
			if child is CollisionShape3D:shape=child;break
		var size:Vector3=shape.shape.size
		var nosings:Array[Transform3D]=[]
		for side in [-1.0,1.0]:
			nosings.append(KIT._sized(Vector3(side*(size.x*.5-.055),size.y*.5-.011,0),Vector3(.055,.018,size.z-.12)))
		KIT._batch(body,"NativeEnvelopeAmberEdgeNosings",marker,nosings)
	for visual in room.get_node("AbyssFloor").get_children():
		if visual is MeshInstance3D:visual.material_override=KIT._finish(Color(.21,.24,.26),.24,.62)
	# Fixed physical bounce reveals the base without introducing an animated
	# threat cue,extra clock or any player-triggered light.
	for side in [-1.0,1.0]:
		var bounce:=OmniLight3D.new();bounce.name="ContainmentWellBounce"
		bounce.position=Vector3(side*10,-7.7,-22);bounce.light_color=Color(.34,.46,.52)
		bounce.light_energy=2.1;bounce.omni_range=18;bounce.shadow_enabled=false
		root.add_child(bounce)
	# Foundation shoes remain below the existing abyss recovery threshold;
	# they never create a false reachable landing or alter the original floor.
	var foundations:Array[Transform3D]=[]
	for x in [-1.0,1.0]:
		for z in [-1.0,1.0]:
			var a:=Vector3(x*3.9,-9.79,-22+z*3.9)
			var b:=Vector3(x*13.5,-9.79,-22+z*13.5)
			var direction:Vector3=b-a
			foundations.append(Transform3D(Basis.looking_at(direction.normalized(),Vector3.UP)*Basis.from_scale(Vector3(.45,.36,direction.length())),(a+b)*.5))
	KIT._batch(root,"AbyssFoundationBelowRecoveryPlane",trim,foundations)

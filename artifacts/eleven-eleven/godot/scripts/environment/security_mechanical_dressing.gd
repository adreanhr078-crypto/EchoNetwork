extends RefCounted

## Reuse the measured accepted facility cabinet without another paid job.
## Native six cover solids,all stations,detector,walkway and cues remain live.
const KIT=preload("res://scripts/environment/specimen_mechanical_dressing.gd")
const FILTER=preload("res://assets/environments/specimen_cp45/specimen_filter_h31_pbr4k.glb")
const SENSOR=preload("res://assets/environments/specimen_cp45/specimen_sensor_housing.glb")
const TRIM=preload("res://assets/environments/specimen_cp45/specimen_trim_unit.glb")

static func install(room:Node3D)->void:
	if room.has_node("SecurityMechanicalDressing"):return
	var root:=Node3D.new();root.name="SecurityMechanicalDressing";room.add_child(root)
	var placements:Array[Transform3D]=[]
	var cover_size:=Vector3(1.6,1.7,1.1)
	for body in room.get_children():
		if not body is StaticBody3D:continue
		var shape:CollisionShape3D=body.get_node_or_null("CollisionShape3D")
		if not shape or not shape.shape is BoxShape3D or not shape.shape.size.is_equal_approx(cover_size):continue
		# Fit the shared geometry to this original cover volume. Its two access
		# doors and solid vent back remain plausible at the narrower width.
		var scale:=Vector3(1.6/2.2,1.7/1.8,1.1/1.4)
		placements.append(KIT._sized(body.position-Vector3(0,.85,0),scale))
		for visual in body.get_children():
			if visual is MeshInstance3D:visual.hide()
	assert(placements.size()==6,"Expected six unchanged security cover solids")
	# Existing flat overlay plates would obscure the new physical doors.
	# Hide their meshes only;retain every original slim indicator/safe edge.
	for node in room.get_children():
		if not node is Node3D:continue
		for visual in node.get_children():
			if visual is MeshInstance3D and visual.mesh is BoxMesh and visual.mesh.size.is_equal_approx(Vector3(1.36,1.4,.025)):
				visual.hide()
	var mesh:=KIT._mesh(FILTER,room)
	var finish:ShaderMaterial=mesh.surface_get_material(0)
	finish.set_shader_parameter("base_color",Color(.67,.73,.80))
	finish.set_shader_parameter("minimum_roughness",.45)
	var draw:=KIT._batch(root,"SixMeasuredSecurityCoverCabinets",mesh,placements)
	draw.set_meta("native_cover_volume",cover_size)
	var floor:Node3D=room.get_node("Floor")
	var floor_finish:=preload("res://scripts/environment/room_panel_finish.gd").material(Color(.30,.35,.41),Vector2(2.2,2.2),.16,.60)
	for visual in floor.get_children():
		if visual is MeshInstance3D:visual.material_override=floor_finish
	_readable_devices(room,root)
	_readable_architecture(room,root)

static func _readable_devices(room:Node3D,root:Node3D)->void:
	var trim_mesh:=KIT._mesh(TRIM)
	for surface in trim_mesh.get_surface_count():
		trim_mesh.surface_set_material(surface,KIT._finish(Color(.46,.53,.62),.18,.52))
	# Both pressure plates move only with the existing authoritative gate.
	var plates:Array[Transform3D]=[]
	for x in [-.42,.42]:plates.append(KIT._sized(Vector3(x,0,.073),Vector3(.74,2.55,.03)))
	for mesh in room._gate.get_children():
		if mesh is MeshInstance3D and mesh.mesh is BoxMesh and mesh.mesh.size.is_equal_approx(Vector3(1.76,2.8,.18)):mesh.scale.z=.72
	KIT._batch(room._gate,"FittedGatePressurePlates",trim_mesh,plates)
	var frame:Array[Transform3D]=[]
	for x in [-.99,.99]:frame.append(KIT._sized(Vector3(x,1.4,-16.35),Vector3(.16,2.8,.12)))
	frame.append(KIT._sized(Vector3(0,2.94,-16.35),Vector3(2.1,.24,.12)))
	KIT._batch(root,"MeasuredSecurityExitFrame",trim_mesh,frame)
	var sensor_mesh:=KIT._mesh(SENSOR)
	for child in room._scanner.get_children():
		if not child is MeshInstance3D:continue
		if child.mesh is SphereMesh:child.hide()
		elif child.mesh is CylinderMesh and is_equal_approx(child.mesh.height,.05):child.hide()
	KIT._batch(room._scanner,"CompactNativeScannerHousing",sensor_mesh,[KIT._sized(Vector3.ZERO,Vector3(.34/.48,.24/.38,.34/.78))])
	var optic:=preload("res://scripts/environment/security_optic_indicator.gd").new()
	optic.name="NativeThreatOptic";optic.lamp=room._lamp
	var iris:=QuadMesh.new();iris.size=Vector2(.13,.13);optic.mesh=iris
	optic.position.z=-.197;optic.rotation.y=PI
	var iris_material:=ShaderMaterial.new();iris_material.shader=preload("res://shaders/specimen_sensor_optic.gdshader")
	optic.material_override=iris_material;optic.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	room._scanner.add_child(optic)
	var mount:Node3D=room.get_node("ScannerMount")
	for child in mount.get_children():
		if child is MeshInstance3D:child.hide()
	KIT._batch(root,"MachinedScannerSuspension",trim_mesh,[KIT._sized(mount.position,Vector3(.075,2.58,.075)),KIT._sized(Vector3(0,4.55,-14.5),Vector3(.24,.07,.24))])
	for station in room._stations.values():
		for child in station.get_children():
			if not child is MeshInstance3D or not child.mesh is BoxMesh:continue
			if child.mesh.size.is_equal_approx(Vector3(.4,.6,.22)):
				child.hide();KIT._batch(station,"FittedStationCasing",trim_mesh,[KIT._sized(Vector3.ZERO,Vector3(.4,.6,.22))])
			elif child.mesh.size.is_equal_approx(Vector3(.24,.28,.025)):
				var prior:StandardMaterial3D=child.get_active_material(0)
				var signal_color:Color=prior.emission
				child.material_override=KIT._finish(Color(.04,.06,.08),.20,.5)
				var display:=MeshInstance3D.new();display.name="NativeStationReadout"
				var panel:=QuadMesh.new();panel.size=Vector2(.21,.25);display.mesh=panel;display.position.z=.014
				var surface:=ShaderMaterial.new();surface.shader=preload("res://shaders/security_station_readout.gdshader")
				surface.set_shader_parameter("signal_color",signal_color);display.material_override=surface
				display.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;child.add_child(display)


static func _readable_architecture(room:Node3D,root:Node3D)->void:
	# Continuous ceramic response lifts the original opaque shell out of the
	# actor cel ramp. No additional light or changed collision/route is used.
	var wall:=KIT._finish(Color(.33,.40,.49),.08,.62)
	var inset:=KIT._finish(Color(.43,.50,.57),.06,.65)
	var deck:=KIT._finish(Color(.35,.43,.50),.12,.58)
	var rail:=KIT._finish(Color(.60,.66,.70),.10,.52)
	var edge:=KIT._mesh(TRIM)
	for surface in edge.get_surface_count():
		edge.surface_set_material(surface,rail)
	var trims:Array[Transform3D]=[]
	for node in room.get_children():
		if not node is Node3D:continue
		for visual in node.get_children():
			if not visual is MeshInstance3D or not visual.mesh is BoxMesh:continue
			var size:Vector3=visual.mesh.size
			if size.is_equal_approx(Vector3(.2,4.8,18)) or size.is_equal_approx(Vector3(3.6,4.4,.4)) or size.is_equal_approx(Vector3(3.6,4.4,.25)) or size.is_equal_approx(Vector3(8.8,4.4,.12)) or size.is_equal_approx(Vector3(1.8,1.6,.25)) or size.is_equal_approx(Vector3(1.8,1.2,.4)):
				visual.material_override=wall
			elif size.is_equal_approx(Vector3(.08,1.45,1.6)):
				visual.material_override=inset
				# Four beveled retainers remain inside each original inset AABB.
				var x:float=node.position.x-signf(node.position.x)*.029
				for y in [-.69,.69]:trims.append(KIT._sized(Vector3(x,node.position.y+y,node.position.z),Vector3(.018,.055,1.58)))
				for z in [-.76,.76]:trims.append(KIT._sized(Vector3(x,node.position.y,node.position.z+z),Vector3(.018,1.35,.055)))
			elif size.is_equal_approx(Vector3(1.3,2.4,1.6)) or size.is_equal_approx(Vector3(1.3,.24,9.2)) or size.is_equal_approx(Vector3(1.3,.18,1.6)):
				visual.material_override=deck
			elif size.is_equal_approx(Vector3(.9,.055,.06)) or size.is_equal_approx(Vector3(.04,.7,.04)) or size.is_equal_approx(Vector3(.04,.04,10)):
				visual.material_override=rail
	# Bright machined lips fit entirely inside the solid climb and deck bounds.
	for x in [2.985,4.215]:
		trims.append(KIT._sized(Vector3(x,2.365,-8.4),Vector3(.055,.055,9.16)))
		trims.append(KIT._sized(Vector3(x,1.2,-2.325),Vector3(.055,2.35,.045)))
		trims.append(KIT._sized(Vector3(x,1.315,-14.2),Vector3(.055,.045,1.56)))
	KIT._batch(root,"InsetRetainersAndNativeTraversalLips",edge,trims)

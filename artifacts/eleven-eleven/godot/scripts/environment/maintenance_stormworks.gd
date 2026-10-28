extends "res://scripts/environment/maintenance_vertical.gd"

## Full Tripo architecture candidate. Gameplay/save acceptance remains separate.
const VISUAL = preload("res://assets/environments/maintenance_stormworks/stormworks_original_pbr_metric_v8.glb")
const COLLISION = preload("res://assets/environments/maintenance_stormworks/stormworks_collision_portal_v7.glb")
const SERVICE_SOURCE = preload("res://assets/environments/maintenance_jutsu_v1.glb")
const ATMOSPHERE = preload("res://scripts/environment/maintenance_stormworks_presentation.gd")
const FAN = preload("res://assets/environments/maintenance_cp45/maintenance_ventilation_fan_pbr.glb")
const WALL_MODULE = preload("res://assets/environments/maintenance_cp45/maintenance_primary_cassette_pbr4k.glb")
const GATE_CRAFT = preload("res://assets/environments/maintenance_stormworks/stormworks_precision_gate_v1.glb")
const WHEEL_CRAFT = preload("res://assets/environments/maintenance_stormworks/stormworks_precision_wheel_v1.glb")
const BULKHEAD_CRAFT = preload("res://assets/environments/maintenance_stormworks/stormworks_precision_bulkhead_v1.glb")
const FINISH_KIT = preload("res://scripts/environment/specimen_mechanical_dressing.gd")
const ROUTE = preload("res://scripts/systems/stormworks_route.gd")
const UNIFORM_SCALE := 18.334597451041343
const SOURCE_TRANSLATION := Vector3(0,-1.05,-9.8818091025)
const LAYOUT_REVISION := ROUTE.REVISION
const CLIMB_PARTS := [3,4,8,9,11,13,18,20,21]
var visual_time := 0.0
var collision_parts := 0
var source_visual: Node3D
var _fan_rotors: Array[Node3D] = []
var _finishes := {}
var _vault_adjustment := Transform3D.IDENTITY

func _ready() -> void:
	name = "MaintenanceStormworks"
	service_floor_anchor = Vector3(1.25,5.5,-17.46)
	service_hand_anchor = Vector3(1.25,5.5,-17.54)
	service_wheel_center = Vector3(1.25,6.45,-17.7)
	service_gate_anchor = Vector3(0,6.46,-18.3)
	service_camera_position = Vector3(2.8,7,-16.21)
	service_camera_target = Vector3(.4,6.5,-18.11)
	source_visual = VISUAL.instantiate()
	source_visual.name = "CompleteTripoArchitecture"
	# v8 is baked into metres, retaining every original per-part UV array.
	# Collision v7 still uses its explicitly measured normalized transform below.
	add_child(source_visual)
	_position_vault()
	var source := COLLISION.instantiate()
	source.scale = Vector3.ONE * UNIFORM_SCALE
	source.position = SOURCE_TRANSLATION
	_install_collision(source,Transform3D.IDENTITY)
	source.free()
	_install_entry_threshold()
	_install_grip_face()
	_install_chamber_housing()
	_install_turbines()
	_install_service_parts()
	_build_service()
	presentation = ATMOSPHERE.new()
	presentation.name = "StormworksPresentation"
	presentation.configure(self,{
		"water_bounds":AABB(Vector3(-7.6,-.45,-17.2),Vector3(15.2,.25,12.3)),
		"vent_positions":[Vector3(-7.15,.1,-7),Vector3(7.1,.1,-11.5),Vector3(-6.8,3.05,-15.4)],
		"vent_height":2.5,"vent_width":.9,"quality":"high"})
	presentation.set_presence(true)
	set_language("ar")
	set_reduced_motion(_motion_reduced)
	_install_route_markers()
	_install_lights()
	_finish_facility(self)
	var adapter = preload("res://engine_visuals/HyperMaterialAdapter.gd").new()
	adapter.convert_tree(self)

func _install_collision(node: Node, parent_pose: Transform3D) -> void:
	var pose := parent_pose
	if node is Node3D: pose = parent_pose * node.transform
	if node is MeshInstance3D and node.mesh:
		var body := StaticBody3D.new()
		body.name = "COLL_"+node.name
		var index := -1
		for part in 27:
			if String(node.name) == "Stormworks_tripo_part_%d" % part:
				index = part
		if index == 23: pose = _vault_adjustment * pose
		var shape := CollisionShape3D.new()
		var surface := ConcavePolygonShape3D.new()
		var faces: PackedVector3Array = node.mesh.get_faces()
		for vertex in faces.size(): faces[vertex] = pose * faces[vertex]
		surface.set_faces(faces)
		surface.backface_collision = true
		shape.shape = surface
		body.add_child(shape)
		add_child(body)
		if index in CLIMB_PARTS: body.add_to_group("climbable")
		if index == 23: body.add_to_group("vaultable")
		collision_parts += 1
	for child in node.get_children(): _install_collision(child,pose)

func _position_vault() -> void:
	var obstacle := source_visual.find_child("Stormworks_tripo_part_23",true,false) as MeshInstance3D
	assert(obstacle != null,"Measured Tripo vault part missing")
	var original := global_transform.affine_inverse()*obstacle.global_transform
	var center := original*obstacle.mesh.get_aabb().get_center()
	var target := Vector3(-4,center.y,-15.1)
	var rotation := Basis(Vector3.UP,PI*.5)
	_vault_adjustment = Transform3D(rotation,target-rotation*center)
	# The original crate overlaps the side-wall pedestal. Relocate and rotate
	# this rigid modular part into the open deck; retain mesh/UV/source keys.
	obstacle.global_transform = global_transform*_vault_adjustment*original

func _install_entry_threshold() -> void:
	# Visible load-bearing connection across the measured one metre front setback.
	var threshold := _box_with_collision("EntryThreshold",Vector3(0,.035,-1.25),Vector3(1.85,.18,3.3),Color(.21,.28,.3))
	threshold.rotation.x = .075
	_box_with_collision("EntryRunway",Vector3(0,-.12,-3.65),Vector3(3.4,.24,2.2),Color(.21,.28,.3))
	# Recess lining covers the precisely split generated wall's open edges.
	for x in [-.975,.975]:
		_box_with_collision("EntryPortalJamb",Vector3(x,1.2,-2.2),Vector3(.05,2.6,.65),Color(.19,.24,.26))
	_box_with_collision("EntryPortalLintel",Vector3(0,2.52,-2.2),Vector3(2,.08,.65),Color(.19,.24,.26))
	# The bridge ends before the rear wall; this visible continuation supports
	# the service wheel and later connection without an invisible floor.
	_box_with_collision("ServiceThreshold",Vector3(0,5.38,-18.35),Vector3(3.9,.24,1.8),Color(.21,.28,.3))
	for x in [-1.03,1.03]:
		_box_with_collision("ServicePortalJamb",Vector3(x,6.65,-18.35),Vector3(.08,2.3,.4),Color(.24,.31,.33))
	_box_with_collision("ServicePortalHeader",Vector3(0,7.8,-18.35),Vector3(4.2,.14,.4),Color(.24,.31,.33))
	for x in [-1.55,1.55]:
		_box_with_collision("ServiceAlcoveBacking",Vector3(x,6.65,-18.1),Vector3(1.1,2.3,.1),Color(.24,.31,.33))
	_box_with_collision("BridgeEndLining",Vector3(0,5.41,-16.18),Vector3(5.3,.16,.1),Color(.21,.28,.3))
	# The measured crate-to-rear-rail clearance did not fit a full capsule.
	# A supported front apron provides a fair approach and moves the vault
	# landing away from that rail, while retaining the complete Tripo deck.
	_box_with_collision("VaultRunupApron",Vector3(-3.8,2.85,-13.9),Vector3(3,.2,1),Color(.3,.37,.39))
	for x in [-5,-2.6]:
		var brace := _box_with_collision("VaultApronBrace",Vector3(x,2.2,-14.1),Vector3(.12,1.1,.14),Color(.18,.25,.27),false)
		brace.rotation.x = -.5

func _install_chamber_housing() -> void:
	# The complete generated architecture is an open structural assembly.
	# Housing closes its perimeter behind the source, without masking its detail.
	var steel := Color(.29,.34,.35)
	for x in [-9.25,9.25]:
		_box_with_collision("PressureChamberSide",Vector3(x,3.8,-10),Vector3(.3,8.8,19),steel)
	for x in [-5.2,5.2]:
		_box_with_collision("PressureChamberRear",Vector3(x,3.8,-19.4),Vector3(8.4,8.8,.3),steel)
	_box_with_collision("PressureChamberRearSill",Vector3(0,2.3,-19.4),Vector3(2,6.1,.3),steel)
	_box_with_collision("PressureChamberRoof",Vector3(0,8.4,-10),Vector3(18.8,.3,19),Color(.25,.3,.32))
	for z in [-5.5,-10,-14.5]:
		_box_with_collision("CeilingRib",Vector3(0,8.12,z),Vector3(18.4,.22,.2),Color(.17,.23,.25))
	for x in [-7.5,-2.5,2.5,7.5]:
		_box_with_collision("RoofCableSpine",Vector3(x,8.16,-10),Vector3(.12,.12,17.6),Color(.38,.43,.44),false)
	# Shared Tripo meshes/maps close the black perimeter with actual relief.
	# The existing housing owns collision; these instances remain outside the route.
	for side in [-1,1]:
		for z in [-4.15,-9.35,-14.55]:
			for y in [1.75,5.2]:
				var panel := WALL_MODULE.instantiate() as Node3D
				panel.name = "TripoPressureWallCassette"
				panel.position = Vector3(side*8.95,y,z)
				panel.rotation.y = -side*PI*.5
				panel.scale = Vector3.ONE*1.02
				add_child(panel)
				for mesh: MeshInstance3D in panel.find_children("*","MeshInstance3D",true,false):
					mesh.lod_bias = .7
	for z in [-4.5,-9.5,-14.5]:
		for x in [-5,0,5]:
			_box_with_collision("CeilingLuminaireHousing",Vector3(x,7.96,z),Vector3(2.7,.15,.34),Color(.32,.38,.4),false)
			var fixture := _box_with_collision("CeilingDiffuser",Vector3(x,7.87,z),Vector3(2.5,.035,.23),Color(.7,.83,.87),false)
			var lens := StandardMaterial3D.new()
			lens.albedo_color = Color(.7,.83,.87)
			lens.emission_enabled = true
			lens.emission = Color(.6,.8,.85)
			lens.emission_energy_multiplier = 2.0
			fixture.get_child(0).material_override = lens

func _install_grip_face() -> void:
	# The generated cap overhang leaves the support pillar out of hand reach.
	# A visible bolted plate supplies the qualified flat braced-hang surface.
	var grip := _box_with_collision("FirstPierGripFace",Vector3(-1.15,1.09,-4.55),Vector3(1.35,2.18,.12),Color(.26,.34,.36))
	grip.add_to_group("climbable")
	# Source relief at the front lip failed the five-point sole support check.
	# A visible 55mm steel landing plate spans that relief and remains inside
	# the generated platform's measured footprint; it is not a floating floor.
	_box_with_collision("FirstPierLandingPlate",Vector3(-1.15,2.2025,-5.58),Vector3(1.55,.055,1.75),Color(.32,.39,.4))
	for y in [.45,.95,1.45,2.12]:
		_box_with_collision("FirstPierGripRail",Vector3(-1.15,y,-4.475),Vector3(1.05,.035,.025),Color(.6,.39,.15),false)
	var final_grip := _box_with_collision("FinalBridgeGripFace",Vector3(-1.8,4.26,-16.18),Vector3(1.35,2.6,.12),Color(.26,.34,.36))
	final_grip.add_to_group("climbable")
	_box_with_collision("FinalBridgeLandingPlate",Vector3(-1.8,5.575,-16.725),Vector3(1.6,.05,1.15),Color(.32,.39,.4))
	for y in [3.3,3.8,4.3,4.8,5.5]:
		_box_with_collision("FinalBridgeGripRail",Vector3(-1.8,y,-16.105),Vector3(1.05,.035,.025),Color(.6,.39,.15),false)

func _install_turbines() -> void:
	for x in [-4.3,4.3]:
		var fan := FAN.instantiate()
		fan.name = "RearPressureTurbine"
		fan.position = Vector3(x,5.25,-18.85)
		fan.scale = Vector3.ONE * 2.5
		add_child(fan)
		var rotor := fan.find_child("FanPBRRotorPivot",true,false) as Node3D
		if rotor: _fan_rotors.append(rotor)
	# Match the three real upper intake apertures on the entrance elevation.
	for x in [-4.7,0,4.7]:
		var intake := FAN.instantiate() as Node3D
		intake.name = "EntrancePressureIntake"
		intake.position = Vector3(x,4.9,-1.9)
		intake.rotation.y = PI
		intake.scale = Vector3.ONE*3.5
		add_child(intake)
		var rotor := intake.find_child("FanPBRRotorPivot",true,false) as Node3D
		if rotor: _fan_rotors.append(rotor)

func _finish_facility(node: Node) -> void:
	if node is MeshInstance3D and node.mesh:
		for surface in node.mesh.get_surface_count():
			var source = node.get_active_material(surface)
			if source is StandardMaterial3D:
				if not _finishes.has(source):
					var finish: ShaderMaterial = FINISH_KIT._texture_finish(source,self)
					finish.set_shader_parameter("minimum_roughness",.48)
					finish.set_shader_parameter("normal_strength",source.normal_scale*.5)
					if node.name == "CassetteStructuralMesh":
						finish.set_shader_parameter("base_color",source.albedo_color*Color(.62,.63,.60))
						finish.set_shader_parameter("metalness",source.metallic*.75)
					_finishes[source] = finish
				node.set_surface_override_material(surface,_finishes[source])
	for child in node.get_children(): _finish_facility(child)

func _box_with_collision(label: String, point: Vector3, size: Vector3, color: Color, solid: bool = true) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = label
	body.position = point
	var shape := BoxShape3D.new()
	shape.size = size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	if solid: body.add_child(collider)
	else: collider.free()
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = .55
	material.roughness = .58
	mesh.material_override = material
	body.add_child(mesh)
	add_child(body)
	return body

func _install_service_parts() -> void:
	var original := SERVICE_SOURCE.instantiate()
	var shift := service_gate_anchor - Vector3(0,6.36,-12.94)
	for label in ["ServiceGateRoot","ServiceValveRoot"]:
		var part := original.find_child(label,true,false) as Node3D
		if not part:
			push_error("Stormworks missing preserved service hierarchy")
			continue
		var pose := part.transform
		var ancestor := part.get_parent()
		while ancestor != original and ancestor is Node3D:
			pose = ancestor.transform * pose
			ancestor = ancestor.get_parent()
		var copy := part.duplicate() as Node3D
		copy.name = label
		copy.transform = pose
		copy.position += shift
		add_child(copy)
		# Preserve the original animated root and contact API; replace only rigid visuals.
		for mesh: MeshInstance3D in copy.find_children("*","MeshInstance3D",true,false): mesh.hide()
		var crafted: Node3D
		var center: Vector3
		if label == "ServiceGateRoot":
			crafted = GATE_CRAFT.instantiate()
			center = service_gate_anchor+Vector3(0,.18,0)
		else:
			crafted = WHEEL_CRAFT.instantiate()
			center = service_wheel_center
		copy.add_child(crafted)
		crafted.global_transform = global_transform*Transform3D(Basis.IDENTITY,center)
	original.free()
	var bulkhead := BULKHEAD_CRAFT.instantiate() as Node3D
	bulkhead.name = "PrecisionServiceBulkhead"
	bulkhead.position = Vector3(0,6.65,-18.05)
	add_child(bulkhead)

func _install_route_markers() -> void:
	for row in [
		["Entry",Vector3(0,.1,-3.4)],
		["FirstPier",Vector3(-1.15,2.25,-5.58)],
		["LeftPier",Vector3(-4.95,2.25,-8)],
		["ThirdPier",Vector3(-3.5,2.25,-11.6)],
		["VaultDeck",Vector3(-2.3,3.05,-14.65)],
		["VaultApproach",Vector3(-4,3.05,-13.9)],
		["VaultLanding",Vector3(-4,3.05,-16)],
		["ServiceDeck",Vector3(0,5.6,-17.1)],
		["BridgeLanding",Vector3(-1.8,5.65,-16.725)],
		["CampaignExit",Vector3(0,5.6,-18.85)]]:
		var marker := Marker3D.new()
		marker.name = row[0]
		marker.position = row[1]
		add_child(marker)

func _install_lights() -> void:
	for row in [[Vector3(-5.5,6.5,-7),Color(.63,.8,.86),3.0,11.0],
		[Vector3(5.5,6,-12),Color(.95,.79,.58),2.8,10.0],
		[Vector3(0,7.5,-10),Color(.82,.89,.92),3.2,14.0],
		[Vector3(0,7,-17),Color(.82,.89,.92),2.5,6.0]]:
		var light := OmniLight3D.new()
		light.position = row[0]
		light.light_color = row[1]
		light.light_energy = row[2]
		light.omni_range = row[3]
		add_child(light)

func _process(delta: float) -> void:
	visual_time += delta
	if is_instance_valid(presentation): presentation.tick_presentation(visual_time)
	if not _motion_reduced and is_instance_valid(presentation) and presentation._present:
		for rotor in _fan_rotors: rotor.rotation.z = -fposmod(presentation._elapsed*2.4,TAU)

func set_reduced_motion(reduced: bool) -> void:
	_motion_reduced = reduced
	if is_instance_valid(presentation): presentation.set_reduced_motion(reduced)
	if reduced and _valve_tween:
		_valve_tween.kill()
		if is_instance_valid(_valve): _valve.rotation = _closed_valve

func open_campaign_aperture() -> void:
	if is_instance_valid(presentation):presentation.open_campaign_aperture()

func contains_presentation_point(point: Vector3) -> bool:
	return absf(point.x)<9.3 and point.z<=.6 and point.z>=-19.25

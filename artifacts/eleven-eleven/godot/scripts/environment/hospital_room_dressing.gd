extends Node3D

## Original visual skin. No collision, clinical simulation or story progression.
var room: Node3D
var rain: ShaderMaterial
var elapsed := 0.0
var _ivory: StandardMaterial3D
var _graphite: StandardMaterial3D
var _walnut: StandardMaterial3D
var _seam: StandardMaterial3D

func configure(ward: Node3D) -> void:
	room=ward
	_ivory=_material(Color(.67,.71,.68),.63)
	_graphite=_material(Color(.12,.16,.18),.48,.2)
	_walnut=_material(Color(.38,.30,.23),.7)
	_seam=_material(Color(.44,.49,.50),.85)
	var floor_skin:=ShaderMaterial.new()
	floor_skin.shader=preload("res://shaders/ward_floor.gdshader")
	(room.get_node("Floor/FloorMesh") as MeshInstance3D).material_override=floor_skin
	var wall:=_material(Color(.47,.53,.55),.87)
	for mesh: MeshInstance3D in room.find_children("*","MeshInstance3D",true,false):
		if mesh.name in ["NorthWallMesh","WestWallMesh","EastWallMesh","SouthWallBelowWindowMesh","SouthWallAboveWindowMesh"] or str(mesh.name).begins_with("SouthWindowPier"):
			mesh.material_override=wall
	# Cove/baseboard lines read depth without adding obstacles to the route.
	for x in [-3.175,3.175]:
		_box("Baseboard",Vector3(.035,.115,5.65),Vector3(x,.065,0),_graphite)
		_box("Cove",Vector3(.045,.045,5.65),Vector3(x,3.14,0),_ivory)
	for z in [-2.875,2.875]:
		_box("Baseboard",Vector3(6.3,.115,.035),Vector3(0,.065,z),_graphite)
		_box("Cove",Vector3(6.3,.045,.045),Vector3(0,3.14,z),_ivory)
	_box("HeadwallWarmPanel",Vector3(.035,.9,2.15),Vector3(-3.17,.63,-.1),_walnut)
	_box("MedicalServiceRail",Vector3(.07,.24,1.95),Vector3(-3.125,1.36,-.1),_ivory)
	for z in [-.77,-.48,-.18,.18,.52]:
		_box("ServiceSocket",Vector3(.008,.075,.075),Vector3(-3.085,1.36,z),_graphite)
	_box("ReadingLightHousing",Vector3(.09,.05,.52),Vector3(-3.11,1.79,-.12),_ivory)
	for x in [-1.55,0,1.55]:
		_box("CeilingJoint",Vector3(.005,.004,5.6),Vector3(x,3.196,0),_seam)
	for z in [-1.6,0,1.6]:
		_box("CeilingJoint",Vector3(6.2,.004,.005),Vector3(0,3.196,z),_seam)
	_skin_bed()
	_skin_chair()
	_skin_vanity()
	_window()
	var environment: Environment=room.get_node("HospitalWorldEnvironment").environment
	environment.ambient_light_energy=.46
	environment.ambient_light_color=Color(.74,.80,.88)
	(room.get_node("WardInteriorFill") as OmniLight3D).light_energy=.58
	(room.get_node("MirrorVanityLight") as OmniLight3D).light_energy=.58
	# Bound this room's virtual camera to its measured hull. The shared mirror
	# default and other rooms' reflection depths are deliberately independent.
	room.get_node("WardMirrorReflection").reflection_depth=6.8
	var daylight:=room.get_node("WardDaylight") as DirectionalLight3D
	# At35 degrees, the ray reaching the mattress intersects the opaque wall
	# above the2.75m aperture.24 degrees reaches the actual bed through it.
	daylight.rotation_degrees=Vector3(-24,155,0)
	daylight.directional_shadow_max_distance=14.0
	if RenderingServer.get_current_rendering_method()=="forward_plus":
		environment.ssao_enabled=true
		environment.ssao_radius=.28
		environment.ssao_intensity=.8
		environment.ssao_power=1.4

func _skin_bed() -> void:
	var furniture: Node3D = room.get_node("WardFurniture")
	var parts := ["BedDeck","Mattress","MattressPipingNear","MattressPipingFar","BedLeg","LockingCaster","CasterLock","BedEndPanel","EndPanelHandle","LowerSideRail","RailPost","Pillow","PillowSeam","FoldedCover","CoverFold"]
	for node in furniture.get_children():
		if node is MeshInstance3D and node.get_meta("ward_part",str(node.name)) in parts:
			# Keep its mesh/contact bounds and descendant collision bodies intact.
			node.layers=0
	var bed: Node3D=preload("res://assets/props/ward_bed_original_v1.glb").instantiate()
	bed.name="WardBedVisual"
	furniture.add_child(bed)
	var linen:=ShaderMaterial.new();linen.shader=preload("res://shaders/ward_linen.gdshader")
	var meshes: Array[Node]=bed.find_children("*","MeshInstance3D",true,false)
	if bed is MeshInstance3D: meshes.push_front(bed)
	var linen_surfaces:=0
	for mesh: MeshInstance3D in meshes:
		for surface in mesh.mesh.get_surface_count():
			var material: Material=mesh.get_active_material(surface)
			if material and material.resource_name.begins_with("CP37_Ward_Linen"):
				mesh.set_surface_override_material(surface,linen)
				linen_surfaces+=1
	set_meta("linen_surfaces",linen_surfaces)

func _skin_chair() -> void:
	var furniture: Node3D = room.get_node("WardFurniture")
	for node in furniture.get_children():
		if node is MeshInstance3D and str(node.get_meta("ward_part",str(node.name))).begins_with("VisitorChair"):
			node.layers=0
	var chair: Node3D=preload("res://assets/props/ward_visitor_chair_v1.glb").instantiate()
	chair.name="WardVisitorChair"
	# The old seat faces +Z; reuse its location and keep the mirror approach clear.
	chair.position=Vector3(1.78,0,-1.55)
	furniture.add_child(chair)

func _skin_vanity() -> void:
	var station: Node3D=room.get_node("VanityMirrorStation")
	for label in ["CounterMesh","Faucet"]:
		(station.get_node(label) as MeshInstance3D).layers=0
	var vanity: Node3D=preload("res://assets/props/ward_vanity_v1.glb").instantiate()
	vanity.name="WardVanity"
	# Preserve the original .60 x .85 x 1.10 counter collision and mirror area.
	# The new ceramic rim sits at .849m; its back meets the existing east wall.
	vanity.position=Vector3(-.30,0,0)
	vanity.rotation.y=-PI/2.0
	station.add_child(vanity)

func _window() -> void:
	var glass_mesh:=room.get_node("WindowGlassBarrier/WindowGlassBarrierMesh") as MeshInstance3D
	var glass:=_material(Color(.74,.82,.85,.16),.2)
	glass.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	glass_mesh.material_override=glass
	var view:=MeshInstance3D.new()
	view.name="RainWindowView"
	view.mesh=QuadMesh.new();view.mesh.size=Vector2(2.86,1.79)
	view.position=Vector3(0,1.85,-2.925)
	view.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rain=ShaderMaterial.new();rain.shader=preload("res://shaders/ward_rain_window.gdshader")
	view.material_override=rain
	add_child(view)
	for x in [-1.43,0,1.43]:
		_box("WindowMullion",Vector3(.055,1.8,.075),Vector3(x,1.85,-2.815),_ivory)
	for y in [.97,2.73]:
		_box("WindowFrame",Vector3(2.92,.055,.075),Vector3(0,y,-2.815),_ivory)

func _process(delta: float) -> void:
	if not is_instance_valid(room) or not rain: return
	if not room.reduced_motion: elapsed+=delta
	rain.set_shader_parameter("elapsed",elapsed)
	rain.set_shader_parameter("motion",0.0 if room.reduced_motion else 1.0)

func _box(label: String,dimensions: Vector3,point: Vector3,material: Material) -> MeshInstance3D:
	var mesh:=MeshInstance3D.new()
	mesh.name=label;mesh.mesh=BoxMesh.new();mesh.mesh.size=dimensions
	mesh.position=point;mesh.material_override=material
	add_child(mesh)
	return mesh

func _material(color: Color,roughness: float,metallic := 0.0) -> StandardMaterial3D:
	var material:=StandardMaterial3D.new()
	material.albedo_color=color;material.roughness=roughness;material.metallic=metallic
	return material

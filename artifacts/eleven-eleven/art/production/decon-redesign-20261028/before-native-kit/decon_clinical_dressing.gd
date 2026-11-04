extends RefCounted

## Reuses the measured clinical kit; all native solids and interactions remain
## owned by the quarantine wing. Materials and instances are local to this room.
const KIT = preload("res://scripts/environment/specimen_mechanical_dressing.gd")
const FINISH = preload("res://scripts/environment/room_panel_finish.gd")

static func install(room: Node3D) -> void:
	if room.has_node("DeconClinicalDressing"): return
	var root := Node3D.new()
	root.name = "DeconClinicalDressing"
	room.add_child(root)
	var panels: Array[Transform3D] = []
	for side in [-1.0, 1.0]:
		for i in 11:
			for y in [0.12, 3.64]:
				panels.append(Transform3D(Basis(Vector3.UP, -side*PI/2.0).scaled(Vector3(2.86/2.96,1,1)),Vector3(side*11.94,y,-1.46-i*2.9)))
	for label in ["SouthWallWest","SouthWallEast","NorthWallWest","NorthWallEast"]:
		var body: Node3D = room.get_node(label)
		var size: Vector3 = body.get_node("CollisionShape3D").shape.size
		var count := ceili(size.x/3.0)
		var pitch := size.x/float(count)
		for i in count:
			for y in [0.12,3.64]:
				var point := Vector3(body.position.x-size.x/2.0+pitch*(i+.5),y,.03 if label.begins_with("South") else -31.97)
				panels.append(Transform3D(Basis(Vector3.UP,PI if label.begins_with("South") else 0.0).scaled(Vector3((pitch-.04)/2.96,1,1)),point))
	KIT._batch(root,"ClinicalServiceWallBays",KIT._mesh(KIT.PANEL),panels)
	var trays: Array[Transform3D] = []
	for x in [-5.0,5.0]:
		for i in 10: trays.append(Transform3D(Basis.IDENTITY,Vector3(x,6.96,-1.5-i*3.0)))
	KIT._batch(root,"OverheadExtractionTrays",KIT._mesh(KIT.TRAY),trays)
	var caps: Array[Transform3D] = []
	var cap: Mesh = KIT._mesh(KIT.CAP)
	for x in [-6.5,6.5]:
		for z in [-11.0,-16.0,-21.0]:
			caps.append(_fit(cap,Vector3(x,.16,z),Vector3(3.04,.32,3.04)))
			caps.append(_fit(cap,Vector3(x,2.64,z),Vector3(3.04,.32,3.04)))
	KIT._batch(root,"TwelveQuarantinePressureSeals",cap,caps)
	var trim: Mesh = KIT._mesh(KIT.TRIM)
	var beams: Array[Transform3D] = []
	# The existing opaque guard collider stays intact; only its visual slab is
	# replaced by a fabricated open rail, with supports at measured intervals.
	for label in ["CatwalkRailNorth","CatwalkRailSouth"]:
		var rail: Node3D = room.get_node(label)
		var size: Vector3 = rail.get_node("CollisionShape3D").shape.size
		for child in rail.get_children():
			if child is MeshInstance3D: child.hide()
		for y in [3.28,3.72,4.16]: beams.append(_fit(trim,Vector3(rail.position.x,y,rail.position.z),Vector3(size.x,.065,.09)))
		var count := ceili(size.x/1.5)
		for i in count+1:
			beams.append(_fit(trim,Vector3(rail.position.x-size.x/2.0+size.x*i/count,3.72,rail.position.z),Vector3(.075,.92,.09)))
	for x in [-8.5,8.5]:
		beams.append(_fit(trim,Vector3(x,1.48,-16),Vector3(.18,2.96,.28)))
	KIT._batch(root,"FabricatedObservationBridge",trim,beams)
	for pod in room.find_children("QuarantinePod_*","StaticBody3D",false,false):
		for child in pod.get_children():
			if child is MeshInstance3D and child.name in ["PodCap","PodBase"]: child.hide()
	for label in ["Ceiling","WestWall","EastWall","SouthWallWest","SouthWallEast","SouthLintel","NorthWallWest","NorthWallEast","NorthLintel"]:
		for child in room.get_node(label).get_children():
			if child is MeshInstance3D: child.material_override=KIT._finish(Color(.50,.56,.60),.08,.65)
	for child in room.get_node("Floor").get_children():
		if child is MeshInstance3D: child.material_override=FINISH.material(Color(.50,.57,.61),Vector2(3,3),.12,.58)
	# Restrict bounced fixture light to environment geometry, protecting Echo.
	FINISH.environment_fill(room,"ClinicalCeilingBounce",Vector3(0,5.2,-13),Color(.77,.85,.94),1.2,19.0)
	FINISH.environment_fill(room,"ClinicalExitBounce",Vector3(0,3,-26),Color(.58,.78,.84),.75,11.0)

static func _fit(mesh: Mesh, center: Vector3, size: Vector3) -> Transform3D:
	var box := mesh.get_aabb()
	var scale := size/box.size
	var basis := Basis.from_scale(scale)
	return Transform3D(basis,center-basis*box.get_center())

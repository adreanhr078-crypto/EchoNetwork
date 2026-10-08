extends RefCounted

## Authored telemetry: no fabricated live camera feed or full-screen neon slab.
static func material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.015,0.031,0.045)
	return mat

static func populate(parent: Node3D, center: Vector3, width: float, height: float, title: String) -> Node3D:
	var panel := Node3D.new()
	panel.name = "Telemetry"
	panel.position = center
	parent.add_child(panel)
	var heading := Label3D.new()
	heading.name="Heading"
	heading.text = title
	heading.font_size = 48
	heading.pixel_size = height / 220.0
	heading.position.y = height * 0.3
	heading.modulate = Color(0.78,0.87,0.9)
	heading.outline_size = 0
	heading.no_depth_test = false
	panel.add_child(heading)
	for row in range(3):
		var label := Label3D.new()
		label.name="Readout%d" % row
		label.text = ["EX-011  /  SIGNAL LOST", "ACCESS  /  LOCKED", "SECTOR 11  /  LOCAL RECORD"][row]
		label.font_size = 32
		label.pixel_size = height / 220.0
		label.position = Vector3(-width*0.18,height*(0.08-row*0.19),0)
		label.modulate = Color(0.48,0.67,0.74)
		label.outline_size = 0
		panel.add_child(label)
		var marker := MeshInstance3D.new()
		marker.name="Status%d" % row
		var mesh := BoxMesh.new()
		mesh.size = Vector3(width*0.045,height*0.065,0.005)
		marker.mesh = mesh
		marker.position = Vector3(width*0.34,height*(0.08-row*0.19),0)
		var ink := StandardMaterial3D.new()
		ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ink.albedo_color = Color(0.68,0.2,0.19) if row == 1 else Color(0.24,0.55,0.63)
		marker.material_override = ink
		panel.add_child(marker)
	return panel

static func update(panel:Node3D, language:String, inspected:bool, unlocked:bool) -> void:
	var ar:=language=="ar"
	panel.get_node("Heading").text="المراقبة / السجل المحلي" if ar else "SURVEILLANCE / LOCAL TELEMETRY"
	panel.get_node("Readout0").text=("EX-011 / تم الفحص" if inspected else "EX-011 / لم يتم الفحص") if ar else ("EX-011 / INSPECTED" if inspected else "EX-011 / NOT INSPECTED")
	panel.get_node("Readout1").text=("الوصول / مفتوح" if unlocked else "الوصول / مقفل") if ar else ("ACCESS / UNLOCKED" if unlocked else "ACCESS / LOCKED")
	panel.get_node("Readout2").text="القطاع 11 / السجل المحلي" if ar else "SECTOR 11 / LOCAL RECORD"
	panel.get_node("Status1").material_override.albedo_color=Color(0.24,0.55,0.46) if unlocked else Color(0.68,0.2,0.19)

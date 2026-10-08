extends RefCounted

## Continuous capsule support matching the displayed stair/walkway.
static func add_ramp(parent: Node3D, label: String, start: Vector3, finish: Vector3, width: float, material: Material = null) -> StaticBody3D:
	var axis := (finish - start).normalized()
	var side := Vector3.UP.cross(axis).normalized()
	var normal := axis.cross(side).normalized()
	var body := StaticBody3D.new()
	body.name = label
	body.transform = Transform3D(Basis(side, normal, axis), (start + finish) * 0.5 - normal * 0.1)
	var col := CollisionShape3D.new()
	col.shape = BoxShape3D.new()
	col.shape.size = Vector3(width, 0.2, start.distance_to(finish))
	body.add_child(col)
	if material:
		var mesh := MeshInstance3D.new()
		mesh.mesh = BoxMesh.new()
		mesh.mesh.size = col.shape.size
		mesh.material_override = material
		body.add_child(mesh)
	parent.add_child(body)
	return body

static func add_guardrails(ramp:StaticBody3D, width:float, entry_gap:float=1.5, exit_gap:float=1.5) -> void:
	var shape:=ramp.get_child(0).shape as BoxShape3D
	var span:float=shape.size.z-entry_gap-exit_gap
	if span<=0: return
	var center:float=(entry_gap-exit_gap)*0.5
	var steel:=StandardMaterial3D.new()
	steel.albedo_color=Color(0.29,0.34,0.37)
	steel.metallic=0.65
	steel.roughness=0.5
	for side in [-1.0,1.0]:
		var fence:=StaticBody3D.new()
		fence.name="ServiceGuardrail"
		fence.position=Vector3(side*(width*0.5-0.06),0.62,center)
		var collider:=CollisionShape3D.new()
		collider.shape=BoxShape3D.new()
		collider.shape.size=Vector3(0.08,1.02,span)
		fence.add_child(collider)
		ramp.add_child(fence)
		for height in [-0.25,0.5]:
			var rail:=MeshInstance3D.new()
			rail.mesh=BoxMesh.new()
			rail.mesh.size=Vector3(0.065,0.05,span)
			rail.position.y=height
			rail.material_override=steel
			fence.add_child(rail)
		var bays:int=maxi(1,int(ceil(span/2.0)))
		for i in bays+1:
			var post:=MeshInstance3D.new()
			post.mesh=BoxMesh.new()
			post.mesh.size=Vector3(0.05,1.0,0.05)
			post.position.z=-span*0.5+span*float(i)/bays
			post.material_override=steel
			fence.add_child(post)

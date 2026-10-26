extends RefCounted

## Static measured cladding only. The native room retains every solid,portal,
## interaction,clock and story owner. Shared mesh/PBR maps and four batches
## avoid storing120 copies of the source tile's vertex buffers.
const TILE=preload("res://assets/environments/lab_clinical_cp45/clinical_wall_p2_4k.glb")
const FRAME=preload("res://assets/environments/lab_clinical_cp45/clinical_service_frame_clean.glb")

static func build(owner:Node3D)->Node3D:
	var root:=Node3D.new()
	var prototype:Node3D=TILE.instantiate()
	var source_mesh:MeshInstance3D=prototype.find_children("*","MeshInstance3D",true,false)[0]
	var mesh:Mesh=source_mesh.mesh
	assert(mesh.get_surface_count()==1)
	assert(mesh.get_aabb().size.is_equal_approx(Vector3(3,3,.2)))
	var source:StandardMaterial3D=mesh.surface_get_material(0) as StandardMaterial3D
	var finish:ShaderMaterial=owner.call("_architectural_finish",source)
	finish.set_shader_parameter("minimum_roughness",.45)
	finish.set_shader_parameter("cladding_tone_enabled",true)
	var room:Node3D=owner.get("laboratory")
	finish.set_shader_parameter("cladding_base_y",room.global_position.y)
	var groups:Dictionary={"West":[],"East":[],"North":[],"South":[]}
	for side in [-1.0,1.0]:
		var label:="West" if side<0 else "East"
		var yaw:=PI*.5 if side<0 else -PI*.5
		for i in 13:
			for y in [0.0,3.0,6.0]:groups[label].append(_placement(Vector3(side*16.08,y,-2.0-3.0*i),yaw,3.0))
		for x in [7.55,10.8,14.05]:
			for y in [0.0,3.0,6.0]:groups.North.append(_placement(Vector3(side*x,y,-40.08),0.0,3.15))
		for x in [3.09,6.69,10.29,13.89]:
			for y in [0.0,3.0,6.0]:groups.South.append(_placement(Vector3(side*x,y,.08),PI,3.54))
	for label in groups:
		var batch:=MultiMesh.new()
		batch.transform_format=MultiMesh.TRANSFORM_3D
		batch.mesh=mesh
		batch.instance_count=groups[label].size()
		var bounds:=AABB()
		for index in batch.instance_count:
			var transform:Transform3D=groups[label][index]
			batch.set_instance_transform(index,transform)
			var current:AABB=transform*mesh.get_aabb()
			bounds=current if index==0 else bounds.merge(current)
		batch.custom_aabb=bounds
		var draw:=MultiMeshInstance3D.new()
		draw.name="Clinical"+label+"Cladding"
		draw.multimesh=batch;draw.material_override=finish
		root.add_child(draw)
	prototype.free()
	var frame:Node3D=FRAME.instantiate()
	frame.name="MeasuredServiceFrameAndGallery"
	root.add_child(frame)
	return root

static func _placement(point:Vector3,yaw:float,width:float)->Transform3D:
	var scale:=Basis(Vector3(width/3.0,0,0),Vector3(0,1,0),Vector3(0,0,1))
	return Transform3D(Basis(Vector3.UP,yaw)*scale,point)

extends SceneTree

## Isolated source-preserving rig and pose review. The connected campaign
## cannot load this candidate until its visual/skin inspection is accepted.
const Pose=preload("res://scripts/cinematics/kinja_trauma_pose.gd")
var stage: Node3D
var rig: Skeleton3D
var motion: Node3D
var camera: Camera3D
var folder: String
var body: MeshInstance3D
var rest_vertices:=PackedVector3Array()

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	root.size=Vector2i(960,720)
	root.content_scale_size=root.size
	folder=ProjectSettings.globalize_path("res://../audits/evidence/room-color-cinematics-20261007/kinja-rig-v1/")
	var document:=GLTFDocument.new()
	var state:=GLTFState.new()
	assert(document.append_from_file(folder+"kinja-rig-candidate.glb",state)==OK)
	var model:=document.generate_scene(state)
	stage=Node3D.new()
	root.add_child(stage)
	stage.add_child(model)
	model.scale=Vector3.ONE*1.8
	model.position.y=0.9
	model.rotation.y=-PI/2
	rig=model.find_child("Skeleton3D",true,false) as Skeleton3D
	assert(rig and rig.get_bone_count()==33,"Actual generated skeleton must be present")
	body=_body(model)
	assert(body and body.skin)
	rest_vertices=_skin_vertices()
	var source_vertices: PackedVector3Array=body.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var rest_error:=_max_delta(rest_vertices,source_vertices)
	print("KINJA native rest skin error_m=",rest_error)
	# Four uint16 normalized export weights sum within 3/65535; the observed
	# rest error is 22.5 micrometres on this 1 m source. Keep a 50 micrometre
	# import threshold, not a bone-only pass that overlooks exploding sleeves.
	assert(rest_error<0.00005,"Actual imported inverse binds must preserve source rest mesh within 0.05 mm")
	motion=Pose.new()
	stage.add_child(motion)
	assert(motion.setup(rig))
	motion.set_process(false)
	_build_review_lighting()
	camera=Camera3D.new()
	stage.add_child(camera)
	camera.position=Vector3(2.45,1.36,4.0)
	camera.look_at(Vector3(0,1.0,0))
	camera.fov=32
	camera.make_current()
	for i in 6: await process_frame
	var feet:=_feet()
	await _capture("native-01-rest-three-quarter")
	motion.set_contact_count(1)
	motion._impact_age=0.16
	motion._apply_pose()
	for i in 3: await process_frame
	assert(_head_delta()>0.01,"A real head pose must change through Skeleton3D")
	var flinch_delta:=_max_delta(_skin_vertices(),rest_vertices)
	print("KINJA contact skin max_delta_m=",flinch_delta)
	assert(flinch_delta<0.16,"Bounded acting cannot stretch the skin beyond measured source scale")
	_assert_feet(feet)
	await _capture("native-02-contact-flinch")
	motion.set_contact_count(3)
	motion._impact_age=1.0
	motion._apply_pose()
	for i in 3: await process_frame
	_assert_feet(feet)
	await _capture("native-03-three-contact-settled")
	motion.begin_collar()
	for i in 3: await process_frame
	_assert_feet(feet)
	var collar_delta:=_max_delta(_skin_vertices(),rest_vertices)
	print("KINJA collar skin max_delta_m=",collar_delta)
	assert(collar_delta<0.16,"Collar pose cannot stretch the skin beyond measured source scale")
	await _capture("native-04-collar-three-quarter")
	camera.position=Vector3(0,1.4,4.8)
	camera.look_at(Vector3(0,1.0,0))
	await _capture("native-05-collar-front")
	camera.position=Vector3(4.8,1.4,0)
	camera.look_at(Vector3(0,1.0,0))
	await _capture("native-06-collar-side")
	motion.reduced_motion=true
	motion._process(0.2)
	var pose:=_pose_snapshot()
	var phase: float=motion._phase
	motion._process(3.0)
	assert(phase==motion._phase and pose==_pose_snapshot(),"Reduced motion must hold exact detailed character pose")
	_assert_feet(feet)
	var report:={"status":"NATIVE_SKELETAL_STAGING_PASS_VISUAL_REVIEW_REQUIRED","bones":rig.get_bone_count(),"actual_skeleton":true,"native_rest_skin_error_m":rest_error,"contact_max_skin_delta_m":flinch_delta,"collar_max_skin_delta_m":collar_delta,"feet_rest_unchanged":true,"reduced_motion_pose_freezes":true,"candidate_only":true,"campaign_integrated":false,"source_replaced":false,"limitation":"No paired Echo collar reach or facial blendshape acting; coat and arm skin must be inspected in actual saved frames."}
	var file:=FileAccess.open(folder+"native-acting-review.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	stage.queue_free()
	for i in 6: await process_frame
	print("PASS isolated Kinja: actual 33-bone skin, bounded contact and collar poses, fixed feet and exact reduced-motion pose freeze")
	print("UNVERIFIED paired Echo grip, facial acting and final scene acceptance")
	quit(0)

func _feet() -> Array[Transform3D]:
	return [rig.get_bone_global_pose(rig.find_bone("LeftFoot")),rig.get_bone_global_pose(rig.find_bone("RightFoot"))]

func _assert_feet(expected: Array[Transform3D]) -> void:
	var actual:=_feet()
	for i in 2: assert(actual[i].is_equal_approx(expected[i]),"Kinja feet cannot slide during upper-body acting")

func _head_delta() -> float:
	var index:=rig.find_bone("Head")
	return rig.get_bone_global_pose(index).origin.distance_to(rig.get_bone_global_rest(index).origin)

func _pose_snapshot() -> Array[Transform3D]:
	var poses: Array[Transform3D]=[]
	for i in rig.get_bone_count(): poses.append(rig.get_bone_global_pose(i))
	return poses

func _body(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D: return node
	for child in node.get_children():
		var found:=_body(child)
		if found: return found
	return null

func _skin_vertices() -> PackedVector3Array:
	var arrays:=body.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array=arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
	var transforms: Array[Transform3D]=[]
	for binding in body.skin.get_bind_count():
		var name:=body.skin.get_bind_name(binding)
		var index:=rig.find_bone(name) if name!="" else body.skin.get_bind_bone(binding)
		assert(index>=0)
		transforms.append(rig.get_bone_global_pose(index)*body.skin.get_bind_pose(binding))
	var result:=PackedVector3Array()
	var stride: int=bones.size()/vertices.size()
	for vertex in vertices.size():
		var point:=Vector3.ZERO
		for binding in stride:
			var at: int=vertex*stride+binding
			if weights[at]>0: point+=(transforms[bones[at]]*vertices[vertex])*weights[at]
		result.append(point)
	return result

func _max_delta(a: PackedVector3Array,b: PackedVector3Array) -> float:
	var result:=0.0
	assert(a.size()==b.size())
	for index in a.size(): result=maxf(result,a[index].distance_to(b[index]))
	return result

func _capture(label: String) -> void:
	if DisplayServer.get_name()=="headless": return
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder+label+".png")

func _build_review_lighting() -> void:
	var world:=WorldEnvironment.new()
	var environment:=Environment.new()
	environment.background_mode=Environment.BG_COLOR
	environment.background_color=Color(0.025,0.040,0.062)
	environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color=Color(0.65,0.74,0.89)
	environment.ambient_light_energy=0.55
	environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	world.environment=environment
	stage.add_child(world)
	for data in [[Vector3(2.4,3.8,3.0),Color(0.8,0.88,1.0),1.6],[Vector3(-2.0,2.7,-1.4),Color(0.28,0.65,0.77),1.2]]:
		var light:=OmniLight3D.new()
		light.position=data[0]
		light.light_color=data[1]
		light.light_energy=data[2]
		light.omni_range=7
		stage.add_child(light)
	var floor:=MeshInstance3D.new()
	var mesh:=PlaneMesh.new()
	mesh.size=Vector2(10,10)
	floor.mesh=mesh
	var material:=StandardMaterial3D.new()
	material.albedo_color=Color(0.15,0.20,0.27)
	material.roughness=0.76
	floor.material_override=material
	stage.add_child(floor)

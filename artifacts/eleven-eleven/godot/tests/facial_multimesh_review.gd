extends SceneTree

const Facial = preload("res://scripts/player/echo_facial_controller.gd")

func _initialize() -> void: _run.call_deferred()

func expression_mesh(label: String, shapes: Array[String]) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	var mesh := ArrayMesh.new()
	mesh.blend_shape_mode = Mesh.BLEND_SHAPE_MODE_RELATIVE
	for shape in shapes: mesh.add_blend_shape(shape)
	var base := []
	base.resize(Mesh.ARRAY_MAX)
	base[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO, Vector3.RIGHT, Vector3.UP])
	base[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.FORWARD, Vector3.FORWARD, Vector3.FORWARD])
	var morphs: Array[Array] = []
	for _shape in shapes:
		var morph := []
		morph.resize(Mesh.ARRAY_MAX)
		morph[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(0,0.01,0), Vector3(0,0.02,0), Vector3(0,0.03,0)])
		morph[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.ZERO, Vector3.ZERO, Vector3.ZERO])
		morphs.append(morph)
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, base, morphs)
	node.mesh = mesh
	return node

func _run() -> void:
	var avatar := Node3D.new()
	var body := expression_mesh("AuthoredBody", ["Mouth_Grimace", "Brow_Frown"])
	var lids := expression_mesh("SeparateHeadSkinnedLids", ["Blink_L", "Blink_R"])
	avatar.add_child(body)
	avatar.add_child(lids)
	var face := Facial.new()
	face.mesh_instance = body # Mirrors the existing legacy caller contract.
	avatar.add_child(face)
	root.add_child(avatar)
	face.set_process(false)
	face.blink_weight = 0.8
	face.current_grimace = 0.4
	face._apply_eyelids()
	face._set_shape("Mouth_Grimace", 0.4)
	var passed := face.expression_meshes.size() == 2 and is_equal_approx(lids.get_blend_shape_value(0), 0.8) and is_equal_approx(lids.get_blend_shape_value(1), 0.8) and is_equal_approx(body.get_blend_shape_value(0), 0.4)
	face._set_shape("Blink_L", INF)
	passed = passed and lids.get_blend_shape_value(0) == 0.0
	var explicit_face := Facial.new()
	explicit_face.mesh_instance_path = NodePath("../AuthoredBody")
	avatar.add_child(explicit_face)
	explicit_face.set_process(false)
	passed = passed and explicit_face.expression_meshes.size() == 1
	avatar.queue_free()
	await process_frame
	await process_frame
	print("PASS" if passed else "FAIL", " actual separate morph meshes: assigned primary body, independent lids, malformed weight and explicit-path scope")
	quit(0 if passed else 2)

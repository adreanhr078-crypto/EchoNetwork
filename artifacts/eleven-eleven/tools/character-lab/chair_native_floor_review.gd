extends SceneTree
## Compare the native floor with an isolated chair-entry fixture.

const LAB_PATH := "res://scripts/environment/dr_kinja_lab_room.gd"
const LAB := preload(LAB_PATH)
const ARCHITECTURE := "res://scripts/environment/clinical_lab_architecture.gd"
const CHAIR := "res://assets/environments/lab_clinical_cp45/neural_chair_tripo_20k.glb"

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var room := LAB.new()
	root.add_child(room)
	await physics_frame
	await physics_frame
	var chair := room.find_child("NeuralChairTripo", true, false) as Node3D
	var table := room.get_node_or_null("NeuralRigTable") as StaticBody3D
	var mesh := table.find_child("*", false, false) if table else null
	var table_mesh := mesh as MeshInstance3D
	if not chair or not table_mesh or table_mesh.visible:
		push_error("Expected the rendered chair and hidden original table mesh")
		quit(1)
		return
	var clear_table := OS.get_cmdline_user_args().has("--chair-entry-clearance")
	if clear_table:
		var table_shapes := table.find_children("*", "CollisionShape3D", false, false)
		if table_shapes.size() != 1:
			push_error("Expected one hidden table collision shape")
			quit(1)
			return
		table_shapes[0].set_deferred("disabled", true)
		await physics_frame
		await physics_frame

	var samples: Array[Dictionary] = []
	for z_offset in [0.0, 0.4, 0.55, 0.8]:
		for x in [-0.82, -0.72, -0.68, -0.55, 0.55, 0.68, 0.72, 0.82]:
			var from := chair.global_position + Vector3(x, 2.0, z_offset)
			var query := PhysicsRayQueryParameters3D.create(from, from - Vector3.UP * 3.0)
			var hit := room.get_world_3d().direct_space_state.intersect_ray(query)
			if hit.is_empty():
				push_error("Expected solid footing below " + str(from))
				quit(1)
				return
			var collider := hit.collider as StaticBody3D
			var height: float = hit.position.y - chair.global_position.y
			samples.append({"x_m": x, "front_offset_m": z_offset, "height_above_dais_m": height, "solid": String(collider.name)})
			var hits_table := not clear_table and absf(x) < 0.7
			var expected := "NeuralRigTable" if hits_table else "SurgicalDaisPlatform"
			var expected_height := 0.5 if hits_table else 0.0
			if collider.name != expected or absf(height - expected_height) > 0.002:
				push_error("Unexpected footing " + str(samples[-1]))
				quit(1)
				return

	var output := FileAccess.open(OS.get_environment("ECHO_NATIVE_ENTRY_OUT"), FileAccess.WRITE)
	if not output:
		quit(1)
		return
	var hashes := {}
	for path in [LAB_PATH, ARCHITECTURE, CHAIR]:
		hashes[path.trim_prefix("res://")] = FileAccess.get_sha256(path)
	var status := "PASS_CHAIR_ENTRY_FLOOR_FIXTURE" if clear_table else "PASS_RETAINED_TABLE_COLLISION_BOUNDARY"
	output.store_string(JSON.stringify({
		"status": status,
		"scope": "32 native floor rays; full-body clearance and stand-to-seat motion are open.",
		"chair_origin": [chair.global_position.x, chair.global_position.y, chair.global_position.z],
		"legacy_table_mesh_hidden": true,
		"legacy_table_collision_disabled_in_fixture": clear_table,
		"contacts": samples,
		"sources": hashes
	}, "\t") + "\n")
	output.close()
	print(status, " native rays=", samples.size())
	room.queue_free()
	await process_frame
	quit()

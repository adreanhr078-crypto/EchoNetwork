extends SceneTree

const OUTPUT := "res://../audits/evidence/hospital-bedside-foundation-20261002/"
var patient
var camera: Camera3D

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	var ward := load("res://scenes/environment/hospital_bedside_foundation.tscn").instantiate() as Node3D
	root.add_child(ward)
	var ink_owner := Node3D.new()
	ink_owner.set_script(load("res://scripts/player/echo_skin_identifier.gd"))
	var avatar := load("res://assets/characters/echo_opening_uniform_v13.glb").instantiate() as Node3D
	avatar.scale = Vector3.ONE * 1.81
	ink_owner.add_child(avatar)
	ward.add_child(ink_owner)
	patient = Node3D.new()
	patient.set_script(load("res://scripts/environment/hospital_patient_recovery.gd"))
	ward.add_child(patient)
	for frame in range(4): await process_frame
	assert(patient.bind_existing_actor(avatar, ward))
	assert(not patient.begin_recovery({}))
	assert(not patient.begin_recovery({"pact_confirmed": true, "revenge_completed": true, "wish_confirmed": true, "transfer_completed": false, "stage": "hospital_bedside"}))
	assert(not patient.request_action("wake"))
	var original := avatar.transform
	assert(patient.begin_recovery({"pact_confirmed": true, "revenge_completed": true, "wish_confirmed": true, "transfer_completed": true, "stage": "hospital_bedside"}))
	assert(not patient.request_action("stand"))
	assert(not patient.request_action("inspect_mark"))
	assert(not patient.begin_recovery({}))
	print("POSE_HEAD ", patient.skeleton.get_bone_global_pose(16), " REST ", patient.skeleton.get_bone_global_rest(16), " FOOT ",patient.skeleton.get_bone_global_pose(3))
	var points: PackedVector3Array = patient.skin_points()
	var mattress_penetration := 0.0
	var head_gap := INF
	var foot_gap := INF
	for point in points:
		if absf(point.x) < 1.06 and absf(point.z) < 0.48: mattress_penetration = maxf(mattress_penetration, 0.70 - point.y)
		if point.x > -0.99 and point.x < -0.55 and absf(point.z) < 0.34: head_gap = minf(head_gap, point.y - 0.80)
		if point.x > 0.65 and absf(point.z) < 0.42: foot_gap = minf(foot_gap, point.y - 0.79)
	var folder := ProjectSettings.globalize_path(OUTPUT)
	DirAccess.make_dir_recursive_absolute(folder)
	var report := {"status": "PARTIAL", "source_keys_changed": false, "mesh_rest_changed": false, "native_player_replaced": false, "entry_guards": "explicit pact/revenge/wish/transfer + hospital stage", "head_pillow_envelope_gap_m": head_gap, "foot_cover_gap_m": foot_gap, "mattress_penetration_m": mattress_penetration, "captures": [], "acting_acceptance": "UNVERIFIED: isolated authored pose review; no Japanese performance, hand fingers or genuine eye closure"}
	var capture := "--capture" in OS.get_cmdline_user_args()
	if capture:
		assert(DisplayServer.get_name() != "headless")
		root.size = Vector2i(1280, 720)
		camera = Camera3D.new()
		ward.add_child(camera)
		camera.current = true
		camera.fov = 43
		await _capture("reclined-three-quarter", Vector3(1.7, 2.1, 2.5), Vector3(-0.10, 0.90, 0), report)
		await _capture("reclined-side-contact", Vector3(0.0, 1.1, 3.2), Vector3(0, 0.85, 0), report)
	assert(patient.request_action("wake"))
	assert(not patient.request_action("wake"))
	assert(patient.request_action("sit"))
	assert(not patient.request_action("stand"))
	if capture: await _capture("seated-body-review", Vector3(2.0, 1.8, 2.1), Vector3(0.0, 1.1, 0), report)
	assert(patient.request_action("inspect_mark"))
	assert(patient.request_action("stand"))
	assert(patient.stage == patient.Stage.CONTROL)
	if capture: await _capture("bedside-control-anchor", Vector3(2.8, 2.1, 3.0), Vector3(-0.1, 0.9, 0.7), report)
	patient.restore_scope()
	assert(avatar.transform.is_equal_approx(original))
	assert(patient.stage == patient.Stage.WAITING)
	var file := FileAccess.open(folder + "verification.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("PASS isolated bedside intentional stage guards/restore; CONTACT REVIEW ", JSON.stringify(report))
	ward.queue_free()
	await process_frame
	quit(0)

func _capture(label: String, from: Vector3, target: Vector3, report: Dictionary) -> void:
	camera.position = from
	camera.look_at(target)
	for frame in range(5): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUTPUT) + label + ".png")
	report.captures.append(label)

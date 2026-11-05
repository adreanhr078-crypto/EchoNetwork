extends SceneTree
## Isolated replay. --native-lab adds the real laboratory as a review stage.

const LAB_PATH := "res://scripts/environment/dr_kinja_lab_room.gd"
const LAB_ARCHITECTURE := "res://scripts/environment/clinical_lab_architecture.gd"

func _initialize() -> void:
	_run.call_deferred()

func fail(message: String) -> void:
	push_error(message)
	quit(1)

func import_gltf(path: String) -> Node3D:
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	if document.append_from_file(path, state) != OK:
		return null
	return document.generate_scene(state, 30, false, false) as Node3D

func find_skin(scene: Node3D) -> MeshInstance3D:
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		if node.skin:
			return node
	return null

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var sequence_dir := ""
	for arg in args:
		if arg.begins_with("--sequence-dir="):
			sequence_dir = arg.trim_prefix("--sequence-dir=")
			args.erase(arg)
			break
	var lab_index := args.find("--native-lab")
	var native_lab := lab_index != -1
	if native_lab:
		args.remove_at(lab_index)
		if args.size() != 7 or not ResourceLoader.exists(LAB_PATH):
			fail("Native lab review requires the active Godot project and the exact cuff inputs")
			return
	if not sequence_dir.is_empty() and (not native_lab or DisplayServer.get_name() == "headless"):
		fail("Sequence capture requires a rendered native lab review")
		return
	if args.size() < 5 or args.size() > 7:
		fail("Expected actor, evidence, source School, chair and output, with optional frames folder or cuff GLB and evidence")
		return
	var record = JSON.parse_string(FileAccess.get_file_as_string(args[1]))
	var actor := import_gltf(args[0])
	if not actor or not record is Dictionary:
		fail("Missing candidate or Blender evidence")
		return
	root.add_child(actor)
	var skeleton := actor.find_child("Skeleton3D", true, false) as Skeleton3D
	var player := actor.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if not skeleton or skeleton.get_bone_count() != 65 or not player:
		fail("Expected the qualified 65-joint rig and AnimationPlayer")
		return
	var clips := player.get_animation_list()
	if clips.size() != 1 or record.frames.size() != 61:
		fail("Unexpected clip or native clock")
		return
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	player.play(clips[0], 0.0)
	player.pause()
	var max_error := 0.0
	var sample_count := 0
	for sample in record.frames:
		player.seek(float(sample.frame) / 30, true)
		player.advance(0.0)
		skeleton.force_update_all_bone_transforms()
		for joint in sample.joints:
			var index := skeleton.find_bone("mixamorig_" + joint)
			if index < 0:
				fail("Missing measured joint " + joint)
				return
			var raw: Array = sample.joints[joint]
			var expected := Vector3(raw[0], raw[2], -raw[1])
			var actual := skeleton.to_global(skeleton.get_bone_global_pose(index).origin)
			max_error = maxf(max_error, actual.distance_to(expected))
			sample_count += 1
	if max_error > .001 or absf(player.current_animation_length - 2.0) > .0001:
		fail("Native round trip differs from Blender: " + str(max_error))
		return
	var cuff_player: AnimationPlayer
	var cuffs: Node3D
	var cuff_evidence := {}
	if args.size() == 7:
		var cuff_record = JSON.parse_string(FileAccess.get_file_as_string(args[6]))
		cuffs = import_gltf(args[5])
		if not cuffs or not cuff_record is Dictionary or cuff_record.status != "PASS_BLENDER_CUFF_CONTACT" or cuff_record.cuff_glb_sha256 != FileAccess.get_sha256(args[5]):
			fail("Missing qualified cuff asset and matching Blender record")
			return
		root.add_child(cuffs)
		cuff_player = cuffs.find_child("AnimationPlayer", true, false) as AnimationPlayer
		var cuff_nodes := [cuffs.find_child("LeftCuff", true, false) as Node3D, cuffs.find_child("RightCuff", true, false) as Node3D]
		if not cuff_player or not cuff_nodes[0] or not cuff_nodes[1] or cuff_player.get_animation_list().size() != 1 or cuff_record.frames.size() != 61:
			fail("Missing cuff nodes or exact clip")
			return
		cuff_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		cuff_player.play(cuff_player.get_animation_list()[0], 0.0)
		cuff_player.pause()
		var tip_error := 0.0
		for frame in cuff_record.frames:
			cuff_player.seek(float(frame.frame) / 30, true)
			cuff_player.advance(0)
			for index in range(2):
				var node := cuff_nodes[index] as Node3D
				var expected = frame[String(node.name)].latch_tip
				var local_tip: Array = cuff_record.local_latch_tips[String(node.name)]
				var actual := node.to_global(Vector3(local_tip[0], local_tip[2], -local_tip[1]))
				tip_error = maxf(tip_error, actual.distance_to(Vector3(expected[0], expected[2], -expected[1])))
		if tip_error > .001 or absf(cuff_player.current_animation_length - 2) > .0001:
			fail("Native cuff animation differs from Blender: " + str(tip_error))
			return
		cuff_evidence = {"status": "PASS_NATIVE_CUFF_REPLAY", "latch_tip_samples": 122,
			"max_tip_error_m": tip_error, "asset_sha256": FileAccess.get_sha256(args[5]),
			"reference_sha256": FileAccess.get_sha256(args[6])}
	var lab: Node3D
	var anchor := Vector3.ZERO
	if native_lab:
		lab = load(LAB_PATH).new()
		lab.audio_muted = true
		lab.reduced_motion = true
		AudioServer.set_bus_mute(0, true)
		root.add_child(lab)
		var mounted_chair := lab.find_child("NeuralChairTripo", true, false) as Node3D
		if not mounted_chair or not is_equal_approx(mounted_chair.rotation.y, -PI / 2) or not mounted_chair.scale.is_equal_approx(Vector3.ONE * float(record.chair_scale)):
			fail("Native chair transform differs from the authored seating reference")
			return
		if FileAccess.get_sha256(mounted_chair.scene_file_path) != FileAccess.get_sha256(args[3]):
			fail("Native chair geometry differs from the authored seating reference")
			return
		anchor = mounted_chair.global_position
		actor.global_position = anchor
		cuffs.global_position = anchor
		for sample in [0, 30, 60]:
			player.seek(float(sample) / 30, true)
			player.advance(0.0)
			skeleton.force_update_all_bone_transforms()
			var hips: Array = record.frames[sample].joints.Hips
			var expected := anchor + Vector3(hips[0], hips[2], -hips[1])
			var actual := skeleton.to_global(skeleton.get_bone_global_pose(skeleton.find_bone("mixamorig_Hips")).origin)
			if actual.distance_to(expected) > .001:
				fail("Lab placement changed the authored seat alignment")
				return
	var captured := PackedStringArray()
	if DisplayServer.get_name() != "headless":
		var material_source := import_gltf(args[2])
		var chair := import_gltf(args[3]) if not native_lab else null
		var mesh := find_skin(actor)
		var source_mesh := find_skin(material_source) if material_source else null
		if (not native_lab and not chair) or not mesh or not source_mesh or mesh.mesh.get_surface_count() != source_mesh.mesh.get_surface_count():
			fail("Exact source material or chair unavailable")
			return
		for surface in mesh.mesh.get_surface_count():
			mesh.set_surface_override_material(surface, source_mesh.mesh.surface_get_material(surface))
		material_source.free()
		if chair:
			root.add_child(chair)
			chair.rotation.y = -PI / 2
			chair.scale = Vector3.ONE * float(record.chair_scale)
		var environment := WorldEnvironment.new()
		environment.environment = Environment.new()
		environment.environment.background_mode = Environment.BG_COLOR
		environment.environment.background_color = Color("121522")
		environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		environment.environment.ambient_light_color = Color("b0bddd")
		environment.environment.ambient_light_energy = .85
		if native_lab:
			environment.environment.ambient_light_energy = .55
			root.get_node("HyperAnimeWorldManager").configure_environment(environment.environment)
		root.add_child(environment)
		if not native_lab:
			var light := DirectionalLight3D.new()
			light.rotation = Vector3(-.8, -.7, 0)
			light.light_energy = 1.45
			root.add_child(light)
		var camera := Camera3D.new()
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 2.48 if native_lab else 2.24
		root.add_child(camera)
		camera.make_current()
		player.seek(1.0, true)
		player.advance(0)
		if cuff_player:
			cuff_player.seek(1.0, true)
			cuff_player.advance(0)
		for view in [["side", Vector3(4, 1.55, .1)], ["three-quarter", Vector3(2.7, 2.05, 2.6)]]:
			camera.position = anchor + view[1]
			camera.look_at(anchor + Vector3(0, .91, .02))
			await process_frame
			await RenderingServer.frame_post_draw
			var file_path := args[4].path_join("godot-" + view[0] + ".png")
			if root.get_texture().get_image().save_png(file_path) != OK:
				fail("Failed to save native capture")
				return
			captured.append(file_path.get_file())
		if args.size() == 6:
			var preview_folder := args[5]
			DirAccess.make_dir_recursive_absolute(preview_folder)
			for frame in range(60):
				player.seek(frame / 30.0, true)
				player.advance(0)
				await RenderingServer.frame_post_draw
				var path := preview_folder.path_join("%03d.jpg" % frame)
				if root.get_texture().get_image().save_jpg(path, .91) != OK:
					fail("Failed to save animation preview frame")
					return
		if cuff_player:
			camera.size = .83
			camera.position = anchor + Vector3(1.3, 1.88, 2.2)
			camera.look_at(anchor + Vector3(0, 1.17, -.16))
			for sample in [[0, "open"], [22, "closing"], [45, "latched"]]:
				player.seek(float(sample[0]) / 30, true)
				cuff_player.seek(float(sample[0]) / 30, true)
				player.advance(0)
				cuff_player.advance(0)
				await process_frame
				await RenderingServer.frame_post_draw
				var file_path := args[4].path_join("godot-cuffs-" + String(sample[1]) + ".png")
				if root.get_texture().get_image().save_png(file_path) != OK:
					fail("Failed to save cuff capture")
					return
				captured.append(file_path.get_file())
			if not sequence_dir.is_empty():
				if DirAccess.make_dir_recursive_absolute(sequence_dir) != OK:
					fail("Could not create the native lab sequence directory")
					return
				for frame in 60:
					player.seek(frame / 30.0, true)
					cuff_player.seek(frame / 30.0, true)
					player.advance(0)
					cuff_player.advance(0)
					await RenderingServer.frame_post_draw
					var path := sequence_dir.path_join("%03d.jpg" % frame)
					if root.get_texture().get_image().save_jpg(path, .92) != OK:
						fail("Could not save the native lab sequence frame")
						return
	var evidence := {"status": "PASS_NATIVE_JOINT_REPLAY", "frames": record.frames.size(),
		"joint_samples": sample_count, "max_joint_error_m": max_error, "duration_s": player.current_animation_length, "imported_clip": clips[0],
		"capture_files": captured, "display": DisplayServer.get_name(),
		"renderer": RenderingServer.get_current_rendering_method(), "source_sha256": FileAccess.get_sha256(args[0]),
		"reference_sha256": FileAccess.get_sha256(args[1])}
	if not cuff_evidence.is_empty():
		evidence["cuffs"] = cuff_evidence
	if native_lab:
		if lab.confrontation_done or lab.contract_done or lab.revenge_done or lab.wish_done or lab.breach_open:
			fail("Review changed a laboratory story flag")
			return
		evidence["native_lab"] = {
			"chair_origin": [anchor.x, anchor.y, anchor.z],
			"chair_source_sha256": FileAccess.get_sha256(args[3]),
			"room_sha256": FileAccess.get_sha256(LAB_PATH),
			"architecture_sha256": FileAccess.get_sha256(LAB_ARCHITECTURE),
			"review_sha256": FileAccess.get_sha256(get_script().resource_path),
			"source_material_sha256": FileAccess.get_sha256(args[2]),
			"sampled_anchor_frames": [0, 30, 60],
			"story_flags_clear": true,
			"viewport": [root.size.x, root.size.y],
			"sequence_frames": 0 if sequence_dir.is_empty() else 60,
			"sequence_fps": 30,
			"scope": "Seated body and cuff replay in original lab geometry under review lighting"
		}
	var file := FileAccess.open(args[4].path_join("native-" + DisplayServer.get_name() + ".json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(evidence, "  ") + "\n")
	file.close()
	print("CHAIR_NATIVE ", JSON.stringify(evidence))
	quit(0)

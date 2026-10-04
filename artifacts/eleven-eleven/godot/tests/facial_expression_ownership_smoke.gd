extends SceneTree

const Facial = preload("res://scripts/player/echo_facial_controller.gd")

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	var avatar = load("res://assets/characters/echo_opening_uniform_v13.glb").instantiate()
	root.add_child(avatar)
	var body := avatar.find_child("EchoOpeningUniformBody", true, false) as MeshInstance3D
	var controller_script: GDScript = Facial
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--baseline-controller="):
			controller_script = GDScript.new()
			# The baseline keeps its original bytes on disk. Remove only global
			# registration in this isolated script to avoid a duplicate class name.
			controller_script.source_code = FileAccess.get_file_as_string(argument.trim_prefix("--baseline-controller=")).replace("class_name EchoFacialController", "")
			if controller_script.reload() != OK:
				push_error("Saved baseline facial controller cannot be loaded")
				quit(1)
				return
	var face = controller_script.new()
	face.mesh_instance = body
	avatar.add_child(face)
	face.set_process(false)
	face.trigger_blink(0.30)
	await create_timer(0.08).timeout
	face.trigger_damage_grimace(0.90, 0.80)
	# Blink completion must not erase the still-active damage expression.
	await create_timer(0.30).timeout
	var grimace := body.get_blend_shape_value(body.find_blend_shape_by_name("Mouth_Grimace"))
	var left := body.get_blend_shape_value(body.find_blend_shape_by_name("Blink_L"))
	print("EXPRESSION overlap grimace=", grimace, " left=", left)
	if not _check(grimace > 0.01 and left >= grimace * 0.7 - 0.001, "blink completion erased damage eyelids"): return
	# Interrupt a long response with a shorter one. The first response must not
	# resume writing after the second has settled to the neutral pose.
	face.trigger_damage_grimace(0.75, 1.40)
	await create_timer(0.12).timeout
	face.trigger_damage_grimace(0.50, 0.18)
	await create_timer(0.32).timeout
	if not _check(absf(body.get_blend_shape_value(body.find_blend_shape_by_name("Mouth_Grimace"))) < 0.001, "superseded damage tween resumed writing"): return
	if not _check(absf(body.get_blend_shape_value(body.find_blend_shape_by_name("Blink_R"))) < 0.001, "damage eyelid did not recover"): return
	face.trigger_damage_grimace(1.0, 0.01)
	await create_timer(0.15).timeout
	if not _check(absf(body.get_blend_shape_value(body.find_blend_shape_by_name("Mouth_Grimace"))) < 0.001, "short damage duration did not settle"): return
	avatar.queue_free()
	await process_frame
	await process_frame
	print("PASS actual Echo blend shapes: concurrent blink/damage, interrupted damage, neutral recovery and short-duration input")
	quit(0)

func _check(condition: bool, message: String) -> bool:
	if not condition:
		push_error(message)
		quit(1)
	return condition

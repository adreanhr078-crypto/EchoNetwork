extends SceneTree
const Hair = preload("res://scripts/player/echo_contract_hair.gd")
const Cel = preload("res://shaders/anime_cel.gdshader")
const Applicator = preload("res://scripts/combat/shader_applicator.gd")
class Settings extends Node3D:
	var reduced_motion := false
class Actor extends Node3D:
	var contract_with_zero_sealed := false
var failures: Array[String] = []
func _initialize() -> void: _run.call_deferred()
func check(condition: bool, label: String) -> void:
	if not condition: failures.append(label)
func _run() -> void:
	var settings := Settings.new()
	root.add_child(settings)
	var actor := Actor.new()
	settings.add_child(actor)
	var model := Node3D.new()
	model.name = "ModelRoot"
	actor.add_child(model)
	var avatar: Node3D = load("res://assets/characters/echo_opening_uniform_v13.glb").instantiate()
	model.add_child(avatar)
	Applicator.apply_cel_shader(avatar, Cel, Color.WHITE, Color(0.1,0.4,0.6), Color(0.3,0.3,0.4))
	var body := avatar.find_child("EchoOpeningUniformBody",true,false) as MeshInstance3D
	var source := body.get_active_material(0) as ShaderMaterial
	var untouched_mesh := body.mesh
	var untouched_skin := body.skin
	var hair := Hair.new()
	actor.add_child(hair)
	hair.reveal()
	hair._process(1.0)
	check(hair.material == null and hair.blend == 0.0, "no hair transformation before sealed pact")
	actor.contract_with_zero_sealed = true
	hair.reveal()
	check(hair.material != source and source.get_shader_parameter("contract_hair_enabled") == false, "instance material authority")
	check(body.mesh == untouched_mesh and body.skin == untouched_skin, "native skin and topology untouched")
	check(hair.material.get_shader_parameter("albedo_texture") == source.get_shader_parameter("albedo_texture"), "authored texture preserved")
	check(hair.material.next_pass == source.next_pass, "ink pass preserved")
	hair._process(0.05)
	check(hair.blend > 0.0 and hair.blend < 1.0, "bounded colour transition")
	var frozen_time := hair.local_time
	var frozen_blend := hair.blend
	paused = true
	await create_timer(0.08,true).timeout
	check(hair.local_time == frozen_time and hair.blend == frozen_blend, "tree pause freezes colour animation")
	paused = false
	settings.reduced_motion = true
	hair._process(0.05)
	check(hair.blend == 1.0 and hair.local_time == frozen_time, "reduced motion settles without shimmer")
	actor.contract_with_zero_sealed = false
	hair._process(0.05)
	check(hair.material.get_shader_parameter("contract_hair_blend") == 0.0, "permission revocation restores base palette")
	actor.contract_with_zero_sealed = true
	hair.reveal(true)
	check(hair.blend == 1.0, "restore settles final palette")
	var refreshed := source.duplicate() as ShaderMaterial
	refreshed.set_shader_parameter("rim_intensity", 0.42)
	body.set_surface_override_material(0, refreshed)
	hair._process(0.05)
	check(hair.material != refreshed and hair.material.get_shader_parameter("rim_intensity") == 0.42, "rebind respects a newly authored ink material")
	hair.queue_free()
	await process_frame
	check(body.get_active_material(0) == refreshed, "removing colour controller restores its latest base material")
	var replacement := Hair.new()
	actor.add_child(replacement)
	replacement.reveal(true)
	await process_frame
	settings.queue_free()
	await process_frame
	print("CONTRACT_HAIR_REVIEW ",JSON.stringify({"status":"PASS" if failures.is_empty() else "FAIL","failures":failures,"scope":"Actual authored v13 mesh/native skin and shader parameters; hair-only native colour acceptance remains separate"}))
	quit(0 if failures.is_empty() else 2)

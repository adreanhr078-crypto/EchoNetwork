extends SceneTree

const Rig = preload("res://engine_visuals/camera/DynamicActionCameraRig.gd")
const Adapter = preload("res://engine_visuals/HyperMaterialAdapter.gd")
var hyper: Node
var vfx: Node
var checks := 0
var folder := "res://../audits/evidence/hyper-anime-cp41-20261019/"
var scene: Node3D
var body: ReviewBody
var camera: Camera3D

class ReviewBody extends CharacterBody3D:
	var reduced_motion := false
	var control_locked := false
	var opening_recovery_active := false
	var combat_available := false
	signal landing_executed(speed: float, heavy: bool)
	signal combat_roll_executed(direction: Vector3)
	signal attack_hit(damage: int, critical: bool)

func _initialize() -> void: _run.call_deferred()

func check(value: bool, message: String) -> void:
	checks+=1
	if not value:
		push_error(message)
		quit(1)
		assert(value,message)

func _run() -> void:
	hyper=root.get_node("HyperAnimeWorldManager")
	vfx=root.get_node("KineticVFXOrchestrator")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence="): folder=argument.trim_prefix("--evidence=").replace("\\","/")+"/"
	folder=ProjectSettings.globalize_path(folder).simplify_path()+"/"
	check(DirAccess.make_dir_recursive_absolute(folder)==OK,"Evidence directory failed")
	root.content_scale_size=Vector2i(960,540)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_VIEWPORT
	scene=Node3D.new()
	scene.name="HyperReviewFixture"
	root.add_child(scene)
	body=ReviewBody.new()
	scene.add_child(body)
	camera=Camera3D.new()
	camera.position=Vector3(4,3.2,6)
	scene.add_child(camera)
	camera.look_at(Vector3(0,0.7,0))
	camera.make_current()
	var world:=WorldEnvironment.new()
	world.name="WorldEnvironment"
	world.environment=Environment.new()
	world.environment.ambient_light_energy=0.8
	scene.add_child(world)
	var before: Environment=world.environment.duplicate()
	var original_resource:=world.environment
	var light:=DirectionalLight3D.new()
	light.rotation_degrees=Vector3(-50,-35,0)
	light.light_energy=1.0
	scene.add_child(light)
	var floor_mesh:=MeshInstance3D.new()
	var box:=BoxMesh.new()
	box.size=Vector3(10,0.1,10)
	floor_mesh.mesh=box
	floor_mesh.position.y=-0.05
	floor_mesh.material_override=hyper.make_reactive_surface(Color(0.2,0.28,0.36))
	scene.add_child(floor_mesh)
	var sample:=MeshInstance3D.new()
	sample.mesh=SphereMesh.new()
	sample.position=Vector3(0,1,0)
	scene.add_child(sample)
	var standard:=StandardMaterial3D.new()
	standard.albedo_color=Color(0.18,0.5,0.76)
	standard.metallic=0.2
	standard.roughness=0.32
	sample.material_override=standard
	hyper.attach_scene(scene,body)
	print("HYPER fixture environment/material attached")
	vfx.attach_player(scene,body)
	check(hyper.adapter.converted>0,"Active mesh material did not convert")
	check(sample.material_override is ShaderMaterial,"Visible standard material remained")
	standard.albedo_color=Color(0.24,0.4,0.7)
	hyper.adapter.sync_animated_values()
	check(sample.material_override.get_shader_parameter("albedo_color")==standard.albedo_color,"Dynamic source color stopped updating")
	Adapter.set_signal_color(sample.material_override,Color(0.1,0.8,0.9),true)
	check(standard.emission==Color(0.1,0.8,0.9),"Converted room beacon lost emission property API")
	Adapter.set_signal_color(sample.material_override,Color(0.3,0.4,0.5))
	check(standard.albedo_color==Color(0.3,0.4,0.5),"Converted telemetry lost color property API")
	# Conversion order must not make ordinary alpha and depth-prepass glass
	# share the same render policy.
	var alpha_source:=StandardMaterial3D.new()
	alpha_source.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	var depth_source:=StandardMaterial3D.new()
	depth_source.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
	var alpha_material:ShaderMaterial=hyper.adapter.convert_material(alpha_source)
	var depth_material:ShaderMaterial=hyper.adapter.convert_material(depth_source)
	check(alpha_material.shader!=depth_material.shader and depth_material.shader.code.contains("depth_prepass_alpha") and not alpha_material.shader.code.contains("depth_prepass_alpha"),"Glass conversion inherited another transparency policy")
	for index in 2:
		var glass:=MeshInstance3D.new()
		glass.mesh=SphereMesh.new()
		glass.position=Vector3(-2+index*4,0.8,0)
		glass.material_override=alpha_material if index==0 else depth_material
		scene.add_child(glass)
	var surface: ShaderMaterial=hyper.make_reactive_surface(Color(0.2,0.28,0.36))
	surface.set_shader_parameter("energy_enabled",0.6)
	floor_mesh.material_override=surface
	print("HYPER material transfer and surface attached")
	check(is_equal_approx(world.environment.tonemap_exposure,1.18) and is_equal_approx(world.environment.tonemap_white,6.5),"ACES reference values missing")
	check(is_equal_approx(world.environment.adjustment_saturation,1.38),"Chroma grade missing")
	check(world.environment.volumetric_fog_enabled==(RenderingServer.get_current_rendering_method()=="forward_plus"),"Unsupported volumetric tier")
	check(not hyper.set_preset("invalid"),"Invalid preset accepted")
	for id in hyper.PRESETS:
		check(hyper.set_preset(id,0.0),"Preset failed: "+id)
	hyper.set_preset("arcane_neon_sanctuary",0.0)
	hyper.set_preset("crimson_overdrive",0.04)
	await real_wait(0.08)
	check(is_equal_approx(world.environment.volumetric_fog_density,0.008),"Preset tween did not reach new profile")
	hyper.set_preset("arcane_neon_sanctuary",0.0)
	for i in 20: hyper.imprint(Vector3(i*0.05,0,0),0.8)
	check(hyper.ripple_points.size()==16 and hyper._ripple_cursor==4,"Imprint ring grew beyond sixteen")
	for fps in [30,60,120]:
		var position:=Vector3.ZERO
		var velocity:=Vector3.ZERO
		for tick in fps:
			var result:=Rig.spring(position,velocity,Vector3.ONE,2.0,1.0/fps)
			position=result[0]
			velocity=result[1]
		check(position.distance_to(Vector3.ONE)<0.0001,"Spring differs at frame rate "+str(fps))
	var a:=Vector2.ZERO
	var b:=Vector2.ZERO
	for tick in 30: a=vfx.exponential_velocity(a,Vector2.ONE,5,1.0/30)
	for tick in 120: b=vfx.exponential_velocity(b,Vector2.ONE,5,1.0/120)
	check(a.distance_to(b)<0.00001,"Locomotion depends on frame rate")
	check(vfx.pool.size()==12 and vfx.ambient.size()==3,"VFX budgets missing")
	for i in 16: vfx.emit_burst(Vector3(0,0.2,0),Vector3.UP,"landing")
	check(vfx.emitted_bursts==12 and vfx.dropped_bursts==4,"Burst pool overflow allocated extra effects")
	hyper.set_reduced_motion(true)
	vfx.set_reduced_motion(true)
	var clock: float=hyper.visual_time
	await create_timer(0.05,true,false,true).timeout
	check(is_equal_approx(hyper.visual_time,clock),"Reduced Motion shader clock moved")
	check(not vfx.emit_burst(Vector3.ZERO,Vector3.UP,"step"),"Reduced Motion emitted burst")
	check(not vfx.ambient[0].visible,"Reduced Motion kept ambient movement")
	hyper.set_reduced_motion(false)
	vfx.set_reduced_motion(false)
	Engine.time_scale=0.7
	hyper.trigger_impact_pulse(0.9,0.2,Vector3.ZERO)
	check(is_equal_approx(Engine.time_scale,0.7),"Human impact granted combat time stop")
	body.combat_available=true
	hyper.trigger_impact_pulse(0.9,0.2,Vector3.ZERO)
	check(is_equal_approx(Engine.time_scale,0.21),"Combat impact failed leased scale")
	hyper.trigger_impact_pulse(0.8,0.2,Vector3.ZERO)
	await real_wait(0.09)
	check(is_equal_approx(Engine.time_scale,0.7),"Overlapping impacts failed original scale restore")
	hyper.trigger_impact_pulse(0.9,0.2,Vector3.ZERO)
	paused=true
	await real_wait(0.04)
	check(is_equal_approx(Engine.time_scale,0.7),"Pause stranded hit stop")
	paused=false
	hyper.trigger_impact_pulse(0.9,0.2,Vector3.ZERO)
	Engine.time_scale=0.5
	await real_wait(0.09)
	check(is_equal_approx(Engine.time_scale,0.5),"Hit stop overwrote another owner's scale")
	Engine.time_scale=1.0
	hyper.set_quality("low")
	check(not world.environment.ssr_enabled and not world.environment.volumetric_fog_enabled,"Low tier retained costly effects")
	hyper.set_quality("high")
	body.velocity=Vector3(6,0,0)
	body.attack_hit.emit(1,false)
	for i in 35: await process_frame
	if DisplayServer.get_name()!="headless":
		hyper.imprint(Vector3(0,0,1),1.5)
		for i in 8: await process_frame
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(folder+"shader-world.png")==OK,"Capture save failed")
	var replacement:=Node3D.new()
	print("HYPER behavior checks complete")
	root.add_child(replacement)
	var next_body:=ReviewBody.new()
	replacement.add_child(next_body)
	hyper.attach_scene(replacement,next_body)
	print("HYPER replacement scene attached")
	scene.queue_free()
	await process_frame
	check(hyper.main==replacement,"Old scene exit detached new scene")
	check(is_equal_approx(original_resource.tonemap_exposure,before.tonemap_exposure),"Environment lease did not restore")
	hyper.detach_scene()
	vfx.detach_player()
	replacement.queue_free()
	await process_frame
	var result:={"status":"PASS","checks":checks,"renderer":RenderingServer.get_current_rendering_method(),"scope":"module behavior and shader render fixture; not chapter/art/device acceptance"}
	var file:=FileAccess.open(folder+"module-review.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"\t"))
	print("HYPER_ENGINE_REVIEW ",JSON.stringify(result))
	quit()

func real_wait(seconds: float) -> void:
	var deadline:=Time.get_ticks_usec()+int(seconds*1000000.0)
	while Time.get_ticks_usec()<deadline: await process_frame
	await process_frame

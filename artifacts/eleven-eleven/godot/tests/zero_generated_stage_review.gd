extends SceneTree

## Actual source skin and independently animated field, isolated from story
## authority. Every source rest/key remains read-only throughout this test.
const Slot=preload("res://scripts/cinematics/zero_generated_model_slot.gd")
var stage: Node3D
var slot: Node3D
var camera: Camera3D
var folder: String

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	root.size=Vector2i(960,720)
	root.content_scale_size=root.size
	folder=ProjectSettings.globalize_path("res://../audits/evidence/room-color-cinematics-20261007/zero-generated-stage/")
	DirAccess.make_dir_recursive_absolute(folder)
	var source:=ProjectSettings.globalize_path("res://../art/production/tripo-20261007/zero-rig-v1/tripo-out/zero-rig-v1-20261008-rig-925ca3b6/model.glb")
	var document:=GLTFDocument.new()
	var state:=GLTFState.new()
	assert(document.append_from_file(source,state)==OK)
	var model:=document.generate_scene(state)
	stage=Node3D.new()
	root.add_child(stage)
	slot=Slot.new()
	stage.add_child(slot)
	assert(slot.configure(model,{
		"source_height":2.09993577003479,"source_base_y":0.0000317096710205078,"facing_y_radians":-PI/2,
		"allow_articulated_fallback":true,"source_front":[1,0,0],
		"articulation_bones":{"spine":"tripo__0_Left_Limb_1","chest":"tripo__0_Left_Limb_2","head":"tripo__Head_1","left_arm":"tripo__0_Left_Limb_4","left_forearm":"tripo__0_Left_Limb_5","left_hand":"tripo__0_Left_Limb_6","right_arm":"bone_17","right_forearm":"bone_18","right_hand":"bone_19"},
		"eyes":[{"source_position":[0.122,1.85596,0.04084],"source_forward":[1,0,0],"bone_name":"tripo__Head_1","width":0.022,"height":0.006,"color":[0.90,0.05,0.15]},
		{"source_position":[0.122,1.85596,-0.04084],"source_forward":[1,0,0],"bone_name":"tripo__Head_1","width":0.022,"height":0.006,"color":[0.56,0.13,0.95]}]}))
	assert(slot.body_animation_verified and slot.body_animation_kind=="measured_native_articulation")
	_build_lighting()
	camera=Camera3D.new()
	stage.add_child(camera)
	camera.fov=35
	camera.position=Vector3(6.0,4.0,11.5)
	camera.look_at(Vector3(0,3.0,0))
	camera.make_current()
	slot.tick(0.0,false,"manifested",0.016)
	for i in 4: await process_frame
	var poses:=_poses()
	await _capture("01-source-idle-phase0-three-quarter")
	slot.tick(2.5,false,"manifested",0.016)
	for i in 3: await process_frame
	var changed:=0
	for index in slot.skeleton.get_bone_count():
		if not slot.skeleton.get_bone_pose(index).is_equal_approx(poses[index]): changed+=1
	assert(changed>=7,"A moving body must articulate actual source bones, not only the surrounding field")
	await _capture("02-source-idle-phase2-three-quarter")
	for i in 60: slot.tick(2.5+i/60.0,false,"accepted",1.0/60.0)
	for i in 3: await process_frame
	await _capture("03-source-pact-reaction-three-quarter")
	camera.position=Vector3(0,3.7,13.0)
	camera.look_at(Vector3(0,3.0,0))
	await _capture("04-source-pact-front")
	camera.position=Vector3(13.0,3.7,0)
	camera.look_at(Vector3(0,3.0,0))
	await _capture("05-source-pact-side")
	camera.position=Vector3(0,5.8,3.4)
	camera.look_at(Vector3(0,5.35,0))
	await _capture("06-source-living-face-close")
	var snapshot:=_poses()
	slot.tick(2.5+59.0/60.0,true,"accepted",3.0)
	assert(snapshot==_poses(),"Reduced motion must hold actual body pose at the same phase and accepted stance")
	var json:={"status":"GENERATED_SOURCE_NATIVE_ARTICULATION_PASS_VISUAL_REVIEW_REQUIRED","source_sha256":FileAccess.get_sha256(source),"source_keys_changed":false,"source_bones":slot.skeleton.get_bone_count(),"changed_source_bones":changed,"body_animation_kind":slot.body_animation_kind,"reduced_motion_pose_freezes":true,"eye_overlay_count":slot._eye_materials.size(),"campaign_integrated":false,"source_clip_pipeline":"Root-owned paid clip attempt pending; this evidence uses measured native articulation, not an imported mocap clip."}
	var file:=FileAccess.open(folder+"native-stage-review.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(json,"\t"))
	stage.queue_free()
	for i in 5: await process_frame
	print("PASS source Zero:42 real bones, measured torso/head/arm/hand articulation, source preserved, independent fracture/eyes and exact reduced-motion freeze")
	print("UNVERIFIED imported native Idle/Pact clips and connected-campaign visual acceptance")
	quit(0)

func _poses() -> Array[Transform3D]:
	var poses: Array[Transform3D]=[]
	for index in slot.skeleton.get_bone_count(): poses.append(slot.skeleton.get_bone_pose(index))
	return poses

func _capture(label: String) -> void:
	if DisplayServer.get_name()=="headless": return
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder+label+".png")

func _build_lighting() -> void:
	var world:=WorldEnvironment.new()
	var environment:=Environment.new()
	environment.background_mode=Environment.BG_COLOR
	environment.background_color=Color(0.025,0.040,0.062)
	environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color=Color(0.60,0.68,0.85)
	environment.ambient_light_energy=0.65
	environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled=true
	environment.glow_intensity=0.25
	environment.glow_hdr_threshold=1.0
	world.environment=environment
	stage.add_child(world)
	for data in [[Vector3(3.2,7.0,4.0),Color(0.77,0.84,1.0),3.2],[Vector3(-3.0,4.7,-1.4),Color(0.35,0.40,0.85),2.3]]:
		var light:=OmniLight3D.new()
		light.position=data[0]
		light.light_color=data[1]
		light.light_energy=data[2]
		light.omni_range=14
		stage.add_child(light)
	var floor:=MeshInstance3D.new()
	var mesh:=PlaneMesh.new()
	mesh.size=Vector2(22,22)
	floor.mesh=mesh
	var material:=StandardMaterial3D.new()
	material.albedo_color=Color(0.14,0.18,0.25)
	material.roughness=0.76
	floor.material_override=material
	stage.add_child(floor)

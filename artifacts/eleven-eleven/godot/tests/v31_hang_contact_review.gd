extends SceneTree

## Actual Room02 geometry and current avatar; fixture spawn, public traversal inputs.
## This is contact/controller evidence, not an earned chapter route or art acceptance.
var actor:EchoPlayer
var rig:Skeleton3D
var camera:Camera3D
var folder:String
var checks:=0
var samples:Array=[]

func _initialize() -> void: _run.call_deferred()
func _check(ok:bool,message:String) -> bool:
	checks+=1
	if not ok:
		push_error(message)
		quit(1)
	return ok

func _frames(count:int) -> void:
	for frame in count:
		await physics_frame
		await process_frame

func _capture(id:String,side:bool=false) -> void:
	if DisplayServer.get_name()=="headless":return
	var center:=Vector3(0,2.7,-5.5)
	camera.position=center+(Vector3(3.0,0,0.4) if side else Vector3(2.5,0.4,3.5))
	camera.look_at(center)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder.path_join(id+".png"))

func _run() -> void:
	root.unfocusable=true
	root.size=Vector2i(1280,720)
	AudioServer.set_bus_mute(0,true)
	var args:=OS.get_cmdline_user_args()
	folder=args[0] if not args.is_empty() else ProjectSettings.globalize_path("res://../audits/evidence/echo-parkour-cp40-20261019/room02-contact/")
	DirAccess.make_dir_recursive_absolute(folder)
	var world:=Node3D.new()
	root.add_child(world)
	world.add_child(load("res://scenes/environment/maintenance_vertical.tscn").instantiate())
	var environment:=WorldEnvironment.new()
	environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR
	environment.environment.background_color=Color("171f2d")
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color=Color("c7d5e5")
	environment.environment.ambient_light_energy=0.6
	world.add_child(environment)
	var light:=DirectionalLight3D.new()
	light.rotation_degrees=Vector3(-40,-35,0)
	light.light_energy=1.5
	world.add_child(light)
	actor=load("res://scenes/player/echo_player.tscn").instantiate()
	actor.position=Vector3(0,0.1,-5.1)
	world.add_child(actor)
	actor.finish_opening_recovery()
	actor.set_gameplay_orbit(Vector3.ZERO)
	rig=actor.find_child("Skeleton3D",true,false)
	camera=Camera3D.new()
	world.add_child(camera)
	camera.current=true
	await _frames(12)
	if not _check(actor.animation_player.has_animation("PARKOUR_HANG"),"Qualified Hang absent on actual current avatar"):return
	var source_hash:=FileAccess.get_sha256("res://assets/animations/v31/hang_cp40.res")
	var clip:=actor.animation_player.get_animation("PARKOUR_HANG")
	if not _check(clip.loop_mode==Animation.LOOP_NONE and absf(clip.length-28.0/30)<0.0001,"Finite source duration/loop altered"):return
	actor.set_mobile_input_vector(Vector2(0,-1),true)
	actor.request_jump()
	for frame in 180:
		await _frames(1)
		if actor.surface_motor.hanging:break
	if not _check(actor.surface_motor.hanging,"Public Jump and climb failed to reach actual Room02 ledge"):return
	actor.set_mobile_input_vector(Vector2.ZERO,false)
	var maximum_grip_error:=0.0
	var maximum_hand_height_error:=0.0
	var maximum_hand_plane_error:=0.0
	var minimum_torso_clearance:=INF
	var last_clock:=-1.0
	for frame in 100:
		await _frames(1)
		var left:=rig.to_global(rig.get_bone_global_pose(rig.find_bone("LeftHand")).origin)
		var right:=rig.to_global(rig.get_bone_global_pose(rig.find_bone("RightHand")).origin)
		var expected:Vector3=actor.surface_motor.hang_grip_world
		var wall_point:Vector3=expected-actor.traversal.wall_normal*0.025
		for name in ["Hips","Spine","Spine1","Spine2"]:
			var joint:=rig.to_global(rig.get_bone_global_pose(rig.find_bone(name)).origin)
			minimum_torso_clearance=minf(minimum_torso_clearance,(joint-wall_point).dot(actor.traversal.wall_normal)-0.12)
		var grip:=(left+right)*0.5
		var error:=grip.distance_to(expected)
		maximum_grip_error=maxf(maximum_grip_error,error)
		for hand in [left,right]:
			maximum_hand_height_error=maxf(maximum_hand_height_error,absf(hand.y-expected.y))
			maximum_hand_plane_error=maxf(maximum_hand_plane_error,absf((hand-expected).dot(actor.traversal.wall_normal)))
		var clock:float=actor.animation_player.current_animation_position
		if not _check(clock+0.0001>=last_clock,"Hang entry restarted instead of terminal hold"):return
		last_clock=clock
		if frame%5==0:samples.append({"frame":frame,"clock":clock,"left":str(left),"right":str(right),"grip_error_m":error,"capsule":str(actor.position)})
		if frame in [0,28,65]:await _capture("hang-%03d"%frame)
	if not _check(maximum_grip_error<0.002 and maximum_hand_height_error<0.07 and maximum_hand_plane_error<0.07,"Hands lost the measured ledge"):return
	if not _check(minimum_torso_clearance>0.0,"Torso intersects the wall despite valid wrist contact"):return
	if not _check(absf(last_clock-float(clip.get_meta("wall_support_pose_seconds",clip.length)))<0.0001 and actor.animation_player.speed_scale==0.0,"Wall support hold did not preserve its selected original sample"):return
	await _capture("hang-hold-side",true)
	actor.request_jump()
	for frame in 140:
		await _frames(1)
		if not actor.traversal.is_climbing():break
	await _frames(35)
	if not _check(actor.is_on_floor() and actor.position.y>3.3,"Jump from Hang failed to finish existing swept mantle"):return
	var presentation:Node3D=actor.get_node("ModelRoot/EchoOpeningUniform")
	if not _check(presentation.position.length()<0.001 and actor.animation_player.speed_scale==1.0,"Release retained presentation offset or frozen playback"):return
	if not _check(not actor.combat_available and not actor.contract_with_zero_sealed,"Human traversal granted a pact or power"):return
	if not _check(source_hash==FileAccess.get_sha256("res://assets/animations/v31/hang_cp40.res"),"Runtime altered source library bytes"):return
	var report:={"status":"PASS","scope":"Fixture on actual Room02 geometry, public input, braced wall support pose/contact only; no free-hang entry acceptance","checks":checks,"minimum_torso_clearance_m":minimum_torso_clearance,"max_grip_error_m":maximum_grip_error,"max_hand_height_error_m":maximum_hand_height_error,"max_hand_plane_error_m":maximum_hand_plane_error,"samples":samples,"source_hashes":{}}
	for path in ["assets/animations/v31/hang_cp40.res","assets/characters/echo_v31_adopted_high.glb","scripts/player/echo_v31_motion_adapter.gd","scripts/player/surface_traversal_motor.gd"]:report.source_hashes[path]=FileAccess.get_sha256("res://"+path)
	var file:=FileAccess.open(folder.path_join("contact-review.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"));file.close()
	print("V31_HANG_CONTACT PASS ",checks," grip=",maximum_grip_error," hand_y=",maximum_hand_height_error," hand_plane=",maximum_hand_plane_error)
	world.queue_free()
	await _frames(3)
	quit(0)

extends SceneTree
## Real EchoPlayer and public inputs; staged floor/wall, not a chapter acceptance.
var player: EchoPlayer
var failures: Array[String] = []
var checks := 0
var contacts: Array = []
var captures: Array = []
var folder := "res://../audits/evidence/character-school-20261101/pilot"

func _initialize() -> void: _run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
	print("PASS " if ok else "FAIL ",label)

func drive(input: Vector2, frames: int) -> void:
	player.set_mobile_input_vector(input,not input.is_zero_approx())
	for i in frames: await physics_frame

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var file := folder.path_join(label+".png")
	root.get_texture().get_image().save_png(file)
	captures.append(file)

func _run() -> void:
	folder = ProjectSettings.globalize_path(folder).simplify_path()
	DirAccess.make_dir_recursive_absolute(folder)
	var floor_body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(80,.2,80)
	collision.shape = box
	floor_body.position.y = -.1
	floor_body.add_child(collision)
	var floor_mesh := MeshInstance3D.new()
	var floor_box := BoxMesh.new()
	floor_box.size = box.size
	floor_mesh.mesh = floor_box
	floor_body.add_child(floor_mesh)
	root.add_child(floor_body)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40,-30,0)
	root.add_child(light)
	var unsupported := Node3D.new()
	var unsupported_scene := PackedScene.new()
	unsupported_scene.pack(unsupported)
	unsupported.free()
	var protected_player = load("res://scenes/player/echo_player.tscn").instantiate()
	protected_player.avatar_scene_override = unsupported_scene
	root.add_child(protected_player)
	check(protected_player.rig_profile.get("id") == "echo_v31_authored_68", "Unsupported candidate retains the existing qualified avatar")
	protected_player.queue_free()
	await process_frame
	player = load("res://scenes/player/echo_player.tscn").instantiate()
	player.avatar_scene_override = load("res://scenes/characters/echo_school_candidate.tscn")
	root.add_child(player)
	if not player.animation_player or player.rig_profile.get("id") != "echo_school_mixamo_65":
		check(false,"School player did not initialize; inspect model/import identity before retry")
		quit(1)
		return
	player.finish_opening_recovery()
	player.set_gameplay_orbit(Vector3(-.12,0,0))
	player.player_camera.make_current()
	for i in 20: await physics_frame
	check(player.rig_profile.get("id") == "echo_school_mixamo_65","Actual controller identifies the qualified school65 target")
	var skeleton := player.find_child("Skeleton3D",true,false) as Skeleton3D
	check(skeleton != null and skeleton.get_bone_count() == 65,"School avatar has65bones and no old avatar remains")
	var mixer := player.animation_player
	for alias in ["IDLE","WALK","RUN","preset_jump"]:
		check(mixer.has_animation(alias),"Qualified source available: "+alias)
	check(mixer.has_animation("MELEE_HORIZONTAL") and mixer.get_animation("MELEE_HORIZONTAL").get_meta("source_take_id","")=="088cddda8d40025753006381:0:b0913491","Qualified native horizontal source is available without granting combat")
	var native_sources := {"PARKOUR_HANG":"4623a1fd693e3506912844f9:0:bf075e31","PARKOUR_MANTLE":"ec61818d927decfc379508c9:0:b0913491","PARKOUR_STAND":"8dd34e2b14939c747d1b9787:0:b0913491"}
	for alias: String in native_sources:
		check(mixer.has_animation(alias) and mixer.get_animation(alias).get_meta("source_take_id","")==native_sources[alias],"Qualified native traversal provenance: "+alias)
	check(not player.combat_available,"Human candidate receives no early combat/power")
	check(not player.get_node("ProceduralFootIK").enabled,"Unqualified IK does not alter source gait")
	check(mixer.callback_mode_process == AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS,"Controlled source shares capsule physics clock")
	var avatar := player.get_node("ModelRoot/EchoOpeningUniform")
	check(avatar.scale.is_equal_approx(Vector3.ONE),"Metric school source is not multiplied by V31 scale")
	player.footstep_system.footstep_triggered.connect(func(left: bool,_surface: String,running: bool,point: Vector3): contacts.append({"left":left,"run":running,"height":point.y}))
	var origin := player.global_position
	await drive(Vector2(0,-.45),75)
	check(player.current_anim == "WALK" and player.global_position.distance_to(origin) > .5,"Partial public input produces actual Walk and capsule travel")
	await capture("walk")
	var time := mixer.current_animation_position
	var position := player.global_position
	paused = true
	for i in 6: await process_frame
	check(mixer.current_animation_position == time and player.global_position == position,"Pause freezes both movement and source time")
	paused = false
	await drive(Vector2(0,-1),85)
	check(player.current_anim == "RUN","Full public input uses the separately qualified Jog source")
	await capture("run")
	await drive(Vector2(.45,0),40)
	check(player.current_anim == "WALK","Direction and pace change return to Walk")
	await drive(Vector2.ZERO,35)
	check(player.current_anim == "IDLE" and Vector2(player.velocity.x,player.velocity.z).length() < .05,"Release brakes to stable Idle")
	check(contacts.any(func(c): return not c.run) and contacts.any(func(c): return c.run) \
		and contacts.any(func(c): return c.left) and contacts.any(func(c): return not c.left),
		"Measured source phases trigger both feet across Walk and Run")
	var max_height := 0.0
	for contact in contacts: max_height = maxf(max_height,float(contact.height))
	check(max_height < .20,"Contact events stay near the floor without runtime IK")
	player.request_jump()
	var airborne := false
	var jump_played := false
	for i in 75:
		await physics_frame
		airborne = airborne or not player.is_on_floor()
		jump_played = jump_played or player.current_anim == "preset_jump"
	check(airborne and jump_played and player.is_on_floor(),"Public jump uses qualified clip and lands on the actual floor")
	await capture("idle-after-jump")
	var roll_start:=player.global_position
	var roll_seen:=false
	var roll_fraction:=0.0
	var roll_hips_gap:=0.0
	var hips:=skeleton.find_bone("mixamorig_Hips")
	player.set_mobile_input_vector(Vector2(0,-1),true)
	player.request_dodge()
	for frame in 58:
		await physics_frame
		if mixer.current_animation=="preset_biped_roll_001":
			roll_seen=true
			roll_fraction=maxf(roll_fraction,mixer.current_animation_position/mixer.get_animation("preset_biped_roll_001").length)
			var hip_position:=skeleton.to_global(skeleton.get_bone_global_pose(hips).origin)
			roll_hips_gap=maxf(roll_hips_gap,Vector2(hip_position.x-player.global_position.x,hip_position.z-player.global_position.z).length())
			if frame%7==0: await capture("roll-%02d"%frame)
	check(roll_seen and roll_fraction>.92,"Public roll plays the full qualified source within the physics action clock")
	check(roll_hips_gap<.03,"Native roll remains inside its authoritative horizontal capsule")
	check(player.is_on_floor() and not player.is_dodging and player.global_position.distance_to(roll_start)>1.0,"Native roll returns grounded control after actual displacement")
	player.set_mobile_input_vector(Vector2.ZERO,false)
	var ink: Node = player.get_node("ModelRoot")
	check(not ink.placement_report.is_empty() and ink.placement_report.get("atlas_skin_only",false),"EX-011 is stamped on actual authored skin")
	if DisplayServer.get_name() != "headless":
		var detail_camera := Camera3D.new()
		root.add_child(detail_camera)
		detail_camera.fov = 42.0
		detail_camera.global_position = player.visual_root.to_global(Vector3(-.20,1.53,.45))
		detail_camera.look_at(player.visual_root.to_global(Vector3(0,1.52,.035)))
		detail_camera.make_current()
		await capture("neck-ink")
		player.player_camera.make_current()
		detail_camera.queue_free()
	var report := {"status":"PASS" if failures.is_empty() else "FAIL","checks":checks,"failures":failures,
		"contacts":contacts,"captures":captures,"skin":ink.placement_report,
		"scope":"School65 candidate controlled locomotion/pause/jump/contact pilot; staged floor,not chapter,traversal,combat orfinalart acceptance"}
	var output := FileAccess.open(folder.path_join("review.json"),FileAccess.WRITE)
	output.store_string(JSON.stringify(report,"\t")+"\n")
	player.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

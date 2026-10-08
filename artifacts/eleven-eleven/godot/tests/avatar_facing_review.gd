extends SceneTree

## Inspect the untouched runtime GLB and its authored clips without modifiers,
## transfer, blending, IK, fitted roots, or replacement keys.
func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	root.size=Vector2i(960,540)
	var folder:=ProjectSettings.globalize_path("res://../audits/evidence/quality-repair-20261006/avatar-facing/")
	DirAccess.make_dir_recursive_absolute(folder)
	var world:=Node3D.new()
	root.add_child(world)
	var env:=WorldEnvironment.new()
	env.environment=Environment.new()
	env.environment.background_mode=Environment.BG_COLOR
	env.environment.background_color=Color(0.15,0.17,0.22)
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color=Color.WHITE
	env.environment.ambient_light_energy=0.8
	world.add_child(env)
	var light:=DirectionalLight3D.new()
	light.rotation_degrees=Vector3(-35,-25,0)
	world.add_child(light)
	var avatar:Node3D=load("res://assets/characters/echo_opening_uniform_v13.glb").instantiate()
	avatar.scale=Vector3.ONE*1.72
	world.add_child(avatar)
	var skeleton:=avatar.find_child("Skeleton3D",true,false) as Skeleton3D
	var ap:=avatar.find_child("AnimationPlayer",true,false) as AnimationPlayer
	var camera:=Camera3D.new()
	camera.fov=35
	world.add_child(camera)
	camera.current=true
	var measurements:=[]
	for clip in ["preset_idle","preset_walk","preset_run"]:
		if not ap.has_animation(clip):
			push_error("Missing source clip: "+clip)
			quit(1)
			return
		ap.play(clip)
		ap.seek(0.3,true)
		ap.pause()
		await process_frame
		var feet:=[]
		for side in ["Left","Right"]:
			var foot:=skeleton.get_bone_global_rest(skeleton.find_bone("tripo__1_"+side+"_Limb_2")).origin
			var toe:=skeleton.get_bone_global_rest(skeleton.find_bone("tripo__1_"+side+"_Limb_3")).origin
			var forward:=toe-foot
			feet.append({"label":side,"rest_foot":[foot.x,foot.y,foot.z],"rest_toe":[toe.x,toe.y,toe.z],"rest_forward":[forward.x,forward.y,forward.z]})
		measurements.append({"clip":clip,"feet":feet})
		for view in {"positive_x":Vector3(3.8,1.05,0),"negative_x":Vector3(-3.8,1.05,0),"positive_z":Vector3(0,1.05,3.8),"negative_z":Vector3(0,1.05,-3.8)}:
			camera.position={"positive_x":Vector3(3.8,1.05,0),"negative_x":Vector3(-3.8,1.05,0),"positive_z":Vector3(0,1.05,3.8),"negative_z":Vector3(0,1.05,-3.8)}[view]
			camera.look_at(Vector3(0,0.88,0))
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(folder+clip+"-"+view+".png")
	var file:=FileAccess.open(folder+"measurements.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"status":"CAPTURED_NOT_ARTISTIC_APPROVAL","source":"echo_opening_uniform_v13.glb","source_keys_edited":false,"measurements":measurements},"\t"))
	file.close()
	world.queue_free()
	await process_frame
	await physics_frame
	quit()


extends SceneTree

## Isolated native-clock character inspection; never retargets or changes keys.
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	root.unfocusable=true
	root.size=Vector2i(960,720)
	var args:=OS.get_cmdline_user_args()
	if args.size()<3:push_error("Provide raw GLB, native Blender reference, output folder");quit(1);return
	var reference:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args[1]))
	if FileAccess.get_sha256(args[0])!=reference.source_sha256:push_error("Source/reference mismatch");quit(1);return
	DirAccess.make_dir_recursive_absolute(args[2])
	var document:=GLTFDocument.new();var state:=GLTFState.new()
	if document.append_from_file(args[0],state)!=OK:push_error("GLB parse failed");quit(1);return
	var model:Node3D=document.generate_scene(state,float(reference.fps),false,false)
	root.add_child(model)
	var rig:Skeleton3D=model.find_child("Skeleton3D",true,false)
	var animator:AnimationPlayer=model.find_child("AnimationPlayer",true,false)
	if not rig or not animator or animator.get_animation_list().size()!=1:push_error("Need a rig and one untouched clip");quit(1);return
	var clip:String=animator.get_animation_list()[0]
	animator.active=true
	animator.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	animator.root_motion_track=NodePath("")
	var world:=WorldEnvironment.new();world.environment=Environment.new()
	world.environment.background_mode=Environment.BG_COLOR
	world.environment.background_color=Color(.025,.035,.05)
	world.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color=Color(.75,.81,.92)
	world.environment.ambient_light_energy=.5;root.add_child(world)
	var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-35,-35,0);light.light_energy=1.1;root.add_child(light)
	var floor_mesh:=MeshInstance3D.new();var plane:=PlaneMesh.new();plane.size=Vector2(5,5);floor_mesh.mesh=plane
	var material:=StandardMaterial3D.new();material.albedo_color=Color(.075,.09,.12);material.roughness=1;floor_mesh.material_override=material;root.add_child(floor_mesh)
	var camera:=Camera3D.new();camera.fov=33;root.add_child(camera);camera.make_current()
	var views:={"front":Vector3(0,.63,2.25),"quarter":Vector3(1.25,.7,1.85),"side":Vector3(2.25,.63,0)}
	var sample_indices:=[0,int(reference.frames.size()/4),int(reference.frames.size()/2),int(reference.frames.size()*3/4),reference.frames.size()-1]
	if args.has("--sequence"):
		views={"quarter":views.quarter}
		sample_indices=range(reference.frames.size())
	for view:String in views:
		for index:int in sample_indices:
			var time:float=reference.frames[index].time
			animator.play(clip,0);animator.seek(time,true);animator.pause()
			rig.force_update_all_bone_transforms()
			var hips:int=rig.find_bone("mixamorig_Hips")
			if hips<0:push_error("Missing source hips");quit(1);return
			var root_position:Vector3=rig.global_transform*rig.get_bone_global_pose(hips).origin
			# A following review camera does not remove or rewrite source root travel.
			var follow:=Vector3(root_position.x,0,root_position.z)
			camera.position=views[view]+follow;camera.look_at(Vector3(0,.5,0)+follow)
			for frame in 3:await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(args[2]+"/%s-%03d.png"%[view,index+1])
	var report:={"source_sha256":reference.source_sha256,"native_fps":reference.fps,"frames":reference.frames.size(),"views":views.keys(),"sample_indices":sample_indices,"rig_bones":rig.get_bone_count(),"visual_acceptance":"REQUIRES_INSPECTION","runtime_replacement":false,"fixture_sha256":FileAccess.get_sha256("res://tests/tripo_character_visual_review.gd")}
	var file:=FileAccess.open(args[2]+"/visual-source.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("PASS raw character visual capture; appearance/contact acceptance requires inspection")
	quit(0)

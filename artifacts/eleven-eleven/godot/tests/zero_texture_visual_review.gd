extends SceneTree

## Fixed-pose material A/B inspection, separate from chapter art acceptance.
const Slot=preload("res://scripts/cinematics/zero_generated_model_slot.gd")
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var args:=OS.get_cmdline_user_args()
	if args.is_empty(): quit(1);return
	var folder:=args[0]
	DirAccess.make_dir_recursive_absolute(folder)
	root.unfocusable=true;root.size=Vector2i(1000,900)
	var slot:=Slot.new();root.add_child(slot)
	if not slot.load_profile("res://assets/characters/zero_manifestation_profile_v1.json"): push_error("Zero failed profile load");quit(1);return
	slot.source_player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	slot.source_player.play("idle");slot.source_player.seek(.5,true);slot.source_player.pause()
	slot.tick(0,true,"manifested",0)
	slot.source_player.seek(.5,true)
	var world:=WorldEnvironment.new();world.environment=Environment.new()
	world.environment.background_mode=Environment.BG_COLOR;world.environment.background_color=Color(.06,.075,.095)
	world.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;world.environment.ambient_light_color=Color(.7,.78,.9);world.environment.ambient_light_energy=.6;root.add_child(world)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-30,-25,0);sun.light_energy=1.5;root.add_child(sun)
	var camera:=Camera3D.new();camera.fov=35;camera.far=30;root.add_child(camera);camera.make_current()
	# The animated source moves its head. Aim from the actual evaluated bone,
	# rather than the profile's rest height, so a closeup cannot crop the face.
	slot.skeleton.force_update_all_bone_transforms()
	var head_index:=slot.skeleton.find_bone("Head")
	if head_index<0: push_error("Zero Head missing");quit(1);return
	var head:=slot.skeleton.to_global(slot.skeleton.get_bone_global_pose(head_index).origin)
	var chest:=head-Vector3(0,1.4,0)
	var shots:={"body":[Vector3(4,4.2,14),Vector3(0,3.1,0)],"face":[head+Vector3(.65,.2,2.7),head+Vector3(0,.2,0)],"torso":[chest+Vector3(2.5,.7,4.7),chest]}
	for shot in shots:
		camera.position=shots[shot][0];camera.look_at(shots[shot][1])
		for i in 5: await process_frame
		if DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(folder+"/"+shot+".png")
	var rows:=[]
	for mesh in slot.model_root.find_children("*","MeshInstance3D",true,false):
		for surface in mesh.mesh.get_surface_count():
			var mat:=mesh.get_active_material(surface) as StandardMaterial3D
			if not mat: continue
			for label in ["albedo_texture","normal_texture","roughness_texture"]:
				var tex:Texture2D=mat.get(label)
				if not tex: continue
				# Avoid synchronously reading hundreds of MiB back from an integrated
				# GPU. Actual aggregate residency is measured below; settings and
				# source fingerprints identify the imported derivative.
				var config:=ConfigFile.new();config.load(tex.resource_path+".import")
				rows.append({"map":label,"path":tex.resource_path,"width":tex.get_width(),"height":tex.get_height(),"compression_mode":config.get_value("params","compress/mode"),"source_sha256":FileAccess.get_sha256(tex.resource_path),"import_sha256":FileAccess.get_sha256(tex.resource_path+".import")})
	var report:={"scope":"Fixed source pose .5seconds, same local material profile/lighting/camera; source images and animation untouched; visual approval separate","texture_monitor_bytes":Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED),"source_glb_sha256":FileAccess.get_sha256("res://assets/characters/zero_manifestation_idle_v1.glb"),"textures":rows}
	var output:=FileAccess.open(folder+"/review.json",FileAccess.WRITE);output.store_string(JSON.stringify(report,"\t"));output.close()
	print("ZERO_TEXTURE_REVIEW ",JSON.stringify(report))
	quit(0)

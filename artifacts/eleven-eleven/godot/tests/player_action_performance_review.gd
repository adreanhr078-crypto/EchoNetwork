extends SceneTree

## Actual controller input and weighted skin samples, not clip seeking.
var player: EchoPlayer
var rig: Skeleton3D
var camera: Camera3D
var frame:=0
var trace: Array=[]
var surfaces: Array=[]
var folder: String

func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	root.size=Vector2i(960,540)
	folder=ProjectSettings.globalize_path("res://../audits/evidence/quality-repair-20261006/actions-runtime/")
	DirAccess.make_dir_recursive_absolute(folder)
	var environment:=WorldEnvironment.new()
	environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR
	environment.environment.background_color=Color(0.11,0.14,0.18)
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_energy=0.65
	root.add_child(environment)
	var light:=DirectionalLight3D.new()
	light.rotation_degrees=Vector3(-50,-25,0)
	light.light_energy=0.8
	light.shadow_enabled=true
	root.add_child(light)
	var floor:=StaticBody3D.new()
	var shape:=BoxShape3D.new()
	shape.size=Vector3(80,0.2,80)
	var col:=CollisionShape3D.new()
	col.shape=shape
	floor.add_child(col)
	var mesh:=MeshInstance3D.new()
	mesh.mesh=BoxMesh.new()
	mesh.mesh.size=shape.size
	var mat:=StandardMaterial3D.new()
	mat.albedo_color=Color(0.42,0.43,0.45)
	mat.roughness=1
	mesh.material_override=mat
	floor.add_child(mesh)
	floor.position.y=-0.1
	root.add_child(floor)
	player=load("res://scenes/player/echo_player.tscn").instantiate()
	root.add_child(player)
	player.finish_opening_recovery()
	player.set_combat_available(true)
	player.unsheath_weapon()
	rig=player.find_child("Skeleton3D",true,false)
	_cache_skin()
	camera=Camera3D.new()
	camera.fov=43
	root.add_child(camera)
	camera.current=true
	await _frames(35,"idle")
	player.request_dodge()
	await _frames(75,"roll")
	for action in [1,2,3]:
		player.perform_attack()
		await _frames(80,"attack_%d" % action)
	player.set_combat_available(false)
	player.position.y=6
	player.velocity=Vector3.ZERO
	await _frames(125,"drop_and_land")
	var file:=FileAccess.open(folder+"trace.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(trace))
	file.close()
	print("CAPTURED actual action input and weighted-skin trace: ",folder)
	player.queue_free()
	floor.queue_free()
	for i in 5: await process_frame
	quit(0)

func _frames(count: int,phase: String) -> void:
	for i in count:
		await physics_frame
		camera.position=player.position+Vector3(3.0,1.65,3.6)
		camera.look_at(player.position+Vector3.UP*0.9)
		await process_frame
		if DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw
			if OS.get_cmdline_user_args().has("--dense") or frame%6==0:
				root.get_texture().get_image().save_png(folder+"%04d.png" % frame)
		var skin:=_skin_minima()
		trace.append({"frame":frame,"phase":phase,"clip":player.current_anim,"position":[player.position.x,player.position.y,player.position.z],"on_floor":player.is_on_floor(),"dodging":player.is_dodging,"attacking":player.is_attacking,"rate":player.animation_player.speed_scale,"skin":skin})
		frame+=1

func _cache_skin() -> void:
	for mesh: MeshInstance3D in player.visual_root.find_children("*","MeshInstance3D",true,false):
		if not mesh.mesh or not mesh.skin: continue
		for surface in mesh.mesh.get_surface_count():
			var arrays:=mesh.mesh.surface_get_arrays(surface)
			surfaces.append({"mesh":mesh,"vertices":arrays[Mesh.ARRAY_VERTEX],"bones":arrays[Mesh.ARRAY_BONES],"weights":arrays[Mesh.ARRAY_WEIGHTS]})

func _skin_minima() -> Dictionary:
	var matrices: Array=[]
	var mesh: MeshInstance3D=surfaces[0].mesh
	for bind in mesh.skin.get_bind_count():
		var bone:=mesh.skin.get_bind_bone(bind)
		if bone<0: bone=rig.find_bone(mesh.skin.get_bind_name(bind))
		var t: Transform3D=rig.global_transform*rig.get_bone_global_pose(bone)*mesh.skin.get_bind_pose(bind)
		matrices.append([[t.basis.x.x,t.basis.y.x,t.basis.z.x,t.origin.x],[t.basis.x.y,t.basis.y.y,t.basis.z.y,t.origin.y],[t.basis.x.z,t.basis.y.z,t.basis.z.z,t.origin.z]])
	return {"world_skin_matrices":matrices}

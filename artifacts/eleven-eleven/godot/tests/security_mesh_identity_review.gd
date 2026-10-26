extends "res://tests/remaining_rooms_high_inventory.gd"

var inspected:=false
func _frames(count:int)->void:
	await super._frames(count)
	if inspected or count!=35:return
	inspected=true
	var room:Node3D=main.get_node("NativeJourneyController").security
	var rows:=[]
	for mesh in main.find_children("*","MeshInstance3D",true,false):
		if not mesh.is_visible_in_tree():continue
		var p:Vector3=room.to_local(mesh.global_position)
		if (p.z< -12 and p.z> -19 and absf(p.x)<2 and p.y>3) or (p.x>2.5 and p.y>2.3):
			rows.append({"path":str(mesh.get_path()),"local_position":str(p),"aabb":str(mesh.get_aabb()),"mesh":mesh.mesh.resource_path,"class":mesh.mesh.get_class()})
	_write(out.path_join("mesh-identities.json"),{"scope":"Read-only native rendered mesh identity diagnostic","meshes":rows})
	var camera:=Camera3D.new();camera.fov=65;camera.near=.05;room.add_child(camera)
	camera.environment=main.player.player_camera.environment;camera.attributes=main.player.player_camera.attributes
	camera.position=Vector3(1.8,2.1,-12.8);camera.look_at(room.to_global(Vector3(0,1.5,-15.9)));camera.make_current();main.hud.hide()
	for mode in ["baseline","no_kinetic","no_room_dust"]:
		if mode=="no_kinetic":
			for holder in main.find_children("KineticVFXPool","Node3D",true,false):holder.hide()
		if mode=="no_room_dust":room.get_node("SecurityAtmosphere").hide()
		for i in 6:await process_frame;await physics_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out.path_join("identity-"+mode+".png"))
	quit(0)
	await create_timer(2).timeout

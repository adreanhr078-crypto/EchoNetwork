extends SceneTree

## Art direction references only, restored from an earned route save.
## Hidden HUD/player/guide and review cameras are never runtime changes.
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	root.unfocusable=true
	root.size=Vector2i(1280,720)
	var folder:=ProjectSettings.globalize_path("res://../art/production/room09-cp37/references/")
	DirAccess.make_dir_recursive_absolute(folder)
	var profile: String="user://lab_reference_%d/"%OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(profile)
	for file in ["opening.json","maintenance.json","route.json","campaign.json","preferences.cfg"]:
		var earned: String="res://../audits/evidence/pre-tripo-20261018/cp37/route/cp37-current-rendered/earned/before-trial/"+file
		if DirAccess.copy_absolute(earned,profile+file)!=OK: push_error("Missing earned reference profile");quit(1);return
	var main=load("res://scenes/native_journey.tscn").instantiate()
	main.native_checkpoint_path=profile+"opening.json"
	main.native_preferences_path=profile+"preferences.cfg"
	main.get_node("SystemJourneyPreview").checkpoint_path=profile+"maintenance.json"
	main.get_node("NativeJourneyController").checkpoint_path=profile+"route.json"
	main.get_node("NativeCampaignController").checkpoint_path=profile+"campaign.json"
	root.add_child(main)
	for i in 20: await process_frame
	main.set_audio_muted(true)
	main.set_reduced_motion(true)
	main.hud.hide()
	main.native_pause_menu.hide()
	main.player.get_node("ModelRoot").hide()
	main.companion.hide()
	var room: Node3D=main.get_node("NativeCampaignController").rooms[5]
	var camera:=Camera3D.new()
	room.add_child(camera)
	camera.fov=60
	camera.near=.07
	camera.environment=main.player.player_camera.environment
	camera.make_current()
	var shots=[
		["01-entry-wide",Vector3(0,2.2,-1.5),Vector3(0,1.7,-21)],
		["02-reverse-wide",Vector3(0,3.3,-27),Vector3(0,1.8,-3)],
		["03-lateral",Vector3(-13,3.2,-16),Vector3(3,1.5,-21)],
		["04-memory-pod-detail",Vector3(3.6,2.2,-16.5),Vector3(7,1.35,-20)]
	]
	var refs:=[]
	for shot in shots:
		camera.position=shot[1]
		camera.look_at(room.to_global(shot[2]))
		for i in 6: await process_frame
		await RenderingServer.frame_post_draw
		var path: String=folder+shot[0]+".png"
		if root.get_texture().get_image().save_png(path)!=OK: push_error("Cannot save reference");quit(1);return
		refs.append({"id":shot[0],"file":shot[0]+".png","sha256":FileAccess.get_sha256(path),"camera":str(shot[1]),"target":str(shot[2]),"fov":camera.fov})
	var report:=FileAccess.open(folder+"native-reference-manifest.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"scope":"Art references, HUD/player/guide hidden for capture only; no artistic/gameplay acceptance","dimensions_m":[32,40,10],"source_sha256":FileAccess.get_sha256("res://scripts/environment/dr_kinja_lab_room.gd"),"references":refs},"\t"))
	report.close()
	print("PASS four native lab art reference files; no gameplay/art acceptance")
	quit(0)

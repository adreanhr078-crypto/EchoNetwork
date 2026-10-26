extends "res://tests/post_contract_journey_review.gd"

## Four production design views of the live earned room, not traversal proof.
func _review_melee_camera()->bool:
	# Reference tier for art inspection. This writes only the PID-isolated
	# fixture preferences, never the owner's saved graphics preference.
	main.set_visual_quality("high")
	var review_camera:=Camera3D.new();review_camera.fov=65
	room.add_child(review_camera)
	review_camera.environment=player.player_camera.environment
	review_camera.make_current()
	main.hud.hide();main.native_pause_menu.hide()
	var shots:=[
		["01-entry",Vector3(0,2.2,-2),Vector3(0,2,-23)],
		["02-reverse",Vector3(0,3,-36),Vector3(0,2,-14)],
		["03-lateral",Vector3(-13.8,3.5,-15),Vector3(2,2.5,-22)],
		["04-theater",Vector3(3.2,3.2,-16),Vector3(0,2.1,-20)]
	]
	for shot in shots:
		review_camera.position=shot[1]
		review_camera.look_at(room.to_global(shot[2]))
		for tick in 15:await process_frame
		await _capture(shot[0])
	var paths:=["res://scripts/environment/clinical_lab_architecture.gd","res://scripts/environment/lab_memory_cinema.gd","res://scripts/environment/memory_reflection_space.gd","res://scripts/cinematics/lab_memory_trial.gd","res://scripts/cinematics/pact_revenge_presentation.gd","res://assets/environments/lab_clinical_cp45/clinical_scanner_p2_4k.glb","res://assets/environments/lab_clinical_cp45/clinical_wall_p2_4k.glb","res://assets/environments/lab_clinical_cp45/clinical_service_frame_clean.glb","res://scripts/environment/clinical_modular_perimeter.gd","res://shaders/clinical_architecture_surface.gdshader","res://shaders/clinical_vitrine_glass.gdshader","res://shaders/clinical_porcelain_floor.gdshader","res://tests/lab_rebuild_views_review.gd"]
	var hashes:={}
	paths.append("res://shaders/clinical_diagnostic_display.gdshader")
	for path in paths:hashes[path]=FileAccess.get_sha256(path)
	for path in ["res://scripts/environment/lab_memory_cinema.gd","res://scripts/environment/memory_reflection_space.gd","res://shaders/memory_water.gdshader","res://assets/cinematics/memory-screens/city-high.ogv","res://assets/cinematics/memory-screens/friends-high.ogv"]:
		hashes[path]=FileAccess.get_sha256(path)
	var report:={"renderer":RenderingServer.get_current_rendering_method(),"framebuffer":[root.size.x,root.size.y],"scope":"Four fixed art cameras in actual earned native room; HUD hidden only by this fixture. No art/traversal/performance acceptance.","source_hashes":hashes,"contract_done":room.contract_done,"wish_done":room.wish_done,"contacts":campaign.kinja.contacts,"motion":not room.reduced_motion}
	var output:=FileAccess.open(folder+"review.json",FileAccess.WRITE);output.store_string(JSON.stringify(report,"\t"));output.close()
	return _check(room.contract_done and not room.wish_done and campaign.kinja.contacts==0,"Architecture views changed earned state")

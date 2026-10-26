extends "res://tests/post_contract_journey_review.gd"

## Actual earned lab profile: moving footage, pause, live RM, tier and unload.
func _review_melee_camera()->bool:
	main.set_visual_quality("high")
	main.set_reduced_motion(false)
	var avatar:Node3D=player.get_node("ModelRoot/EchoOpeningUniform")
	var skin_report:Dictionary=player.get_node("ModelRoot").placement_report
	if not _check(skin_report.get("ink_pixels",0)>0 and skin_report.get("atlas_skin_only",false) and skin_report.get("native_skin",false),"VRAM import lost the real skin-bound EX-011 lettering"):return false
	var cinema:Node=main.find_child("IntactMemoryCinema",true,false)
	var water:Node=main.find_child("MemoryReflectionSpace",true,false)
	var architecture:Node=main.find_child("ClinicalLabArchitecture",true,false)
	if not _check(is_instance_valid(architecture) and main.find_child("ClinicalDiagnosticReadout",true,false)!=null,"Clinical terminal lost its instrument readout"):return false
	var clock_housing:MeshInstance3D=room.get_node("StasisClockHousing")
	var altar:Node3D=room.get_node("ZeroContractAltar")
	var plinth:MeshInstance3D=altar.get_node("ClinicalContractPlinth")
	if not _check(altar.position.is_equal_approx(Vector3(0,0,-32)) and plinth.position.is_equal_approx(Vector3(0,.6,0)) and is_equal_approx(plinth.mesh.top_radius,1.05) and is_equal_approx(plinth.mesh.bottom_radius,1.18) and is_equal_approx(plinth.mesh.height,1.2),"Plinth refinement moved the original manifestation landmark"):return false
	var altar_shape:BoxShape3D=altar.get_node("CollisionShape3D").shape
	if not _check(altar_shape.size.is_equal_approx(Vector3(2.4,1.2,2.4)),"Visual plinth refinement changed the original solid"):return false

	# Verify the global adapter did not replace the local continuous-light
	# alloys after room construction; this previously looked correct in code
	# while the actual terminal still used an unqualified dark cel material.
	for label in ["EchoSignalConsole_Static_Graphite","EchoSignalConsole_Static_Titanium","MemoryScreenRearCasing"]:
		var alloy_mesh:MeshInstance3D=room.find_child(label,true,false) as MeshInstance3D
		var alloy_finish:ShaderMaterial=alloy_mesh.get_active_material(0) as ShaderMaterial if alloy_mesh else null
		if not _check(alloy_finish!=null and alloy_finish.shader.resource_path=="res://shaders/clinical_architecture_surface.gdshader","Global adapter replaced the local clinical alloy: "+label):return false
	if not _check(clock_housing.mesh.size.is_equal_approx(Vector3(10,2.4,.1)) and clock_housing.position.is_equal_approx(Vector3(0,5,-39.7)),"Clock housing geometry/placement changed"):return false
	if not _check(clock_housing.material_override==architecture.stasis_display_material and architecture.stasis_display_material.get_shader_parameter("stasis_active")==false and not room._stasis_digits.visible,"Standby housing revealed the story clock prematurely"):return false
	var perimeter:Node=architecture.get_node("MeasuredTripoClinicalPerimeter")
	var meshes:Array=perimeter.find_children("*","MeshInstance3D",true,false)
	var batches:Array=perimeter.find_children("*","MultiMeshInstance3D",true,false)
	if not _check(meshes.size()==1 and batches.size()==4,"Modular perimeter lost its shared tile batches or service frame"):return false
	var total_instances:=0
	for draw in batches:
		total_instances+=draw.multimesh.instance_count
		var bounds:AABB=draw.multimesh.custom_aabb
		if draw.name=="ClinicalWestCladding" and not _check(bounds.size.x<.21 and bounds.end.x< -15.95,"West batch rotation/clearance failed"):return false
		if draw.name=="ClinicalEastCladding" and not _check(bounds.size.x<.21 and bounds.position.x>15.95,"East batch rotation/clearance failed"):return false
		if draw.name=="ClinicalNorthCladding" and not _check(bounds.size.z<.21 and bounds.end.z< -39.95,"North batch rotation/clearance failed"):return false
		if draw.name=="ClinicalSouthCladding" and not _check(bounds.size.z<.21 and bounds.position.z> -.03,"South batch rotation/clearance failed"):return false
	if not _check(total_instances==120,"Modular cladding lost a measured tile placement"):return false
	var finish:ShaderMaterial=batches[0].material_override as ShaderMaterial
	if not _check(finish!=null and finish.get_shader_parameter("has_normal_map") and finish.get_shader_parameter("has_roughness_map") and finish.get_shader_parameter("has_metallic_map"),"Packed PBR normal/roughness/metallic channels were not retained"):return false
	if not _check(finish.get_shader_parameter("cladding_tone_enabled")==true,"Modular cladding lost its local focal hierarchy finish"):return false
	var gate_plates:MultiMeshInstance3D=room.get_node("DimensionalBreachPortal/ClinicalGatePressurePlates")
	if not _check(gate_plates.multimesh.instance_count==6,"Portal lost its original six pressure-plate placements"):return false
	var scanner:Node3D=architecture.get_node("SegmentedTripoScanner")
	var scanner_meshes:Array=scanner.find_children("*","MeshInstance3D",true,false)
	if not _check(scanner.position.is_equal_approx(Vector3(0,7,-20)) and scanner_meshes.size()==1 and scanner_meshes[0].mesh.get_surface_count()==1,"Measured scanner lost its retained ring anchor/shared surface"):return false
	var scanner_finish:ShaderMaterial=scanner_meshes[0].get_active_material(0) as ShaderMaterial
	if not _check(scanner_finish!=null and scanner_finish.get_shader_parameter("has_normal_map") and scanner_finish.get_shader_parameter("combined_rm_map"),"Scanner lost genuine normal/packed PBR channels"):return false
	var suspension:Array=architecture.find_children("ScannerCeilingSuspension*","MeshInstance3D",true,false)
	if not _check(suspension.size()==4,"Measured scanner lost its four ceiling connections"):return false
	for support in suspension:
		var lower:float=support.position.y-support.mesh.size.y*.5
		var upper:float=support.position.y+support.mesh.size.y*.5
		if not _check(absf(lower-8.83131314)<.001 and upper>=10.0,"Scanner suspension is floating below its retained ceiling"):return false
	if not _check(is_instance_valid(cinema) and is_instance_valid(water),"Live room lost moving memories or reflection owner"):return false
	if not _check(water.coolant_material!=water.material and is_equal_approx(float(water.coolant_material.get_shader_parameter("reflection_gain")),.55) and is_equal_approx(float(water.material.get_shader_parameter("reflection_gain")),1.0),"Physical coolant hierarchy leaked into the story-owned full reflection"):return false
	if not _check(is_equal_approx(room._surgical_light.light_size,.18),"High tier lost the measured soft surgical light source"):return false
	for i in 2:
		if not _check(cinema.players[i].stream.resource_path.ends_with("-high.ogv") and cinema.players[i].get_parent().size==Vector2i(1280,720),"High tier still uses the old low-resolution movie"):return false
		if not _check(is_equal_approx(cinema.panels[i].pixel_size*cinema.panels[i].texture.get_width(),2.624),"Native720 movie changed the physical screen width"):return false
		if not _check(cinema.frames[i].get_node_or_null("MemoryScreenRearCasing")!=null,"Whole memory panel lost its physical rear casing"):return false
	var before:=JSON.stringify(campaign.progress)
	for tick in 40:await process_frame
	if not _check(cinema.players.size()==2 and cinema.panels.size()==2 and water.physical_basins.size()==2,"Whole footage or side reservoirs missing"):return false
	var samples:Array=[]
	for video in cinema.players:samples.append(video.stream_position)
	var elapsed:float=water.elapsed
	var monitor_time:float=architecture.monitor_elapsed
	var advanced_seconds:Array[float]=[0.0,0.0]
	var previous_positions:Array=samples.duplicate()
	# A fixed frame count at High on an iGPU can span an entire movie loop.
	# Accumulate observed forward decoder movement instead of comparing only
	# the two endpoints, which rejects a correctly looping movie after wrap.
	for tick in 45:
		await process_frame
		for i in 2:
			var position:float=cinema.players[i].stream_position
			advanced_seconds[i]+=maxf(0.0,position-float(previous_positions[i]))
			previous_positions[i]=position
	for i in 2:
		if not _check(cinema.players[i].is_playing() and advanced_seconds[i]>.05,"Whole memory footage did not advance: "+str(advanced_seconds)):return false
		if not _check(cinema.players[i].volume_db<= -80 and cinema.panels[i].visible,"Memory video added an audible source or disappeared"):return false
	if not _check(water.active and water.elapsed>elapsed and water.physical_basins[0].visible,"Physical coolant is not live in the actual lab"):return false
	if not _check(architecture.monitor_elapsed>monitor_time,"Local clinical instrument clock did not advance"):return false
	paused=true
	for tick in 3:await process_frame
	samples.clear()
	for video in cinema.players:samples.append(video.stream_position)
	elapsed=water.elapsed
	monitor_time=architecture.monitor_elapsed
	for tick in 25:await process_frame
	for i in 2:
		if not _check(absf(cinema.players[i].stream_position-samples[i])<.06,"Pause advanced memory footage"):return false
	if not _check(is_equal_approx(water.elapsed,elapsed),"Pause advanced the reflection/ripple clock"):return false
	if not _check(is_equal_approx(architecture.monitor_elapsed,monitor_time),"Pause advanced the clinical instrument clock"):return false
	# A real pause-menu quality choice must apply immediately without ticking
	# the room's pausable clocks or waiting for gameplay to resume.
	var paused_streams:Array=[]
	for video in cinema.players:paused_streams.append(video.stream)
	main.set_visual_quality("medium")
	for light in architecture.service_shadow_sources:
		if not _check(not light.shadow_enabled,"Paused Medium retained expensive service shadows"):return false
	for i in 2:
		if not _check(cinema.players[i].stream==paused_streams[i] and absf(cinema.players[i].stream_position-samples[i])<.06,"Paused quality choice restarted or sought the whole film"):return false
	main.set_visual_quality("high")
	for light in architecture.service_shadow_sources:
		if not _check(light.shadow_enabled==architecture.service_shadow_sources[light],"Paused High failed to restore the service budget"):return false
	main.set_reduced_motion(true)
	paused=false
	for tick in 5:await process_frame
	elapsed=water.elapsed
	monitor_time=architecture.monitor_elapsed
	for tick in 25:await process_frame
	for i in 2:
		if not _check(cinema.players[i].paused and cinema.panels[i].texture==cinema.posters[i],"Live Reduced Motion lost the intact static memory equivalent"):return false
	for panel in cinema.panels:
		if not _check(is_equal_approx(panel.pixel_size*panel.texture.get_width(),2.624),"Reduced Motion poster changed the physical screen span"):return false
	if not _check(float(water.coolant_material.get_shader_parameter("motion"))==0.0,"Reduced Motion did not freeze physical coolant"):return false
	if not _check(is_equal_approx(water.elapsed,elapsed) and float(water.material.get_shader_parameter("motion"))==0.0,"Reduced Motion did not freeze the local water clock"):return false
	if not _check(is_equal_approx(architecture.monitor_elapsed,monitor_time) and float(architecture.monitor_material.get_shader_parameter("motion"))==0.0,"Reduced Motion did not freeze clinical instrument animation"):return false
	main.set_visual_quality("low")
	for tick in 5:await process_frame
	if not _check(not finish.get_shader_parameter("has_normal_map") and finish.get_shader_parameter("normal_map")!=null,"Low tier lost the retained PBR normal source or kept its optional micro-normal sampling"):return false
	if not _check(not scanner_finish.get_shader_parameter("has_normal_map") and scanner_finish.get_shader_parameter("normal_map")!=null,"Low tier lost the scanner normal source or kept its optional sampling"):return false
	if not _check(architecture.service_shadow_sources.size()==6,"Measured clinical fill-light budget lost a service source"):return false
	for light in architecture.service_shadow_sources:
		if not _check(not light.shadow_enabled and light.light_energy>0,"Low tier retained a six-face service shadow or lost its fill"):return false
	if not _check(room._surgical_light.shadow_enabled,"Service budget removed the focal surgical shadow"):return false
	if not _check(water.reflection_view.size==Vector2i(320,400),"Low tier retained the high reflection target"):return false
	main.set_reduced_motion(false)
	main.set_visual_quality("high")
	for tick in 20:await process_frame
	if not _check(finish.get_shader_parameter("has_normal_map"),"High tier lost the recovered PBR micro-normal"):return false
	if not _check(scanner_finish.get_shader_parameter("has_normal_map"),"High tier failed to restore the scanner PBR normal"):return false
	for light in architecture.service_shadow_sources:
		if not _check(light.shadow_enabled==architecture.service_shadow_sources[light],"High tier failed to restore the authored service shadow"):return false
	for i in 2:
		if not _check(not cinema.players[i].paused and cinema.panels[i].texture!=cinema.posters[i],"Motion did not resume after live accessibility change"):return false
	if not _check(water.reflection_view.size==Vector2i(768,960),"High tier reflection target did not restore"):return false
	# Change live whole-film resolution at its natural loop boundary. No
	# fabricated seek,restart or changed screen size during active playback.
	for tier in ["low","high"]:
		main.set_visual_quality(tier)
		var desired:bool=tier=="high"
		var deadline:int=Time.get_ticks_msec()+14000
		while (cinema._loaded_high[0]!=desired or cinema._loaded_high[1]!=desired) and Time.get_ticks_msec()<deadline:
			await process_frame
		for i in 2:
			if not _check(cinema._loaded_high[i]==desired and cinema.players[i].is_playing(),"Whole movie did not adopt the quality choice at its loop end"):return false
			if not _check(is_equal_approx(cinema.panels[i].pixel_size*cinema.panels[i].texture.get_width(),2.624),"Live movie quality switch changed the physical screen width"):return false
	if not _check(before==JSON.stringify(campaign.progress) and campaign.kinja.contacts==0 and not room.wish_done,"Presentation mutated story/combat progression"):return false
	var report:={"checks":checks,"renderer":RenderingServer.get_current_rendering_method(),"scope":"Earned native lab: two advancing whole muted videos; pause; live Reduced Motion posters and frozen water; low/high reflection targets; no story mutations; scene unload. No full-route/performance/art acceptance."}
	# Inspect the actual GPU-skinned neck after the compressed source was
	# classified and stamped; this is not a detached lettering substitute.
	var rig:Skeleton3D=avatar.find_child("Skeleton3D",true,false)
	var profile:Dictionary=preload("res://scripts/player/echo_rig_profile.gd").identify(rig)
	var neck:int=rig.find_bone(skin_report.bone)
	var target:Vector3=rig.global_transform*rig.get_bone_global_pose(neck).origin
	var outward:Vector3=(rig.global_basis*(Basis(Vector3.UP,-deg_to_rad(skin_report.angle_degrees))*profile.local_forward)).normalized()
	var inspection:=Camera3D.new();inspection.near=.01;inspection.fov=40
	room.add_child(inspection);inspection.environment=player.player_camera.environment
	inspection.global_position=target+outward*.38
	inspection.look_at(target+Vector3(0,.025,0));inspection.make_current()
	main.hud.hide()
	for tick in 5:await process_frame
	await _capture("ex011-vram-decoded")
	report["skin_identifier"]=skin_report
	report["framebuffer"]=[root.size.x,root.size.y]
	report["source_hashes"]={}
	for path in ["res://tests/lab_presentation_lifecycle_review.gd","res://scripts/environment/clinical_lab_architecture.gd","res://scripts/environment/dr_kinja_lab_room.gd","res://shaders/clinical_stasis_display.gdshader","res://engine_visuals/HyperAnimeWorldManager.gd","res://scripts/player/echo_skin_identifier.gd","res://shaders/clinical_architecture_surface.gdshader","res://shaders/clinical_porcelain_floor.gdshader","res://assets/environments/lab_clinical_cp45/clinical_wall_p2_4k.glb","res://assets/environments/lab_clinical_cp45/clinical_service_frame_clean.glb","res://scripts/environment/clinical_modular_perimeter.gd","res://assets/environments/lab_clinical_cp45/clinical_scanner_p2_4k.glb","res://assets/characters/echo_v31_short_jacket.glb"]:
		report.source_hashes[path]=FileAccess.get_sha256(path)
	for path in ["res://scripts/environment/lab_memory_cinema.gd","res://scripts/environment/memory_reflection_space.gd","res://shaders/memory_water.gdshader","res://assets/cinematics/memory-screens/city-high.ogv","res://assets/cinematics/memory-screens/friends-high.ogv"]:
		report.source_hashes[path]=FileAccess.get_sha256(path)
	main.queue_free()
	for tick in 4:await process_frame
	if not _check(not is_instance_valid(cinema) and not is_instance_valid(water),"Room unload retained live video/reflection owners"):return false
	report["checks"]=checks
	var output:=FileAccess.open(folder+"presentation-review.json",FileAccess.WRITE)
	output.store_string(JSON.stringify(report,"\t"));output.close()
	print("LAB_PRESENTATION_LIFECYCLE ",JSON.stringify(report))
	return true

extends RefCounted

## Precision room reconstruction,with the Tripo design source preserved.
## The stretched whole-room runtime candidate failed native art review. Original solids,
## grip cues,hand contact,pressure task,door,motion and saved truth stay native.
const KIT=preload("res://scripts/environment/specimen_mechanical_dressing.gd")
const FINISH=preload("res://shaders/maintenance_surface_finish.gdshader")

static func install(room:Node3D)->void:
	if room.has_node("MaintenanceMechanicalDressing"):return
	var root:=Node3D.new();root.name="MaintenanceMechanicalDressing";room.add_child(root)
	# The whole-room generated candidate remains preserved as a design source.
	# Actual native art review rejected its stretched/soft hard-surface skins.
	# Production now builds precise solids from that composition and accepted
	# 4K facility modules,without loading the rejected1.55M runtime derivative.
	var spec:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/environments/maintenance_collision_v1.json"))
	var names:=["COLL_LeftBoundary","COLL_RightBoundary","COLL_FarBoundary","COLL_CLIMB_FirstWall","COLL_CLIMB_SecondWall","COLL_UpperRest","COLL_GapLanding","COLL_FinalRest","COLL_ExitDeck","COLL_ServiceVestibule","COLL_EntryFloor","COLL_ServiceSideReturn","COLL_ServiceSideReturn.001"]
	var minima:=PackedVector3Array();var maxima:=PackedVector3Array()
	for name in names:
		for row in spec.bodies:
			if row.name!=name:continue
			var p:=Vector3(row.position[0],row.position[1],row.position[2]);var size:=Vector3(row.size[0],row.size[1],row.size[2])
			minima.append(p-size*.5-Vector3.ONE*.002)
			var upper:Vector3=p+size*.5+Vector3.ONE*.002
			# The preserved authored platform skins sit6mm above their physics.
			# Clear that measured old finish,so it cannot cover the new grating.
			if name in ["COLL_UpperRest","COLL_GapLanding","COLL_FinalRest","COLL_ExitDeck","COLL_ServiceVestibule","COLL_EntryFloor"]:upper.y+=.008
			maxima.append(upper)
	while minima.size()<16:
		minima.append(Vector3.ONE*1000000);maxima.append(-Vector3.ONE*1000000)
	# The imported source joins multiple original bodies per material. Mask
	# only the replaced solid skins;all original luminous grip rows stay intact.
	for original in room.presentation._finishes:
		var material:ShaderMaterial=room.presentation._finishes[original]
		material.set_shader_parameter("visual_replacement_room_inverse",room.global_transform.affine_inverse())
		material.set_shader_parameter("replacement_count",names.size())
		material.set_shader_parameter("replacement_min",minima);material.set_shader_parameter("replacement_max",maxima)
		material.set_shader_parameter("source_saturation",.12)
		var label:String=original.resource_name.to_lower()
		if "void" in label:
			var local_min:PackedVector3Array=minima.duplicate();var local_max:PackedVector3Array=maxima.duplicate()
			# Exact connected-component bounds of the old opaque title cuboid.
			# Only its original void material opts in;moving gate seams stay live.
			local_min[13]=Vector3(-1.352,7.328,-12.872);local_max[13]=Vector3(1.352,9.632,-12.448)
			material.set_shader_parameter("replacement_min",local_min);material.set_shader_parameter("replacement_max",local_max);material.set_shader_parameter("replacement_count",14)
		if "graphite" in label:material.set_shader_parameter("tint",Color(.38,.40,.40))
		elif "ivory" in label:material.set_shader_parameter("tint",Color(.56,.57,.55))
	# Flat unobstructed contact insets cover the generated model's alternative
	# handle pattern. The existing source grip rows and11adapter cues remain
	# visible at exactly their original hand/foot/ledge coordinates.
	var contact:=KIT._finish(Color(.40,.43,.43),.22,.74)
	_plane(root,"NativeFirstGripContactInset",Vector3(0,1.7,-5.765),Vector2(4.22,3.06),contact)
	_plane(root,"NativeSecondGripContactInset",Vector3(4,4.4,-9.165),Vector2(1.68,1.73),contact)
	# Solid joint backing follows the existing opt-in exit aperture owner.
	# The generated fixed door/wheel were removed from this prefab.
	var backing:=ShaderMaterial.new();backing.shader=FINISH
	backing.set_shader_parameter("tint",Color(.28,.31,.31));backing.set_shader_parameter("metal",.24);backing.set_shader_parameter("base_roughness",.64)
	_plane(root,"NativeFarWallJointBacking",Vector3(.5,5.3,-14.61),Vector2(9.98,10.59),backing)
	room.presentation._boundary_finishes.append(backing)
	# Generated pressure-bay relief replaces the older floating patch panels.
	# Hide only decorative nodes;native contact,cue and state owners stay live.
	for visual in room.presentation.get_children():
		if String(visual.name).begins_with("ServicePanelInset") or String(visual.name).begins_with("PanelUpperFrame") or String(visual.name).begins_with("PanelLowerFrame") or visual.name in ["PressureBayIndicators","WallPressureLines"] or (visual is MeshInstance3D and absf(visual.position.x)>4.0):visual.visible=false
	_build_native_gratings(root,spec)
	_rebuild_clear_native_rear_bulkhead(room,root,spec)
	var portal_mesh:Mesh=_clad_service_portal(room,root,spec)
	_retire_covered_portal_backfaces.call_deferred(room,root,portal_mesh)
	_build_physical_task_projectors(root)
	_finish_service_equipment(room,root)
	room.presentation._pressure_caption.position=Vector3(0,7.72,-12.40)
	room.presentation._pressure_caption.font_size=26
	room.presentation._pressure_caption.pixel_size=.004
	room.presentation._pressure_caption.modulate=Color(.78,.79,.74)
	# Physical light sources stay at their authored positions. A restrained
	# warm-neutral task fill reveals the new metal instead of washing it blue.
	for light in room.find_children("*","OmniLight3D",true,false):
		light.light_color=Color(.96,.97,.94)
	preload("res://scripts/environment/maintenance_precision_architecture.gd").build(room,root,spec)
	root.set_meta("precision_architecture",true)
	root.set_meta("fullroom_source_candidate_status","REFERENCE_ONLY_NATIVE_ART_REFINE")
	root.set_meta("fullroom_source_triangles",1913491)
	root.set_meta("fullroom_native_triangles",0)
	root.set_meta("native_grip_cues_preserved",11)

static func _plane(root:Node3D,label:String,point:Vector3,size:Vector2,material:Material)->void:
	var visual:=MeshInstance3D.new();visual.name=label
	var mesh:=QuadMesh.new();mesh.size=size;visual.mesh=mesh;visual.position=point;visual.material_override=material
	visual.layers|=KIT.ENVIRONMENT_LAYER;root.add_child(visual)

static func _box(root:Node3D,label:String,point:Vector3,size:Vector3,material:Material)->MeshInstance3D:
	var visual:=MeshInstance3D.new();visual.name=label;visual.set_meta("design_label",label)
	var mesh:=BoxMesh.new();mesh.size=size;visual.mesh=mesh;visual.position=point;visual.material_override=material
	visual.layers|=KIT.ENVIRONMENT_LAYER;root.add_child(visual);return visual

static func _build_native_gratings(root:Node3D,spec:Dictionary)->void:
	# An unbroken structural support remains native. Small machined bars are
	# fitted below its top contact plane,with no visual bridge across the gap.
	var metal:=KIT._finish(Color(.34,.36,.35),.34,.62)
	var backing:=KIT._finish(Color(.11,.12,.12),.18,.73)
	var mesh:=BoxMesh.new();mesh.size=Vector3(.016,.016,1)
	for row in spec.bodies:
		if row.name not in ["COLL_UpperRest","COLL_GapLanding","COLL_FinalRest","COLL_ExitDeck","COLL_ServiceVestibule"]:continue
		var p:=Vector3(row.position[0],row.position[1],row.position[2]);var size:=Vector3(row.size[0],row.size[1],row.size[2]);var top:float=p.y+size.y*.5
		var prefab_candidate:Node3D=root.get_node_or_null("MeasuredFullPressureBay")
		if prefab_candidate!=null:prefab_candidate.find_child("MeasuredGrating_"+row.name,true,false).visible=false
		_box(root,"MeasuredDeckBacking_"+row.name,Vector3(p.x,top-.045,p.z),Vector3(size.x-.018,.018,size.z-.018),backing)
		var placements:Array[Transform3D]=[]
		var frame_height:float=size.y-.055
		for x in [-size.x*.5+.026,size.x*.5-.026]:_box(root,"DeckStructuralSideFascia_"+row.name,Vector3(p.x+x,p.y-.008,p.z),Vector3(.048,frame_height,size.z-.008),metal)
		for z in [-size.z*.5+.026,size.z*.5-.026]:_box(root,"DeckStructuralEndFascia_"+row.name,Vector3(p.x,p.y-.008,p.z+z),Vector3(size.x-.008,frame_height,.048),metal)
		var first_x:float=ceil((p.x-size.x*.5+.04)/.045)*.045
		var count:=int(floor((p.x+size.x*.5-.04-first_x)/.045))+1
		for i in count:
			var x:float=first_x+i*.045
			placements.append(Transform3D(Basis.from_scale(Vector3(1,1,size.z-.075)),Vector3(x,top-.007,p.z)))
		var draw:=KIT._batch(root,"MeasuredDeckGrating_"+row.name,mesh,placements);draw.material_override=metal
		for z in [-size.z*.5+.025,size.z*.5-.025]:_box(root,"DeckEndFrame_"+row.name,Vector3(p.x,top-.012,p.z+z),Vector3(size.x-.02,.026,.035),metal)
		for x in [-size.x*.5+.025,size.x*.5-.025]:_box(root,"DeckSideFrame_"+row.name,Vector3(p.x+x,top-.012,p.z),Vector3(.035,.026,size.z-.02),metal)
		var first_z:float=ceil((p.z-size.z*.5+.05)/.45)*.45
		for index in maxi(0,int(floor((p.z+size.z*.5-.05-first_z)/.45))+1):
			_box(root,"GratingCrossTie_"+row.name,Vector3(p.x,top-.008,first_z+index*.45),Vector3(size.x-.04,.018,.018),metal)

static func _finish_service_equipment(room:Node3D,root:Node3D)->void:
	var alloy:=KIT._finish(Color(.32,.34,.33),.34,.59)
	var graphite:=KIT._finish(Color(.13,.145,.15),.25,.66)
	var copper:=KIT._finish(Color(.44,.29,.15),.38,.58)
	_box(root,"FlushPressureCaptionPlaque",Vector3(0,7.72,-12.43),Vector3(2.3,.32,.035),graphite)
	_box(root,"FixedPressureCaptionMachinedHeader",Vector3(0,7.71,-12.63),Vector3(2.22,.34,.30),alloy)
	for name in ["PressureHousing","PressureFace"]:
		var item:MeshInstance3D=room.presentation.get_node(name)
		item.material_override=alloy if name=="PressureHousing" else graphite
	room.presentation.get_node("PressureFace").visible=false
	var face:=MeshInstance3D.new();face.name="PressureDialFace"
	var disk:=CylinderMesh.new();disk.top_radius=.205;disk.bottom_radius=.205;disk.height=.012;disk.radial_segments=64
	face.mesh=disk;face.rotation_degrees.x=90;face.position=Vector3(1.88,6.95,-12.46);face.material_override=graphite;root.add_child(face)
	var ring:=MeshInstance3D.new();ring.name="PressureDialMachinedRim"
	var torus:=TorusMesh.new();torus.inner_radius=.198;torus.outer_radius=.222;torus.rings=64;torus.ring_segments=16
	ring.mesh=torus;ring.rotation_degrees.x=90;ring.position=Vector3(1.88,6.95,-12.445);ring.material_override=alloy;root.add_child(ring)
	var ticks:=KIT._finish(Color(.63,.66,.60),.15,.63)
	for i in 11:
		var angle:float=-2.4+i*.48
		var tick:=_box(root,"DialPressureTick",Vector3(1.88+sin(angle)*.164,6.95+cos(angle)*.164,-12.437),Vector3(.008,.028,.006),ticks);tick.rotation.z=-angle
	room.presentation._gauge_needle.position.z=-12.421
	# These fasteners are children of the original moving gate root.
	for x in [-.78,.78]:
		for y in [.18,.96,1.74]:_box(room._gate,"GatePanelCaptiveFastener",Vector3(x,y,.092),Vector3(.034,.034,.018),copper)
	for y in [.15,.96,1.77]:_box(room._gate,"GatePanelRecessedSeam",Vector3(0,y,.087),Vector3(1.49,.008,.006),graphite)

static func _clad_service_portal(room:Node3D,root:Node3D,spec:Dictionary)->Mesh:
	var source=preload("res://assets/environments/lab_clinical_cp45/clinical_wall_p2_4k.glb")
	var mesh:Mesh=preload("res://scripts/environment/archive_mechanical_dressing.gd")._pbr_mesh(source,room)
	for surface in mesh.get_surface_count():
		var finish:ShaderMaterial=mesh.surface_get_material(surface)
		finish.set_shader_parameter("base_color",Color(.52,.53,.50))
		finish.set_shader_parameter("texture_saturation",.15)
		finish.set_shader_parameter("metalness",.18)
		finish.set_shader_parameter("minimum_roughness",.62)
	var placements:Array[Transform3D]=[]
	var steel:=KIT._finish(Color(.26,.275,.26),.25,.63)
	for row in spec.bodies:
		if not String(row.name).begins_with("COLL_ServiceSideReturn"):continue
		var p:=Vector3(row.position[0],row.position[1],row.position[2]);var size:=Vector3(row.size[0],row.size[1],row.size[2])
		_box(root,"ServiceReturnStructuralBacking",p-Vector3(0,0,.08),size-Vector3(.008,.008,.16),steel)
		var placement:=Transform3D(Basis.from_scale(Vector3(size.x/3,size.y/3,.8)),Vector3(p.x,p.y-size.y*.5,p.z+size.z*.5-.08))
		assert(AABB(p-size*.5,size).grow(.002).encloses(placement*mesh.get_aabb()),"Service return skin escaped original solid")
		placements.append(placement)
	var draw:=KIT._batch(root,"MeasuredNativeServiceReturnPanels",mesh,placements)
	draw.set_meta("native_solid_skin_only",true)
	return mesh

static func _retire_covered_portal_backfaces(room:Node3D,root:Node3D,mesh:Mesh)->void:
	if not is_instance_valid(room):return
	var owner:Node=room.get_parent().get_node_or_null("NativeJourneyController")
	if owner==null or not is_instance_valid(owner.security):return
	var placements:Array[Transform3D]=[]
	var native_volumes:=[]
	for body in owner.security.get_children():
		if not body is StaticBody3D:continue
		var box:BoxShape3D
		for collision in body.get_children():
			if collision is CollisionShape3D and collision.shape is BoxShape3D:box=collision.shape
		if box==null:continue
		var portal:bool=is_equal_approx(body.position.z,0) and (box.size.is_equal_approx(Vector3(3.6,4.4,.4)) or box.size.is_equal_approx(Vector3(1.8,1.2,.4)))
		var ceiling_end:bool=is_equal_approx(body.position.y,4.8) and box.size.is_equal_approx(Vector3(8.8,.4,18.4))
		if not portal and not ceiling_end:continue
		var point:Vector3=room.to_local(body.global_position)
		var native:=AABB(point-box.size*.5,box.size);native_volumes.append(native)
		var rows:int=2 if box.size.y>3 else 1
		var height:float=box.size.y/rows
		for row in rows:
			var placement:=Transform3D(Basis.from_scale(Vector3(box.size.x/3,height/3,.8)),Vector3(point.x,point.y-box.size.y*.5+row*height,point.z+box.size.z*.5-.079))
			assert(native.grow(.002).encloses(placement*mesh.get_aabb()),"Portal skin crossed actual existing solid")
			placements.append(placement)
		for visual in body.get_children():
			if not visual is MeshInstance3D:continue
			var original:Material=visual.get_active_material(0)
			if original is ShaderMaterial and original.shader.resource_path=="res://shaders/clinical_architecture_surface.gdshader":
				var finish:ShaderMaterial=original.duplicate()
				finish.shader=preload("res://shaders/maintenance_portal_backface.gdshader")
				finish.set_shader_parameter("service_skin_origin",body.to_global(Vector3(0,0,box.size.z*.5)))
				finish.set_shader_parameter("service_skin_outward",body.global_basis*Vector3.BACK)
				visual.material_override=finish
	if not placements.is_empty():
		var draw:=KIT._batch(root,"MeasuredActualSecurityPortalBackSkins",mesh,placements)
		draw.set_meta("native_portal_volumes",native_volumes)

static func _build_physical_task_projectors(root:Node3D)->void:
	var casing:=KIT._finish(Color(.22,.235,.22),.33,.63)
	var lens:=StandardMaterial3D.new();lens.albedo_color=Color(.82,.74,.59);lens.emission_enabled=true;lens.emission=Color(1,.86,.66);lens.emission_energy_multiplier=.65
	for point in [Vector3(-2.8,8.9,-4.4),Vector3(3.9,9.0,-9.8),Vector3(.4,9.9,-12.0)]:
		_box(root,"PressureBayTaskProjectorHousing",point,Vector3(.68,.16,.28),casing)
		_box(root,"PressureBayTaskProjectorLens",point+Vector3(0,-.085,0),Vector3(.57,.012,.19),lens)
		var light:=SpotLight3D.new();light.name="PressureBayWarmTaskProjector"
		light.position=point+Vector3(0,-.11,0);light.rotation_degrees.x=-90
		light.light_color=Color(1,.92,.80);light.light_energy=4.2;light.spot_range=13;light.spot_angle=64;light.spot_attenuation=.7
		light.shadow_enabled=true;light.shadow_bias=.04;root.add_child(light)

static func _rebuild_clear_native_rear_bulkhead(room:Node3D,root:Node3D,spec:Dictionary)->void:
	# The generated rear retains part of a fixed sign above its removed door.
	# Replace that entire ambiguous skin with fitted facility panels. The
	# preserved source master stays intact;the native aperture owner stays live.
	var prefab_candidate:Node3D=root.get_node_or_null("MeasuredFullPressureBay")
	if prefab_candidate!=null:prefab_candidate.find_child("MeasuredRearServiceBulkhead",true,false).visible=false
	var source=preload("res://assets/environments/lab_clinical_cp45/clinical_wall_p2_4k.glb")
	var mesh:Mesh=preload("res://scripts/environment/archive_mechanical_dressing.gd")._pbr_mesh(source,room)
	for surface in mesh.get_surface_count():
		var finish:ShaderMaterial=mesh.surface_get_material(surface)
		finish.shader=preload("res://shaders/maintenance_architecture_aperture.gdshader")
		finish.set_shader_parameter("base_color",Color(.48,.49,.46));finish.set_shader_parameter("texture_saturation",.18)
		finish.set_shader_parameter("metalness",.20);finish.set_shader_parameter("minimum_roughness",.61)
		room.presentation._boundary_finishes.append(finish)
	var row:Dictionary
	for candidate in spec.bodies:
		if candidate.name=="COLL_FarBoundary":row=candidate
	var point:=Vector3(row.position[0],row.position[1],row.position[2]);var size:=Vector3(row.size[0],row.size[1],row.size[2]);var native:=AABB(point-size*.5,size)
	var placements:Array[Transform3D]=[]
	for column in 4:
		for tier in 4:
			var placement:=Transform3D(Basis.from_scale(Vector3(size.x/12,size.y/12,.95)),Vector3(point.x-size.x*.5+(column+.5)*size.x/4,point.y-size.y*.5+tier*size.y/4,point.z+.1))
			assert(native.grow(.002).encloses(placement*mesh.get_aabb()),"Rear skin crossed native solid")
			placements.append(placement)
	var draw:=KIT._batch(root,"MeasuredRearBulkheadWithNativeAperture",mesh,placements);draw.set_meta("native_solid_volume",native)

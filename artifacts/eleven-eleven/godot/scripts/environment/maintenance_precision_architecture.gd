extends RefCounted

## Precision reconstruction after the generated full-room native art REFINE.
## It preserves all source assets and uses their design,not their warped skins.
const KIT=preload("res://scripts/environment/specimen_mechanical_dressing.gd")
const PBR=preload("res://scripts/environment/archive_mechanical_dressing.gd")
const WALL=preload("res://assets/environments/lab_clinical_cp45/clinical_wall_p2_4k.glb")
const TRIM=preload("res://assets/environments/specimen_cp45/specimen_trim_unit.glb")

static func build(room:Node3D,root:Node3D,spec:Dictionary)->void:
	var steel:=KIT._finish(Color(.30,.325,.315),.35,.60)
	var edge:=KIT._finish(Color(.42,.445,.42),.42,.54)
	var dark:=KIT._finish(Color(.17,.19,.185),.24,.65)
	var trim:Mesh=KIT._mesh(TRIM)
	_walls(room,root)
	_climb_cases(root,spec,trim,steel,edge,edge)
	preload("res://scripts/environment/maintenance_primary_cassette.gd").build(room,root)
	_entry_floor(root,spec,trim,dark)
	_service_seal(room,root,trim,steel,edge)
	_overhead(root,trim,KIT._finish(Color(.30,.32,.31),.25,.65))
	_climb_wall_attachments(room,root,trim,steel)
	_bearing_and_fixture_mounts(room,root,trim,steel,edge)
	_entry_bulkhead_skins.call_deferred(room,root)
	_closed_service_ceiling(root,trim)
	_nonwalkable_shaft(room,root)
	_reveal_existing_structural_depth(root)
	_interior_reflection(root)
	var ventilation:=preload("res://scripts/environment/maintenance_ventilation_fan.gd").new()
	ventilation.name="MeasuredVentilationFan";ventilation.room=room;root.add_child(ventilation)
	var shadows:=preload("res://scripts/environment/maintenance_soft_shadow_lease.gd").new();shadows.name="NativeMaintenanceSoftShadowLease";shadows.room=room;root.add_child(shadows)

static func _walls(room:Node3D,root:Node3D)->void:
	var mesh:Mesh=PBR._pbr_mesh(WALL,room)
	for surface in mesh.get_surface_count():
		var finish:ShaderMaterial=mesh.surface_get_material(surface)
		finish.set_shader_parameter("base_color",Color(.56,.58,.55))
		finish.set_shader_parameter("texture_saturation",.20)
		finish.set_shader_parameter("metalness",.18)
		finish.set_shader_parameter("minimum_roughness",.59)
	var backing:=BoxMesh.new();backing.size=Vector3.ONE;backing.material=KIT._finish(Color(.15,.17,.16),.15,.7)
	var backs:Array[Transform3D]=[]
	for name in ["COLL_LeftBoundary","COLL_RightBoundary"]:
		var body:Node3D=room.get_node(name);var size:Vector3=body.get_child(0).shape.size
		var native:=AABB(body.position-size*.5,size);var left:bool=name=="COLL_LeftBoundary"
		var normal:=Vector3.RIGHT if left else Vector3.LEFT
		var rotation:=Basis(Vector3.UP,PI*.5 if left else -PI*.5)
		var columns:int=ceili(size.z/3);var rows:int=ceili(size.y/3)
		var span:float=size.z/columns;var height:float=size.y/rows
		var placements:Array[Transform3D]=[]
		for column in columns:
			for row in rows:
				var point:Vector3=body.position+normal*.05+rotation.x*(-size.z*.5+(column+.5)*span)
				point.y=body.position.y-size.y*.5+row*height+.006
				var placement:=Transform3D(rotation*Basis.from_scale(Vector3((span-.012)/3,(height-.012)/3,.90)),point)
				assert(native.grow(.001).encloses(placement*mesh.get_aabb()),"Precision wall crossed original solid")
				placements.append(placement)
		var draw:=KIT._batch(root,"MeasuredMaintenanceWall_"+name,mesh,placements);draw.set_meta("native_wall_volume",native)
		backs.append(KIT._sized(body.position-normal*.10,Vector3(.012,size.y-.004,size.z-.004)))
		_pressure_pipes(root,body,normal,native)
	KIT._batch(root,"ContinuousPrecisionWallJointBackings",backing,backs)

static func _pressure_pipes(root:Node3D,body:Node3D,normal:Vector3,native:AABB)->void:
	var pipe:=CylinderMesh.new();pipe.top_radius=.032;pipe.bottom_radius=.032;pipe.height=1;pipe.radial_segments=32
	var clamp:=CylinderMesh.new();clamp.top_radius=.043;clamp.bottom_radius=.043;clamp.height=.065;clamp.radial_segments=32
	var pipes:Array[Transform3D]=[];var clamps:Array[Transform3D]=[]
	var x:float=body.position.x+normal.x*(native.size.x*.5-.045)
	for z in [-2.9,-7.4,-11.9]:
		pipes.append(Transform3D(Basis.from_scale(Vector3(1,8.8,1)),Vector3(x,4.9,z)))
		for y in [1.5,3.8,6.1,8.4]:clamps.append(Transform3D(Basis.IDENTITY,Vector3(x,y,z)))
	var draw:=KIT._batch(root,"PrecisionCopperPressureLines_"+str(body.name),pipe,pipes);draw.material_override=KIT._finish(Color(.38,.245,.12),.42,.58);draw.set_meta("native_wall_volume",native)
	draw=KIT._batch(root,"PrecisionMachinedPipeCollars_"+str(body.name),clamp,clamps);draw.material_override=KIT._finish(Color(.22,.245,.23),.5,.55);draw.set_meta("native_wall_volume",native)

static func _climb_cases(root:Node3D,spec:Dictionary,trim:Mesh,steel:Material,edge:Material,copper:Material)->void:
	var mesh:Mesh=trim.duplicate();for surface in mesh.get_surface_count():mesh.surface_set_material(surface,steel)
	var frame:Mesh=trim.duplicate();for surface in frame.get_surface_count():frame.surface_set_material(surface,edge)
	var bolt:Mesh=trim.duplicate();for surface in bolt.get_surface_count():bolt.surface_set_material(surface,copper)
	for row in spec.bodies:
		if not String(row.name).begins_with("COLL_CLIMB_"):continue
		# The complete first casing now comes from its measured four-view
		# Tripo source. Keep the smaller second casing and every native cue.
		if row.name=="COLL_CLIMB_FirstWall":continue
		var p:=Vector3(row.position[0],row.position[1],row.position[2]);var size:=Vector3(row.size[0],row.size[1],row.size[2]);var native:=AABB(p-size*.5,size)
		var draw:=KIT._batch(root,"PrecisionClosedClimbCase_"+row.name,mesh,[KIT._sized(p,size-Vector3(.016,.012,.05))]);draw.set_meta("native_climb_volume",native)
		var placements:Array[Transform3D]=[];var screws:Array[Transform3D]=[]
		var z:float=p.z+size.z*.5-.023
		for x in [-size.x*.5+.05,size.x*.5-.05]:placements.append(KIT._sized(Vector3(p.x+x,p.y,z),Vector3(.075,size.y-.04,.036)))
		for y in [-size.y*.5+.05,size.y*.5-.05]:placements.append(KIT._sized(Vector3(p.x,p.y+y,z),Vector3(size.x-.04,.075,.036)))
		for x in [-size.x*.5+.14,size.x*.5-.14]:
			for y in [-size.y*.5+.18,0,size.y*.5-.18]:screws.append(KIT._sized(Vector3(p.x+x,p.y+y,z),Vector3(.035,.035,.027)))
		draw=KIT._batch(root,"PrecisionClimbFrame_"+row.name,frame,placements);draw.set_meta("native_climb_volume",native)
		draw=KIT._batch(root,"PrecisionCaptiveClimbFasteners_"+row.name,bolt,screws);draw.set_meta("native_climb_volume",native)

static func _entry_floor(root:Node3D,spec:Dictionary,trim:Mesh,material:Material)->void:
	var row:Dictionary
	for candidate in spec.bodies:
		if candidate.name=="COLL_EntryFloor":row=candidate
	var p:=Vector3(row.position[0],row.position[1],row.position[2]);var size:=Vector3(row.size[0],row.size[1],row.size[2]);var native:=AABB(p-size*.5,size)
	var mesh:Mesh=trim.duplicate();for surface in mesh.get_surface_count():mesh.surface_set_material(surface,material)
	var placements:Array[Transform3D]=[]
	for x in 4:
		for z in 4:placements.append(KIT._sized(Vector3(p.x-size.x*.5+(x+.5)*size.x/4,p.y,p.z-size.z*.5+(z+.5)*size.z/4),Vector3(size.x/4-.012,size.y-.002,size.z/4-.012)))
	var draw:=KIT._batch(root,"PrecisionEntryFloorPanels",mesh,placements);draw.set_meta("native_floor_volume",native)

static func _service_seal(room:Node3D,root:Node3D,trim:Mesh,steel:Material,edge:Material)->void:
	var mesh:Mesh=trim.duplicate();for surface in mesh.get_surface_count():mesh.surface_set_material(surface,steel)
	# Each old side gap is.625m;the native capsule is.8m wide. These fixed
	# gasket adapters seal that already non-traversable clearance without a
	# new collider or any change to the1.75m moving door/control/socket.
	var placements:Array[Transform3D]=[]
	for x in [-1.20,1.20]:placements.append(KIT._sized(Vector3(x,6.4,-12.79),Vector3(.62,2.2,.56)))
	placements.append(KIT._sized(Vector3(0,7.69,-12.74),Vector3(3.02,.36,.46)))
	placements.append(KIT._sized(Vector3(0,7.415,-12.79),Vector3(1.79,.21,.56)))
	var draw:=KIT._batch(root,"PrecisionFixedDoorGasketAdapters",mesh,placements);draw.set_meta("old_side_gap_width",.625)
	var signal_material:=StandardMaterial3D.new();signal_material.albedo_color=Color(.1,.35,.38);signal_material.emission_enabled=true;signal_material.emission=Color(.10,.58,.66);signal_material.emission_energy_multiplier=.4
	var amber:=StandardMaterial3D.new();amber.albedo_color=Color(.70,.42,.12);amber.emission_enabled=true;amber.emission=Color(.9,.52,.13);amber.emission_energy_multiplier=.3
	_box(root,"NativeDoorHeaderWarningFace",Vector3(0,7.34,-12.495),Vector3(.36,.05,.012),amber)
	# This closed transom stays inside the original opaque title-block volume.
	# Its small return-air baffle replaces the upper slot without changing any
	# collider or the original moving gate/hand/control ownership.
	var transom:Mesh=trim.duplicate();for surface in transom.get_surface_count():transom.surface_set_material(surface,steel)
	var transom_draw:=KIT._batch(root,"PrecisionClosedUpperTransom",transom,[KIT._sized(Vector3(0,8.24,-12.77),Vector3(1.79,.72,.16))])
	transom_draw.set_meta("original_visual_header_volume",AABB(Vector3(-1.35,7.33,-12.87),Vector3(2.7,2.3,.42)))
	var fins:Mesh=trim.duplicate();for surface in fins.get_surface_count():fins.surface_set_material(surface,edge)
	var ribs:Array[Transform3D]=[]
	for row in 8:ribs.append(KIT._sized(Vector3(0,7.99+row*.07,-12.675),Vector3(1.50,.025,.035)))
	var ribs_draw:=KIT._batch(root,"PrecisionUpperTransomBaffleFins",fins,ribs);ribs_draw.set_meta("original_visual_header_volume",transom_draw.get_meta("original_visual_header_volume"))
	for x in [-.9,.9]:_box(root,"PrecisionDoorJambSignal",Vector3(x,6.36,-12.495),Vector3(.016,1.84,.012),signal_material)
	for x in [-.18,.18]:
		for y in [.25,1.75]:_box(room._gate,"NativeDoorStiffenerCaptiveEnd",Vector3(x,y,.094),Vector3(.035,.045,.022),edge)

static func _overhead(root:Node3D,trim:Mesh,material:Material)->void:
	var mesh:Mesh=trim.duplicate();for surface in mesh.get_surface_count():mesh.surface_set_material(surface,material)
	var placements:Array[Transform3D]=[]
	for z in [-2.5,-6.5,-10.5]:
		for y in [9.78,10.32]:placements.append(KIT._sized(Vector3(.5,y,z),Vector3(9.32,.12,.20)))
		for i in 5:
			var a:=Vector3(-4.1+i*1.84,9.84 if i%2==0 else 10.26,z);var b:=Vector3(a.x+1.84,10.26 if i%2==0 else 9.84,z);var direction:Vector3=b-a
			placements.append(Transform3D(Basis.looking_at(direction.normalized(),Vector3.UP)*Basis.from_scale(Vector3(.055,.065,direction.length())),(a+b)*.5))
	KIT._batch(root,"PrecisionUpperServiceTrusses",mesh,placements)

static func _box(root:Node3D,label:String,point:Vector3,size:Vector3,material:Material)->void:
	var mesh:=BoxMesh.new();mesh.size=size;var visual:=MeshInstance3D.new();visual.name=label;visual.mesh=mesh;visual.material_override=material;visual.position=point;visual.layers|=KIT.ENVIRONMENT_LAYER;root.add_child(visual)

static func _reveal_existing_structural_depth(root:Node3D)->void:
	# Static reflected-light approximations reveal actual trusses,wall bases
	# and the existing entry floor. The authored fall void gains no fake floor.
	for spec in [[Vector3(.5,8.7,-6),Color(.74,.81,.84),.48,15.0],[Vector3(.5,1.4,-5),Color(.53,.65,.68),.34,13.0],[Vector3(.5,.7,-10.5),Color(.50,.57,.61),.55,11.0]]:
		var light:=OmniLight3D.new();light.name="PrecisionStructuralBounce"
		light.position=spec[0];light.light_color=spec[1];light.light_energy=spec[2];light.omni_range=spec[3]
		light.light_cull_mask=KIT.ENVIRONMENT_LAYER;light.shadow_enabled=false;root.add_child(light)

static func _climb_wall_attachments(room:Node3D,root:Node3D,trim:Mesh,material:Material)->void:
	var wall:StaticBody3D=room.get_node("COLL_RightBoundary")
	var climb:StaticBody3D=room.get_node("COLL_CLIMB_SecondWall")
	var wall_size:Vector3=wall.get_child(0).shape.size
	var climb_size:Vector3=climb.get_child(0).shape.size
	var inner_wall:float=wall.position.x-wall_size.x*.5
	var case_edge:float=climb.position.x+climb_size.x*.5
	var gap:float=inner_wall-case_edge
	# This existing .20m side clearance cannot fit the native .80m capsule.
	# Wall cleats close that visual mounting gap without a new walk surface.
	assert(gap>0 and gap<.3)
	var mesh:Mesh=trim.duplicate()
	for surface in mesh.get_surface_count():mesh.surface_set_material(surface,material)
	var placements:Array[Transform3D]=[]
	for y in [-.68,.68]:
		placements.append(KIT._sized(Vector3((case_edge+inner_wall)*.5,climb.position.y+y,climb.position.z),Vector3(gap+.04,.14,.36)))
	placements.append(KIT._sized(Vector3(inner_wall+.008,climb.position.y,climb.position.z),Vector3(.055,1.8,.48)))
	var draw:=KIT._batch(root,"SecondClimbNativeWallCleats",mesh,placements)
	draw.set_meta("untraversable_native_clearance",gap)
	draw.set_meta("clearance_attachment_volume",AABB(Vector3(case_edge-.022,climb.position.y-.92,climb.position.z-.25),Vector3(gap+.062,1.84,.50)))

static func _bearing_and_fixture_mounts(room:Node3D,root:Node3D,trim:Mesh,steel:Material,edge:Material)->void:
	var mesh:Mesh=trim.duplicate()
	for surface in mesh.get_surface_count():mesh.surface_set_material(surface,steel)
	var climb:StaticBody3D=room.get_node("COLL_CLIMB_SecondWall")
	var size:Vector3=climb.get_child(0).shape.size
	var native:=AABB(climb.position-size*.5,size)
	var side:Array[Transform3D]=[]
	# Folded side webs sit inside the existing case. The visible end now
	# reads as a load-bearing cassette rather than an unsupported thin sheet.
	for z in [-.205,.205]:side.append(KIT._sized(Vector3(native.position.x+.016,climb.position.y,climb.position.z+z),Vector3(.026,size.y-.10,.065)))
	for y in [-.90,.90]:side.append(KIT._sized(Vector3(native.position.x+.016,climb.position.y+y,climb.position.z),Vector3(.026,.11,size.z-.035)))
	var draw:=KIT._batch(root,"SecondClimbFoldedSideWebs",mesh,side);draw.set_meta("native_climb_volume",native)
	# This bearing beam spans the same solid plus the already untraversable
	# .20m wall clearance. Its front/top never protrude into the approach.
	var wall:StaticBody3D=room.get_node("COLL_RightBoundary")
	var wall_size:Vector3=wall.get_child(0).shape.size
	var end_x:float=wall.position.x-wall_size.x*.5+.012
	var beam_box:=AABB(Vector3(native.position.x+.002,native.position.y+.006,native.position.z+.025),Vector3(end_x-native.position.x-.002,.14,size.z-.05))
	draw=KIT._batch(root,"SecondClimbContinuousBearingBeam",mesh,[KIT._sized(beam_box.get_center(),beam_box.size)])
	draw.set_meta("bearing_native_and_untraversable_volume",beam_box)
	draw.set_meta("source_climb_volume",native)
	var bolt:=CylinderMesh.new();bolt.top_radius=.026;bolt.bottom_radius=.026;bolt.height=.010;bolt.radial_segments=24;bolt.material=edge
	var screws:Array[Transform3D]=[]
	for y in [-.82,0,.82]:
		for z in [-.15,.15]:screws.append(Transform3D(Basis(Vector3.FORWARD,PI*.5),Vector3(native.position.x+.006,climb.position.y+y,climb.position.z+z)))
	draw=KIT._batch(root,"SecondClimbSideCaptiveBolts",bolt,screws);draw.set_meta("native_climb_volume",native)
	var hangers:Array[Transform3D]=[]
	for p in [Vector3(-2.8,8.9,-4.4),Vector3(3.9,9.0,-9.8),Vector3(.4,9.9,-12.0)]:
		var bottom:float=p.y+.07;var top:=10.51
		hangers.append(KIT._sized(Vector3(p.x,(bottom+top)*.5,p.z),Vector3(.065,top-bottom,.065)))
		hangers.append(KIT._sized(Vector3(p.x,10.49,p.z),Vector3(.20,.035,.20)))
	draw=KIT._batch(root,"CeilingTaskFixtureSuspension",mesh,hangers)
	draw.set_meta("unreachable_fixture_min_y",8.96)

static func _entry_bulkhead_skins(room:Node3D,root:Node3D)->void:
	if not is_instance_valid(room):return
	var shell:Node=room.get_parent().get_node_or_null("Sector11OpeningShell")
	if shell==null:return # Isolated room has no adjacent-owner architecture.
	var mesh:Mesh=PBR._pbr_mesh(WALL,room)
	for surface in mesh.get_surface_count():
		var material:ShaderMaterial=mesh.surface_get_material(surface)
		material.set_shader_parameter("base_color",Color(.47,.50,.48))
		material.set_shader_parameter("texture_saturation",.16)
		material.set_shader_parameter("minimum_roughness",.50)
	var source_box:AABB=mesh.get_aabb()
	for label in ["Gate1_Bulkhead_West_Body","Gate1_Bulkhead_East_Body","Gate1_Bulkhead_Lintel_Body"]:
		var body:StaticBody3D=shell.get_node_or_null(label)
		if body==null:continue
		var shape:BoxShape3D=body.get_node("CollisionShape3D").shape if body.has_node("CollisionShape3D") else null
		if shape==null:
			for child in body.get_children():
				if child is CollisionShape3D and child.shape is BoxShape3D:shape=child.shape
		assert(shape!=null,"Entry skin requires its actual existing solid")
		var point:Vector3=room.to_local(body.global_position)
		var native:=AABB(point-shape.size*.5,shape.size)
		var backing:MeshInstance3D=body.get_node_or_null("Surface") as MeshInstance3D
		if backing!=null and not backing.has_meta("maintenance_back_recess"):
			# Relief needs space in front of the retained backing. Preserve the
			# opening-facing front plane and every collider;recess only this
			# maintenance-facing end of these three existing visual solids.
			var before:AABB=backing.transform*backing.mesh.get_aabb()
			assert(before.size.z>.14)
			backing.set_meta("maintenance_original_surface_transform",backing.transform)
			backing.set_meta("maintenance_original_surface_mesh",backing.mesh)
			backing.mesh=backing.mesh.duplicate()
			backing.scale.z*=(before.size.z-.14)/before.size.z
			var after:AABB=backing.transform*backing.mesh.get_aabb()
			backing.position.z+=before.end.z-after.end.z
			backing.set_meta("maintenance_back_recess",.14)
		var columns:int=ceili(shape.size.x/3);var rows:int=ceili(shape.size.y/3)
		var width:float=shape.size.x/columns;var height:float=shape.size.y/rows
		var placements:Array[Transform3D]=[]
		for x in columns:
			for y in rows:
				var target_size:=Vector3(width-.012,height-.012,.12)
				var basis:=Basis(Vector3.UP,PI)*Basis.from_scale(target_size/source_box.size)
				var center:=Vector3(native.position.x+(x+.5)*width,native.position.y+(y+.5)*height,native.position.z+.059)
				var placement:=Transform3D(basis,center-basis*source_box.get_center())
				assert(native.grow(.002).encloses(placement*source_box),"Entry cladding escaped the unchanged solid")
				placements.append(placement)
		var draw:=KIT._batch(root,"MeasuredEntryBulkhead_"+label,mesh,placements)
		draw.set_meta("native_wall_volume",native)
		draw.set_meta("adjacent_source_body",str(body.get_path()))

static func _closed_service_ceiling(root:Node3D,trim:Mesh)->void:
	var mesh:Mesh=trim.duplicate()
	for surface in mesh.get_surface_count():mesh.surface_set_material(surface,KIT._finish(Color(.30,.335,.33),.38,.50))
	var placements:Array[Transform3D]=[]
	for x in 3:
		for z in 5:
			placements.append(KIT._sized(Vector3(-4.2+(x+.5)*9.4/3,10.55,-14.3+(z+.5)*14.6/5),Vector3(9.4/3-.014,.08,14.6/5-.014)))
	var draw:=KIT._batch(root,"MaintenanceClosedCeilingCassettes",mesh,placements)
	# Native boundary tops are10.60m;the current highest route is5.40m.
	# This roof is outside player reach and adds no collision or route.
	draw.set_meta("nonwalkable_roof_volume",AABB(Vector3(-4.2,10.50,-14.3),Vector3(9.4,.10,14.6)))

static func _nonwalkable_shaft(room:Node3D,root:Node3D)->void:
	# The original geometry ended atY0: no amount of fill light could reveal
	# a deeper shaft. Continue only vertical perimeter panels below the floor.
	# Native retry is belowY-1 (orY.6 after the first climb);no floor/bridge,
	# collider,interactable or new walkable landing is introduced here.
	var mesh:Mesh=PBR._pbr_mesh(WALL,room)
	for surface in mesh.get_surface_count():
		var finish:ShaderMaterial=mesh.surface_get_material(surface)
		finish.set_shader_parameter("base_color",Color(.32,.365,.36))
		finish.set_shader_parameter("texture_saturation",.12)
		finish.set_shader_parameter("metalness",.30)
		finish.set_shader_parameter("minimum_roughness",.56)
	for label in ["COLL_LeftBoundary","COLL_RightBoundary","COLL_FarBoundary"]:
		var body:StaticBody3D=room.get_node(label)
		var size:Vector3=body.get_child(0).shape.size
		var side:bool=label!="COLL_FarBoundary"
		var span:float=size.z if side else size.x
		var count:int=ceili(span/3);var width:float=span/count
		var normal:=Vector3.RIGHT if label=="COLL_LeftBoundary" else Vector3.LEFT if side else Vector3.BACK
		var rotation:=Basis(Vector3.UP,PI*.5 if label=="COLL_LeftBoundary" else -PI*.5 if side else 0)
		var placements:Array[Transform3D]=[]
		for column in count:
			for tier in 4:
				var point:Vector3=body.position+normal*(.05 if side else .10)+rotation.x*(-span*.5+(column+.5)*width)
				point.y=-12.0+tier*3.0+.004
				placements.append(Transform3D(rotation*Basis.from_scale(Vector3((width-.012)/3,.998,.90)),point))
		var draw:=KIT._batch(root,"NonwalkableShaftPanels_"+label,mesh,placements)
		draw.set_meta("nonwalkable_shaft_volume",AABB(Vector3(body.position.x-size.x*.5,-12,body.position.z-size.z*.5),Vector3(size.x,12,size.z)))
	if RenderingServer.get_current_rendering_method()=="forward_plus":
		var fog:=FogVolume.new();fog.name="MaintenanceDeepShaftAtmosphere"
		fog.position=Vector3(.5,-7.5,-10.25);fog.size=Vector3(9.35,9,8.1)
		var material:=FogMaterial.new();material.density=.035;material.albedo=Color(.27,.32,.34);material.height_falloff=.25;material.edge_fade=.25
		fog.material=material;fog.visible=false;root.add_child(fog)
	for row in [[-3.2,1.1,7.0],[-8.0,.8,6.5]]:
		var light:=OmniLight3D.new();light.name="ShaftStructuralReflectedLight"
		light.position=Vector3(.5,row[0],-10.1);light.light_color=Color(.68,.75,.76);light.light_energy=row[1];light.omni_range=row[2]
		light.light_cull_mask=KIT.ENVIRONMENT_LAYER;light.light_volumetric_fog_energy=.3;root.add_child(light)

static func _interior_reflection(root:Node3D)->void:
	if RenderingServer.get_current_rendering_method()!="forward_plus":return
	var probe:=ReflectionProbe.new();probe.name="MaintenanceInteriorReflection"
	probe.position=Vector3(.5,5.3,-7);probe.size=Vector3(9.4,10.6,14.6)
	probe.interior=true;probe.box_projection=true;probe.enable_shadows=true
	probe.ambient_mode=ReflectionProbe.AMBIENT_DISABLED;probe.intensity=.65
	probe.cull_mask=KIT.ENVIRONMENT_LAYER;probe.reflection_mask=KIT.ENVIRONMENT_LAYER
	probe.max_distance=20;probe.blend_distance=.6;probe.update_mode=ReflectionProbe.UPDATE_ONCE
	probe.visible=false;root.add_child(probe)

extends RefCounted

## Measured static mechanical kit, separate from native solids and gameplay.
const CAP=preload("res://assets/environments/specimen_cp45/specimen_seal_cap.glb")
const PANEL=preload("res://assets/environments/specimen_cp45/specimen_wall_service_panel.glb")
const TRAY=preload("res://assets/environments/specimen_cp45/specimen_ceiling_tray.glb")
const FILTER=preload("res://assets/environments/specimen_cp45/specimen_filter_h31_pbr4k.glb")
const SENSOR=preload("res://assets/environments/specimen_cp45/specimen_sensor_housing.glb")
const TERMINAL=preload("res://assets/environments/specimen_cp45/specimen_terminal_case.glb")
const TRIM=preload("res://assets/environments/specimen_cp45/specimen_trim_unit.glb")
const FINISH=preload("res://shaders/clinical_architecture_surface.gdshader")
const GRAIN=preload("res://assets/environments/maintenance_jutsu_v1_Maintenance ceramic grain 512.png")
const ENVIRONMENT_LAYER:=1<<18

static func install(room:Node3D)->void:
	if room.has_node("SpecimenMechanicalDressing"):return
	var kit:=Node3D.new();kit.name="SpecimenMechanicalDressing";room.add_child(kit)
	var filter_mesh:=_mesh(FILTER,room)
	assert(filter_mesh.get_aabb().size.is_equal_approx(Vector3(2.2,1.8,1.4)))
	var filters:Array[Transform3D]=[]
	for i in 4:
		var solid:Node3D=room.get_node("CoverPlinth_%d"%i)
		filters.append(Transform3D(Basis.IDENTITY,solid.position-Vector3(0,.9,0)))
		for visual in solid.get_children():
			if visual is MeshInstance3D:visual.hide()
	_batch(kit,"FourNativeVolumeBiofilters",filter_mesh,filters)
	var cap_mesh:=_mesh(CAP)
	var caps:Array[Transform3D]=[]
	for cfg in room._specimen_tanks:
		caps.append(Transform3D(Basis.IDENTITY,Vector3(cfg.x,0,cfg.z)))
		caps.append(Transform3D(Basis(Vector3.RIGHT,PI),Vector3(cfg.x,4.5,cfg.z)))
		for label in ["TankBase_","TankCap_"]:
			var body:Node=room.get_node(label+String(cfg.id))
			for visual in body.get_children():
				if visual is MeshInstance3D:visual.hide()
	_batch(kit,"TwelveMeasuredSealCaps",cap_mesh,caps)
	var panel_mesh:=_mesh(PANEL)
	var panels:Array[Transform3D]=[]
	# Native wall boxes define their own spans,including both real door holes.
	for label in ["NorthWall","SouthWallWest","SouthWallEast","EastWall","WestWallNorth","WestWallSouth"]:
		var solid:Node3D=room.get_node(label)
		var shape:BoxShape3D=solid.get_node("CollisionShape3D").shape
		var along_x:bool=label.begins_with("North") or label.begins_with("South")
		var span:float=shape.size.x if along_x else shape.size.z
		var count:=ceili(span/3.0);var width:=span/float(count)
		var yaw:=0.0 if label.begins_with("North") else (PI if label.begins_with("South") else (-PI*.5 if label=="EastWall" else PI*.5))
		for i in count:
			var point:=solid.position
			if along_x:point.x+=-span*.5+width*(float(i)+.5);point.z+=.24 if label.begins_with("North") else -.24
			else:point.z+=-span*.5+width*(float(i)+.5);point.x+=-.24 if label=="EastWall" else .24
			for y in [.12,3.61]:
				point.y=y
				var scale:=Basis(Vector3((width-.04)/2.96,0,0),Vector3(0,1,0),Vector3(0,0,1))
				panels.append(Transform3D(Basis(Vector3.UP,yaw)*scale,point))
	_batch(kit,"MeasuredWallServicePanels",panel_mesh,panels)
	# The privacy baffle remains opaque and physically identical. Its native
	# mesh receives a purpose-built continuous-light finish,with trim inside
	# the original volume rather than protruding into the reading pocket.
	var baffle:Node3D=room.get_node("TerminalShieldPlinth")
	for visual in baffle.get_children():
		if visual is MeshInstance3D:
			# Recess only the old visual core so the fitted faces remain visible
			# inside the original0.5m collider,without coincident surfaces.
			visual.scale.x=.78
			visual.material_override=_finish(Color(.37,.43,.48),.28,.57)
	var baffle_panels:Array[Transform3D]=[]
	for side in [-1.0,1.0]:
		for z in [-.8,.8]:
			var scale:=Basis(Vector3(1.55/2.96,0,0),Vector3(0,2.88/3.46,0),Vector3(0,0,1))
			baffle_panels.append(Transform3D(Basis(Vector3.UP,side*PI*.5)*scale,baffle.position+Vector3(side*.20,-1.44,z)))
	_batch(kit,"FittedPrivacyBaffleServicePanels",panel_mesh,baffle_panels)
	# Ceiling connections remain above the vessel tops and outside all routes.
	var tube:=CylinderMesh.new();tube.top_radius=.045;tube.bottom_radius=.045;tube.height=2.66;tube.radial_segments=20
	tube.material=_finish(Color(.25,.31,.36),.72,.36)
	var pipes:Array[Transform3D]=[]
	for cfg in room._specimen_tanks:
		for x in [-.82,.82]:pipes.append(Transform3D(Basis.IDENTITY,Vector3(cfg.x+x,5.83,cfg.z-.82)))
	_batch(kit,"VesselCeilingServiceConnections",tube,pipes)
	var trays:Array[Transform3D]=[]
	for x in [-8.0,-22.0]:
		for i in 8:trays.append(Transform3D(Basis.IDENTITY,Vector3(x,7.035,-16.5+float(i)*3.0)))
	_batch(kit,"CeilingCableTrays",_mesh(TRAY),trays)
	_readability_repairs(room,kit)
	# Keep the native glass,fluid,labels and actual scanner palette untouched.
	# Existing opaque hull surfaces need a readable continuous ceramic finish.
	for label in ["Ceiling","NorthWall","SouthWallWest","SouthWallEast","SouthLintel","EastWall","WestWallNorth","WestWallSouth","WestExitLintel"]:
		for visual in room.get_node(label).get_children():
			if visual is MeshInstance3D:visual.material_override=_finish(Color(.39,.45,.50),.08,.64)
	# Lift the opaque floor's graphite midtones locally; preserve the global
	# Hyper Anime environment and character lighting instead of a room wash.
	var floor_finish:=preload("res://scripts/environment/room_panel_finish.gd").material(Color(.43,.48,.53),Vector2(3,3),.16,.53)
	for visual in room.get_node("Floor").get_children():
		if visual is MeshInstance3D:visual.material_override=floor_finish

static func _readability_repairs(room:Node3D,kit:Node3D)->void:
	var trim_mesh:=_mesh(TRIM)
	var fittings:Array[Transform3D]=[]
	for x in [-8.0,-22.0]:
		for z in [-17.94,5.94]:fittings.append(_sized(Vector3(x,7.055,z),Vector3(.54,.22,.16)))
	for cfg in room._specimen_tanks:
		for x in [-.82,.82]:
			fittings.append(_sized(Vector3(cfg.x+x,7.18,cfg.z-.82),Vector3(.16,.04,.16)))
	_batch(kit,"CeilingTerminationFittings",trim_mesh,fittings)
	# Frames follow the two real portals,with all trim outside their original
	# clear apertures. They do not invent another doorway or an objective.
	var frames:Array[Transform3D]=[]
	for x in [-3.88,-1.12]:frames.append(_sized(Vector3(x,1.5,5.94),Vector3(.16,3,.12)))
	frames.append(_sized(Vector3(-2.5,3.12,5.94),Vector3(2.92,.22,.12)))
	for z in [-13.105,-10.895]:frames.append(_sized(Vector3(-29.94,1.4,z),Vector3(.12,2.8,.16)))
	frames.append(_sized(Vector3(-29.94,2.94,-12),Vector3(.12,.20,2.37)))
	_batch(kit,"MeasuredEntryAndExitFrames",trim_mesh,frames)
	var mount:Node3D=room.get_node("ScannerMount")
	for child in mount.get_children():
		if child is MeshInstance3D:child.hide()
	_batch(kit,"ScannerCeilingCoupling",trim_mesh,[_sized(mount.position,Vector3(1.18,.36,1.18))])
	for child in room._scanner_head.get_children():
		if child is MeshInstance3D and child.mesh is BoxMesh:child.hide()
	_batch(room._scanner_head,"MeasuredMechanicalScanner",_mesh(SENSOR),[Transform3D.IDENTITY])
	var lens:=MeshInstance3D.new();lens.name="NativeScannerOptic"
	var quad:=QuadMesh.new();quad.size=Vector2(.22,.15);lens.mesh=quad
	lens.position=Vector3(0,0,-.395);lens.rotation.y=PI
	var optic:=ShaderMaterial.new();optic.shader=preload("res://shaders/specimen_sensor_optic.gdshader")
	lens.material_override=optic;lens.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	room._scanner_head.add_child(lens);room._scanner_optics=optic
	var terminal:Node3D=room._terminal_body
	for child in terminal.get_children():
		if not child is MeshInstance3D or not child.mesh is BoxMesh:continue
		if child.mesh.size.is_equal_approx(Vector3(1.2,1.2,.8)):child.hide()
		elif child.mesh.size.is_equal_approx(Vector3(.8,.5,.04)):
			child.material_override=_finish(Color(.035,.05,.065),.20,.48)
			_batch(child,"MachinedTerminalBezel",trim_mesh,[_sized(Vector3.ZERO,Vector3(.84,.54,.05))])
			var face:=MeshInstance3D.new();face.name="NativeReadoutSurface"
			var panel:=QuadMesh.new();panel.size=Vector2(.74,.44);face.mesh=panel;face.position.z=.026
			var display:=ShaderMaterial.new();display.shader=preload("res://shaders/clinical_diagnostic_display.gdshader")
			display.set_shader_parameter("motion",0.0);face.material_override=display
			face.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;child.add_child(face)
	_batch(kit,"MeasuredTerminalCase",_mesh(TERMINAL),[Transform3D(Basis.IDENTITY,terminal.position-Vector3(0,.6,0))])
	room._terminal_light.light_energy=.22
	var glass:MeshInstance3D=room.get_node("Tank_ex_011").get_child(0)
	var reserved_glass:=ShaderMaterial.new();reserved_glass.shader=preload("res://shaders/specimen_reserved_glass.gdshader")
	glass.material_override=reserved_glass

static func _sized(point:Vector3,size:Vector3)->Transform3D:
	return Transform3D(Basis(Vector3(size.x,0,0),Vector3(0,size.y,0),Vector3(0,0,size.z)),point)

static func _mesh(scene:PackedScene,room:Node3D=null)->Mesh:
	var prototype:Node3D=scene.instantiate()
	var source:MeshInstance3D=prototype.find_children("*","MeshInstance3D",true,false)[0]
	var result:Mesh=source.mesh.duplicate()
	for surface in result.get_surface_count():
		var original:StandardMaterial3D=result.surface_get_material(surface)
		if scene==FILTER:
			result.surface_set_material(surface,_texture_finish(original,room))
			continue
		var color:Color=original.albedo_color
		if scene==PANEL and original.resource_name.contains("Pearl"):color*=Color(.83,.84,.86)
		if scene==CAP and original.resource_name.contains("Pearl"):color*=Color(.80,.84,.90)
		result.surface_set_material(surface,_finish(color,original.metallic,original.roughness))
	prototype.free();return result

static func _texture_finish(source:StandardMaterial3D,room:Node3D)->ShaderMaterial:
	var result:=_finish(source.albedo_color,source.metallic,source.roughness)
	result.set_shader_parameter("ceramic_finish",false)
	result.set_shader_parameter("uv_scale",source.uv1_scale)
	result.set_shader_parameter("uv_offset",source.uv1_offset)
	for slot in ["albedo","normal","roughness","metallic","ao"]:
		var key:String="color" if slot=="albedo" else slot
		var texture:Texture2D=source.get(slot+"_texture")
		result.set_shader_parameter(key+"_map",texture)
		var enabled:bool=texture!=null
		if slot in ["normal","ao"]:enabled=enabled and bool(source.get(slot+"_enabled"))
		result.set_shader_parameter("has_"+key+"_map",enabled)
	result.set_shader_parameter("combined_rm_map",source.roughness_texture!=null and source.roughness_texture==source.metallic_texture)
	result.set_shader_parameter("normal_strength",source.normal_scale)
	var adapter:RefCounted=room.get_node("/root/HyperAnimeWorldManager").adapter
	for slot in ["roughness","metallic","ao"]:result.set_shader_parameter(slot+"_channel",adapter.channel(int(source.get(slot+"_texture_channel"))))
	return result

static func _finish(color:Color,metal:float,roughness:float)->ShaderMaterial:
	var result:=ShaderMaterial.new();result.shader=FINISH
	result.set_shader_parameter("base_color",color)
	result.set_shader_parameter("metalness",metal)
	result.set_shader_parameter("surface_roughness",roughness)
	result.set_shader_parameter("minimum_roughness",.3)
	result.set_shader_parameter("finish_grain",GRAIN)
	return result

static func _batch(parent:Node3D,label:String,mesh:Mesh,placements:Array[Transform3D])->MultiMeshInstance3D:
	var draw:=MultiMeshInstance3D.new();draw.name=label
	var batch:=MultiMesh.new();batch.transform_format=MultiMesh.TRANSFORM_3D;batch.mesh=mesh;batch.instance_count=placements.size()
	var bounds:=AABB()
	for index in placements.size():
		batch.set_instance_transform(index,placements[index])
		var current:AABB=placements[index]*mesh.get_aabb()
		bounds=current if index==0 else bounds.merge(current)
	batch.custom_aabb=bounds;draw.multimesh=batch
	draw.layers|=ENVIRONMENT_LAYER
	parent.add_child(draw);return draw

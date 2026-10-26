extends RefCounted

## Static manufactured equipment only. Native racks,shards,decoder,bridge,
## ramp/rail solids,gate,projection and timeline keep their original owners.
const KIT=preload("res://scripts/environment/specimen_mechanical_dressing.gd")
const TRIM=preload("res://assets/environments/specimen_cp45/specimen_trim_unit.glb")
const TRAY=preload("res://assets/environments/specimen_cp45/specimen_ceiling_tray.glb")
const WALL_TILE=preload("res://assets/environments/lab_clinical_cp45/clinical_wall_p2_4k.glb")
const CORE_PATH="res://assets/environments/archive_cp45/archive_core_base_pbr4k.glb"

static func install(room:Node3D)->void:
	if room.has_node("ArchiveMechanicalDressing"):return
	var root:=Node3D.new();root.name="ArchiveMechanicalDressing";room.add_child(root)
	var wall:=KIT._finish(Color(.24,.24,.22),.16,.66)
	for name in ["Ceiling","SouthWall","WestWall","EastWallNorth","EastWallSouth","EastLintel","NorthWallWest","NorthWallEast","NorthLintel"]:
		for visual in room.get_node(name).get_children():
			if visual is MeshInstance3D:visual.material_override=wall
	_measured_shell(room,root)
	var trim:=KIT._mesh(TRIM)
	for surface in trim.get_surface_count():trim.surface_set_material(surface,KIT._finish(Color(.48,.47,.43),.34,.54))
	var fittings:Array[Transform3D]=[]
	# Open framed mesh infill retains each original solid safety-rail volume.
	for name in ["CatwalkRailNorth","CatwalkRailSouth"]:
		var body:Node3D=room.get_node(name)
		var length:float=16.0 if name.ends_with("North") else 14.2
		for child in body.get_children():
			if child is MeshInstance3D:child.hide()
		for y in [-.465,.465]:fittings.append(KIT._sized(body.position+Vector3(0,y,0),Vector3(length,.055,.08)))
		var count:int=ceili(length/2.0)
		for i in count+1:
			var x:float=-length*.5+.035+(length-.07)*float(i)/float(count)
			fittings.append(KIT._sized(body.position+Vector3(x,0,0),Vector3(.055,.9,.08)))
		var wire:=MeshInstance3D.new();wire.name=name+"PerforatedInfill"
		var plane:=QuadMesh.new();plane.size=Vector2(length-.08,.88);wire.mesh=plane;wire.position=body.position
		var material:=ShaderMaterial.new();material.shader=preload("res://shaders/archive_perforated_rail.gdshader")
		material.set_shader_parameter("cells",Vector2(roundf(length/.22),4));wire.material_override=material
		root.add_child(wire)
	# Measured underside edge extrusions fit within the existing20cm deck.
	for z in [-1.055,1.055]:fittings.append(KIT._sized(Vector3(-11,3.52,z),Vector3(15.94,.13,.07)))
	# Manufactured open grating replaces only the blank deck skin. A real
	# lattice gives the original projection a plausible path through the
	# walkway;the unchanged continuous collider owns safe foot support.
	var bridge:Node3D=room.get_node("CatwalkBridge")
	for child in bridge.get_children():
		if child is MeshInstance3D:child.hide()
	var grating:Array[Transform3D]=[]
	for i in 73:
		grating.append(KIT._sized(Vector3(-18.965+float(i)*15.93/72.0,3.55,0),Vector3(.022,.10,2.13)))
	for i in 10:
		grating.append(KIT._sized(Vector3(-11,3.47,-.99+float(i)*.22),Vector3(15.94,.06,.028)))
	KIT._batch(root,"ManufacturedMetalCatwalkDeck",trim,grating)
	# A machined nosing sits inside each original visual tread envelope.
	for i in 12:
		fittings.append(KIT._sized(Vector3(-3.8,float(i)*.3+.277,7.9-float(i)*.55+.25),Vector3(1.72,.035,.045)))
		for visual in room.get_node("CatwalkStair_%d"%i).get_children():
			if visual is MeshInstance3D:visual.material_override=KIT._finish(Color(.29,.29,.27),.26,.58)
	# Slender steel stringers remain inside the original tread/ramp width.
	for x in [-4.66,-2.94]:
		var a:=Vector3(x,.12,8.12);var b:=Vector3(x,3.42,1.68)
		var direction:Vector3=b-a
		var basis:=Basis.looking_at(direction.normalized(),Vector3.UP)*Basis.from_scale(Vector3(.07,.11,direction.length()))
		fittings.append(Transform3D(basis,(a+b)*.5))
	# Four ceiling ties terminate on the rail edges and real ceiling slab.
	# Their bases sit in the already solid rail strip,outside the walk lane.
	for x in [-18.7,-3.3]:
		for z in [-1.05,1.05]:
			fittings.append(KIT._sized(Vector3(x,6.075,z),Vector3(.055,4.85,.055)))
			for y in [3.70,8.45]:fittings.append(KIT._sized(Vector3(x,y,z),Vector3(.18,.10,.18)))
	# Portal casing stays outside the existing entry/exit clear apertures.
	for x in [-12.13,-9.87]:fittings.append(KIT._sized(Vector3(x,1.4,-13.94),Vector3(.13,2.8,.12)))
	fittings.append(KIT._sized(Vector3(-11,2.97,-13.94),Vector3(2.39,.13,.12)))
	for z in [-1.39,1.39]:fittings.append(KIT._sized(Vector3(-.04,1.6,z),Vector3(.12,3.2,.13)))
	fittings.append(KIT._sized(Vector3(-.04,3.33,0),Vector3(.12,.13,2.91)))
	KIT._batch(root,"MeasuredRailStairPortalHardware",trim,fittings)
	var trays:Array[Transform3D]=[]
	# Offset from the existing six light strips;do not bury their emitters.
	for x in [-8.0,-14.0]:
		for i in 8:trays.append(Transform3D(Basis.IDENTITY,Vector3(x,8.20,-10.5+float(i)*3.0)))
	KIT._batch(root,"PairedRackCeilingCableRuns",KIT._mesh(TRAY),trays)
	_racks(room)
	_decoder(room)
	_archive_light_direction(room)
	# Imported core is optional during the isolated build phase. Native base
	# remains visible until a real measured asset has been imported.
	if ResourceLoader.exists(CORE_PATH):
		var base:Node3D=room.get_node("HolographicCorePedestal")
		var packed:PackedScene=load(CORE_PATH)
		var mesh:=_pbr_mesh(packed,room)
		for s in mesh.get_surface_count():
			var source:Material=mesh.surface_get_material(s)
			# Core PBR source uses the same exact texture/channel adapter as racks.
			if source is ShaderMaterial:
				source.set_shader_parameter("minimum_roughness",.45)
				source.set_shader_parameter("texture_saturation",.08)
				source.set_shader_parameter("base_color",Color(1.0,.98,.94))
		for child in base.get_children():
			if child is MeshInstance3D:child.hide()
		KIT._batch(root,"MeasuredArchiveProjectorBase",mesh,[Transform3D(Basis.IDENTITY,base.position-Vector3(0,.5,0))])
	# Gate material/pressure ribs follow only the existing authoritative body.
	for child in room._gate.get_children():
		if child is MeshInstance3D:child.material_override=KIT._finish(Color(.30,.30,.28),.24,.58)
	KIT._batch(room._gate,"NativeGateMachinedRibs",trim,[KIT._sized(Vector3(-.89,0,.106),Vector3(.055,2.65,.032)),KIT._sized(Vector3(.89,0,.106),Vector3(.055,2.65,.032))])

static func _racks(room:Node3D)->void:
	var original:Node3D=room.SERVER_RACK_PROP.instantiate()
	var finishes:={}
	for source in original.find_children("*","MeshInstance3D",true,false):
		var materials:Array[Material]=[]
		for surface in source.mesh.get_surface_count():
			var prior:StandardMaterial3D=source.get_active_material(surface)
			var material:=KIT._texture_finish(prior,room)
			material.set_shader_parameter("minimum_roughness",.42)
			material.set_shader_parameter("metalness",.38)
			material.set_shader_parameter("texture_saturation",.45)
			materials.append(material)
		finishes[original.get_path_to(source)]=materials
	for name in ["NorthRack_6","NorthRack_11","NorthRack_16","SouthRack_6","SouthRack_11","SouthRack_16"]:
		var model:Node3D=room.get_node(name+"/Model")
		for path in finishes:
			var live:MeshInstance3D=model.get_node(path)
			for surface in finishes[path].size():live.set_surface_override_material(surface,finishes[path][surface])
	original.free()

static func _pbr_mesh(packed:PackedScene,room:Node3D)->Mesh:
	var original:Node3D=packed.instantiate()
	var source:MeshInstance3D=original.find_children("*","MeshInstance3D",true,false)[0]
	var mesh:Mesh=source.mesh.duplicate()
	for surface in mesh.get_surface_count():
		mesh.surface_set_material(surface,KIT._texture_finish(source.get_active_material(surface),room))
	original.free();return mesh

static func _decoder(room:Node3D)->void:
	var model:Node3D=room._console_body.get_node("Model")
	var original:Node3D=room.SIGNAL_CONSOLE_PROP.instantiate()
	for source in original.find_children("*","MeshInstance3D",true,false):
		var live:MeshInstance3D=model.get_node(original.get_path_to(source))
		for surface in source.mesh.get_surface_count():
			var prior:StandardMaterial3D=source.get_active_material(surface)
			if prior.resource_name.ends_with("Titanium"):
				live.set_surface_override_material(surface,KIT._finish(Color(.50,.49,.45),.30,.54))
			elif prior.resource_name.ends_with("Graphite"):
				live.set_surface_override_material(surface,KIT._finish(Color(.13,.135,.13),.18,.68))
	original.free()
	# The authored source identifies a1.17x.66m face centred atlocalZ.07
	# under ScreenMount. This cull-back readout lies2mm above its real front,
	# inside the original bezel;the terminal's reverse remains opaque casing.
	var mount:Node3D=model.find_child("EchoSignalConsole_ScreenMount",true,false)
	assert(mount!=null,"Existing authored decoder screen mount missing")
	var readout:=preload("res://scripts/environment/archive_decoder_readout.gd").new()
	readout.name="NativeArchiveDecoderReadout";readout.archive=room
	var plane:=QuadMesh.new();plane.size=Vector2(1.10,.59);readout.mesh=plane
	readout.position=Vector3(0,0,.081);readout.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var finish:=ShaderMaterial.new();finish.shader=preload("res://shaders/archive_decoder_readout.gdshader")
	readout.material_override=finish;mount.add_child(readout)

static func _measured_shell(room:Node3D,root:Node3D)->void:
	# Rebuild every perimeter sector from the already accepted image-guided
	# Tripo P2 tile. Exactly measured sectors preserve both native apertures.
	# One shared mesh/maps,eight bounded batches;no new generated whole-room
	# envelope with guessed openings or baked racks/actors.
	var mesh:=_pbr_mesh(WALL_TILE,room)
	assert(mesh.get_aabb().size.is_equal_approx(Vector3(3,3,.2)))
	for surface in mesh.get_surface_count():
		var finish:ShaderMaterial=mesh.surface_get_material(surface)
		finish.set_shader_parameter("base_color",Color(.41,.40,.36))
		finish.set_shader_parameter("texture_saturation",.25)
		finish.set_shader_parameter("metalness",.26)
		finish.set_shader_parameter("minimum_roughness",.55)
	var total:=0
	for name in ["WestWall","SouthWall","EastWallNorth","EastWallSouth","EastLintel","NorthWallWest","NorthWallEast","NorthLintel"]:
		var body:Node3D=room.get_node(name)
		var shape:BoxShape3D=body.get_node("CollisionShape3D").shape
		var size:Vector3=shape.size
		var along_x:bool=size.x>size.z
		var span:float=size.x if along_x else size.z
		var normal:Vector3
		var yaw:float
		if name=="WestWall":normal=Vector3.RIGHT;yaw=PI*.5
		elif name=="SouthWall":normal=Vector3.FORWARD;yaw=PI
		elif name.begins_with("East"):normal=Vector3.LEFT;yaw=-PI*.5
		else:normal=Vector3.BACK;yaw=0
		var rotation:=Basis(Vector3.UP,yaw)
		var columns:int=ceili(span/3.0);var rows:int=ceili(size.y/3.0)
		var width:float=span/float(columns);var height:float=size.y/float(rows)
		var face:Vector3=body.position+normal*.2
		var original_bounds:=AABB(body.position-size*.5,size)
		var placements:Array[Transform3D]=[]
		for column in columns:
			for row in rows:
				var point:Vector3=face-normal*.10+rotation.x*(-span*.5+(float(column)+.5)*width)
				point.y=body.position.y-size.y*.5+float(row)*height+.006
				var basis:=rotation*Basis.from_scale(Vector3((width-.012)/3.0,(height-.012)/3.0,.90))
				var placement:=Transform3D(basis,point)
				assert(original_bounds.grow(.001).encloses(placement*mesh.get_aabb()),"Archive tile crossed native wall/portal volume: "+name)
				placements.append(placement)
		# Retain a thin real backing within the old solid,behind the cladding,
		# so panel joints cannot reveal sky or the neighbouring room.
		for visual in body.get_children():
			if visual is MeshInstance3D:
				visual.position=-normal*.18
				if along_x:visual.scale.z=.05
				else:visual.scale.x=.05
		var draw:=KIT._batch(root,"MeasuredArchiveCladding_"+name,mesh,placements)
		draw.set_meta("original_wall_volume",original_bounds)
		total+=placements.size()
	root.set_meta("measured_archive_cladding_tiles",total)

static func _archive_light_direction(room:Node3D)->void:
	# The shared HyperAnime environment still owns HDR,cel characters,camera,
	# bloom and coloured shadow bounce. Local fittings now illuminate an
	# aged graphite data vault instead of tinting every surface clinical blue.
	for light in room.get_node("ServiceLighting").find_children("*","OmniLight3D",false,false):
		light.light_color=Color(1.0,.96,.88)
		light.light_energy=.85
	var fill:OmniLight3D=room.get_node("ArchiveUpperFill")
	fill.light_color=Color(.90,.90,.85);fill.light_energy=.60
	var floor:Node3D=room.get_node("Floor")
	for visual in floor.get_children():
		if visual is MeshInstance3D:
			visual.material_override=preload("res://scripts/environment/room_panel_finish.gd").material(Color(.24,.235,.22),Vector2(2.2,2.2),.22,.68)
	for name in ["CatwalkStairSupport","CatwalkStairLanding"]:
		for visual in room.get_node(name).get_children():
			if visual is MeshInstance3D:visual.material_override=KIT._finish(Color(.25,.255,.24),.24,.64)

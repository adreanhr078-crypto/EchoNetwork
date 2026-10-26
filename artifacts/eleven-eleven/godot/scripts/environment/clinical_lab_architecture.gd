extends Node3D

## Original editable clinical kit. Presentation only; the existing room keeps
## all collision, authoritative terminals, anchors and story state.
const KIT="res://assets/environments/lab_clinical_cp45/"
const TRIPO_CHAIR=preload("res://assets/environments/lab_clinical_cp45/neural_chair_tripo_20k.glb")
const PERIMETER_KIT=preload("res://scripts/environment/clinical_modular_perimeter.gd")
const SCANNER=preload("res://assets/environments/lab_clinical_cp45/clinical_scanner_p2_4k.glb")
var pearl:StandardMaterial3D
var graphite:StandardMaterial3D
var alloy:StandardMaterial3D
var amber:StandardMaterial3D
var clinical_white:StandardMaterial3D
var gate_alloy:StandardMaterial3D
var laboratory:Node3D
var architectural_materials:Dictionary={}
var monitor_material:ShaderMaterial
var monitor_elapsed:=0.0
var service_shadow_sources:Dictionary={}
var _service_shadow_tier:=""
var equipment_materials:Dictionary={}
var stasis_display_material:ShaderMaterial
var _stasis_display_active:=false

func _sync_stasis_display(force:=false)->void:
	if not stasis_display_material:return
	var active:bool=laboratory.wish_done
	if active==_stasis_display_active and not force:return
	_stasis_display_active=active
	stasis_display_material.set_shader_parameter("stasis_active",active)

func _dress_stasis_display(room:Node3D)->void:
	# The dark band is the original clock housing, confirmed by a rendered
	# pixel/triangle probe. Retain its geometry and the story-owned digits.
	var housing:MeshInstance3D=room.get_node_or_null("StasisClockHousing")
	if not housing:return
	stasis_display_material=ShaderMaterial.new()
	stasis_display_material.shader=preload("res://shaders/clinical_stasis_display.gdshader")
	housing.material_override=stasis_display_material
	_sync_stasis_display(true)

func _tone_equipment(node:Node)->void:
	for mesh in node.find_children("*","MeshInstance3D",true,false):
		for surface in mesh.mesh.get_surface_count():
			var source:ShaderMaterial=mesh.get_active_material(surface) as ShaderMaterial
			if not source or not source.has_meta("hyper_source"):continue
			var id:=source.get_instance_id()
			if not equipment_materials.has(id):
				var finish:ShaderMaterial=source.duplicate()
				finish.set_shader_parameter("shadow_color",Color(.48,.50,.60))
				finish.set_shader_parameter("rim_intensity",.02)
				equipment_materials[id]=finish
			mesh.set_surface_override_material(surface,equipment_materials[id])

func _dress_contract_plinth(room:Node3D)->void:
	var altar:Node3D=room.get_node_or_null("ZeroContractAltar")
	if not altar or altar.get_node_or_null("ClinicalContractPlinth"):return
	for child in altar.get_children():
		if child is MeshInstance3D and child.mesh is CylinderMesh and is_equal_approx(child.mesh.height,1.2):
			# Preserve the exact native taper,height,pose and original solid.
			# Only the visual radial tessellation and clinical metal finish change.
			child.name="ClinicalContractPlinth"
			child.mesh=child.mesh.duplicate();child.mesh.radial_segments=96
			child.material_override=_architectural_finish(_material(Color(.24,.30,.37),.42,.50))
			for spec in [[.04,1.165],[1.18,1.03]]:
				var rim:=_ring("ClinicalPlinthMachinedRim%d"%int(spec[0]*1000),Vector3(0,spec[0],0),spec[1],.015,_architectural_finish(alloy))
				var rim_mesh:TorusMesh=rim.mesh as TorusMesh
				rim_mesh.rings=96;rim_mesh.ring_segments=12
				rim.reparent(altar,false)
			return

func _dress_sealed_exit(room:Node3D)->void:
	# Finish the existing solid lintel and piers without a protruding cover.
	for label in ["NorthLintel","NorthWallWest","NorthWallEast"]:
		var solid:Node=room.get_node_or_null(label)
		if solid:
			for mesh in solid.find_children("*","MeshInstance3D",true,false):
				mesh.material_override=_architectural_finish(clinical_white)
	var gate:Node3D=room.get_node_or_null("DimensionalBreachPortal")
	if not gate:return
	var plate_material:=_architectural_finish(gate_alloy)
	var plate_mesh:=BoxMesh.new();plate_mesh.size=Vector3(.94,.85,.024)
	var plates:=MultiMesh.new();plates.transform_format=MultiMesh.TRANSFORM_3D
	plates.mesh=plate_mesh;plates.instance_count=6
	var index:=0
	for x in [-.49,.49]:
		for y in [-.9,0.0,.9]:
			plates.set_instance_transform(index,Transform3D(Basis.IDENTITY,Vector3(x,y,.116)))
			index+=1
	var plate_draw:=MultiMeshInstance3D.new();plate_draw.name="ClinicalGatePressurePlates"
	plate_draw.multimesh=plates;plate_draw.material_override=plate_material
	gate.add_child(plate_draw)
	var centre:=_block("ClinicalGateCentreSeal",Vector3(0,0,.145),Vector3(.08,2.65,.025),_architectural_finish(alloy))
	centre.reparent(gate,false)

func _on_quality_changed(_tier:String)->void:
	_apply_service_shadow_budget()

func _apply_service_shadow_budget()->void:
	var world:Node=get_node_or_null("/root/HyperAnimeWorldManager")
	if not world:return
	var tier:String=world.quality
	if tier==_service_shadow_tier:return
	_service_shadow_tier=tier
	# Six ceiling fill omnis otherwise render six shadow faces each. Low and
	# medium keep their illumination, the focal surgical spotlight and Zero's
	# authored shadow; high/ultra restore every original service shadow.
	for light in service_shadow_sources:
		if is_instance_valid(light):
			light.shadow_enabled=service_shadow_sources[light] and tier in ["high","ultra"]
	if is_instance_valid(laboratory) and is_instance_valid(laboratory._surgical_light):
		laboratory._surgical_light.light_size=.18 if tier in ["high","ultra"] else 0.0
	for finish in architectural_materials.values():
		finish.set_shader_parameter("has_normal_map",bool(finish.get_meta("clinical_normal_enabled",false)) and tier!="low")

func _process(delta:float)->void:
	if not is_instance_valid(laboratory) or not is_instance_valid(laboratory.player):return
	_sync_stasis_display()
	var p:Vector3=laboratory.to_local(laboratory.player.global_position)
	var moving:bool=not laboratory.reduced_motion and absf(p.x)<17 and p.z<1 and p.z> -41
	if moving:monitor_elapsed+=delta
	monitor_material.set_shader_parameter("elapsed",monitor_elapsed)
	monitor_material.set_shader_parameter("motion",1.0 if moving else 0.0)

func _ring(label:String,at:Vector3,radius:float,thickness:float,m:Material)->MeshInstance3D:
	var node:=MeshInstance3D.new();node.name=label
	var mesh:=TorusMesh.new()
	mesh.inner_radius=radius-thickness;mesh.outer_radius=radius+thickness
	mesh.rings=48;mesh.ring_segments=8
	node.mesh=mesh;node.position=at;node.material_override=m;add_child(node)
	return node

func _vitrine(at:Vector3)->void:
	# Match the retained pod glass: radius1.44m, height4.42m. The existing
	# memory/interact/anchor owners stay at their original transforms.
	for y in [.18,.34,4.22,4.42]:
		_ring("VitrineSurgicalRim",at+Vector3(0,y,0),1.48,.075,alloy)
	for angle in [PI*.25,PI*.75,PI*1.25,PI*1.75]:
		var offset:=Vector3(cos(angle)*1.48,2.30,sin(angle)*1.48)
		_block("VitrineSupport",at+offset,Vector3(.075,4.0,.075),graphite)
		_block("VitrineServiceLamp",at+offset+Vector3(0,1.35,0),Vector3(.085,.25,.085),amber)
	_ring("VitrineBaseGasket",at+Vector3(0,.075,0),1.50,.10,graphite)
	for side in [-1.0,1.0]:
		_block("MemoryDisplayBezel",at+Vector3(side*1.365,2.3,.27),Vector3(.045,1.65,.055),graphite)
	for y in [1.49,3.11]:
		_block("MemoryDisplayBezel",at+Vector3(0,y,.27),Vector3(2.77,.045,.055),graphite)
	var glass:=ShaderMaterial.new()
	glass.shader=preload("res://shaders/clinical_vitrine_glass.gdshader")
	var vessel:=MeshInstance3D.new();vessel.name="ClinicalVitrineGlass"
	var cylinder:=CylinderMesh.new();cylinder.top_radius=1.465;cylinder.bottom_radius=1.465
	cylinder.height=4.12;cylinder.radial_segments=48
	cylinder.cap_top=false;cylinder.cap_bottom=false
	vessel.mesh=cylinder;vessel.position=at+Vector3(0,2.28,0)
	vessel.material_override=glass;vessel.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(vessel)

func _architectural_finish(source:StandardMaterial3D)->ShaderMaterial:
	var id:=source.get_instance_id()
	if architectural_materials.has(id):return architectural_materials[id]
	var finish:=ShaderMaterial.new()
	finish.shader=preload("res://shaders/clinical_architecture_surface.gdshader")
	finish.resource_name="ClinicalFinish_"+source.resource_name
	finish.set_shader_parameter("base_color",source.albedo_color)
	finish.set_shader_parameter("metalness",source.metallic)
	finish.set_shader_parameter("surface_roughness",source.roughness)
	finish.set_shader_parameter("ceramic_finish",source==pearl or source==clinical_white or source.resource_name.contains("Pearl"))
	finish.set_shader_parameter("finish_grain",preload("res://assets/environments/maintenance_jutsu_v1_Maintenance ceramic grain 512.png"))
	finish.set_shader_parameter("uv_scale",source.uv1_scale)
	finish.set_shader_parameter("uv_offset",source.uv1_offset)
	for slot in ["albedo","normal","roughness","metallic","ao"]:
		var texture:Texture2D=source.get(slot+"_texture")
		var key:String="color" if slot=="albedo" else slot
		finish.set_shader_parameter(key+"_map",texture)
		var enabled:bool=texture!=null
		if slot in ["normal","ao"]:enabled=enabled and bool(source.get(slot+"_enabled"))
		if slot=="normal":
			finish.set_meta("clinical_normal_enabled",enabled)
			enabled=enabled and get_node("/root/HyperAnimeWorldManager").quality!="low"
		finish.set_shader_parameter("has_"+key+"_map",enabled)
	finish.set_shader_parameter("combined_rm_map",source.roughness_texture!=null and source.roughness_texture==source.metallic_texture)
	finish.set_shader_parameter("normal_strength",source.normal_scale)
	for slot in ["roughness","metallic","ao"]:
		finish.set_shader_parameter(slot+"_channel",get_node("/root/HyperAnimeWorldManager").adapter.channel(int(source.get(slot+"_texture_channel"))))
	architectural_materials[id]=finish
	return finish

func _material(color:Color,metal:float,rough:float,emission:=0.0)->StandardMaterial3D:
	var m:=StandardMaterial3D.new()
	m.albedo_color=color;m.metallic=metal;m.roughness=rough
	if emission>0:
		m.emission_enabled=true;m.emission=color;m.emission_energy_multiplier=emission
	return m

func _block(label:String,at:Vector3,size:Vector3,m:Material)->MeshInstance3D:
	var node:=MeshInstance3D.new();node.name=label
	var mesh:=BoxMesh.new();mesh.size=size;node.mesh=mesh
	node.position=at;node.material_override=m;add_child(node)
	return node

func _asset(file:String,at:Vector3,yaw:=0.0)->Node3D:
	var node:Node3D=load(KIT+file+".glb").instantiate()
	node.position=at;node.rotation.y=yaw;add_child(node)
	return node

func build(room:Node3D)->void:
	laboratory=room
	var service:Node=room.get_node_or_null("ServiceLighting")
	if service:
		for light in service.get_children():
			if light is OmniLight3D:service_shadow_sources[light]=light.shadow_enabled
	_apply_service_shadow_budget()
	var quality_owner:Node=get_node_or_null("/root/HyperAnimeWorldManager")
	if quality_owner and not quality_owner.quality_changed.is_connected(_on_quality_changed):
		quality_owner.quality_changed.connect(_on_quality_changed)
	pearl=_material(Color(.42,.48,.54),.12,.55)
	graphite=_material(Color(.15,.19,.25),.32,.48)
	alloy=_material(Color(.35,.42,.48),.65,.32)
	amber=_material(Color(.95,.46,.10),.1,.4,.7)
	clinical_white=_material(Color(.66,.67,.68),.10,.65)
	gate_alloy=_material(Color(.24,.29,.36),.28,.56)
	monitor_material=ShaderMaterial.new()
	monitor_material.shader=preload("res://shaders/clinical_diagnostic_display.gdshader")
	var shell:Node3D=PERIMETER_KIT.build(self)
	shell.name="MeasuredTripoClinicalPerimeter"
	add_child(shell)
	var floor_finish:=ShaderMaterial.new()
	floor_finish.shader=preload("res://shaders/clinical_porcelain_floor.gdshader")
	floor_finish.set_shader_parameter("ceramic_grain",preload("res://assets/environments/maintenance_jutsu_v1_Maintenance ceramic grain 512.png"))
	var dry_floor:=MeshInstance3D.new();dry_floor.name="ClinicalPorcelainFloor"
	var plane:=PlaneMesh.new();plane.size=Vector2(31.5,39.5)
	dry_floor.mesh=plane;dry_floor.position=Vector3(0,.006,-20)
	dry_floor.material_override=floor_finish;add_child(dry_floor)
	var deck_finish:ShaderMaterial=floor_finish.duplicate()
	deck_finish.set_shader_parameter("porcelain",Color(.42,.48,.54))
	deck_finish.set_shader_parameter("surface_roughness",.46)
	deck_finish.set_shader_parameter("surface_metalness",.16)
	var access:Node=room.get_node_or_null("TheaterApproach")
	if access:
		for mesh in access.find_children("*","MeshInstance3D",true,false):mesh.material_override=deck_finish
	# Hide only replaceable mesh visuals. Leave solids, areas, terminal scripts
	# and original medical landmark transforms fully live.
	for label in ["NeuralRigTable","DrowningPoolFloor"]:
		var original:Node=room.get_node_or_null(label)
		if original:
			for mesh in original.find_children("*","MeshInstance3D",true,false):mesh.hide()
	var dais:Node=room.get_node_or_null("SurgicalDaisPlatform")
	if dais:
		for mesh in dais.find_children("*","MeshInstance3D",true,false):mesh.material_override=deck_finish
	# One retained deck mesh with analytic joints replaces36 raised tiles;
	# this removes repeated corner occlusion and36 unnecessary mesh nodes.
	var terminal:Node=room.get_node_or_null("KinjaNeuralRigTerminal")
	var mount:Node=terminal.find_child("EchoSignalConsole_ScreenMount",true,false) if terminal else null
	if mount:
		var readout:=MeshInstance3D.new();readout.name="ClinicalDiagnosticReadout"
		var quad:=QuadMesh.new();quad.size=Vector2(1.11,.55)
		readout.mesh=quad;readout.position=Vector3(0,.025,.081)
		readout.material_override=monitor_material;readout.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mount.add_child(readout)
	# Inspected Tripo derivative: 20,336 triangles, retained 4K base and
	# 2K normal/RM maps. Source is 0.979126m along X; scale to the existing
	# 2.6m clinical landmark and rotate its foot end toward the entry.
	var chair:Node3D=TRIPO_CHAIR.instantiate()
	chair.name="NeuralChairTripo"
	chair.position=Vector3(0,1.2,-20)
	chair.scale=Vector3.ONE*(2.6/.9791260362)
	chair.rotation.y= -PI*.5
	add_child(chair)
	var scanner:Node3D=SCANNER.instantiate()
	scanner.name="SegmentedTripoScanner";scanner.position=Vector3(0,7.0,-20)
	add_child(scanner)
	# A measured ceramic perimeter lip separates the existing ring from
	# the dark ceiling; retain the native7m anchor and physical shadows.
	_ring("ScannerCeramicIdentificationLip",Vector3(0,7.12,-20),2.605,.025,clinical_white)
	# Measured source cap centres, BlenderXY -> GodotXZ. Extensions
	# overlap the four generated posts and meet the retained ceilingY10.
	var suspension_bottom:=8.83131314
	var suspension_top:=10.01
	var suspension_index:=0
	for point in [Vector2(-1.18632137,1.18124092), Vector2(-1.18632152,-1.21934531), Vector2(1.19267228,1.17870046), Vector2(1.19267213,-1.22188576)]:
		_block("ScannerCeilingSuspension%d"%suspension_index,Vector3(point.x,(suspension_bottom+suspension_top)*.5,-20+point.y),Vector3(.12,suspension_top-suspension_bottom,.12),graphite)
		suspension_index+=1
	for pod in [room._shizuka_pod,room._yuki_pod]:
		# Environment instance transform only: same retained glass/frame source.
		# Anchor the lower rim at ground instead of scaling through the floor.
		pod.scale=Vector3(1.8,1.7,1.8)
		pod.position.y=2.21
		_vitrine(Vector3(pod.position.x,0,pod.position.z))
	# An opaque dry deck keeps the exact tested support. Layered fascias and
	# drains add scale, without disguising its square collision boundary.
	for side in [-1.0,1.0]:
		_block("TheaterSideFascia",Vector3(side*6.005,.58,-20),Vector3(.025,.94,12.0),graphite)
		_block("TheaterFrontFascia",Vector3(side*3.8,.58,-13.99),Vector3(4.4,.94,.025),graphite)
		_block("TheaterFrontSeam",Vector3(side*3.8,1.08,-13.965),Vector3(4.4,.035,.035),alloy)
		for x in [2.3,4.7]:
			_block("TheaterAccessLamp",Vector3(side*x,.35,-13.96),Vector3(.40,.09,.035),amber)
	for side in [-1.0,1.0]:
		for z in [-8.0,-15.0,-25.0,-32.0]:
			_asset("diagnostic_cart",Vector3(side*8.7,0,z),PI*.5 if side>0 else -PI*.5)
		for z in [-9.0,-19.0,-29.0]:
			var equipment:Node3D=preload("res://assets/props/medical_wall_unit_tripo_20261008.glb").instantiate()
			equipment.name="ClinicalWallEquipment"
			equipment.position=Vector3(side*14.7,1.1,z)
			equipment.rotation.y=PI*.5 if side<0 else -PI*.5
			add_child(equipment)
		for z in [-15.7,-24.3]:
			_asset("diagnostic_cart",Vector3(side*4.7,1.2,z))
		# Coolant troughs stay outside the authored dry navigation/interaction
		# lanes. Their water comes from the shared planar reflection space.
		for x in [side*8.8,side*13.2]:
			_block("CoolantCoping",Vector3(x,.13,-20),Vector3(.18,.23,25.2),alloy)
		for z in [-7.4,-32.6]:
			_block("CoolantEndCap",Vector3(side*11,.13,z),Vector3(4.5,.23,.18),alloy)
		for z in [-9.0,-14.0,-26.0,-31.0]:
			_block("DrainSafetyMarker",Vector3(side*8.65,.035,z),Vector3(.10,.025,.48),amber)
	# Perimeter floor tiles reveal scale and surface direction without hiding
	# the collider or adding obstacles to the tested3.2m access ramp.
	for x in [-14.8,-7.7,7.7,14.8]:
		for z in range(-37,-2,3):
			_block("ClinicalFloorPanel",Vector3(x,.011,z),Vector3(1.30,.016,2.94),pearl)
	for side in [-1.0,1.0]:
		var key:=OmniLight3D.new();key.name="ClinicalReflectedFill"
		key.position=Vector3(side*9.0,4.0,-21)
		key.light_color=Color(.78,.86,.92);key.light_energy=.65
		key.omni_range=14.0;key.omni_attenuation=.65;key.shadow_enabled=false;add_child(key)
	# Ceiling service coffers and articulated suspension give the room a
	# clinical overhead silhouette rather than an unbroken dark cube.
	for z in [-5.0,-11.0,-17.0,-23.0,-29.0,-35.0]:
		_block("CeilingServiceSpine",Vector3(0,9.52,z),Vector3(31.3,.28,.34),alloy)
		for x in [-11.0,-5.0,5.0,11.0]:
			_block("CeilingCassette",Vector3(x,9.68,z+1.5),Vector3(5.7,.16,2.4),pearl)
	var world:Node=get_node_or_null("/root/HyperAnimeWorldManager")
	if world:
		_dress_sealed_exit(room)
		_dress_stasis_display(room)
		_dress_contract_plinth(room)
		world.adapter.convert_tree(self)
		if terminal:
			for mesh in terminal.find_children("*","MeshInstance3D",true,false):
				if mesh.name in ["EchoSignalConsole_Static_Graphite","EchoSignalConsole_Static_Titanium"]:
					for surface in mesh.mesh.get_surface_count():
						var converted:Material=mesh.get_active_material(surface)
						# The terminal can still hold its original material here:
						# the main world's adapter runs after this room is built.
						var source:StandardMaterial3D=converted as StandardMaterial3D
						if converted and converted.has_meta("hyper_source"):source=converted.get_meta("hyper_source")
						if source:
							var finish:=_architectural_finish(source)
							# These authored linear alloy values enter a source_color
							# uniform,so convert to its expected sRGB input first.
							finish.set_shader_parameter("base_color",(Color(.18,.22,.28) if mesh.name=="EchoSignalConsole_Static_Graphite" else Color(.34,.39,.44)).linear_to_srgb())
							finish.set_shader_parameter("minimum_roughness",.45)
							mesh.set_surface_override_material(surface,finish)
		_tone_equipment(chair)
		# Clean4K source retains actual PBR channels under the clinical
		# continuous-light finish; no threshold coating or repainted texture.
		for mesh in scanner.find_children("*","MeshInstance3D",true,false):
			for surface in mesh.mesh.get_surface_count():
				var converted:Material=mesh.get_active_material(surface)
				var source:StandardMaterial3D=converted.get_meta("hyper_source") if converted and converted.has_meta("hyper_source") else null
				if source:
					var finish:=_architectural_finish(source)
					finish.set_shader_parameter("minimum_roughness",.35)
					mesh.set_surface_override_material(surface,finish)
		room._surgical_light.light_color=Color(.99,.98,.94)
		# Clinical walls need continuous rough reflection, rather than a flat
		# cel band over a six-metre panel. Preserve the shared renderer and
		# existing hero textures; use this authored finish only on the kit's
		# opaque architectural ceramic/metal slots.
		for mesh in find_children("*","MeshInstance3D",true,false):
			var override:Material=mesh.material_override
			var override_source:StandardMaterial3D=override.get_meta("hyper_source") if override and override.has_meta("hyper_source") else null
			if override_source in [pearl,graphite,alloy,clinical_white]:mesh.material_override=_architectural_finish(override_source)
			for surface in mesh.mesh.get_surface_count():
				var m:Material=mesh.get_active_material(surface)
				var source:StandardMaterial3D=m.get_meta("hyper_source") if m and m.has_meta("hyper_source") else null
				if source and source.resource_name in ["ClinicalPearlCeramic","GraphiteGaskets","BrushedSurgicalAlloy"]:
					var finish:=_architectural_finish(source)
					if source.resource_name=="ClinicalPearlCeramic":finish.set_shader_parameter("base_color",Color(.40,.46,.52))
					if source.resource_name=="GraphiteGaskets":finish.set_shader_parameter("base_color",Color(.10,.14,.20).linear_to_srgb())
					mesh.set_surface_override_material(surface,finish)
				elif source and source.resource_name=="SurgicalTaskLight":
					mesh.set_surface_override_material(surface,monitor_material)
		for mesh in shell.find_children("*","MeshInstance3D",true,false):
			for surface in mesh.mesh.get_surface_count():
				var m:Material=mesh.get_active_material(surface)
				if not m or not m.has_meta("hyper_source"):continue
				var source:StandardMaterial3D=m.get_meta("hyper_source")
				# Retain the shared adapter's actual service-strip emission.
				if source.emission_enabled:continue
				if source.transparency==BaseMaterial3D.TRANSPARENCY_DISABLED:
					var finish:=_architectural_finish(source)
					finish.set_shader_parameter("minimum_roughness",.45)
					finish.set_shader_parameter("clean_clinical_coating",false)
					mesh.set_surface_override_material(surface,finish)

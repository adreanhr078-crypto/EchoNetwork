extends Node3D

## Existing Tripo room, measured core and authoritative route are preserved.
## Replaces rejected soft surfaces with the accepted laboratory kit and the
## existing precise Tripo-textured vessel. No new generation or progression.
const TILE=preload("res://assets/environments/lab_clinical_cp45/clinical_wall_p2_4k.glb")
const POD=preload("res://assets/environments/decon_clinical/decon_pod_precision_pbr.glb")
const ARCH=preload("res://assets/environments/decon_clinical/decon_sterilizer_precision.glb")
const SPINE=preload("res://assets/environments/decon_clinical/decon_service_spine_precision.glb")
const LAMP=preload("res://assets/environments/decon_clinical/decon_service_light_precision.glb")
const GAUGE=preload("res://assets/environments/decon_clinical/decon_pressure_gauge_precision.glb")
const KIT=preload("res://scripts/environment/specimen_mechanical_dressing.gd")
const EMITTER=preload("res://shaders/decon_device_emitter.gdshader")
var owner_room:Node3D
var _emitters:Array[ShaderMaterial]=[]
var _finishes:Dictionary={}
var _readout:ShaderMaterial

static func evidence_paths()->PackedStringArray:
	return PackedStringArray(["res://scripts/environment/decon_precision_refinement.gd","res://scripts/environment/room_reactive_moisture.gd","res://shaders/decon_device_emitter.gdshader","res://shaders/room_condensation_water.gdshader",TILE.resource_path,POD.resource_path,ARCH.resource_path,SPINE.resource_path,LAMP.resource_path,GAUGE.resource_path,"res://assets/environments/decon_clinical/decon_whole_v2_authored_core.glb"])

func _ready()->void:
	var prototype:Node3D=TILE.instantiate()
	var draw:MeshInstance3D=prototype.find_children("*","MeshInstance3D",true,false)[0]
	var tile:Mesh=draw.mesh
	var source:StandardMaterial3D=tile.surface_get_material(0)
	var skin:ShaderMaterial=KIT._texture_finish(source,owner_room)
	skin.set_shader_parameter("minimum_roughness",.52)
	skin.set_shader_parameter("surface_roughness",.86)
	skin.set_shader_parameter("metalness",.12)
	skin.set_shader_parameter("normal_strength",.45)
	skin.set_shader_parameter("base_color",Color(.55,.53,.49))
	var groups:Dictionary={"West":[],"East":[],"North":[],"South":[]}
	for side in [-1.0,1.0]:
		var label:="West" if side<0 else "East"
		for i in 10:
			for y in [1.8,5.4]:
				groups[label].append(_fit(tile,Vector3(side*10.2,y,-1.6-i*3.2),Vector3(3.12,3.54,.2),PI*.5 if side<0 else -PI*.5))
		for i in 3:
			for y in [1.8,5.4]:
				groups.North.append(_fit(tile,Vector3(side*(1.025+(i+.5)*3.025),y,-32.0),Vector3(2.945,3.54,.2),0.0))
				groups.South.append(_fit(tile,Vector3(side*(1.3+(i+.5)*2.9333),y,.0),Vector3(2.8533,3.54,.2),PI))
	groups.North.append(_fit(tile,Vector3(0,5.0,-32),Vector3(2.05,4.4,.2),0))
	groups.South.append(_fit(tile,Vector3(0,5.2,0),Vector3(2.6,4.0,.2),PI))
	for label in groups:_batch("Precision"+label+"ServicePanels",tile,groups[label],skin)
	prototype.free()
	var spines:Array=[];var lamps:Array=[]
	for side in [-1.0,1.0]:
		var basis:=Basis(Vector3.UP,PI*.5 if side<0 else -PI*.5)
		for i in 11:spines.append(Transform3D(basis,Vector3(side*10.2,0,-.18-i*3.164)))
		for i in 10:
			for y in [.44,6.67]:lamps.append(Transform3D(basis,Vector3(side*10.07,y,-1.76-i*3.164)))
	_batch("BatchedPrecisionServiceSpines",_manufactured_mesh(SPINE),spines)
	_batch("BatchedWarmServiceLights",_manufactured_mesh(LAMP),lamps)
	for i in 2:
		var arch:Node3D=ARCH.instantiate();arch.name="MeasuredSterilizationFrame_%d"%i
		arch.position=Vector3(0,0,-3.5-i*3.0);add_child(arch);_manufactured_finish(arch)
	var pod_finish:ShaderMaterial
	var gauges:Array=[];var displays:Array=[]
	for body in owner_room.find_children("QuarantinePod_*","StaticBody3D",false,false):
		var pod:Node3D=POD.instantiate();pod.name=String(body.name)+"PreciseVessel"
		pod.position=body.position-Vector3(0,1.4,0)
		pod.rotation.y=PI*.5 if body.position.x<0 else -PI*.5
		add_child(pod)
		for mesh in pod.find_children("*","MeshInstance3D",true,false):
			mesh.layers|=1<<18
			if pod_finish==null:
				pod_finish=KIT._texture_finish(mesh.mesh.surface_get_material(0),owner_room)
				pod_finish.set_shader_parameter("minimum_roughness",.56)
				pod_finish.set_shader_parameter("surface_roughness",.84)
				pod_finish.set_shader_parameter("metalness",.28)
				pod_finish.set_shader_parameter("normal_strength",.5)
			mesh.material_override=pod_finish
		var basis:=Basis(Vector3.UP,PI*.5 if body.position.x<0 else -PI*.5)
		var center:=Vector3(-5.10 if body.position.x<0 else 5.10,1.82,body.position.z+.55)
		gauges.append(Transform3D(basis,center))
		displays.append(Transform3D(basis,center+basis*Vector3(0,0,.085)))
	_batch("SixPressureInstrumentHousings",_manufactured_mesh(GAUGE),gauges)
	var panel:=QuadMesh.new();panel.size=Vector2(.49,.28)
	_readout=ShaderMaterial.new();_readout.shader=preload("res://shaders/decon_pressure_readout.gdshader")
	_batch("SixLivePressureDisplays",panel,displays,_readout)
	var grates:Array=[];var grate:Mesh=KIT._mesh(KIT.TRAY)
	for x in [-4.7,4.7]:
		for z in [-11.7,-16.0,-20.5]:grates.append(_fit(grate,Vector3(x,0,z),Vector3(.35,.012,3.1),0))
	_batch("SixRecessedCondensateDrains",grate,grates)
	# Existing fixtures remain the light owners. Environment-only fills do
	# not wash out the player and do not add another shadow-map budget.
	for label in ["ClinicalCeilingBounce","ClinicalExitBounce"]:
		var light:OmniLight3D=owner_room.get_node(label)
		light.light_color=Color(.96,.80,.63)
		light.light_energy=.65 if label=="ClinicalCeilingBounce" else .42
	for child in owner_room.get_node("ServiceLighting").get_children():
		if child is OmniLight3D:
			child.light_color=Color(.98,.85,.68)
			child.light_energy=.52
		elif child is MeshInstance3D:
			if not _finishes.has("WarmFixture"):
				_finishes.WarmFixture=_finishes.ServiceLamp
			child.material_override=_finishes.WarmFixture
	var moisture:Node3D=preload("res://scripts/environment/room_reactive_moisture.gd").new()
	moisture.name="ReactiveMoisture";moisture.owner_room=owner_room;add_child(moisture)
	_refresh()

func _process(_delta:float)->void:_refresh()

func _refresh()->void:
	for material in _emitters:
		material.set_shader_parameter("elapsed",owner_room._uv_timer)
		material.set_shader_parameter("motion",0.0 if owner_room.reduced_motion else 1.0)
		material.set_shader_parameter("cleared",1.0 if owner_room.override_done else 0.0)
	if _readout:
		_readout.set_shader_parameter("elapsed",owner_room._mist_time)
		_readout.set_shader_parameter("motion",0.0 if owner_room.reduced_motion else 1.0)
		_readout.set_shader_parameter("cleared",owner_room.override_done)

func _manufactured_finish(parent:Node3D)->void:
	for draw in parent.find_children("*","MeshInstance3D",true,false):
		draw.layers|=1<<18
		for index in draw.mesh.get_surface_count():
			var source:StandardMaterial3D=draw.mesh.surface_get_material(index)
			draw.set_surface_override_material(index,_source_finish(source))

func _source_finish(source:StandardMaterial3D)->ShaderMaterial:
	var label:=source.resource_name
	if not _finishes.has(label):
		var finish:ShaderMaterial
		if label in ["UVEmitter","ServiceLamp","Signal"]:
			finish=ShaderMaterial.new();finish.shader=EMITTER
			finish.set_shader_parameter("device_role",0 if label=="UVEmitter" else (1 if label=="ServiceLamp" else 2))
			_emitters.append(finish)
		else:
			finish=KIT._finish(source.albedo_color,source.metallic*.7,source.roughness)
			finish.set_shader_parameter("minimum_roughness",.46)
		_finishes[label]=finish
	return _finishes[label]

func _manufactured_mesh(scene:PackedScene)->Mesh:
	var prototype:Node3D=scene.instantiate()
	var draw:MeshInstance3D=prototype.find_children("*","MeshInstance3D",true,false)[0]
	var mesh:Mesh=draw.mesh.duplicate()
	for i in mesh.get_surface_count():mesh.surface_set_material(i,_source_finish(mesh.surface_get_material(i)))
	prototype.free();return mesh

func _fit(mesh:Mesh,center:Vector3,size:Vector3,yaw:float)->Transform3D:
	var bounds:=mesh.get_aabb()
	var basis:=Basis(Vector3.UP,yaw)*Basis.from_scale(size/bounds.size)
	return Transform3D(basis,center-basis*bounds.get_center())

func _batch(label:String,mesh:Mesh,placements:Array,finish:ShaderMaterial=null)->void:
	var batch:=MultiMesh.new();batch.transform_format=MultiMesh.TRANSFORM_3D
	batch.mesh=mesh;batch.instance_count=placements.size()
	var bounds:=AABB()
	for i in placements.size():
		var transform:Transform3D=placements[i];batch.set_instance_transform(i,transform)
		var current:AABB=transform*mesh.get_aabb();bounds=current if i==0 else bounds.merge(current)
	batch.custom_aabb=bounds
	var draw:=MultiMeshInstance3D.new();draw.name=label;draw.multimesh=batch
	draw.material_override=finish;draw.layers|=1<<18;add_child(draw)

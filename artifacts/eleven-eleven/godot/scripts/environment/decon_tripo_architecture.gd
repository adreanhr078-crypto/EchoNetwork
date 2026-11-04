extends RefCounted

## The complete generated room supplies an editable measured kit. Its source
## layout is retained in production; native gameplay owns the assembled route.
const SHELL=preload("res://assets/environments/decon_clinical/decon_shell_whole_pbr.glb")
const ARCH=preload("res://assets/environments/decon_clinical/sterilization_arch_pbr4k.glb")
const POD=preload("res://assets/environments/decon_clinical/decon_pod_precision_pbr.glb")
const KIT=preload("res://scripts/environment/specimen_mechanical_dressing.gd")

static func install(room:Node3D)->void:
	if room.has_node("DeconTripoArchitecture"):return
	var kit:=Node3D.new();kit.name="DeconTripoArchitecture";room.add_child(kit)
	var shell:Node3D=SHELL.instantiate();shell.name="MeasuredGeneratedPerimeter";kit.add_child(shell)
	_materials(shell,room,true)
	# The outer source footprint fits 24x32m. Its service wall skin stands
	# inside that footprint; guard it physically while keeping the authored
	# staircase, central route, terminal and exit positions unchanged.
	_guard(kit,"GeneratedWallWest",Vector3(-10.3,3.6,-16),Vector3(.4,7.2,32))
	_guard(kit,"GeneratedWallEast",Vector3(10.3,3.6,-16),Vector3(.4,7.2,32))
	for side in [-1.0,1.0]:
		_guard(kit,"GeneratedWallNorthLeft" if side<0 else "GeneratedWallNorthRight",Vector3(side*5.725,3.6,-29.9),Vector3(8.75,7.2,.4))
	_guard(kit,"GeneratedWallExitHeader",Vector3(0,5.2,-29.9),Vector3(2.7,4,.4))
	for i in 2:
		var arch:Node3D=ARCH.instantiate();arch.name="SterilizationArch_%d"%i
		arch.position=Vector3(0,0,-3.5-i*3.0);kit.add_child(arch)
		_materials(arch,room,false)
		for label in ["DeconArchPillarL_%d","DeconArchPillarR_%d","DeconArchLintel_%d"]:
			for child in room.get_node(label%i).get_children():
				if child is MeshInstance3D:child.hide()
	for body in room.find_children("QuarantinePod_*","StaticBody3D",false,false):
		var pod:Node3D=POD.instantiate();pod.name=String(body.name)+"PressureVessel"
		pod.position=body.position-Vector3(0,1.4,0)
		pod.rotation.y=PI*.5 if body.position.x<0 else -PI*.5
		kit.add_child(pod);_materials(pod,room,false)
		for child in body.get_children():
			if not child is MeshInstance3D:continue
			if child.name in ["PodCap","PodBase"]:child.hide()
			elif child.name=="FilterCartridge":child.hide()
			else:child.scale=Vector3(.7,.83,.7)
	var prior:Node=room.get_node("DeconClinicalDressing")
	prior.get_node("TwelveQuarantinePressureSeals").hide()
	# Keep the watertight native hull as the backdrop to the source's service
	# recesses. The old intermediate cladding no longer covers the new skin.
	prior.get_node("ClinicalServiceWallBays").hide()
	_build_roof(kit)
	_finish_gate(room)
	var instruments:Node3D=preload("res://scripts/environment/decon_instrument_detail.gd").new()
	instruments.name="ClinicalInstrumentDetail";instruments.owner_room=room
	kit.add_child(instruments)

static func _materials(parent:Node3D,room:Node3D,perimeter:bool)->void:
	for draw in parent.find_children("*","MeshInstance3D",true,false):
		draw.layers|=1<<18
		for surface in draw.mesh.get_surface_count():
			var source:StandardMaterial3D=draw.mesh.surface_get_material(surface)
			if source==null:continue
			var finish:ShaderMaterial=KIT._texture_finish(source,room)
			# The generated roughness map reads as wet chrome under the actual
			# clinical fixtures. Retain its PBR detail with a dry alloy response.
			finish.set_shader_parameter("minimum_roughness",.60)
			finish.set_shader_parameter("surface_roughness",.78)
			finish.set_shader_parameter("metalness",source.metallic*.35)
			finish.set_shader_parameter("normal_strength",source.normal_scale*.6)
			finish.set_shader_parameter("perimeter_only",perimeter)
			finish.set_shader_parameter("perimeter_origin",room.global_position)
			finish.set_shader_parameter("perimeter_limits",Vector4(9.45,-28.9,1.35,3.2))
			draw.set_surface_override_material(surface,finish)

static func _guard(parent:Node3D,label:String,point:Vector3,size:Vector3)->void:
	var body:=StaticBody3D.new();body.name=label;body.position=point
	var collision:=CollisionShape3D.new();collision.name="CollisionShape3D"
	var box:=BoxShape3D.new();box.size=size;collision.shape=box
	body.add_child(collision);parent.add_child(body)

static func _fit(mesh:Mesh,center:Vector3,size:Vector3)->Transform3D:
	var box:=mesh.get_aabb();var basis:=Basis.from_scale(size/box.size)
	return Transform3D(basis,center-basis*box.get_center())

static func _build_roof(parent:Node3D)->void:
	var trim:Mesh=KIT._mesh(KIT.TRIM)
	var beams:Array[Transform3D]=[]
	for z in [-2.0,-8.0,-14.0,-20.0,-26.0,-30.0]:
		beams.append(_fit(trim,Vector3(0,6.85,z),Vector3(20.2,.26,.18)))
	KIT._batch(parent,"SixStructuralCeilingBays",trim,beams)
	var panel:Mesh=KIT._mesh(KIT.PANEL)
	var box:=panel.get_aabb()
	var basis:=Basis(Vector3.RIGHT,PI*.5)*Basis.from_scale(Vector3(5.5/box.size.x,4.2/box.size.y,.12/box.size.z))
	var cassettes:Array[Transform3D]=[]
	for z in [-4.5,-11.5,-18.5,-25.5]:
		cassettes.append(Transform3D(basis,Vector3(0,7.09,z)-basis*box.get_center()))
	KIT._batch(parent,"FourExtractionCeilingCassettes",panel,cassettes)

static func _finish_gate(room:Node3D)->void:
	for child in room._gate.get_children():
		if child is MeshInstance3D:child.hide()
	var panel:Mesh=KIT._mesh(KIT.PANEL)
	KIT._batch(room._gate,"MeasuredMovingClinicalDoor",panel,[_fit(panel,Vector3.ZERO,Vector3(2.0,2.8,.2))])

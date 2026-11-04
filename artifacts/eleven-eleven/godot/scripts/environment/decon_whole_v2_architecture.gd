extends RefCounted

## Default refined room presentation. Native solids, interaction, gate animation,
## state, clocks and saved progress remain owned by the quarantine wing.
const STATIC_PATH="res://assets/environments/decon_clinical/decon_whole_v2_authored_core.glb"
const GATE=preload("res://assets/environments/decon_clinical/decon_whole_v2_gate.glb")
const TERMINAL=preload("res://assets/environments/decon_clinical/decon_whole_v2_terminal.glb")
const BASE=preload("res://assets/environments/decon_clinical/decon_whole_v2_basecolor.png")
const NORMAL=preload("res://assets/environments/decon_clinical/decon_whole_v2_normal.png")
const ORM=preload("res://assets/environments/decon_clinical/decon_whole_v2_orm.png")
const FINISH=preload("res://shaders/clinical_architecture_surface.gdshader")
const GRAIN=preload("res://assets/environments/maintenance_jutsu_v1_Maintenance ceramic grain 512.png")

static func install(room:Node3D)->void:
	if room.has_node("DeconTripoArchitecture"):return
	var kit:=Node3D.new();kit.name="DeconTripoArchitecture"
	kit.set_meta("source_revision","whole-v2-refined-20261029")
	room.add_child(kit)
	var finish:=_finish()
	var detail_control:=OS.get_cmdline_user_args().has("--decon-v2-full-detail-control")
	var shell_resource:PackedScene=load("res://assets/environments/decon_clinical/decon_whole_v2_static_full_detail.glb" if detail_control else STATIC_PATH)
	var shell:Node3D=shell_resource.instantiate();shell.name="WholeV2MeasuredArchitecture"
	kit.add_child(shell);_apply(shell,finish)
	if not detail_control:
		var refinement:Node3D=preload("res://scripts/environment/decon_precision_refinement.gd").new()
		refinement.name="PrecisionSurfaceRefinement";refinement.owner_room=room;kit.add_child(refinement)
	# Hide visual leaves only; keep every native body and collision active.
	for label in ["Floor","WestWall","EastWall","SouthWallWest","SouthWallEast","SouthLintel","NorthWallWest","NorthWallEast","NorthLintel","ObservationCatwalkDeck","CatwalkRailNorth","CatwalkRailSouth","CatwalkStairSupport","CatwalkStairLanding"]:
		_hide_meshes(room.get_node(label))
	for step in 11:_hide_meshes(room.get_node("CatwalkStair_%d"%step))
	for i in 2:
		for label in ["DeconArchPillarL_%d","DeconArchPillarR_%d","DeconArchLintel_%d"]:
			_hide_meshes(room.get_node(label%i))
	# This dedicated node contains decoration only. Bounced lights belong to
	# the room itself and remain visible. Never hide an interaction ancestor.
	room.get_node("DeconClinicalDressing").hide()
	for body in room.find_children("QuarantinePod_*","StaticBody3D",false,false):
		for child in body.get_children():
			if not child is MeshInstance3D:continue
			if child.name in ["PodCap","PodBase","FilterCartridge"]:child.hide()
			else:child.scale=Vector3(.7,.83,.7)
	_hide_meshes(room._gate)
	var gate:Node3D=GATE.instantiate();gate.name="WholeV2MovingGate"
	room._gate.add_child(gate);_apply(gate,finish)
	# Preserve the existing live screen, interaction area and terminal light.
	_hide_meshes(room._terminal_body.get_node("Prop"))
	var terminal:Node3D=TERMINAL.instantiate();terminal.name="WholeV2TerminalCase"
	room._terminal_body.add_child(terminal);_apply(terminal,finish)
	# Generated inner wall skins retain the previously verified guards. The
	# west stair and central route stay inside the same physical envelope.
	_guard(kit,"GeneratedWallWest",Vector3(-10.3,3.6,-16),Vector3(.5,7.2,32))
	_guard(kit,"GeneratedWallEast",Vector3(10.3,3.6,-16),Vector3(.5,7.2,32))
	for side in [-1.0,1.0]:
		_guard(kit,"GeneratedWallNorthLeft" if side<0 else "GeneratedWallNorthRight",Vector3(side*5.725,3.6,-29.9),Vector3(8.75,7.2,.4))
	_guard(kit,"GeneratedWallExitHeader",Vector3(0,5.2,-29.9),Vector3(2.7,4,.4))
	var detail:Node3D=preload("res://scripts/environment/decon_instrument_detail.gd").new()
	detail.name="ClinicalInstrumentDetail";detail.owner_room=room;kit.add_child(detail)

static func _hide_meshes(parent:Node)->void:
	if parent is MeshInstance3D:parent.hide()
	for child in parent.find_children("*","MeshInstance3D",true,false):child.hide()

static func _guard(parent:Node3D,label:String,point:Vector3,size:Vector3)->void:
	var body:=StaticBody3D.new();body.name=label;body.position=point
	var collision:=CollisionShape3D.new();collision.name="CollisionShape3D"
	var box:=BoxShape3D.new();box.size=size;collision.shape=box
	body.add_child(collision);parent.add_child(body)

static func _apply(parent:Node3D,finish:ShaderMaterial)->void:
	for draw in parent.find_children("*","MeshInstance3D",true,false):
		draw.layers|=1<<18
		draw.material_override=finish

static func _finish()->ShaderMaterial:
	var result:=ShaderMaterial.new();result.shader=FINISH
	for slot in ["color","normal","roughness","metallic","ao"]:
		result.set_shader_parameter("has_"+slot+"_map",true)
	result.set_shader_parameter("base_color",Color(.72,.70,.67))
	result.set_shader_parameter("color_map",BASE)
	result.set_shader_parameter("normal_map",NORMAL)
	result.set_shader_parameter("roughness_map",ORM)
	result.set_shader_parameter("metallic_map",ORM)
	result.set_shader_parameter("ao_map",ORM)
	result.set_shader_parameter("combined_rm_map",true)
	result.set_shader_parameter("roughness_channel",Vector4(0,1,0,0))
	result.set_shader_parameter("metallic_channel",Vector4(0,0,1,0))
	result.set_shader_parameter("ao_channel",Vector4(1,0,0,0))
	result.set_shader_parameter("finish_grain",GRAIN)
	result.set_shader_parameter("ceramic_finish",false)
	result.set_shader_parameter("metalness",.25)
	result.set_shader_parameter("surface_roughness",.90)
	result.set_shader_parameter("minimum_roughness",.56)
	result.set_shader_parameter("normal_strength",0.0 if OS.get_cmdline_user_args().has("--decon-v2-normal-control") else .70)
	return result

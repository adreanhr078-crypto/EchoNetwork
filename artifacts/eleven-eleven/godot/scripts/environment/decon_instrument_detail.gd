extends Node3D

## Equipment-only presentation. The existing room clock, quarantine state and
## accessibility settings own every update; no independent progression/timer.
var owner_room:Node3D
var _readout:ShaderMaterial
var _glass:ShaderMaterial

func _ready()->void:
	_readout=ShaderMaterial.new();_readout.shader=preload("res://shaders/decon_pressure_readout.gdshader")
	for child in owner_room._terminal_body.get_children():
		if not child is MeshInstance3D or not child.mesh is BoxMesh:continue
		if not child.mesh.size.is_equal_approx(Vector3(.9,.6,.05)):continue
		var face:=MeshInstance3D.new();face.name="PressureReadout"
		var quad:=QuadMesh.new();quad.size=Vector2(.82,.52);face.mesh=quad
		face.position.z=.026;face.material_override=_readout
		face.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;child.add_child(face)
	_glass=ShaderMaterial.new();_glass.shader=preload("res://shaders/decon_condensation.gdshader")
	for body in owner_room.find_children("QuarantinePod_*","StaticBody3D",false,false):
		for child in body.get_children():
			if child is MeshInstance3D and child.mesh is CylinderMesh and child.name!="FilterCartridge":
				child.material_override=_glass
	_process(0.0)

func _process(_delta:float)->void:
	refresh()

func refresh()->void:
	var motion:=0.0 if owner_room.reduced_motion else 1.0
	_readout.set_shader_parameter("elapsed",owner_room._mist_time)
	_readout.set_shader_parameter("motion",motion)
	_readout.set_shader_parameter("cleared",owner_room.override_done)
	_glass.set_shader_parameter("elapsed",owner_room._mist_time)
	_glass.set_shader_parameter("motion",motion)
	_glass.set_shader_parameter("moisture",owner_room._mist_amount)

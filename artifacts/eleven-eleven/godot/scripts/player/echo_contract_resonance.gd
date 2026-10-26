extends Node3D

## Violet emergence at the seated wing root and its anatomical left hand.
## Pure attached presentation: no avatar skin, rest, bone or source key writes.
const AuraShader=preload("res://engine_visuals/shaders/contract_resonance.gdshader")
var attachment: RefCounted
var root_aura:MeshInstance3D
var hand_aura:MeshInstance3D
var arm_aura:MeshInstance3D
var hand_light:OmniLight3D
var root_light:OmniLight3D
var material:ShaderMaterial
var hand_bone:=-1
var arm_bone:=-1

func _ready() -> void:
	material=ShaderMaterial.new();material.shader=AuraShader
	root_aura=_orb("WingRootResonance",.13)
	hand_aura=_orb("WingSideHandResonance",.115)
	arm_aura=MeshInstance3D.new();arm_aura.name="WingSideForearmResonance"
	var sleeve:=CylinderMesh.new();sleeve.top_radius=.075;sleeve.bottom_radius=.065;sleeve.height=1.0;sleeve.radial_segments=16;sleeve.rings=2
	arm_aura.mesh=sleeve;arm_aura.material_override=material;arm_aura.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(arm_aura)
	hand_light=_light(hand_aura,.42)
	root_light=_light(root_aura,.50)
	hide()

func _orb(label:String,radius:float) -> MeshInstance3D:
	var mesh:=MeshInstance3D.new();mesh.name=label
	var sphere:=SphereMesh.new();sphere.radius=radius;sphere.height=radius*2.0;sphere.radial_segments=20;sphere.rings=10
	mesh.mesh=sphere;mesh.material_override=material;mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(mesh)
	return mesh

func _light(parent:Node3D,reach:float) -> OmniLight3D:
	var light:=OmniLight3D.new();light.light_color=Color(.48,.055,1.0);light.omni_range=reach;light.light_energy=0;light.shadow_enabled=false;parent.add_child(light)
	return light

func configure(socket:RefCounted) -> void:
	attachment=socket
	if not is_instance_valid(attachment.skeleton):return
	hand_bone=attachment.skeleton.find_bone("LeftHand")
	arm_bone=attachment.skeleton.find_bone("LeftForeArm")

func present(time:float,reveal:float,strength:float,reduced:bool) -> void:
	if not attachment or not attachment.contract_is_sealed() or not attachment.is_manifested:
		hide();return
	var rig:Skeleton3D=attachment.skeleton
	if not is_instance_valid(rig):hide();return
	show()
	var pulse:float=0.0 if reduced else exp(-pow((reveal-.25)/.23,2.0))
	material.set_shader_parameter("local_time",time)
	material.set_shader_parameter("intensity",minf(strength,1.35))
	material.set_shader_parameter("reduced_motion",reduced)
	material.set_shader_parameter("root_pulse",pulse)
	# World-sized shells keep source-avatar scaling out of the effect budget.
	root_aura.global_transform=Transform3D(global_basis.orthonormalized(),global_position)
	root_light.light_energy=.16+(.22*pulse)
	hand_aura.visible=hand_bone>=0
	arm_aura.visible=hand_bone>=0 and arm_bone>=0
	if hand_bone<0:return
	var hand:Transform3D=rig.global_transform*rig.get_bone_global_pose(hand_bone)
	hand_aura.global_transform=Transform3D(hand.basis.orthonormalized(),hand.origin)
	hand_light.light_energy=.55+(.20*pulse)
	if arm_bone<0:return
	var elbow:Vector3=rig.to_global(rig.get_bone_global_pose(arm_bone).origin)
	var forearm:Vector3=hand.origin-elbow
	var length:=forearm.length()
	if length<.001:arm_aura.hide();return
	var axis:=Basis(Quaternion(Vector3.UP,forearm/length))
	arm_aura.global_transform=Transform3D(axis.scaled(Vector3(1,length*.75,1)),elbow.lerp(hand.origin,.60))

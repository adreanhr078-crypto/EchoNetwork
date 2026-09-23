extends Node3D

const IDENTIFIER := "EX-011"
const NECK_BONE := "bone_6"

func _ready() -> void:
	call_deferred("_attach_identifier")

func _attach_identifier() -> void:
	var skeleton := find_child("Skeleton3D", true, false) as Skeleton3D
	if not skeleton:
		push_warning("Echo skin identifier could not find the imported Skeleton3D.")
		return
	var neck_index := skeleton.find_bone(NECK_BONE)
	if neck_index < 0:
		push_warning("Echo skin identifier could not find the neck attachment bone.")
		return
	var attachment := BoneAttachment3D.new()
	attachment.name = "EX011SkinAttachment"
	attachment.bone_name = skeleton.get_bone_name(neck_index)
	skeleton.add_child(attachment)

	var mark := MeshInstance3D.new()
	mark.name = "EX011DirectSkinMark"
	var lettering := TextMesh.new()
	lettering.text = IDENTIFIER
	lettering.font_size = 32
	lettering.pixel_size = 0.00035
	lettering.depth = 0.0002
	lettering.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lettering.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mark.mesh = lettering
	mark.position = Vector3(0.055, 0.012, 0.0)
	mark.rotation.y = PI * 0.5
	mark.material_override = _ink_material()
	mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	attachment.add_child(mark)

func _ink_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.22, 0.045, 0.065, 1.0)
	material.roughness = 0.96
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material

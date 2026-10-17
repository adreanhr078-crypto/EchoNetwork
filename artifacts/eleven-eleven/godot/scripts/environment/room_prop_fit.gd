extends RefCounted

## Fit an imported visual into its existing authored collision envelope.
## Read mesh bounds in root-local coordinates; never change the source GLB.
static func fit(model: Node3D,size: Vector3,center: Vector3) -> bool:
	var bounds := AABB()
	var found := false
	for visual in model.find_children("*","MeshInstance3D",true,false):
		var local: AABB = model.global_transform.affine_inverse()*visual.global_transform*visual.get_aabb()
		bounds = bounds.merge(local) if found else local
		found = true
	if not found or bounds.size.x<=0.0001 or bounds.size.y<=0.0001 or bounds.size.z<=0.0001: return false
	model.scale = size/bounds.size
	model.position = center-bounds.get_center()*model.scale
	return true

extends SceneTree
## Diagnostic project only: never changes the game's physics or import settings.

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1:
		push_error("Expected one absolute report path")
		quit(2)
		return
	var report := {"status": "PASS_API_INSPECTION_ONLY", "engine": Engine.get_version_info(),
		"renderer": "headless", "rendering_acceptance": "UNVERIFIED", "classes": {}}
	var names := ["Skeleton3D", "AnimationPlayer", "SkeletonModifier3D", "SpringBoneSimulator3D",
		"SpringBoneCollisionCapsule3D", "SpringBoneCollisionSphere3D", "LookAtModifier3D",
		"TwoBoneIK3D", "SkeletonIK3D", "SoftBody3D", "PhysicalBoneSimulator3D"]
	for class_id in names:
		var available := ClassDB.class_exists(class_id)
		var entry := {"available": available, "properties": [], "methods": []}
		if available:
			for prop in ClassDB.class_get_property_list(class_id, true):
				entry.properties.append(str(prop.name))
			for method in ClassDB.class_get_method_list(class_id, true):
				entry.methods.append(str(method.name))
		report.classes[class_id] = entry
	var file := FileAccess.open(args[0], FileAccess.WRITE)
	if file == null:
		push_error("Cannot write API report")
		quit(2)
		return
	file.store_string(JSON.stringify(report, "\t") + "\n")
	file.close()
	print("CHARACTER_LAB_API_PASS " + str(Engine.get_version_info().string))
	quit(0)

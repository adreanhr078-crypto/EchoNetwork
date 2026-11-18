extends SceneTree

const ENV := "res://scenes/environment/"
const GROUPS := ["maintenance_stormworks", "security_checkpoint_room", "specimen_containment_wing",
	"memory_archive_wing", "core_reactor_room", "decontamination_quarantine_wing",
	"mirror_chamber_room", "dr_kinja_lab_room", "hospital_bedside_room"]

func _initialize() -> void:
	call_deferred("_extract")

func _extract() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1:
		quit(2)
		return
	var dir := args[0]
	DirAccess.make_dir_recursive_absolute(dir)
	var catalog := []
	for name in GROUPS:
		var filename := "%s%s.tscn" % [ENV, name]
		var packed := load(filename) as PackedScene
		if packed == null:
			push_error("Could not load " + filename)
			quit(3)
			return
		var room := packed.instantiate() as Node3D
		root.add_child(room)
		room.process_mode = Node.PROCESS_MODE_DISABLED
		var report := {"name": name, "scene": filename, "meshes": 0, "colliders": [], "areas": [], "markers": [], "dependencies": ResourceLoader.get_dependencies(filename)}
		_walk(room, room, report)
		catalog.append(report)
		print("SOURCE_ROOM ", name, " mesh=", report.meshes, " collision=", report.colliders.size(), " areas=", report.areas.size())
		room.free()
	var file := FileAccess.open(dir.path_join("GodotRoomsSource.json"), FileAccess.WRITE)
	if file == null:
		quit(4)
		return
	file.store_string(JSON.stringify(catalog, ""))
	file.close()
	quit(0)

func _walk(room: Node3D, node: Node, report: Dictionary) -> void:
	if node is MeshInstance3D and node.mesh != null and node.is_visible_in_tree():
		report.meshes += 1
	if node is CollisionShape3D and node.shape != null and node.get_parent() is StaticBody3D:
		var shape: Shape3D = node.shape
		var item := {"path": String(room.get_path_to(node)), "disabled": node.disabled, "type": shape.get_class(), "transform": _transform(node.global_transform)}
		if shape is BoxShape3D:
			item["size"] = _vec(shape.size)
		elif shape is CapsuleShape3D or shape is CylinderShape3D:
			item["radius"] = shape.radius
			item["height"] = shape.height
		report.colliders.append(item)
	if node is Area3D:
		report.areas.append({"path": String(room.get_path_to(node)), "transform": _transform(node.global_transform), "monitoring": node.monitoring})
	if node is Marker3D:
		report.markers.append({"path": String(room.get_path_to(node)), "transform": _transform(node.global_transform)})
	for child in node.get_children():
		_walk(room, child, report)

func _transform(t: Transform3D) -> Array:
	return [_vec(t.basis.x), _vec(t.basis.y), _vec(t.basis.z), _vec(t.origin)]

func _vec(v: Vector3) -> Array:
	return [snappedf(v.x,0.00001), snappedf(v.y,0.00001), snappedf(v.z,0.00001)]

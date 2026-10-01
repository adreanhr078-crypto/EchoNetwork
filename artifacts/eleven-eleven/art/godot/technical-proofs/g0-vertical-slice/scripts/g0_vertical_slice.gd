extends Node3D

const INTERACTABLE_SCRIPT := preload("res://scripts/interactable.gd")

var player: CharacterBody3D
var objective_label: Label
var hint_label: Label
var status_label: Label
var quality_label: Label
var objective_state := 0
var quality_high := true
var interact_was_down := false
var quality_was_down := false
var reset_was_down := false
var nearest: Node3D
var room_environment: WorldEnvironment
var key_light: DirectionalLight3D
var authored_room: Node3D
var wake_capsule: Node3D


func _ready() -> void:
	_build_environment()
	_build_room()
	_build_player()
	_build_hud()
	print("G0_VERTICAL_SLICE_READY")
	if DisplayServer.get_name() == "headless":
		call_deferred("_headless_check")


func _process(_delta: float) -> void:
	_update_nearest()
	var interact_down := Input.is_key_pressed(KEY_E)
	if interact_down and not interact_was_down and nearest:
		nearest.call("activate")
	interact_was_down = interact_down

	var quality_down := Input.is_key_pressed(KEY_Q)
	if quality_down and not quality_was_down:
		quality_high = not quality_high
		_apply_quality()
	quality_was_down = quality_down

	var reset_down := Input.is_key_pressed(KEY_R)
	if reset_down and not reset_was_down:
		_reset_slice()
	reset_was_down = reset_down

	if player and player.global_position.y < -2.0:
		_reset_slice()


func _build_environment() -> void:
	room_environment = WorldEnvironment.new()
	room_environment.name = "Environment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#080d1b")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#60728c")
	environment.ambient_light_energy = 0.28
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = true
	environment.glow_intensity = 0.22
	environment.adjustment_enabled = true
	environment.adjustment_brightness = 1.02
	environment.adjustment_contrast = 1.12
	environment.adjustment_saturation = 0.86
	room_environment.environment = environment
	add_child(room_environment)

	key_light = DirectionalLight3D.new()
	key_light.name = "KeyLight"
	key_light.rotation_degrees = Vector3(-54.0, -32.0, 0.0)
	key_light.light_color = Color("#e0d9d0")
	key_light.light_energy = 0.68
	key_light.shadow_enabled = true
	add_child(key_light)

	_add_light(Vector3(-3.8, 3.8, 5.2), Color("#58caff"), 1.55, 6.4)
	_add_light(Vector3(3.8, 3.2, 0.5), Color("#6ad8ff"), 1.2, 5.8)
	_add_light(Vector3(0.0, 3.0, -9.2), Color("#ff315f"), 1.55, 5.6)
	_add_light(Vector3(0.0, 2.2, 7.4), Color("#ff8b55"), 0.75, 4.2)


func _build_room() -> void:
	# Invisible fallback shell provides deterministic collision around the authored
	# 12 x 24 metre Sector 11 corridor. Its visible meshes are hidden after import.
	_add_box("RoomFloor", Vector3(0.0, -0.15, 0.0), Vector3(12.0, 0.3, 24.0), Color("#11192d"), true)
	_add_box("BackWall", Vector3(0.0, 3.1, -11.85), Vector3(12.0, 6.2, 0.3), Color("#202b46"), true)
	_add_box("LeftWall", Vector3(-5.85, 3.1, 0.0), Vector3(0.3, 6.2, 24.0), Color("#18233d"), true)
	_add_box("RightWall", Vector3(5.85, 3.1, 0.0), Vector3(0.3, 6.2, 24.0), Color("#18233d"), true)
	_add_box("CeilingBeam", Vector3(0.0, 6.0, -1.6), Vector3(11.5, 0.25, 0.35), Color("#344369"), false)

	for x in [-5.4, -3.6, 3.6, 5.4]:
		_add_box("LightStrip", Vector3(x, 3.35, -2.0), Vector3(0.12, 0.08, 4.6), Color("#5674e8"), false)
	for z in [-5.5, -3.7, -1.9, -0.1, 1.7, 3.5, 5.3]:
		_add_box("FloorGuide", Vector3(0.0, 0.015, z), Vector3(8.0, 0.025, 0.035), Color("#2d4d86"), false)

	_create_interactable("SignalNode", Vector3(-2.4, 0.8, 5.7), "إشارة 11:11", "signal", Color("#f34c78"))
	_create_interactable("MemoryClue", Vector3(3.0, 0.65, 0.8), "أثر الذاكرة", "clue", Color("#5dd6ff"))
	_create_interactable("ExitDoor", Vector3(0.0, 1.5, -11.55), "باب الخروج", "door", Color("#f5c86b"))
	for tube_position in [Vector3(-4.62, 2.5, 6.4), Vector3(-4.62, 2.5, -1.2), Vector3(4.62, 2.5, 2.6), Vector3(4.62, 2.5, -5.0)]:
		_add_tube_collider(tube_position)
	_load_authored_room()
	_load_wake_capsule()


func _load_wake_capsule() -> void:
	var capsule_scene := load("res://assets/candidates/Sector11_WakeCapsule_G0_Runtime.glb") as PackedScene
	if capsule_scene == null:
		push_warning("G0 wake capsule candidate could not be loaded")
		return
	wake_capsule = capsule_scene.instantiate()
	wake_capsule.name = "Sector11WakeCapsule"
	# Tripo's source pivot is offset from the visual centre. This authored placement
	# centres the 2.45 m pod and turns its glass hatch toward the playable corridor.
	wake_capsule.position = Vector3(0.52, 0.0, 9.55)
	wake_capsule.rotation_degrees.y = 180.0
	add_child(wake_capsule)
	_tune_imported_materials(wake_capsule)

	var capsule_collision := StaticBody3D.new()
	capsule_collision.name = "WakeCapsuleCollision"
	capsule_collision.position = Vector3(0.0, 1.22, 0.0)
	wake_capsule.add_child(capsule_collision)
	var collision_shape := CollisionShape3D.new()
	var collision_box := BoxShape3D.new()
	collision_box.size = Vector3(1.28, 2.44, 1.18)
	collision_shape.shape = collision_box
	capsule_collision.add_child(collision_shape)
	print("G0_WAKE_CAPSULE_READY")


func _load_authored_room() -> void:
	var room_scene := load("res://assets/g0-sector11-corridor-r5.glb") as PackedScene
	if room_scene == null:
		return
	authored_room = room_scene.instantiate()
	authored_room.name = "Sector11AuthoredRoom"
	add_child(authored_room)
	_disable_imported_lights(authored_room)
	_tune_imported_materials(authored_room)
	for procedural in get_tree().get_nodes_in_group("g0_procedural_shell"):
		_set_mesh_visibility(procedural)
	_set_mesh_visibility(get_node("ExitDoor"))
	print("G0_AUTHORED_ROOM_READY")


func _disable_imported_lights(node: Node) -> void:
	if node is Light3D:
		(node as Light3D).visible = false
	for child in node.get_children():
		_disable_imported_lights(child)


func _tune_imported_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh:
			for surface_index in mesh_instance.mesh.get_surface_count():
				var source := mesh_instance.get_active_material(surface_index)
				if source is StandardMaterial3D:
					var material := source.duplicate() as StandardMaterial3D
					var role := material.resource_name
					if role.contains("CyanSignal"):
						material.emission_energy_multiplier = 0.72
					elif role.contains("MagentaFault"):
						material.emission_energy_multiplier = 0.9
					elif role.contains("WarmPractical"):
						material.emission_energy_multiplier = 0.62
					elif role.contains("SuspendedFluid"):
						material.emission_energy_multiplier = 0.34
					mesh_instance.set_surface_override_material(surface_index, material)
	for child in node.get_children():
		_tune_imported_materials(child)


func _add_tube_collider(location: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = "ContainmentTubeCollision"
	body.position = location
	add_child(body)
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.92
	shape.height = 4.5
	collision.shape = shape
	body.add_child(collision)


func _set_mesh_visibility(node: Node) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).visible = false
	for child in node.get_children():
		_set_mesh_visibility(child)


func _build_player() -> void:
	player = CharacterBody3D.new()
	player.name = "EchoPlayer"
	player.set_script(load("res://scripts/player.gd"))
	player.position = Vector3(0.0, 0.05, 8.1)
	add_child(player)


func _build_hud() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "UI"
	add_child(canvas)

	var panel := ColorRect.new()
	panel.position = Vector2(26.0, 24.0)
	panel.size = Vector2(520.0, 155.0)
	panel.color = Color(0.025, 0.04, 0.09, 0.9)
	canvas.add_child(panel)

	var title := Label.new()
	title.position = Vector2(48.0, 38.0)
	title.text = "11:11  //  G0 VERTICAL SLICE"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color("#d5ddff"))
	canvas.add_child(title)

	objective_label = Label.new()
	objective_label.position = Vector2(48.0, 76.0)
	objective_label.add_theme_font_size_override("font_size", 17)
	objective_label.add_theme_color_override("font_color", Color("#f5c86b"))
	canvas.add_child(objective_label)

	quality_label = Label.new()
	quality_label.position = Vector2(48.0, 108.0)
	quality_label.add_theme_font_size_override("font_size", 13)
	quality_label.add_theme_color_override("font_color", Color("#8ca1d8"))
	canvas.add_child(quality_label)

	hint_label = Label.new()
	hint_label.position = Vector2(48.0, 650.0)
	hint_label.add_theme_font_size_override("font_size", 18)
	hint_label.add_theme_color_override("font_color", Color("#ffffff"))
	canvas.add_child(hint_label)

	status_label = Label.new()
	status_label.position = Vector2(48.0, 600.0)
	status_label.add_theme_font_size_override("font_size", 16)
	status_label.add_theme_color_override("font_color", Color("#b8c7f5"))
	canvas.add_child(status_label)
	_update_objective("افحص إشارة 11:11")
	_apply_quality()


func _create_interactable(node_name: String, location: Vector3, label_text: String, item_kind: String, color: Color) -> void:
	var item := Node3D.new()
	item.name = node_name
	item.set_script(INTERACTABLE_SCRIPT)
	item.set("display_name", label_text)
	item.set("kind", item_kind)
	item.position = location
	item.add_to_group("interactable")
	add_child(item)
	item.connect("interacted", Callable(self, "_on_interactable_interacted"))

	var pedestal := MeshInstance3D.new()
	var pedestal_mesh := CylinderMesh.new()
	pedestal_mesh.top_radius = 0.2 if item_kind != "door" else 0.08
	pedestal_mesh.bottom_radius = 0.26 if item_kind != "door" else 0.08
	pedestal_mesh.height = 0.5 if item_kind != "door" else 1.8
	pedestal.material_override = _material(color.darkened(0.72), 0.65, 0.22)
	pedestal.mesh = pedestal_mesh
	pedestal.position.y = -location.y + (0.25 if item_kind != "door" else 1.5)
	item.add_child(pedestal)

	var marker := MeshInstance3D.new()
	var marker_mesh := SphereMesh.new()
	marker_mesh.radius = 0.085 if item_kind != "door" else 0.12
	marker_mesh.height = 0.17 if item_kind != "door" else 0.24
	marker.material_override = _material(color, 0.15, 0.22)
	marker.mesh = marker_mesh
	marker.position.y = 0.42 if item_kind != "door" else 1.5
	marker.name = "Marker"
	item.add_child(marker)

	var beacon := OmniLight3D.new()
	beacon.light_color = color
	beacon.light_energy = 0.32 if item_kind != "door" else 0.18
	beacon.omni_range = 1.25 if item_kind != "door" else 1.8
	beacon.position.y = 0.45 if item_kind != "door" else 1.5
	item.add_child(beacon)


func _add_box(node_name: String, location: Vector3, size: Vector3, color: Color, collidable: bool) -> Node3D:
	var parent: Node3D
	if collidable:
		parent = StaticBody3D.new()
		parent.name = node_name
		add_child(parent)
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		parent.add_child(collision)
	else:
		parent = Node3D.new()
		parent.name = node_name
		add_child(parent)
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = _material(color, 0.12, 0.5)
	# Geometry and physics share one transform; a translated child would double it.
	mesh_instance.position = Vector3.ZERO
	parent.add_child(mesh_instance)
	parent.position = location
	parent.add_to_group("g0_procedural_shell")
	return parent


func _add_light(location: Vector3, color: Color, energy: float, range_value: float) -> void:
	var light := OmniLight3D.new()
	light.position = location
	light.light_color = color
	light.light_energy = energy
	light.omni_range = range_value
	add_child(light)


func _material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material


func _update_nearest() -> void:
	nearest = null
	var closest := 2.35
	if player:
		for item in get_tree().get_nodes_in_group("interactable"):
			var distance := player.global_position.distance_to(item.global_position)
			if distance < closest:
				closest = distance
				nearest = item
		if nearest:
			hint_label.text = "[E]  تفاعل: " + str(nearest.get("display_name"))
		else:
			hint_label.text = "WASD حركة  •  Shift ركض  •  زر الفأرة الأيمن للكاميرا  •  R إعادة"


func _on_interactable_interacted(item: Node3D) -> void:
	var kind := str(item.get("kind"))
	if kind == "signal" and objective_state == 0:
		objective_state = 1
		item.call("set_active", true)
		_update_objective("وصلت الإشارة — اتجه إلى باب الخروج")
		status_label.text = "LOCAL TEST // signal_observed  •  تفاعل محلي تجريبي"
	elif kind == "clue" and objective_state >= 1:
		item.call("set_active", true)
		status_label.text = "MEMORY TRACE // الأثر تغيّر بعد ملاحظتك"
	elif kind == "door":
		if objective_state >= 1:
			objective_state = 2
			_update_objective("اكتملت شريحة G0 — عُد بـ R لإعادة الاختبار")
			status_label.text = "SLICE CLEAR // الحركة والتفاعل والهدف والاستئناف جاهزة للقياس"
		else:
			status_label.text = "الباب مغلق — افحص إشارة 11:11 أولاً"


func _update_objective(text_value: String) -> void:
	if objective_label:
		objective_label.text = "الهدف: " + text_value


func _apply_quality() -> void:
	if not room_environment or not key_light:
		return
	room_environment.environment.glow_enabled = quality_high
	room_environment.environment.glow_intensity = 0.22 if quality_high else 0.0
	key_light.light_energy = 1.35 if quality_high else 1.0
	if quality_label:
		quality_label.text = "Q تبدّل الجودة: " + ("HIGH / glow" if quality_high else "SAFE / reduced effects")


func _reset_slice() -> void:
	objective_state = 0
	if player:
		player.global_position = Vector3(0.0, 0.05, 4.8)
		player.velocity = Vector3.ZERO
		player.call("reset_camera")
	for item in get_tree().get_nodes_in_group("interactable"):
		item.call("set_active", false)
	_update_objective("افحص إشارة 11:11")
	status_label.text = "RESET // نقطة البداية جاهزة"


func _headless_check() -> void:
	var has_room := get_node_or_null("RoomFloor") != null
	var has_player := get_node_or_null("EchoPlayer") != null
	var has_ui := get_node_or_null("UI") != null
	var has_camera: bool = player != null and player.camera != null and player.camera.current
	var has_authored_room := authored_room != null
	var has_authored_character: bool = player != null and player.using_authored_character
	for node_name in ["RoomFloor", "BackWall", "LeftWall", "RightWall"]:
		var body := get_node_or_null(node_name) as StaticBody3D
		if body == null:
			push_error("Missing room collision: " + node_name)
			get_tree().quit(1)
			return
		var shape := body.get_child(0) as CollisionShape3D
		var mesh := body.get_child(1) as MeshInstance3D
		if shape == null or mesh == null or not shape.global_position.is_equal_approx(mesh.global_position):
			push_error("Room visual/collision transform mismatch: " + node_name)
			get_tree().quit(1)
			return
	if not has_room or not has_player or not has_ui or not has_camera or not has_authored_room or not has_authored_character:
		push_error("G0 vertical slice proof is missing a required node")
		get_tree().quit(1)
		return
	print("GODOT_SMOKE_OK")
	get_tree().quit(0)

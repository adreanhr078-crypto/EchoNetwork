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
	environment.ambient_light_color = Color("#a8b1bd")
	environment.ambient_light_energy = 0.35
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = true
	environment.glow_intensity = 0.8
	room_environment.environment = environment
	add_child(room_environment)

	key_light = DirectionalLight3D.new()
	key_light.name = "KeyLight"
	key_light.rotation_degrees = Vector3(-54.0, -32.0, 0.0)
	key_light.light_color = Color("#e0d9d0")
	key_light.light_energy = 1.35
	key_light.shadow_enabled = true
	add_child(key_light)

	_add_light(Vector3(-4.5, 2.8, -2.8), Color("#4e76ff"), 4.0, 5.0)
	_add_light(Vector3(4.2, 2.4, 1.8), Color("#ff4f93"), 3.0, 4.0)


func _build_room() -> void:
	_add_box("RoomFloor", Vector3(0.0, -0.15, 0.0), Vector3(15.0, 0.3, 15.0), Color("#11192d"), true)
	_add_box("BackWall", Vector3(0.0, 2.0, -7.2), Vector3(15.0, 4.0, 0.3), Color("#202b46"), true)
	_add_box("LeftWall", Vector3(-7.2, 2.0, 0.0), Vector3(0.3, 4.0, 15.0), Color("#18233d"), true)
	_add_box("RightWall", Vector3(7.2, 2.0, 0.0), Vector3(0.3, 4.0, 15.0), Color("#18233d"), true)
	_add_box("CeilingBeam", Vector3(0.0, 3.75, -1.6), Vector3(13.0, 0.25, 0.35), Color("#344369"), false)

	for x in [-5.4, -3.6, 3.6, 5.4]:
		_add_box("LightStrip", Vector3(x, 3.35, -2.0), Vector3(0.12, 0.08, 4.6), Color("#5674e8"), false)
	for z in [-5.5, -3.7, -1.9, -0.1, 1.7, 3.5, 5.3]:
		_add_box("FloorGuide", Vector3(0.0, 0.015, z), Vector3(8.0, 0.025, 0.035), Color("#2d4d86"), false)

	_create_interactable("SignalNode", Vector3(-3.0, 0.8, -2.6), "إشارة 11:11", "signal", Color("#f34c78"))
	_create_interactable("MemoryClue", Vector3(3.0, 0.65, 0.8), "أثر الذاكرة", "clue", Color("#5dd6ff"))
	_create_interactable("ExitDoor", Vector3(0.0, 1.5, -6.95), "باب الخروج", "door", Color("#f5c86b"))
	_load_authored_room()


func _load_authored_room() -> void:
	var room_scene := load("res://assets/g0-room.glb") as PackedScene
	if room_scene == null:
		return
	authored_room = room_scene.instantiate()
	authored_room.name = "Sector11AuthoredRoom"
	add_child(authored_room)
	for procedural in get_tree().get_nodes_in_group("g0_procedural_shell"):
		_set_mesh_visibility(procedural)
	_set_mesh_visibility(get_node("ExitDoor"))
	print("G0_AUTHORED_ROOM_READY")


func _set_mesh_visibility(node: Node) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).visible = false
	for child in node.get_children():
		_set_mesh_visibility(child)


func _build_player() -> void:
	player = CharacterBody3D.new()
	player.name = "EchoPlayer"
	player.set_script(load("res://scripts/player.gd"))
	player.position = Vector3(0.0, 0.05, 4.8)
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
	pedestal_mesh.top_radius = 0.42
	pedestal_mesh.bottom_radius = 0.5
	pedestal_mesh.height = 0.9 if item_kind != "door" else 3.0
	pedestal.material_override = _material(color.darkened(0.55), 0.4, 0.3)
	pedestal.mesh = pedestal_mesh
	pedestal.position.y = -location.y + (0.45 if item_kind != "door" else 1.5)
	item.add_child(pedestal)

	var marker := MeshInstance3D.new()
	var marker_mesh := SphereMesh.new()
	marker_mesh.radius = 0.2 if item_kind != "door" else 0.55
	marker_mesh.height = 0.4 if item_kind != "door" else 1.1
	marker.material_override = _material(color, 0.15, 0.22)
	marker.mesh = marker_mesh
	marker.position.y = 0.85 if item_kind != "door" else 1.5
	marker.name = "Marker"
	item.add_child(marker)

	var beacon := OmniLight3D.new()
	beacon.light_color = color
	beacon.light_energy = 1.8 if item_kind != "door" else 1.0
	beacon.omni_range = 3.0 if item_kind != "door" else 4.0
	beacon.position.y = 1.0 if item_kind != "door" else 1.5
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
			hint_label.text = "WASD / الأسهم للحركة   •   Shift للركض   •   R لإعادة الشريحة"


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
	room_environment.environment.glow_intensity = 0.8 if quality_high else 0.0
	key_light.light_energy = 1.35 if quality_high else 1.0
	if quality_label:
		quality_label.text = "Q تبدّل الجودة: " + ("HIGH / glow" if quality_high else "SAFE / reduced effects")


func _reset_slice() -> void:
	objective_state = 0
	if player:
		player.global_position = Vector3(0.0, 0.05, 4.8)
		player.velocity = Vector3.ZERO
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

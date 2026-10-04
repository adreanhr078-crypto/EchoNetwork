extends SceneTree

## A readable, stateful lens without moving the body or its interaction volume.
const CONDUIT := preload("res://scenes/props/energy_power_conduit.tscn")
const AMBER := Color(1.0, 0.45, 0.08, 1.0)
const CYAN := Color(0.0, 0.95, 1.0, 1.0)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var first := CONDUIT.instantiate() as EnergyPowerConduit
	var second := CONDUIT.instantiate() as EnergyPowerConduit
	second.position.x = 3.0
	# Capture the imported shared resource before either instance is ready.
	var source := first.get_node("CoreMesh").get_active_material(0) as StandardMaterial3D
	var source_color := source.albedo_color
	var source_emission := source.emission
	var source_energy := source.emission_energy_multiplier
	root.add_child(first)
	root.add_child(second)
	await process_frame
	var first_material := first.get_node("CoreMesh").get_active_material(0) as StandardMaterial3D
	var second_material := second.get_node("CoreMesh").get_active_material(0) as StandardMaterial3D
	if not _check(first_material != source and second_material != source and first_material != second_material, "conduit materials still share a mutable resource"): return
	for index in first._signal_materials.size():
		if not _check(first._signal_materials[index] != second._signal_materials[index], "visible imported signal materials leak state between instances"): return
	for conduit in [first, second]:
		if not _geometry_is_preserved(conduit): return
		if not _state_is(conduit, AMBER, false): return
	# The same visual updater is used by checkpoint restoration. No audio or
	# energize() tween is required for this restored state to become readable.
	first.is_energized = true
	first._update_visuals()
	if not _state_is(first, CYAN, true): return
	if not _state_is(second, AMBER, false): return
	if not _check(source.albedo_color == source_color and source.emission == source_emission and is_equal_approx(source.emission_energy_multiplier, source_energy), "scene's authored shared material was modified"): return
	# Restoring dormant state reuses the one instance material rather than
	# accumulating resources. Locked state still follows gameplay ownership.
	first.is_energized = false
	first.is_locked = true
	first._update_visuals()
	if not _state_is(first, AMBER, false): return
	if not _check(not first.get_node("InteractionArea").is_enabled, "locked conduit became interactable"): return
	first.is_locked = false
	first._update_visuals()
	if not _check(first.get_node("InteractionArea").is_enabled and first.get_node("CoreMesh").get_active_material(0) == first_material, "restoration changed interaction or recreated the material"): return
	if not _geometry_is_preserved(first): return
	print("OBSERVATION seven imported presentation meshes fit the preserved 0.45m-radius/1.8m-height collision volume")
	first.queue_free()
	second.queue_free()
	await process_frame
	print("PASS integrated conduit: collider/interaction/light count preserved, dormant/energized/restored signals and per-instance material isolation")
	quit(0)

func _state_is(conduit: EnergyPowerConduit, color: Color, energized: bool) -> bool:
	var material := conduit.get_node("CoreMesh").get_active_material(0) as StandardMaterial3D
	if not _check(material and material.albedo_color == color and material.emission_enabled and material.emission == color, "lens disagrees with actual conduit state"): return false
	if not _check(conduit.core_light.light_color == color and conduit.spark_particles.emitting == energized, "existing light/particle state changed"): return false
	if not _check(is_equal_approx(material.emission_energy_multiplier, 1.4 if energized else 0.45), "lens brightness disagrees with restored state"): return false
	if not _check(conduit._signal_materials.size() == 3, "presentation signal bindings missing"): return false
	for visible_material in conduit._signal_materials:
		if not _check(visible_material.albedo_color == color and visible_material.emission == color and is_equal_approx(visible_material.emission_energy_multiplier, material.emission_energy_multiplier), "imported visible signal disagrees with actual state"): return false
	if not conduit.is_locked:
		if not _check(conduit.get_node("InteractionArea").is_enabled == not energized, "existing interaction gate changed"): return false
	return true

func _geometry_is_preserved(conduit: EnergyPowerConduit) -> bool:
	var body_shape := conduit.get_node("CollisionShape3D") as CollisionShape3D
	var body := body_shape.shape as CylinderShape3D
	var interaction := conduit.get_node("InteractionArea/CollisionShape3D") as CollisionShape3D
	var core := conduit.get_node("CoreMesh") as MeshInstance3D
	var sphere := core.mesh as SphereMesh
	var pillar := conduit.get_node("PillarMesh") as MeshInstance3D
	var cylinder := pillar.mesh as CylinderMesh
	if not _check(body and is_equal_approx(body.radius, 0.45) and is_equal_approx(body.height, 1.8) and body_shape.position == Vector3(0, 0.9, 0), "solid collision changed"): return false
	if not _check(interaction.shape is SphereShape3D and is_equal_approx(interaction.shape.radius, 1.5) and interaction.position == Vector3(0, 0.9, 0), "interaction shape changed"): return false
	if not _check(sphere and is_equal_approx(sphere.radius, 0.22) and is_equal_approx(sphere.height, 0.44) and cylinder and is_equal_approx(cylinder.top_radius, 0.35) and is_equal_approx(cylinder.bottom_radius, 0.45) and is_equal_approx(cylinder.height, 1.8) and pillar.position == Vector3(0, 0.9, 0), "authored meshes changed"): return false
	var lens_radial_extent := Vector2(core.position.x, core.position.z).length() + sphere.radius
	var lens_vertical_extent := absf(core.position.y - body_shape.position.y) + sphere.radius
	if not _check(lens_radial_extent <= body.radius + 0.00001 and lens_vertical_extent <= body.height * 0.5, "revealed lens extends beyond the existing collision volume"): return false
	var normalized_height := (core.position.y - (pillar.position.y - cylinder.height * 0.5)) / cylinder.height
	var housing_radius := lerpf(cylinder.bottom_radius, cylinder.top_radius, normalized_height)
	if not _check(lens_radial_extent > housing_radius + 0.05, "emissive lens remains hidden in opaque housing"): return false
	if not _check(not core.visible and not pillar.visible and conduit.has_node("Presentation") and conduit.find_children("*", "OmniLight3D", true, false).size() == 1, "fallback is drawn twice or presentation adds a light"): return false
	var visible_meshes := 0
	for imported in conduit.get_node("Presentation").find_children("*", "MeshInstance3D", true, false):
		visible_meshes += 1
		var relative: Transform3D = conduit.global_transform.affine_inverse() * imported.global_transform
		for surface in imported.mesh.get_surface_count():
			var vertices: PackedVector3Array = imported.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			for vertex in vertices:
				var point: Vector3 = relative * vertex
				if not _check(Vector2(point.x, point.z).length() <= body.radius + 0.00002 and point.y >= -0.00002 and point.y <= body.height + 0.00002, "imported prop exceeds preserved collider footprint"): return false
	if not _check(visible_meshes == 7, "unexpected presentation mesh budget"): return false
	return true

func _check(condition: bool, message: String) -> bool:
	if not condition:
		push_error(message)
		quit(1)
	return condition

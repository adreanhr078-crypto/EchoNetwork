extends RefCounted

## Visible service fixtures with direct light in both Forward+ and Compatibility.
## Emissive trim alone cannot illuminate an enclosed room without baked GI.
static func install(room: Node3D, bounds: Rect2, ceiling: float) -> void:
	var fixtures := Node3D.new()
	fixtures.name = "ServiceLighting"
	room.add_child(fixtures)
	var trim := StandardMaterial3D.new()
	trim.albedo_color = Color(0.75, 0.81, 0.84)
	trim.emission_enabled = true
	trim.emission = Color(0.65, 0.75, 0.85)
	trim.emission_energy_multiplier = 0.7
	for row in range(3):
		for column in range(2):
			var position := Vector3(bounds.position.x + bounds.size.x * (0.27 + column * 0.46), ceiling - 0.3, bounds.position.y + bounds.size.y * (0.18 + row * 0.32))
			var housing := MeshInstance3D.new()
			housing.name = "CeilingFixture_%d_%d" % [row,column]
			var mesh := BoxMesh.new()
			mesh.size = Vector3(2.2,0.08,0.34)
			housing.mesh = mesh
			housing.material_override = trim
			housing.position = position
			fixtures.add_child(housing)
			var light := OmniLight3D.new()
			light.position = position - Vector3(0,0.4,0)
			light.light_color = Color(0.9,0.94,1.0)
			light.light_energy = 1.4
			light.omni_range = 14.0
			light.omni_attenuation = 0.7
			light.shadow_enabled = true
			fixtures.add_child(light)

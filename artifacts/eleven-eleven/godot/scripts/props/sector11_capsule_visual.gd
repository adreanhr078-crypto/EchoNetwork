extends Node3D

const GLASS_MATERIAL_TOKEN := "glass"
const SIGNAL_MATERIAL_TOKEN := "signal"

func _ready() -> void:
	for mesh_instance in find_children("*", "MeshInstance3D", true, false):
		if not mesh_instance.mesh:
			continue
		for surface_index in mesh_instance.mesh.get_surface_count():
			var source_material: Material = mesh_instance.get_active_material(surface_index)
			if not source_material is StandardMaterial3D:
				continue
			var source := source_material as StandardMaterial3D
			var material_name := source.resource_name.to_lower()
			if GLASS_MATERIAL_TOKEN in material_name:
				mesh_instance.set_surface_override_material(surface_index, _smoke_glass(source))
			elif SIGNAL_MATERIAL_TOKEN in material_name:
				mesh_instance.set_surface_override_material(surface_index, _restrained_signal(source))

func _smoke_glass(source: StandardMaterial3D) -> StandardMaterial3D:
	var glass := source.duplicate() as StandardMaterial3D
	glass.resource_name = "Sector11_Smoked_Glass"
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color = Color(0.035, 0.075, 0.09, 0.48)
	glass.metallic = 0.12
	glass.roughness = 0.24
	glass.emission_enabled = true
	glass.emission = Color(0.015, 0.12, 0.23)
	glass.emission_energy_multiplier = 0.32
	glass.clearcoat_enabled = true
	glass.clearcoat = 0.62
	return glass

func _restrained_signal(source: StandardMaterial3D) -> StandardMaterial3D:
	var signal_material := source.duplicate() as StandardMaterial3D
	signal_material.resource_name = "Sector11_Restrained_Signal"
	signal_material.albedo_color = Color(0.025, 0.17, 0.19, 1.0)
	if signal_material.emission_enabled:
		signal_material.emission = Color(0.0, 0.3, 0.34, 1.0)
		signal_material.emission_energy_multiplier = minf(signal_material.emission_energy_multiplier, 0.7)
	return signal_material

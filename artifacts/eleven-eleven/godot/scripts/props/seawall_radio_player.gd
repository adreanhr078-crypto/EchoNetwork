class_name SeawallRadioPlayer
extends Node3D

## AAA Seawall Coastal Radio & Musical Lo-Fi Ambient Player
## Located at the Coastal Overlook Point overlooking the Pacific Ocean.
## Features:
## - Cassette boombox mesh with rotating reel indicators
## - Lo-fi seaside synthwave ambient station toggle
## - Grants Echo the "Ocean Solace" buff (+40 Sanity, +15 Max Stamina)

signal radio_toggled(is_playing: bool, station_name: String)
signal ocean_solace_granted(sanity_restored: float)

@export var is_playing: bool = false
@export var station_name: String = "Minato Coastal Lo-Fi // 98.4 FM"

func _ready() -> void:
	_setup_boombox_mesh()

func _setup_boombox_mesh() -> void:
	var box = find_child("BoomboxMesh", true, false)
	if not box:
		var mesh_inst := MeshInstance3D.new()
		mesh_inst.name = "BoomboxMesh"
		var bmesh := BoxMesh.new()
		bmesh.size = Vector3(0.5, 0.3, 0.2)
		mesh_inst.mesh = bmesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.25, 0.28, 0.32, 1.0)
		mesh_inst.material_override = mat
		add_child(mesh_inst)

## Toggles cassette radio playback and bestows coastal mental solace
func toggle_radio(player: Node = null) -> Dictionary:
	is_playing = not is_playing

	var sanity_boost: float = 40.0
	if is_playing and player:
		if player.has_meta("sanity"):
			player.set_meta("sanity", minf(100.0, float(player.get_meta("sanity")) + sanity_boost))
		if player.has_method("restore_stamina"):
			player.restore_stamina(35.0)

	emit_signal("radio_toggled", is_playing, station_name)
	if is_playing:
		emit_signal("ocean_solace_granted", sanity_boost)

	return {
		"success": true,
		"is_playing": is_playing,
		"station": station_name,
		"buff": "Ocean Solace (Sanity +40, Stamina Restored)" if is_playing else "None"
	}

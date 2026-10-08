extends SceneTree

func _init() -> void:
	print("=== TRIPO WEAPON INTEGRATION & GEOMETRY VERIFICATION ===")
	
	# 1. Verify Standard Katana GLB
	var std_scene = load("res://assets/weapons/standard_katana_tripo_20261008.glb") as PackedScene
	assert(std_scene != null, "Standard Katana GLB must load successfully")
	var std_inst = std_scene.instantiate() as Node3D
	assert(std_inst != null, "Standard Katana instance must not be null")
	var std_mesh_inst = std_inst.get_child(0) as MeshInstance3D
	assert(std_mesh_inst != null, "Standard Katana must contain MeshInstance3D")
	var std_aabb = std_mesh_inst.get_aabb()
	print("Standard Katana AABB: pos=", std_aabb.position, " size=", std_aabb.size, " end=", std_aabb.end)
	
	# Verify honest proportions:
	# length ~0.95m - 1.05m
	assert(abs(std_aabb.size.y - 0.95) < 0.05, "Standard Katana length must be ~0.95m")
	# guard diameter ~0.08m
	assert(abs(std_aabb.size.x - 0.08) < 0.015, "Standard Katana guard diameter X must be ~0.08m")
	assert(abs(std_aabb.size.z - 0.08) < 0.015, "Standard Katana guard diameter Z must be ~0.08m")
	# grip length ~0.25m - 0.28m (extends in -Y from 0.0)
	assert(std_aabb.position.y <= -0.25 and std_aabb.position.y >= -0.30, "Grip length must be between 0.25m and 0.30m")
	# pivot origin at center of guard:
	var std_center_x = std_aabb.position.x + std_aabb.size.x * 0.5
	var std_center_z = std_aabb.position.z + std_aabb.size.z * 0.5
	assert(abs(std_center_x) < 0.005, "Standard Katana pivot X must be centered at 0")
	assert(abs(std_center_z) < 0.005, "Standard Katana pivot Z must be centered at 0")
	print("-> Standard Katana proportions and pivot VERIFIED PASS.")
	
	# 2. Verify Shadow Katana GLB
	var shd_scene = load("res://assets/weapons/shadow_katana_tripo_20261008.glb") as PackedScene
	assert(shd_scene != null, "Shadow Katana GLB must load successfully")
	var shd_inst = shd_scene.instantiate() as Node3D
	assert(shd_inst != null, "Shadow Katana instance must not be null")
	var shd_mesh_inst = shd_inst.get_child(0) as MeshInstance3D
	assert(shd_mesh_inst != null, "Shadow Katana must contain MeshInstance3D")
	var shd_aabb = shd_mesh_inst.get_aabb()
	print("Shadow Katana AABB: pos=", shd_aabb.position, " size=", shd_aabb.size, " end=", shd_aabb.end)
	
	# Verify honest proportions:
	# length ~0.95m - 1.05m
	assert(abs(shd_aabb.size.y - 1.05) < 0.05, "Shadow Katana length must be ~1.05m")
	# guard diameter ~0.08m
	assert(abs(shd_aabb.size.x - 0.08) < 0.015, "Shadow Katana guard diameter X must be ~0.08m")
	assert(abs(shd_aabb.size.z - 0.08) < 0.015, "Shadow Katana guard diameter Z must be ~0.08m")
	# grip length ~0.25m - 0.28m (extends in -Y from 0.0)
	assert(shd_aabb.position.y <= -0.24 and shd_aabb.position.y >= -0.29, "Shadow Katana grip length must be between 0.24m and 0.29m")
	# pivot origin at center of guard:
	var shd_center_x = shd_aabb.position.x + shd_aabb.size.x * 0.5
	var shd_center_z = shd_aabb.position.z + shd_aabb.size.z * 0.5
	assert(abs(shd_center_x) < 0.005, "Shadow Katana pivot X must be centered at 0")
	assert(abs(shd_center_z) < 0.005, "Shadow Katana pivot Z must be centered at 0")
	print("-> Shadow Katana proportions and pivot VERIFIED PASS.")
	
	# 3. Test application onto Player via TripoWeaponVisuals
	var player_scene = load("res://scenes/player/echo_player.tscn") as PackedScene
	var player = player_scene.instantiate() as CharacterBody3D
	root.add_child(player)
	
	var apply_res = TripoWeaponVisuals.apply_weapon_visuals(player)
	print("TripoWeaponVisuals.apply_weapon_visuals: ", apply_res)
	assert(apply_res.applied == true, "Weapon visuals must be applied")
	assert(apply_res.standard_katana_replaced == true, "Standard katana must be replaced")
	assert(apply_res.shadow_katana_replaced == true, "Shadow katana must be replaced")
	
	# Verify nodes exist under KatanaBlade and ShadowKatana
	var katana = player.find_child("KatanaBlade", true, false)
	var std_visual = katana.get_node_or_null("TripoVisual")
	assert(std_visual != null, "KatanaBlade must have TripoVisual child")
	
	var shadow_katana = player.find_child("ShadowKatana", true, false)
	var blade_root = shadow_katana.get_node_or_null("BladeRoot")
	var shd_visual = blade_root.get_node_or_null("TripoVisual")
	assert(shd_visual != null, "ShadowKatana BladeRoot must have TripoVisual child")
	
	# Test restoration
	var restore_res = TripoWeaponVisuals.restore_weapon_visuals(player)
	print("TripoWeaponVisuals.restore_weapon_visuals: ", restore_res)
	assert(restore_res.restored == true, "Weapon visuals must be restored")
	assert(katana.get_node_or_null("TripoVisual") == null, "TripoVisual must be removed after restore")
	
	print("=== ALL TRIPO WEAPON INTEGRATION TESTS PASSED CLEANLY ===")
	quit(0)

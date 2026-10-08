extends SceneTree

## Headless SceneTree Test: Tripo Assets, Prop Library & Weapon Visuals Review (2026-10-08)
## Verifies:
## 1. All 6 Tripo GLB models load, instantiate, and pass polygon budget (< 30,000 tris).
## 2. TripoPropLibrary executes non-destructive visual replacement preserving all colliders and triggers.
## 3. TripoWeaponVisuals strictly respects combat_available and pact narrative invariants.

const TripoPropLibraryScript = preload("res://scripts/environment/tripo_prop_library.gd")
const TripoWeaponVisualsScript = preload("res://scripts/player/tripo_weapon_visuals.gd")

const ASSET_PATHS := {
	"diagnostic_cart": "res://assets/props/diagnostic_cart_tripo_20261008.glb",
	"security_terminal": "res://assets/props/security_terminal_tripo_20261008.glb",
	"observation_server": "res://assets/props/observation_server_tripo_20261008.glb",
	"medical_wall_unit": "res://assets/props/medical_wall_unit_tripo_20261008.glb",
	"standard_katana": "res://assets/weapons/standard_katana_tripo_20261008.glb",
	"shadow_katana": "res://assets/weapons/shadow_katana_tripo_20261008.glb",
}

func _init() -> void:
	call_deferred("_run_review")

func _run_review() -> void:
	print("=================================================================")
	print("[TRIPO REVIEW] Starting Headless Verification of 6 Tripo Assets...")
	print("=================================================================")

	# Stage 1: Asset Load, Mesh Integrity & Triangle Counts
	for asset_id in ASSET_PATHS:
		var path: String = ASSET_PATHS[asset_id]
		var scene: PackedScene = load(path)
		if not _assert(scene != null, "Failed to load PackedScene for %s at %s" % [asset_id, path]):
			return

		var instance: Node3D = scene.instantiate() as Node3D
		if not _assert(instance != null, "Failed to instantiate scene for %s" % asset_id):
			return

		root.add_child(instance)
		await process_frame

		var mesh_count := 0
		var total_tris := 0
		var total_verts := 0

		var mesh_instances := instance.find_children("*", "MeshInstance3D", true, false)
		for mi in mesh_instances:
			var m_inst := mi as MeshInstance3D
			if m_inst and m_inst.mesh:
				mesh_count += 1
				var mesh := m_inst.mesh
				for s in range(mesh.get_surface_count()):
					var arrays := mesh.surface_get_arrays(s)
					if arrays.size() > Mesh.ARRAY_VERTEX and arrays[Mesh.ARRAY_VERTEX] != null:
						var verts = arrays[Mesh.ARRAY_VERTEX]
						total_verts += verts.size()
					if arrays.size() > Mesh.ARRAY_INDEX and arrays[Mesh.ARRAY_INDEX] != null:
						var indices = arrays[Mesh.ARRAY_INDEX]
						total_tris += indices.size() / 3

		var aabb := _calculate_bounds(instance)
		print("[TRIPO REVIEW] Asset '%s': Meshes=%d, Tris=%d, Verts=%d, Bounds=(%.2f, %.2f, %.2f)" % [
			asset_id, mesh_count, total_tris, total_verts, aabb.size.x, aabb.size.y, aabb.size.z
		])

		if not _assert(mesh_count > 0, "No meshes found in asset '%s'" % asset_id):
			return
		if not _assert(total_tris < 30000, "Asset '%s' exceeds 30,000 tris limit (has %d)" % [asset_id, total_tris]):
			return

		instance.queue_free()
		await process_frame

	print("[PASS] Stage 1: All 6 Tripo GLBs loaded, bounds validated, and <30k triangle budget satisfied.")

	# Stage 2: TripoPropLibrary Non-Destructive Replacement & Collider Preservation
	var terminal_scene: PackedScene = load("res://scenes/environment/substation_terminal.tscn")
	if not _assert(terminal_scene != null, "Could not load substation_terminal.tscn"):
		return

	var terminal: Node3D = terminal_scene.instantiate()
	root.add_child(terminal)
	await process_frame

	var orig_console := terminal.get_node_or_null("ConsoleVisual") as Node3D
	var orig_collider := terminal.get_node_or_null("TerminalCollider") as StaticBody3D
	var orig_col_shape := terminal.get_node_or_null("TerminalCollider/CollisionShape3D") as CollisionShape3D
	var orig_console_col := terminal.get_node_or_null("TerminalCollider/ConsoleCollision") as CollisionShape3D

	if not _assert(orig_console != null and orig_console.visible, "ConsoleVisual missing or hidden initially"):
		return
	if not _assert(orig_collider != null and orig_col_shape != null and orig_console_col != null, "TerminalCollider missing initial collision shapes"):
		return

	# Apply Tripo visual replacement
	var rep_visual := TripoPropLibraryScript.replace_prop_visual(terminal, "security_terminal")
	if not _assert(rep_visual != null, "replace_prop_visual returned null"):
		return
	if not _assert(terminal.has_node("TripoVisual"), "TripoVisual child not attached to terminal"):
		return
	if not _assert(not orig_console.visible, "ConsoleVisual should be hidden after replacement"):
		return

	# Verify physics colliders remain 100% intact and enabled
	if not _assert(orig_col_shape.shape != null and not orig_col_shape.disabled, "CollisionShape3D damaged or disabled"):
		return
	if not _assert(orig_console_col.shape != null and not orig_console_col.disabled, "ConsoleCollision damaged or disabled"):
		return
	if not _assert(TripoPropLibraryScript.verify_colliders_intact(terminal), "verify_colliders_intact failed on terminal"):
		return

	# Test restoration
	var restore_ok := TripoPropLibraryScript.restore_prop_visual(terminal)
	if not _assert(restore_ok, "restore_prop_visual failed"):
		return
	if not _assert(not terminal.has_node("TripoVisual"), "TripoVisual should be removed after restore"):
		return
	if not _assert(orig_console.visible, "ConsoleVisual should be restored to visible"):
		return
	if not _assert(TripoPropLibraryScript.verify_colliders_intact(terminal), "verify_colliders_intact failed after restore"):
		return

	terminal.queue_free()
	await process_frame

	print("[PASS] Stage 2: TripoPropLibrary visual replacement preserves colliders, triggers, and restores cleanly.")

	# Stage 3: TripoWeaponVisuals & Narrative Invariant (combat_available == false)
	var katana_scene: PackedScene = load("res://scenes/player/katana_blade.tscn")
	var shadow_katana_scene: PackedScene = load("res://scenes/player/shadow_katana.tscn")
	if not _assert(katana_scene != null and shadow_katana_scene != null, "Could not load weapon scenes"):
		return

	# Test KatanaBlade
	var katana: Node3D = katana_scene.instantiate()
	root.add_child(katana)
	await process_frame

	var orig_handle := katana.get_node_or_null("Handle") as Node3D
	var orig_blade := katana.get_node_or_null("Blade") as Node3D
	var glow_light := katana.get_node_or_null("BladeGlowLight") as OmniLight3D
	var tassel := katana.get_node_or_null("TasselRoot") as Node3D

	if not _assert(orig_handle != null and orig_handle.visible, "Katana Handle missing initially"):
		return
	if not _assert(glow_light != null and tassel != null, "Katana glow or tassel missing initially"):
		return

	var tripo_katana := TripoWeaponVisualsScript._replace_katana_visual(katana)
	if not _assert(tripo_katana != null, "_replace_katana_visual failed"):
		return
	if not _assert(not orig_handle.visible and not orig_blade.visible, "Katana procedural meshes not hidden"):
		return
	if not _assert(glow_light != null and tassel != null, "Katana light or tassel lost during replacement"):
		return

	katana.queue_free()
	await process_frame

	# Test ShadowKatana
	var shadow_katana: Node3D = shadow_katana_scene.instantiate()
	root.add_child(shadow_katana)
	await process_frame

	var shadow_hilt := shadow_katana.get_node_or_null("BladeRoot/Hilt") as Node3D
	var shadow_particles := shadow_katana.get_node_or_null("DarkFlameParticles") as GPUParticles3D
	var shadow_glow := shadow_katana.get_node_or_null("BladeGlowLight") as OmniLight3D

	if not _assert(shadow_hilt != null and shadow_hilt.visible, "Shadow Katana Hilt missing initially"):
		return
	if not _assert(shadow_particles != null and shadow_glow != null, "Shadow katana effects missing initially"):
		return

	var tripo_shadow := TripoWeaponVisualsScript._replace_shadow_katana_visual(shadow_katana)
	if not _assert(tripo_shadow != null, "_replace_shadow_katana_visual failed"):
		return
	if not _assert(not shadow_hilt.visible, "Shadow Katana Hilt not hidden"):
		return
	if not _assert(shadow_particles != null and shadow_glow != null, "Shadow katana effects lost during replacement"):
		return

	shadow_katana.queue_free()
	await process_frame

	# Test Real Player scene combat_available Narrative Invariant
	var player_scene: PackedScene = load("res://scenes/player/echo_player.tscn")
	if not _assert(player_scene != null, "Could not load echo_player.tscn"):
		return
	var player: Node3D = player_scene.instantiate()
	root.add_child(player)
	await process_frame

	# Invariant Check 1: In opening room before pact, combat_available MUST be false
	var initial_combat: bool = (player.get("combat_available") == true)
	if not _assert(initial_combat == false, "combat_available must be false initially before pact"):
		return

	# Apply Tripo weapon visuals
	var rep_result := TripoWeaponVisualsScript.apply_weapon_visuals(player)
	if not _assert(rep_result["applied"], "apply_weapon_visuals failed to apply to player"):
		return

	# Invariant Check 2: Weapons MUST be invisible when combat_available is false!
	var player_katana := player.find_child("KatanaBlade", true, false) as Node3D
	var player_shadow := player.find_child("ShadowKatana", true, false) as Node3D
	if not _assert(player_katana != null and not player_katana.visible, "Standard katana must be invisible when combat_available == false"):
		return
	if not _assert(player_shadow != null and not player_shadow.visible, "Shadow katana must be invisible when combat_available == false"):
		return

	# Test Pact activation (combat_available = true)
	player.set("combat_available", true)
	player.set("is_shadow_katana_equipped", false)
	player.set("is_sheathed", false)
	TripoWeaponVisualsScript.sync_weapon_visibility(player)

	if not _assert(player_katana.visible, "Standard katana must become visible when combat_available == true"):
		return
	if not _assert(not player_shadow.visible, "Shadow katana must remain invisible when not equipped"):
		return

	# Equip Shadow Katana
	player.set("is_shadow_katana_equipped", true)
	TripoWeaponVisualsScript.sync_weapon_visibility(player)

	if not _assert(not player_katana.visible, "Standard katana must hide when shadow katana equipped"):
		return
	if not _assert(player_shadow.visible, "Shadow katana must become visible when equipped"):
		return

	# Test Restore Weapon Visuals
	var restore_res := TripoWeaponVisualsScript.restore_weapon_visuals(player)
	if not _assert(restore_res["restored"], "restore_weapon_visuals failed"):
		return

	player.queue_free()
	await process_frame

	print("[PASS] Stage 3: TripoWeaponVisuals strictly enforces pre-pact invisible weapon invariants & socket switching.")

	# Stage 4: Defect Verification - Repeat Apply, Pre-Existing Hidden States & Descendant Protection
	print("-----------------------------------------------------------------")
	print("[TRIPO REVIEW] Starting Stage 4: Defect Regression Tests...")

	# Test 4A: Descendant lights, labels, screen readouts, and interaction areas remain visible and enabled
	var custom_prop_root := Node3D.new()
	custom_prop_root.name = "CustomTerminalWithDescendants"
	root.add_child(custom_prop_root)

	var parent_visual_container := Node3D.new()
	parent_visual_container.name = "ConsoleVisual"
	custom_prop_root.add_child(parent_visual_container)

	var child_body_mesh := MeshInstance3D.new()
	child_body_mesh.name = "ConsoleBodyMesh"
	child_body_mesh.visible = true
	parent_visual_container.add_child(child_body_mesh)

	var child_light := OmniLight3D.new()
	child_light.name = "ConsoleLight"
	child_light.visible = true
	parent_visual_container.add_child(child_light)

	var child_label := Label3D.new()
	child_label.name = "ConsoleReadout"
	child_label.text = "SYS ONLINE"
	child_label.visible = true
	parent_visual_container.add_child(child_label)

	var child_screen := MeshInstance3D.new()
	child_screen.name = "TerminalScreen"
	child_screen.visible = true
	parent_visual_container.add_child(child_screen)

	var child_area := Area3D.new()
	child_area.name = "ConsoleTriggerArea"
	var child_col := CollisionShape3D.new()
	child_col.shape = BoxShape3D.new()
	child_area.add_child(child_col)
	parent_visual_container.add_child(child_area)

	await process_frame

	var rep_parent_vis := TripoPropLibraryScript.replace_prop_visual(custom_prop_root, "security_terminal")
	if not _assert(rep_parent_vis != null, "replace_prop_visual failed on custom_prop_root"):
		return
	if not _assert(not child_body_mesh.visible, "Child mesh should be hidden after replacement"):
		return
	if not _assert(child_light.visible, "Descendant Light3D visible flag should be true"):
		return
	if not _assert(child_light.is_visible_in_tree(), "Descendant Light3D must remain visible in tree"):
		return
	if not _assert(child_label.visible, "Descendant Label3D visible flag should be true"):
		return
	if not _assert(child_label.is_visible_in_tree(), "Descendant Label3D must remain visible in tree"):
		return
	if not _assert(child_screen.visible, "Descendant screen mesh visible flag should be true"):
		return
	if not _assert(child_screen.is_visible_in_tree(), "Descendant screen mesh must remain visible in tree"):
		return
	if not _assert(child_col.shape != null and not child_col.disabled, "Descendant interaction shape must remain enabled"):
		return

	# Restore and verify
	var restore_parent_ok := TripoPropLibraryScript.restore_prop_visual(custom_prop_root)
	if not _assert(restore_parent_ok, "restore_prop_visual failed on custom_prop_root"):
		return
	if not _assert(child_body_mesh.visible, "Child body mesh should be restored to visible=true"):
		return
	if not _assert(child_light.visible and child_light.is_visible_in_tree(), "Descendant light should remain visible after restore"):
		return
	if not _assert(child_label.visible and child_label.is_visible_in_tree(), "Descendant label should remain visible after restore"):
		return
	if not _assert(child_screen.visible and child_screen.is_visible_in_tree(), "Descendant screen should remain visible after restore"):
		return

	custom_prop_root.queue_free()
	await process_frame
	print("[PASS] Test 4A: Descendant lights, labels, screen meshes, and interaction shapes remain visible & active.")

	# Test 4B: Repeat apply (calling replace twice in a row), then restore -> assert clean restoration
	var repeat_terminal: Node3D = terminal_scene.instantiate()
	root.add_child(repeat_terminal)
	await process_frame

	var repeat_console := repeat_terminal.get_node_or_null("ConsoleVisual") as Node3D
	if not _assert(repeat_console != null and repeat_console.visible, "repeat_console missing initially"):
		return

	# First apply
	var r_rep1 := TripoPropLibraryScript.replace_prop_visual(repeat_terminal, "security_terminal")
	if not _assert(r_rep1 != null and not repeat_console.visible, "First replace failed to hide ConsoleVisual"):
		return

	# Second apply (repeat apply)
	var r_rep2 := TripoPropLibraryScript.replace_prop_visual(repeat_terminal, "security_terminal")
	if not _assert(r_rep2 != null and not repeat_console.visible, "Second replace failed on repeat terminal"):
		return
	if not _assert(repeat_terminal.has_meta(TripoPropLibraryScript.META_HIDDEN_VISUALS), "META_HIDDEN_VISUALS missing after repeat apply"):
		return
	var recorded_meta = repeat_terminal.get_meta(TripoPropLibraryScript.META_HIDDEN_VISUALS) as Array
	if not _assert(recorded_meta.size() > 0, "META_HIDDEN_VISUALS was wiped to empty array after repeat apply!"):
		return

	# Restore after repeat apply
	var r_restore := TripoPropLibraryScript.restore_prop_visual(repeat_terminal)
	if not _assert(r_restore, "restore_prop_visual failed after repeat apply"):
		return
	if not _assert(repeat_console.visible, "ConsoleVisual was not restored to visible after repeat apply"):
		return

	repeat_terminal.queue_free()
	await process_frame

	# Weapon repeat apply test
	var repeat_katana: Node3D = katana_scene.instantiate()
	root.add_child(repeat_katana)
	await process_frame

	var rk_blade := repeat_katana.get_node_or_null("Blade") as Node3D
	var rk_handle := repeat_katana.get_node_or_null("Handle") as Node3D
	var rk_tsuba := repeat_katana.get_node_or_null("Tsuba") as Node3D

	var rw1 := TripoWeaponVisualsScript._replace_katana_visual(repeat_katana)
	var rw2 := TripoWeaponVisualsScript._replace_katana_visual(repeat_katana)
	if not _assert(rw1 != null and rw2 != null, "Repeat _replace_katana_visual failed"):
		return
	if not _assert(repeat_katana.has_meta(TripoWeaponVisualsScript.META_HIDDEN_WEAPONS), "META_HIDDEN_WEAPONS missing after repeat apply"):
		return
	var w_meta = repeat_katana.get_meta(TripoWeaponVisualsScript.META_HIDDEN_WEAPONS) as Array
	if not _assert(w_meta.size() > 0, "META_HIDDEN_WEAPONS was wiped to empty array after repeat apply!"):
		return

	var rw_restore := TripoWeaponVisualsScript.restore_katana_visual(repeat_katana)
	if not _assert(rw_restore, "restore_katana_visual failed after repeat apply"):
		return
	if not _assert(rk_blade.visible and rk_handle.visible and rk_tsuba.visible, "Katana parts not restored after repeat apply"):
		return

	repeat_katana.queue_free()
	await process_frame
	print("[PASS] Test 4B: Repeat apply on props and weapons preserves metadata and restores cleanly.")

	# Test 4C: Pre-existing hidden visual -> assert after replace and restore, it REMAINS visible=false
	var prehidden_root := Node3D.new()
	prehidden_root.name = "PrehiddenRoot"
	root.add_child(prehidden_root)

	var p_active_mesh := MeshInstance3D.new()
	p_active_mesh.name = "ActiveMesh"
	p_active_mesh.visible = true
	prehidden_root.add_child(p_active_mesh)

	var p_hidden_mesh := MeshInstance3D.new()
	p_hidden_mesh.name = "AlreadyHiddenMesh"
	p_hidden_mesh.visible = false
	prehidden_root.add_child(p_hidden_mesh)

	await process_frame

	var ph_rep := TripoPropLibraryScript.replace_prop_visual(prehidden_root, "security_terminal")
	if not _assert(ph_rep != null, "replace_prop_visual failed on prehidden_root"):
		return
	if not _assert(not p_active_mesh.visible, "ActiveMesh should be hidden after replacement"):
		return
	if not _assert(not p_hidden_mesh.visible, "AlreadyHiddenMesh should remain hidden"):
		return

	var ph_restore := TripoPropLibraryScript.restore_prop_visual(prehidden_root)
	if not _assert(ph_restore, "restore_prop_visual failed on prehidden_root"):
		return
	if not _assert(p_active_mesh.visible, "ActiveMesh must be restored to visible=true"):
		return
	if not _assert(not p_hidden_mesh.visible, "AlreadyHiddenMesh MUST REMAIN visible=false (preserved)"):
		return

	prehidden_root.queue_free()
	await process_frame

	# Weapon pre-existing hidden state test
	var prehidden_katana: Node3D = katana_scene.instantiate()
	root.add_child(prehidden_katana)
	await process_frame

	var ph_blade := prehidden_katana.get_node_or_null("Blade") as Node3D
	var ph_handle := prehidden_katana.get_node_or_null("Handle") as Node3D
	var ph_tsuba := prehidden_katana.get_node_or_null("Tsuba") as Node3D

	# Pre-hide the Handle before replacement
	ph_handle.visible = false
	ph_blade.visible = true
	ph_tsuba.visible = true

	var ph_w_rep := TripoWeaponVisualsScript._replace_katana_visual(prehidden_katana)
	if not _assert(ph_w_rep != null, "Weapon replacement failed"):
		return
	if not _assert(not ph_blade.visible and not ph_handle.visible and not ph_tsuba.visible, "Weapon parts should be hidden"):
		return

	var ph_w_restore := TripoWeaponVisualsScript.restore_katana_visual(prehidden_katana)
	if not _assert(ph_w_restore, "Weapon restore failed"):
		return
	if not _assert(ph_blade.visible, "Blade should be restored to visible=true"):
		return
	if not _assert(ph_tsuba.visible, "Tsuba should be restored to visible=true"):
		return
	if not _assert(not ph_handle.visible, "Handle was pre-existing hidden and MUST REMAIN visible=false"):
		return

	prehidden_katana.queue_free()
	await process_frame
	print("[PASS] Test 4C: Pre-existing hidden visuals on props and weapons remain false after restore.")

	print("=================================================================")
	print("[ALL CHECKS PASSED] Tripo 20261008 Assets Review Complete: Exit 0")
	print("=================================================================")
	quit(0)

func _calculate_bounds(node: Node3D) -> AABB:
	var aabb := AABB()
	var first := true
	var mesh_instances := node.find_children("*", "MeshInstance3D", true, false)
	for mi in mesh_instances:
		var m_inst := mi as MeshInstance3D
		if m_inst and m_inst.mesh:
			var sub_aabb := m_inst.mesh.get_aabb()
			if first:
				aabb = sub_aabb
				first = false
			else:
				aabb = aabb.merge(sub_aabb)
	return aabb

func _assert(condition: bool, message: String) -> bool:
	if not condition:
		push_error("[TRIPO REVIEW ASSERTION FAILED] " + message)
		printerr("[TRIPO REVIEW ASSERTION FAILED] " + message)
		quit(1)
		return false
	return true

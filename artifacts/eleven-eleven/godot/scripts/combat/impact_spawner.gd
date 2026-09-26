class_name ImpactSpawner
extends Node

## Combat Impact FX & Decal System (Sparks, Slashes, Crater Decals & Screen Shake)

static func spawn_impact_burst(parent: Node, hit_pos: Vector3, is_heavy: bool = false) -> void:
	if not is_instance_valid(parent):
		return
	spawn_katana_sparks(parent, hit_pos, Vector3.UP, is_heavy)

static func spawn_katana_sparks(parent: Node, hit_pos: Vector3, hit_normal: Vector3 = Vector3.UP, is_heavy: bool = false) -> void:
	if not is_instance_valid(parent):
		return

	# 1. High-frequency anime spark burst (Dual Mana: Violet & Crimson / Gold)
	var particles := GPUParticles3D.new()
	particles.name = "KatanaSparks"
	particles.position = hit_pos
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 40 if is_heavy else 24
	particles.lifetime = 0.35
	particles.explosiveness = 0.95

	var p_mat := ParticleProcessMaterial.new()
	p_mat.direction = hit_normal + Vector3(randf_range(-0.4, 0.4), randf_range(0.2, 0.8), randf_range(-0.4, 0.4))
	p_mat.spread = 45.0
	p_mat.initial_velocity_min = 4.5
	p_mat.initial_velocity_max = 10.0 if is_heavy else 7.0
	p_mat.gravity = Vector3(0, -12.0, 0)
	p_mat.scale_min = 0.04
	p_mat.scale_max = 0.14 if is_heavy else 0.09
	p_mat.color = Color(0.85, 0.2, 0.95, 1.0) if not is_heavy else Color(1.0, 0.22, 0.15, 1.0)
	particles.process_material = p_mat

	var draw_mesh := BoxMesh.new()
	draw_mesh.size = Vector3(0.03, 0.03, 0.12)
	var mesh_mat := StandardMaterial3D.new()
	mesh_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	mesh_mat.albedo_color = Color(1.0, 0.7, 0.9, 1.0) if not is_heavy else Color(1.0, 0.85, 0.5, 1.0)
	draw_mesh.material = mesh_mat
	particles.draw_pass_1 = draw_mesh
	parent.add_child(particles)

	# 2. Sumi-e Black Ink Slash Bursts (Obsidian Void Splash)
	var ink_particles := GPUParticles3D.new()
	ink_particles.name = "SumiInkSparks"
	ink_particles.position = hit_pos
	ink_particles.emitting = true
	ink_particles.one_shot = true
	ink_particles.amount = 20 if is_heavy else 12
	ink_particles.lifetime = 0.45
	ink_particles.explosiveness = 0.92

	var ink_p_mat := ParticleProcessMaterial.new()
	ink_p_mat.direction = -hit_normal + Vector3(randf_range(-0.6, 0.6), randf_range(-0.2, 0.5), randf_range(-0.6, 0.6))
	ink_p_mat.spread = 60.0
	ink_p_mat.initial_velocity_min = 2.0
	ink_p_mat.initial_velocity_max = 5.5 if is_heavy else 4.0
	ink_p_mat.gravity = Vector3(0, -9.8, 0)
	ink_p_mat.scale_min = 0.05
	ink_p_mat.scale_max = 0.16 if is_heavy else 0.11
	ink_p_mat.color = Color(0.05, 0.02, 0.08, 0.95)
	ink_particles.process_material = ink_p_mat

	var ink_mesh := SphereMesh.new()
	ink_mesh.radius = 0.04
	ink_mesh.height = 0.08
	var ink_mat := StandardMaterial3D.new()
	ink_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	ink_mat.albedo_color = Color(0.06, 0.02, 0.1, 0.95)
	ink_mesh.material = ink_mat
	ink_particles.draw_pass_1 = ink_mesh
	parent.add_child(ink_particles)

	# 3. Ground Slash Decal (Obsidian & Void Violet)
	var decal := Decal.new()
	decal.name = "KatanaSlashDecal"
	decal.position = Vector3(hit_pos.x, 0.02, hit_pos.z)
	decal.size = Vector3(0.2, 0.8, 1.4) if not is_heavy else Vector3(0.35, 1.0, 2.4)
	decal.rotation.y = randf_range(0, PI)
	decal.modulate = Color(0.65, 0.15, 0.9, 0.85) if not is_heavy else Color(0.95, 0.18, 0.22, 0.9)
	parent.add_child(decal)

	# 4. Visceral 3D Punchy Audio Crunch
	if parent.is_inside_tree():
		var audio := AudioStreamPlayer3D.new()
		audio.position = hit_pos
		audio.max_distance = 25.0
		audio.bus = "Master"
		audio.stream = ProceduralCinematicAudio.create_visceral_katana_hit_sfx(is_heavy)
		parent.add_child(audio)
		audio.play()
		audio.finished.connect(func(): if is_instance_valid(audio): audio.queue_free())

	# Auto-clean via tween
	var tree = parent.get_tree() if parent.is_inside_tree() else null
	if tree:
		var tween := tree.create_tween()
		tween.tween_property(decal, "modulate:a", 0.0, 2.2).set_delay(0.6)
		tween.tween_callback(func():
			if is_instance_valid(decal): decal.queue_free()
			if is_instance_valid(particles): particles.queue_free()
			if is_instance_valid(ink_particles): ink_particles.queue_free()
		)

static func spawn_boss_slam_crater(parent: Node, slam_pos: Vector3) -> void:
	if not parent:
		return

	# Radial Shockwave Crater Decal
	var crater_decal := Decal.new()
	crater_decal.name = "BossCraterDecal"
	crater_decal.position = Vector3(slam_pos.x, 0.02, slam_pos.z)
	crater_decal.size = Vector3(4.2, 1.2, 4.2)
	crater_decal.modulate = Color(1.0, 0.12, 0.22, 0.9)

	parent.add_child(crater_decal)

	# Radial blast particles
	var blast := GPUParticles3D.new()
	blast.name = "CraterBlast"
	blast.position = slam_pos
	blast.emitting = true
	blast.one_shot = true
	blast.amount = 45
	blast.lifetime = 0.5
	blast.explosiveness = 0.92

	var b_mat := ParticleProcessMaterial.new()
	b_mat.direction = Vector3.UP
	b_mat.spread = 80.0
	b_mat.initial_velocity_min = 6.0
	b_mat.initial_velocity_max = 11.0
	b_mat.gravity = Vector3(0, -14.0, 0)
	b_mat.scale_min = 0.08
	b_mat.scale_max = 0.2
	b_mat.color = Color(1.0, 0.2, 0.3, 1.0)
	blast.process_material = b_mat

	var draw_mesh := BoxMesh.new()
	draw_mesh.size = Vector3(0.08, 0.08, 0.08)
	var m_mat := StandardMaterial3D.new()
	m_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	m_mat.albedo_color = Color(1.0, 0.35, 0.4, 1.0)
	draw_mesh.material = m_mat
	blast.draw_pass_1 = draw_mesh

	parent.add_child(blast)

	var tree = parent.get_tree() if parent.is_inside_tree() else null
	if tree:
		var tween := tree.create_tween()
		tween.tween_property(crater_decal, "modulate:a", 0.0, 3.5).set_delay(1.0)
		tween.tween_callback(func():
			if is_instance_valid(crater_decal): crater_decal.queue_free()
			if is_instance_valid(blast): blast.queue_free()
		)

static func trigger_screen_shake(camera: Camera3D, intensity: float = 0.12, duration: float = 0.25) -> void:
	if not camera or not camera.is_inside_tree():
		return
	var tree = camera.get_tree()
	var timer := 0.0
	var orig_h := camera.h_offset
	var orig_v := camera.v_offset

	var tween := tree.create_tween()
	var steps: int = int(duration * 60)
	for i in range(steps):
		var damp: float = 1.0 - (float(i) / float(steps))
		var offset_h = randf_range(-intensity, intensity) * damp
		var offset_v = randf_range(-intensity, intensity) * damp
		tween.tween_property(camera, "h_offset", orig_h + offset_h, 0.016)
		tween.tween_property(camera, "v_offset", orig_v + offset_v, 0.016)
	tween.tween_property(camera, "h_offset", orig_h, 0.02)
	tween.tween_property(camera, "v_offset", orig_v, 0.02)

const DamageNumberSpawnerScript = preload("res://scripts/combat/damage_number_spawner.gd")

static func spawn_deflect_burst(parent: Node, hit_pos: Vector3) -> void:
	if not parent:
		return

	# High-energy radial deflect burst
	var particles := GPUParticles3D.new()
	particles.name = "DeflectSparks"
	particles.position = hit_pos
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 40
	particles.lifetime = 0.38
	particles.explosiveness = 0.98

	var p_mat := ParticleProcessMaterial.new()
	p_mat.direction = Vector3.UP
	p_mat.spread = 180.0
	p_mat.initial_velocity_min = 8.0
	p_mat.initial_velocity_max = 14.0
	p_mat.gravity = Vector3(0, -6.0, 0)
	p_mat.scale_min = 0.05
	p_mat.scale_max = 0.16
	p_mat.color = Color(0.0, 0.95, 1.0, 1.0)
	particles.process_material = p_mat

	var draw_mesh := BoxMesh.new()
	draw_mesh.size = Vector3(0.04, 0.04, 0.16)
	var mesh_mat := StandardMaterial3D.new()
	mesh_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	mesh_mat.albedo_color = Color(1.0, 0.95, 0.5, 1.0)
	draw_mesh.material = mesh_mat
	particles.draw_pass_1 = draw_mesh

	parent.add_child(particles)

	# Deflect point flash
	var light := OmniLight3D.new()
	light.light_color = Color(0.0, 0.95, 1.0)
	light.light_energy = 8.0
	light.omni_range = 4.5
	light.position = hit_pos
	parent.add_child(light)

	# Expanding 3D Radial Shockwave Ring (Genshin / Sekiro Standard)
	var ring := MeshInstance3D.new()
	ring.name = "DeflectShockwaveRing"
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.82
	ring_mesh.outer_radius = 1.0
	ring_mesh.rings = 32
	ring_mesh.ring_segments = 16
	ring.mesh = ring_mesh
	
	var r_mat := StandardMaterial3D.new()
	r_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	r_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	r_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	r_mat.albedo_color = Color(0.1, 0.95, 1.0, 0.9)
	ring.material_override = r_mat
	ring.position = hit_pos
	ring.scale = Vector3(0.1, 0.1, 0.1)
	parent.add_child(ring)

	var tree = parent.get_tree() if parent.is_inside_tree() else null
	if tree:
		var tween := tree.create_tween()
		tween.tween_property(light, "light_energy", 0.0, 0.18)
		tween.tween_callback(func():
			if is_instance_valid(light): light.queue_free()
			if is_instance_valid(particles): particles.queue_free()
		)
		var r_tween := tree.create_tween()
		r_tween.parallel().tween_property(ring, "scale", Vector3(3.2, 3.2, 3.2), 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		r_tween.parallel().tween_property(r_mat, "albedo_color:a", 0.0, 0.24)
		r_tween.tween_callback(func():
			if is_instance_valid(ring): ring.queue_free()
		)

	# Spawn floating DEFLECT! indicator
	spawn_damage_number(parent, hit_pos + Vector3(0, 0.5, 0), 0, false, true)

	# Cinematic Camera Trauma & FOV Punch (Sekiro / Genshin Impact Feedback)
	if parent.is_inside_tree():
		var director = parent.find_child("CineCameraDirector", true, false)
		if not director and parent.get_tree() and parent.get_tree().root:
			director = parent.get_tree().root.find_child("CineCameraDirector", true, false)
		if director and director.has_method("apply_trauma"):
			director.apply_trauma(0.38)
			if director.has_method("punch_fov"):
				director.punch_fov(64.0, 0.06, 0.3)

static func spawn_damage_number(parent: Node, world_pos: Vector3, damage: int, is_crit: bool = false, is_deflect: bool = false) -> void:
	DamageNumberSpawnerScript.spawn_number(parent, world_pos, damage, is_crit, is_deflect)


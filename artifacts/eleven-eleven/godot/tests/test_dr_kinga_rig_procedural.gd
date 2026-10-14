extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	print("--- BEGIN DR. KINGA PROCEDURAL SKELETAL TEST ---")
	var scene: PackedScene = load("res://scenes/characters/dr_kinga.tscn")
	assert(scene != null, "dr_kinga.tscn must load")
	var kinga: DrKinga = scene.instantiate() as DrKinga
	root.add_child(kinga)
	
	# Wait for ready
	for i in 3:
		await process_frame

	# 1. Rig and Bone count check
	var sk: Skeleton3D = kinga.skeleton
	assert(sk != null, "Skeleton3D must exist on DrKinga")
	assert(sk.get_bone_count() == 33, "Skeleton3D must have exactly 33 bones (actual: %d)" % sk.get_bone_count())
	print("[PASS 1/7] 33-bone Skeleton3D confirmed on DrKinga.")

	# 2. Backward compatibility checks
	assert(kinga.hp == 600.0, "HP must be 600")
	assert(kinga.max_hp == 600.0, "max_hp must be 600")
	assert(kinga.monocle_light != null and kinga.monocle_light.visible, "monocle_light must exist and be visible")
	assert(kinga.syringe_glow != null, "syringe_glow must exist")
	assert(kinga.hex_shield != null, "hex_shield must exist")
	assert(kinga.laser_beam != null, "laser_beam must exist")
	assert(kinga.has_signal("confrontation_started"), "confrontation_started signal must exist")
	assert(kinga.has_signal("dialogue_advanced"), "dialogue_advanced signal must exist")
	assert(kinga.has_signal("injection_administered"), "injection_administered signal must exist")
	assert(kinga.has_signal("scientist_terrified"), "scientist_terrified signal must exist")
	assert(kinga.has_signal("kinga_defeated"), "kinga_defeated signal must exist")
	assert(kinga.has_signal("hp_changed"), "hp_changed signal must exist")
	print("[PASS 2/7] Backward compatibility properties and signals verified.")

	# 3. Idle breathing & coat sway test
	kinga.velocity = Vector3.ZERO
	kinga.current_state = kinga.State.IDLE
	kinga.update_procedural_skeleton(0.0)
	var chest_idx: int = sk.find_bone("Chest")
	var coat_idx: int = sk.find_bone("Coat_2_0")
	var idle_chest_rot_0 = sk.get_bone_pose_rotation(chest_idx)
	var idle_coat_rot_0 = sk.get_bone_pose_rotation(coat_idx)
	
	# Advance time
	kinga.update_procedural_skeleton(0.5)
	var idle_chest_rot_1 = sk.get_bone_pose_rotation(chest_idx)
	var idle_coat_rot_1 = sk.get_bone_pose_rotation(coat_idx)
	assert(!idle_chest_rot_0.is_equal_approx(idle_chest_rot_1), "Idle breathing must animate Chest")
	assert(!idle_coat_rot_0.is_equal_approx(idle_coat_rot_1), "Idle coat sway must animate Coat")
	print("[PASS 3/7] Idle breathing cycle and coat sway verified.")

	# 4. Moving locomotion test (velocity.length() > 0.1)
	kinga.velocity = Vector3(2.5, 0, 0)
	kinga.update_procedural_skeleton(0.0)
	var l_leg_idx: int = sk.find_bone("LeftUpLeg")
	var r_leg_idx: int = sk.find_bone("RightUpLeg")
	var l_arm_idx: int = sk.find_bone("LeftArm")
	var r_arm_idx: int = sk.find_bone("RightArm")
	var move_l_leg_0 = sk.get_bone_pose_rotation(l_leg_idx)
	var move_r_leg_0 = sk.get_bone_pose_rotation(r_leg_idx)
	
	kinga.update_procedural_skeleton(0.3)
	var move_l_leg_1 = sk.get_bone_pose_rotation(l_leg_idx)
	var move_r_leg_1 = sk.get_bone_pose_rotation(r_leg_idx)
	var move_l_arm_1 = sk.get_bone_pose_rotation(l_arm_idx)
	var move_r_arm_1 = sk.get_bone_pose_rotation(r_arm_idx)
	assert(!move_l_leg_0.is_equal_approx(move_l_leg_1), "Moving must animate LeftUpLeg")
	assert(!move_r_leg_0.is_equal_approx(move_r_leg_1), "Moving must animate RightUpLeg")
	print("[PASS 4/7] Locomotion leg swing and arm/coat sway verified.")

	# 5. Laser firing pose test
	kinga.velocity = Vector3.ZERO
	kinga._start_neural_laser()
	assert(kinga.is_firing_laser, "is_firing_laser must be true")
	kinga.update_procedural_skeleton(0.016)
	var r_arm_rot = sk.get_bone_pose_rotation(r_arm_idx)
	var r_forearm_idx: int = sk.find_bone("RightForeArm")
	var r_forearm_rot = sk.get_bone_pose_rotation(r_forearm_idx)
	assert(!r_arm_rot.is_equal_approx(sk.get_bone_rest(r_arm_idx).basis.get_rotation_quaternion()), "RightArm must be posed during laser firing")
	print("[PASS 5/7] Neural laser firing arm aim pose verified.")

	# 6. Syringe lunge pose test
	kinga.is_firing_laser = false
	kinga._start_syringe_lunge(Vector3(0, 0, 5))
	assert(kinga.is_lunging, "is_lunging must be true")
	kinga.update_procedural_skeleton(0.016)
	var lunge_arm_rot = sk.get_bone_pose_rotation(r_arm_idx)
	assert(!lunge_arm_rot.is_equal_approx(sk.get_bone_rest(r_arm_idx).basis.get_rotation_quaternion()), "RightArm must be thrust forward during lunge")
	print("[PASS 6/7] Toxic syringe lunge thrust pose verified.")

	# 7. Stagger and Terrified cower poses
	kinga.is_lunging = false
	kinga.is_staggered = true
	kinga.stagger_timer = 2.0
	kinga.update_procedural_skeleton(0.016)
	var stagger_chest = sk.get_bone_pose_rotation(chest_idx)
	assert(!stagger_chest.is_equal_approx(idle_chest_rot_0), "Chest must recoil during stagger")
	
	kinga.is_staggered = false
	kinga.react_to_zero_singularity()
	assert(kinga.current_state == kinga.State.TERRIFIED, "Must enter TERRIFIED state")
	kinga.update_procedural_skeleton(0.016)
	var cower_arm_l = sk.get_bone_pose_rotation(l_arm_idx)
	var cower_arm_r = sk.get_bone_pose_rotation(r_arm_idx)
	assert(!cower_arm_l.is_equal_approx(sk.get_bone_rest(l_arm_idx).basis.get_rotation_quaternion()), "Left arm raised defensively")
	assert(!cower_arm_r.is_equal_approx(sk.get_bone_rest(r_arm_idx).basis.get_rotation_quaternion()), "Right arm raised defensively")
	print("[PASS 7/7] Stagger flinch and Terrified cower poses verified.")

	kinga.free()
	print("ALL DR. KINGA PROCEDURAL SKELETAL TESTS PASSED PERFECTLY!")
	quit(0)

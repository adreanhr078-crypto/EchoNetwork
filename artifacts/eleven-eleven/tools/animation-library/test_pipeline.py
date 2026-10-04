"""Regression guards for actual source-library classification/measurement defects."""
import unittest
import numpy as np

from bone_roles import role, role_indices
from classify import suggest
from contact_metrics import measure_contacts
from retarget_contract import joint_map, planar_yaw
import math
from compare_walks import reusable_fingerprint


class PipelineTests(unittest.TestCase):
    def test_opposite_forward_vectors_use_yaw_and_preserve_up(self):
        yaw = planar_yaw((0,-1,0),(0,1,0))
        self.assertAlmostEqual(abs(yaw), math.pi)
        x,y = 0,-1
        self.assertAlmostEqual(x*math.cos(yaw)-y*math.sin(yaw),0)
        self.assertAlmostEqual(x*math.sin(yaw)+y*math.cos(yaw),1)
        with self.assertRaises(ValueError): planar_yaw((0,0,1),(0,1,0))

    def test_resume_cannot_reuse_a_different_take_or_bake(self):
        original = {'source_sha256':'source','take_id':'take-0','target_sha256':'rig-1',
                    'tool_hashes':{'retarget_contacts.py':'bake-1','review_skin.py':'measure-1'}}
        self.assertTrue(reusable_fingerprint(original,{**original,'tool_hashes':{**original['tool_hashes'],'review_skin.py':'measure-2'}}))
        self.assertFalse(reusable_fingerprint(original,{**original,'take_id':'take-1'}))
        self.assertFalse(reusable_fingerprint(original,{**original,'target_sha256':'rig-2'}))
        self.assertFalse(reusable_fingerprint(original,{**original,'tool_hashes':{**original['tool_hashes'],'retarget_contacts.py':'bake-2'}}))

    def test_rokoko_thigh_is_not_mixamo_shin(self):
        mapping = joint_map(['Hips','LeftLeg','LeftShin','RightLeg','RightShin','Spine1','Spine2','Chest'])
        self.assertEqual(mapping['leftupleg'], 'LeftLeg')
        self.assertEqual(mapping['leftleg'], 'LeftShin')
        self.assertEqual(mapping['spine2'], 'Chest')
        self.assertEqual(joint_map(['mixamorig_LeftUpLeg','mixamorig_LeftLeg'])['leftleg'], 'mixamorig_LeftLeg')
        with self.assertRaises(ValueError): joint_map(['Hips', 'mixamorig_Hips'])
        unreal = joint_map(['pelvis','thigh_l','calf_l','thigh_r','calf_r','ball_l','foot_l','calf_twist_01_l'])
        self.assertEqual(unreal['leftleg'], 'calf_l')
        self.assertEqual(unreal['lefttoebase'], 'ball_l')
        self.assertEqual(unreal['hips'], 'pelvis')
        self.assertNotEqual(unreal['leftleg'], 'calf_twist_01_l')

    def test_humanik_namespace_does_not_hide_real_primary_joints(self):
        names = ["Character1_Hips", "Character1_LeftLeg", "mixamorig:RightFoot", "foot_l"]
        self.assertEqual(set(role_indices(names)), {"hips", "left_knee", "right_foot", "left_foot"})
        self.assertIsNone(role("LeafLeftLegRoll1"))
        with self.assertRaises(ValueError): role_indices(["LeftLeg", "Character1_LeftLeg"])

    def test_different_semantics_stay_separate_while_pack_variants_match(self):
        def proposal(name): return suggest({"original_filename":name, "source_entry":name})["proposed_action_id"]
        self.assertEqual(proposal("MOB1_Walk_F_IPC.fbx"), proposal("Walking.fbx"))
        self.assertNotEqual(proposal("Walk Backward.fbx"), proposal("Walking.fbx"))
        self.assertNotEqual(proposal("Soft Landing.fbx"), proposal("Hard Landing.fbx"))
        self.assertNotEqual(proposal("Light Attack.fbx"), proposal("Heavy Attack.fbx"))

    def test_low_fast_swing_is_not_planted_contact(self):
        positions = np.zeros((12, 3, 3))
        positions[:,0,2] = 1
        positions[:,0,1] = np.arange(12)*.04  # translating-root source
        positions[:,1:,2] = .02
        positions[7:,1,1] = np.arange(5)*.2  # one toe swings fast near floor
        result = measure_contacts(positions, {"hips":0,"left_toe":1,"right_toe":2},30)
        self.assertEqual(result["right"]["contact_samples"],11)
        self.assertEqual(result["left"]["contact_samples"],7)
        self.assertLess(result["left"]["contact_intervals"][0]["world_drift_m"],1e-6)


if __name__ == "__main__": unittest.main()

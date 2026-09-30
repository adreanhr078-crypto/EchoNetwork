"""Regression guards for actual source-library classification/measurement defects."""
import unittest
import numpy as np

from bone_roles import role, role_indices
from classify import suggest
from contact_metrics import measure_contacts


class PipelineTests(unittest.TestCase):
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

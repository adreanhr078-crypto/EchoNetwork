"""Run with Blender: tests structural motion checks, not character artistry."""
import importlib.util
from pathlib import Path
import unittest
import sys

import bpy

sys.dont_write_bytecode = True

spec = importlib.util.spec_from_file_location(
    "character_gate", Path(__file__).with_name("validate_character_glb.py"))
gate = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gate)


class CharacterMotionTests(unittest.TestCase):
    def setUp(self):
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.ops.object.armature_add(enter_editmode=True)
        self.rig = bpy.context.object
        root = self.rig.data.edit_bones[0]
        root.name = "root"
        child = self.rig.data.edit_bones.new("spine")
        child.head = (0, 0, 1)
        child.tail = (0, 0, 2)
        child.parent = root
        bpy.ops.object.mode_set(mode="OBJECT")
        self.bone = self.rig.pose.bones["spine"]
        self.bone.rotation_mode = "XYZ"

    def test_rejects_single_frame_named_action(self):
        self.rig.keyframe_insert(data_path="location", frame=1)
        with self.assertRaisesRegex(RuntimeError, "no duration"):
            gate.validate_animated_pose(self.rig, self.rig.animation_data.action)

    def test_rejects_static_pose_with_duration(self):
        for frame in (1, 25):
            self.bone.keyframe_insert(data_path="rotation_euler", frame=frame)
        with self.assertRaisesRegex(RuntimeError, "no changing bone pose"):
            gate.validate_animated_pose(self.rig, self.rig.animation_data.action)

    def test_rejects_rigid_object_motion(self):
        self.rig.keyframe_insert(data_path="location", frame=1)
        self.rig.location.x = 2
        self.rig.keyframe_insert(data_path="location", frame=25)
        with self.assertRaisesRegex(RuntimeError, "no changing bone pose"):
            gate.validate_animated_pose(self.rig, self.rig.animation_data.action)

    def test_accepts_actual_joint_motion_after_glb_roundtrip(self):
        import tempfile
        self.bone.keyframe_insert(data_path="rotation_euler", frame=1)
        self.bone.rotation_euler.x = 0.4
        self.bone.keyframe_insert(data_path="rotation_euler", frame=25)
        action = self.rig.animation_data.action
        gate.validate_animated_pose(self.rig, action)
        # This non-production fixture also checks the current Blender action API.
        with tempfile.TemporaryDirectory() as directory:
            path = str(Path(directory) / "motion-test.glb")
            bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", export_animations=True)
            bpy.ops.wm.read_factory_settings(use_empty=True)
            bpy.ops.import_scene.gltf(filepath=path)
            rig = next(obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE")
            gate.validate_animated_pose(rig, bpy.data.actions[0])


unittest.main(argv=[__file__])

"""Regression guards for frozen Walk transfer and genuine native FBX timing."""
import argparse
import ast
import contextlib
import io
import json
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

import golden_reference as golden
from native_timing import read_native_fps, validate_timing


TOOLS = Path(__file__).resolve().parent


class GoldenGuardTests(unittest.TestCase):
    def test_landing_uses_actual_cli_without_relaxing_frozen_transfer(self):
        # Execute the real argument-parser construction only. No bpy import,
        # source import, bake or output mutation is needed to test this boundary.
        tree = ast.parse((TOOLS/'single_motion.py').read_text(encoding='utf-8'))
        main = next(node for node in tree.body if isinstance(node, ast.FunctionDef) and node.name == 'main')
        parser_nodes = []
        for node in main.body:
            if isinstance(node, ast.Assign) and ast.unparse(node.targets[0]) == 'args':
                break
            parser_nodes.append(node)
        namespace = {'argparse': argparse, 'Path': Path}
        exec(compile(ast.Module(body=parser_nodes, type_ignores=[]), 'single_motion_actual_cli', 'exec'), namespace)
        parser = namespace['parser']
        base = ['--mode', 'inspect', '--output', str(golden.APP/'audits/evidence/test-cli-only'),
                '--take-id', '1e5dbcb588e10f4fe3615272:0:13373cc7', '--clip-name']
        for clip in ['Run', 'Idle', 'Jump', 'Landing']:
            with self.subTest(clip=clip):
                self.assertEqual(parser.parse_args(base + [clip]).clip_name, clip)
        with contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit):
            parser.parse_args(base + ['UnsupportedSemantic'])
        golden.assert_transfer_equal(TOOLS/'single_motion.py')

    def test_existing_golden_and_adapted_transfer_are_intact(self):
        data = golden.verify()
        self.assertEqual(data['status'], 'OWNER_APPROVED_GOLDEN_REFERENCE')
        golden.assert_transfer_equal(TOOLS/'single_motion.py')

    def test_mutating_rest_loop_or_export_contract_fails_closed(self):
        source = (TOOLS/'single_motion.py').read_text(encoding='utf-8')
        mutations = {
            'rest_alignment': ('align = Quaternion((0,0,1), yaw)',
                               'align = Quaternion((1,0,0), yaw)'),
            'hip_translation': ('position = tr[k].translation + (align @ (pose[k].translation-sr[k].translation))*ratio',
                                'position = tr[k].translation + (align @ (pose[k].translation-sr[k].translation))*ratio*2'),
            'export_scope': ("export_animation_mode='ACTIVE_ACTIONS'",
                             "export_animation_mode='ACTIONS'"),
        }
        with tempfile.TemporaryDirectory(prefix='golden-guard-', dir=golden.APP/'.tmp') as temporary:
            for label, (before, after) in mutations.items():
                with self.subTest(contract=label):
                    self.assertEqual(source.count(before), 1)
                    mutant = Path(temporary)/(label+'.py')
                    mutant.write_text(source.replace(before, after), encoding='utf-8')
                    with self.assertRaises(ValueError):
                        golden.assert_transfer_equal(mutant)

    def test_output_cannot_touch_either_walk_copy_or_escape_app(self):
        original = golden.APP/'audits/evidence/single-walk-20260930'
        for forbidden in [original, original/'child', golden.ROOT,
                          golden.ROOT/'child', golden.APP.parent/'outside-review', golden.APP]:
            with self.subTest(path=str(forbidden)), self.assertRaises(ValueError):
                golden.guard_output(forbidden)
        golden.guard_output(golden.APP/'audits/evidence/new-isolated-motion')

    def test_protected_bytes_and_manifest_tampering_are_detected(self):
        # Use a disposable fake seal; never mutate or reseal the real Walk.
        with tempfile.TemporaryDirectory(prefix='golden-hash-', dir=golden.APP/'.tmp') as temporary:
            app = Path(temporary)
            root = app/'golden'
            root.mkdir()
            protected = app/'source.bin'
            protected.write_bytes(b'original source')
            manifest = root/'GoldenReference.json'
            payload = {'protected_files': {'source.bin': golden.sha(protected)}, 'snapshot_files': {}}
            manifest.write_text(json.dumps(payload), encoding='utf-8')
            (root/'GoldenReference.sha256').write_text(golden.sha(manifest), encoding='utf-8')
            with patch.object(golden, 'APP', app), patch.object(golden, 'ROOT', root):
                golden.verify()
                protected.write_bytes(b'changed source')
                with self.assertRaisesRegex(ValueError, 'Golden reference changed'):
                    golden.verify()
                protected.write_bytes(b'original source')
                manifest.write_text(json.dumps({**payload, 'unexpected': True}), encoding='utf-8')
                with self.assertRaisesRegex(ValueError, 'Golden manifest changed'):
                    golden.verify()

    def test_existing_walk_cannot_be_resealed(self):
        before = golden.sha(golden.ROOT/'GoldenReference.json')
        with self.assertRaisesRegex(ValueError, 'resealing is prohibited'):
            golden.seal()
        self.assertEqual(before, golden.sha(golden.ROOT/'GoldenReference.json'))


class NativeTimingTests(unittest.TestCase):
    def test_native_30_is_accepted_but_60_cannot_be_relabelled(self):
        candidate = {'fps': 30, 'source_frame_range': [1, 25]}
        validate_timing(30, candidate, 1, 25, {'native_fps': 30})
        with self.assertRaises(ValueError):
            validate_timing(30, candidate, 1, 25, {'native_fps': 60})

    def test_import_metadata_and_frame_ranges_must_agree(self):
        cases = [
            (60, {'fps': 30, 'source_frame_range': [1, 25]}, 1, 25),
            (30, {'fps': 60, 'source_frame_range': [1, 25]}, 1, 25),
            (30, {'fps': 30, 'source_frame_range': [1, 24]}, 1, 25),
            (30, {'fps': 30, 'source_frame_range': [0, 24]}, 0, 24),
            (30, {'fps': 30, 'source_frame_range': [1, 25.5]}, 1, 25.5),
        ]
        for args in cases:
            with self.subTest(args=args), self.assertRaises(ValueError):
                validate_timing(*args, {'native_fps': 30})

    def test_original_header_rate_is_read_without_scene_fps(self):
        def parser_for(mode, custom=None):
            properties = [SimpleNamespace(id=b'P', props=[b'TimeMode', None, None, None, mode])]
            if custom is not None:
                properties.append(SimpleNamespace(id=b'P', props=[b'CustomFrameRate', None, None, None, custom]))
            root = SimpleNamespace(elems=[SimpleNamespace(id=b'GlobalSettings', elems=[
                SimpleNamespace(id=b'Properties70', elems=properties)])])
            return SimpleNamespace(parse=lambda _: (root, 7400))

        for mode, custom, expected in [(6, None, 30), (3, None, 60), (14, 60, 60), (17, None, 60/1.001)]:
            with self.subTest(mode=mode), patch('native_timing.importlib.import_module', return_value=parser_for(mode, custom)):
                self.assertAlmostEqual(read_native_fps(Path('unused.fbx'))['native_fps'], expected)
        with patch('native_timing.importlib.import_module', return_value=parser_for(14, 0)), self.assertRaises(ValueError):
            read_native_fps(Path('unused.fbx'))


if __name__ == '__main__':
    unittest.main()

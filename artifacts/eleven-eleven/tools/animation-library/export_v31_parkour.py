"""Run the guarded export, then measure every baked V31 joint without edits.

The 52 mapped bones and 16 unchanged Root/Cape bones are all compared in Godot.
This supplemental reference never replaces or weakens blender-reference.json.
"""
import hashlib
import json
from pathlib import Path
import runpy
import sys

import bpy

driver = Path(__file__).with_name('v31_parkour_motion.py')
runpy.run_path(str(driver), run_name='__main__')
args = sys.argv[sys.argv.index('--') + 1:]
if args[args.index('--mode') + 1] != 'export':
    raise ValueError('Supplemental measurement requires the guarded export mode')
folder = Path(args[args.index('--output') + 1]).resolve()
original = json.loads((folder / 'blender-reference.json').read_text())
rig = bpy.data.objects[original['target_rig']]
if len(rig.data.bones) != 68:
    raise ValueError('Actual current V31 must have exactly 68 joints')
samples = []
for frame in range(len(original['samples'])):
    bpy.context.scene.frame_set(frame)
    bpy.context.view_layer.update()
    joints = {}
    for bone in rig.pose.bones:
        matrix = rig.matrix_world @ bone.matrix
        joints[bone.name] = {'position': list(matrix.translation),
                             'quaternion_wxyz': list(matrix.to_quaternion())}
    samples.append({'time': frame / original['fps'], 'bones': joints})
report = dict(original)
report.update({'target_bones': {b.name: b.name for b in rig.data.bones},
               'samples': samples, 'scope': 'All 68 joints, including unmapped Root/Cape rest chains',
               'baked_blend_sha256': hashlib.sha256((folder / 'single-motion.blend').read_bytes()).hexdigest()})
(folder / 'all-joints-reference.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
print('ALL_JOINTS_REFERENCE', len(samples) * len(rig.data.bones))

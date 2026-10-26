"""Preserve a failed native bake for diagnosis without weakening any gate."""
import json,runpy,sys
from pathlib import Path
import bpy
from mathutils import Vector
case=Path('audits/evidence/chapter-cp45-20261020/stage11/native-attack-20261023/downward').resolve()
sys.argv=['v31_parkour_motion.py','--','--mode','bake','--output',str(case),'--take-id','e927c80f6eafc55775698910:0:13373cc7','--clip-name','Attack']
try:
 runpy.run_path('tools/animation-library/v31_parkour_motion.py',run_name='__main__')
except ValueError as exc:
 if str(exc)!='Blender gate failed; do not export':raise
 report=json.loads((case/'blender-reference.json').read_text())
 rig=bpy.data.objects[report['target_rig']];worst=[]
 for i,sample in enumerate(report['samples']):
  bpy.context.scene.frame_set(i);bpy.context.view_layer.update()
  for role,v in sample['bones'].items():
   bone=rig.pose.bones[report['target_bones'][role]]
   actual=rig.matrix_world@bone.matrix
   error=(actual.translation-Vector(v['position'])).length
   worst.append({'frame':i,'role':role,'error_m':error,'pose_scale':list(bone.scale),'basis_scale':list(bone.matrix_basis.to_scale())})
 worst.sort(key=lambda x:x['error_m'],reverse=True)
 out={'status':'FAIL_PRESERVED_NO_EXPORT','reason':str(exc),'threshold_m':.00001,'worst20':worst[:20],'gate_unchanged':True,'source_keys_changed':False}
 (case/'replay-diagnosis.json').write_text(json.dumps(out,indent=2))
 bpy.ops.wm.save_as_mainfile(filepath=str(case/'failed-bake-diagnostic.blend'))
 print(json.dumps(out))

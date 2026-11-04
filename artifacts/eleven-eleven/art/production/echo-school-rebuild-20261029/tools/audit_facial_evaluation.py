from pathlib import Path
import bpy,numpy as np,json
p=Path(__file__).resolve().parents[1];bpy.ops.wm.open_mainfile(filepath=str(p/'facial/echo-school-facial-rig.blend'));obj=bpy.data.objects['EchoFace_Controls'];keys=obj.data.shape_keys
report={'objects':[(o.name,o.hide_render,len(o.data.vertices) if o.type=='MESH' else None) for o in bpy.context.scene.objects],'controls':{},'frames':[]}
base=np.array([v.co[:] for v in keys.key_blocks['Basis'].data])
for key in keys.key_blocks:report['controls'][key.name]={'value':key.value,'delta_max_local':float(np.max(np.linalg.norm(np.array([v.co[:] for v in key.data])-base,axis=1)))}
for frame in [1,97,121,240]:
 bpy.context.scene.frame_set(frame);bpy.context.view_layer.update();evalobj=obj.evaluated_get(bpy.context.evaluated_depsgraph_get());coords=np.array([v.co[:] for v in evalobj.data.vertices]);report['frames'].append({'frame':frame,'jaw':keys.key_blocks['Jaw_Open'].value,'smile':keys.key_blocks['Smile_L'].value,'evaluated_delta':float(np.max(np.linalg.norm(coords-base,axis=1)))})
(p/'facial/evaluation-audit.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report['frames']));print('FACE_MODIFIERS',[(m.name,m.type,m.show_render) for m in obj.modifiers]);print('ALL_OBJECTS',report['objects'])

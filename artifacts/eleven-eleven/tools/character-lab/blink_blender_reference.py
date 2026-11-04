"""Cache actual evaluated Blender skin samples before the native morph review."""
import hashlib,json
from pathlib import Path
import bpy

APP=Path(__file__).resolve().parents[2];case=APP/'art/production/echo-school-rebuild-20261029/face/blink-retopology-20261102'
sha=lambda path:hashlib.sha256(path.read_bytes()).hexdigest()
export=json.loads((case/'diagnostic-export.json').read_text());report=json.loads((case/'retopology-review.json').read_text())
assert sha(case/'connected-blink-research.blend')==export['source_blend_sha256']==report['blend_sha256']
bpy.ops.wm.open_mainfile(filepath=str(case/'connected-blink-research.blend'))
obj=next(item for item in bpy.context.scene.objects if item.type=='MESH');rig=next(item for item in bpy.context.scene.objects if item.type=='ARMATURE')
blink=obj.data.shape_keys.key_blocks['blink'];basis=obj.data.shape_keys.key_blocks['Basis']
used=sorted({index for polygon in obj.data.polygons for index in polygon.vertices})
moving=[index for index in used if (blink.data[index].co-basis.data[index].co).length>1e-10]
moving_set=set(moving)
static=[index for index in used if index not in moving_set]
selected=sorted(set(moving+static[::max(1,len(static)//256)]+list(range(report['source_vertices']+report['added_skin_vertices'],len(obj.data.vertices),23))))
def convert(point):return [float(point.x),float(point.z),float(-point.y)]
frames=[]
for value in [0,.25,.5,.75,1]:
    blink.value=value;bpy.context.view_layer.update()
    evaluated=obj.evaluated_get(bpy.context.evaluated_depsgraph_get());mesh=evaluated.to_mesh()
    frames.append({'blink':value,'positions':[convert(obj.matrix_world@mesh.vertices[index].co) for index in selected]})
    evaluated.to_mesh_clear()
data={'status':'BLENDER_EVALUATED_REFERENCE','blend_sha256':report['blend_sha256'],'export_glb_sha256':export['glb_sha256'],
      'sampled_original_vertex_indices':selected,'moving_sample_count':len(moving),'static_sample_count':len(selected)-len(moving),
      'moving_flags':[index in moving_set for index in selected],
      'frames':frames,'bones':{bone.name.replace(':','_'):convert((rig.matrix_world@bone.matrix_local).translation) for bone in rig.data.bones},
      'scope':'All moving eyelid vertices plus deterministic distributed originalbody/staticcup samples;actual skin evaluation,not copied morph accessor data.'}
(case/'blender-skin-reference.json').write_text(json.dumps(data,indent=2)+'\n');print('BLINK_BLENDER_REFERENCE',len(selected),len(moving))

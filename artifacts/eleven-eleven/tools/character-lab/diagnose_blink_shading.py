"""Separate real skin folds from stale custom-normal shading;read-only case."""
import json,math
from pathlib import Path
import bpy
from mathutils import Vector
APP=Path(__file__).resolve().parents[2];case=APP/'art/production/echo-school-rebuild-20261029/face/blink-retopology-20261102'
bpy.ops.wm.open_mainfile(filepath=str(case/'connected-blink-research.blend'))
obj=next(item for item in bpy.context.scene.objects if item.type=='MESH')
blink=obj.data.shape_keys.key_blocks['blink'];rows=[];baseline={}
print('CUSTOM_NORMAL_API',obj.data.normals_split_custom_set.__doc__)
for phase in [0,.5,1]:
    blink.value=phase;bpy.context.view_layer.update()
    evaluated=obj.evaluated_get(bpy.context.evaluated_depsgraph_get());mesh=evaluated.to_mesh()
    temporary=mesh.copy();temporary.normals_split_custom_set([(0,0,0)]*len(temporary.loops));temporary.update()
    normal_errors=[];folded=[];faces=0
    for polygon in mesh.polygons:
        if 'ConnectedBlinkAtlas' not in mesh.materials[polygon.material_index].name:continue
        faces+=1
        points=[mesh.vertices[index].co for index in polygon.vertices]
        normal=(points[1]-points[0]).cross(points[2]-points[0]).normalized()
        if phase==0:baseline[polygon.index]=normal
        elif normal.dot(baseline[polygon.index])<-.1:folded.append(polygon.index)
        for loop in polygon.loop_indices:
            a=mesh.corner_normals[loop].vector;b=temporary.corner_normals[loop].vector
            normal_errors.append(math.degrees(a.angle(b,0)))
    rows.append({'blink':phase,'skin_faces':faces,'flipped_skin_faces_vs_neutral':folded,
                 'mean_custom_vs_automatic_normal_degrees':sum(normal_errors)/len(normal_errors),
                 'max_custom_vs_automatic_normal_degrees':max(normal_errors)})
    bpy.data.meshes.remove(temporary);evaluated.to_mesh_clear()
(case/'shading-diagnosis.json').write_text(json.dumps({'status':'MEASURED_SHADING_DIAGNOSIS','phases':rows},indent=2)+'\n')
print('BLINK_SHADING',json.dumps(rows))

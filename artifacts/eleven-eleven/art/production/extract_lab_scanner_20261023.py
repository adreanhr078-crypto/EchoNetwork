"""Extract the actual segmented scanner, retaining source UVs and materials.

The source platform and chair remain archived and are deliberately excluded:
the native room owns those collision and interaction landmarks.
"""
import bpy, json, hashlib
from pathlib import Path
from mathutils import Vector

APP = Path(__file__).resolve().parents[2]
SOURCE = APP/'art/production/lab-clinical-kit-20261023/tripo/lab-theater-textured-4k.glb'
OUT = APP/'art/production/lab-clinical-kit-20261023/tripo/scanner-derivative'
OUT.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(SOURCE))
retained=[]
record=[]
for obj in list(bpy.context.scene.objects):
    if obj.type != 'MESH':
        continue
    bounds=[obj.matrix_world@Vector(c) for c in obj.bound_box]
    low=min(p.z for p in bounds); high=max(p.z for p in bounds)
    # Whole segmented parts, never a face slice across a manufactured surface.
    if high <= .35 or low <= .20:
        bpy.data.objects.remove(obj, do_unlink=True)
        continue
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True); bpy.context.view_layer.objects.active=obj
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    for vertex in obj.data.vertices:
        vertex.co.x *= 12.0
        vertex.co.y *= 12.0
        vertex.co.z = (vertex.co.z-.47)*12.0
    obj.data.calc_loop_triangles()
    record.append({'part':obj.name,'triangles':len(obj.data.loop_triangles)})
    retained.append(obj)
assert retained, 'No qualifying scanner geometry: source layout changed'
bpy.ops.object.select_all(action='DESELECT')
for obj in retained: obj.select_set(True)
bpy.context.view_layer.objects.active=retained[0]
bpy.ops.object.join()
scanner=bpy.context.object
scanner.name='TripoSegmentedClinicalScanner'
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'clinical-scanner.blend'))
target=OUT/'clinical_scanner_tripo.glb'
bpy.ops.export_scene.gltf(filepath=str(target), export_format='GLB', use_selection=True,
                        export_animations=False, export_yup=True)
report={'source':str(SOURCE),'source_sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
        'derivative':str(target),'derivative_sha256':hashlib.sha256(target.read_bytes()).hexdigest(),
        'parts':record,'triangles':sum(p['triangles'] for p in record),
        'fit':'Uniform12x, scanner datum BlenderZ=.47; placed at nativeY7.0. Source keys/rig not involved.',
        'scope':'Static presentation, whole segmented scanner only; native route/camera review required.'}
(OUT/'derivative.json').write_text(json.dumps(report,indent=2)+'\n')
print('SCANNER_EXTRACTED', report['triangles'],len(record))

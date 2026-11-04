"""Read-only source/candidate iris occlusion on the actual triangle surfaces.

Known reviewed iris components supply the sample domain;this is not a facial
selection or edit. Source skin inside the approved eye cut is measured separately
from unchanged front hair,so a future lid fit cannot follow the hair silhouette.
"""
import hashlib,json
from pathlib import Path
import bpy
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

APP=Path(__file__).resolve().parents[2]
face=APP/'art/production/echo-school-rebuild-20261029/face'
intake=face/'intake-20261102';case=face/'blink-retopology-20261102'
components=json.loads((intake/'component-vertices.json').read_text())
regions=json.loads((intake/'eye-rim-region-preview.json').read_text())
retopo=json.loads((case/'retopology-review.json').read_text())
sha=lambda path:hashlib.sha256(path.read_bytes()).hexdigest()
assert sha(case/'connected-blink-research.blend')==retopo['blend_sha256']

def snapshot(path):
    bpy.ops.wm.open_mainfile(filepath=str(path))
    obj=next(item for item in bpy.context.scene.objects if item.type=='MESH')
    for modifier in obj.modifiers:
        if modifier.type=='WIREFRAME':modifier.show_viewport=False
    if obj.data.shape_keys:obj.data.shape_keys.key_blocks['blink'].value=0
    bpy.context.view_layer.update()
    evaluated=obj.evaluated_get(bpy.context.evaluated_depsgraph_get());mesh=evaluated.to_mesh()
    assert len(mesh.vertices)==len(obj.data.vertices),'A topology-changing diagnostic modifier entered the read-only sample'
    points=[obj.matrix_world@vertex.co for vertex in mesh.vertices]
    polygons=[list(poly.vertices) for poly in mesh.polygons]
    evaluated.to_mesh_clear()
    return points,polygons

original_points,original_polygons=snapshot(intake/'head-topology-diagnostic.blend')
candidate_points,candidate_polygons=snapshot(case/'connected-blink-research.blend')
source_count=len(original_points);skin_limit=source_count+retopo['added_skin_vertices']
all_iris=set(components[26]+components[27])
original_other=BVHTree.FromPolygons(original_points,[poly for poly in original_polygons if not all(index in all_iris for index in poly)])
candidate_other=BVHTree.FromPolygons(candidate_points,[poly for poly in candidate_polygons if not all(index in all_iris for index in poly)])
new_skin=BVHTree.FromPolygons(candidate_points,[poly for poly in candidate_polygons if any(index>=source_count for index in poly) and all(index<skin_limit for index in poly)])

def front_y(tree,x,z):
    hit,normal,index,distance=tree.ray_cast(Vector((float(x),-.3,float(z))),Vector((0,1,0)),.6)
    return float(hit.y) if hit is not None else None

results={}
for side,cid in [('right',26),('left',27)]:
    selected=set(components[cid]);points=[original_points[index] for index in selected]
    iris=BVHTree.FromPolygons(original_points,[poly for poly in original_polygons if all(index in selected for index in poly)])
    cut=BVHTree.FromPolygons(original_points,[original_polygons[index] for index in regions['eyes'][side]['cut_region_polygons']])
    delta=max((original_points[index]-candidate_points[index]).length for index in selected)
    assert delta<1e-7,'The original iris geometry moved'
    rows=[];columns=[]
    for x in np.linspace(min(point.x for point in points),max(point.x for point in points),65):
        column=[]
        for z in np.linspace(min(point.z for point in points),max(point.z for point in points),97):
            iris_y=front_y(iris,x,z)
            if iris_y is None:continue
            sy=front_y(original_other,x,z);cy=front_y(candidate_other,x,z)
            ly=front_y(cut,x,z);ny=front_y(new_skin,x,z)
            row={'x':float(x),'z':float(z),'iris_y':iris_y,
                 'source_visible':sy is None or sy>iris_y+.00002,
                 'candidate_visible':cy is None or cy>iris_y+.00002,
                 'source_lid_only_visible':ly is None or ly>iris_y+.00002,
                 'candidate_lid_only_visible':ny is None or ny>iris_y+.00002}
            column.append(row);rows.append(row)
        source_visible=[row['z'] for row in column if row['source_lid_only_visible']]
        new_visible=[row['z'] for row in column if row['candidate_lid_only_visible']]
        if len(source_visible)>2 and len(new_visible)>2:
            columns.append({'x':float(x),'source_lower':min(source_visible),'source_upper':max(source_visible),
                            'candidate_lower':min(new_visible),'candidate_upper':max(new_visible)})
    visible_source=sum(row['source_visible'] for row in rows);visible_candidate=sum(row['candidate_visible'] for row in rows)
    union=sum(row['source_visible'] or row['candidate_visible'] for row in rows)
    intersection=sum(row['source_visible'] and row['candidate_visible'] for row in rows)
    results[side]={'rays':len(rows),'source_visible_rays':visible_source,'candidate_visible_rays':visible_candidate,
                   'extra_exposure_rays':sum(row['candidate_visible'] and not row['source_visible'] for row in rows),
                   'lost_exposure_rays':sum(row['source_visible'] and not row['candidate_visible'] for row in rows),
                   'iris_visibility_iou':intersection/max(union,1),'iris_geometry_error_m':delta,
                   'lid_only_boundary_columns':columns,'samples':rows}
data={'status':'MEASURED_NEUTRAL_IRIS_OCCLUSION_NOT_ART_ACCEPTANCE',
      'candidate_blend_sha256':sha(case/'connected-blink-research.blend'),
      'source_blend_sha256':sha(intake/'head-topology-diagnostic.blend'),'eyes':results,
      'scope':'Actual evaluated source/candidate surfaces;front orthographic rays,unchanged iris. The semantic cut separately measures skin occlusion without copying front-hair silhouette. No mesh,key,UV,weight orruntime write.'}
(case/'neutral-iris-occlusion.json').write_text(json.dumps(data,indent=2)+'\n')
source_reference={'source_blend_sha256':data['source_blend_sha256'],'source_glb_sha256':regions['source_sha256'],
                  'eyes':{side:{'samples':[{key:sample[key] for key in ['x','z','iris_y','source_visible','source_lid_only_visible']} for sample in row['samples']]} for side,row in results.items()},
                  'scope':'Immutable original iris-ray reference only;candidate measurements are stored separately.'}
reference_path=case/'source-iris-occlusion-reference.json'
if reference_path.exists():assert json.loads(reference_path.read_text())==source_reference,'Source occlusion reference changed;inspect the source before replacing it'
else:reference_path.write_text(json.dumps(source_reference,indent=2)+'\n')
print('NEUTRAL_IRIS_VISIBILITY',json.dumps({side:{key:value for key,value in row.items() if key not in ['samples','lid_only_boundary_columns']} for side,row in results.items()}))

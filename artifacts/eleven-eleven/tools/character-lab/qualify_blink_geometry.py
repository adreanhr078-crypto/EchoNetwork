"""Independent evaluated skin/margin checks for the isolated one-blink case."""
import hashlib,json
from pathlib import Path
import bpy
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

APP=Path(__file__).resolve().parents[2];face=APP/'art/production/echo-school-rebuild-20261029/face'
case=face/'blink-retopology-20261102';intake=face/'intake-20261102'
sha=lambda path:hashlib.sha256(path.read_bytes()).hexdigest()
report=json.loads((case/'retopology-review.json').read_text())
assert sha(case/'connected-blink-research.blend')==report['blend_sha256']
reference=json.loads((case/'source-iris-occlusion-reference.json').read_text())
components=json.loads((intake/'component-vertices.json').read_text())

def rig_signature(rig):
    return {bone.name:{'parent':bone.parent.name if bone.parent else None,'matrix':[list(row) for row in bone.matrix_local]} for bone in rig.data.bones}

bpy.ops.wm.open_mainfile(filepath=str(intake/'head-topology-diagnostic.blend'))
source_rig=rig_signature(next(obj for obj in bpy.context.scene.objects if obj.type=='ARMATURE'))
bpy.ops.wm.open_mainfile(filepath=str(case/'connected-blink-research.blend'))
obj=next(obj for obj in bpy.context.scene.objects if obj.type=='MESH');rig=next(obj for obj in bpy.context.scene.objects if obj.type=='ARMATURE')
checks={};checks['original65_rest_and_parents']=len(rig.data.bones)==65 and rig_signature(rig)==source_rig
basis=obj.data.shape_keys.key_blocks['Basis'];blink=obj.data.shape_keys.key_blocks['blink']
original_morph_error=max((basis.data[index].co-blink.data[index].co).length for index in range(report['source_vertices']))
checks['all_original_vertex_morph_deltas_zero']=original_morph_error==0
iris_set=set(components[26]+components[27]);polys=[list(poly.vertices) for poly in obj.data.polygons]
iris_polys=[poly for poly in polys if all(index in iris_set for index in poly)]
other_polys=[poly for poly in polys if not all(index in iris_set for index in poly)]
measurements=[];basis_margin=None;minimum_clearance=float('inf');closed_points=None

for phase in [0,.25,.5,.75,1]:
    blink.value=phase;bpy.context.view_layer.update()
    evaluated=obj.evaluated_get(bpy.context.evaluated_depsgraph_get());mesh=evaluated.to_mesh()
    array=np.empty(len(mesh.vertices)*3,dtype=np.float32);mesh.vertices.foreach_get('co',array)
    assert np.all(np.isfinite(array))
    points=[obj.matrix_world@vertex.co for vertex in mesh.vertices]
    evaluated.to_mesh_clear()
    iris=BVHTree.FromPolygons(points,iris_polys);other=BVHTree.FromPolygons(points,other_polys)
    visible={};clearances=[];overlapping_margin=0
    for side,row in reference['eyes'].items():
        count=0
        for sample in row['samples']:
            hit=other.ray_cast(Vector((sample['x'],-.3,sample['z'])),Vector((0,1,0)),.6)[0]
            count+=int(hit is None or hit.y>sample['iris_y']+.00002)
        visible[side]=count
        for index in report['inner_margins'][side]:
            point=points[index];hit=iris.ray_cast(Vector((point.x,-.3,point.z)),Vector((0,1,0)),.6)[0]
            if hit is not None:
                clearances.append(float(hit.y-point.y));overlapping_margin+=1
    margin={side:[points[index].copy() for index in indices] for side,indices in report['inner_margins'].items()}
    if phase==0:basis_margin=margin
    if phase==1:closed_points=margin
    if clearances:minimum_clearance=min(minimum_clearance,min(clearances))
    measurements.append({'blink':phase,'visible_iris_rays':visible,'margin_projected_iris_samples':overlapping_margin,
                         'minimum_margin_iris_front_clearance_m':min(clearances) if clearances else None})

def branches(points):
    first=min(range(len(points)),key=lambda index:points[index].x);last=max(range(len(points)),key=lambda index:points[index].x)
    paths=[]
    for direction in [1,-1]:
        path=[first]
        while path[-1]!=last:path.append((path[-1]+direction)%len(points))
        paths.append(path)
    paths.sort(key=lambda path:sum(points[index].z for index in path)/len(path),reverse=True)
    return paths

def sample_path(points,x):
    for a,b in zip(points,points[1:]):
        if min(a.x,b.x)<=x<=max(a.x,b.x) and abs(b.x-a.x)>1e-9:return a.lerp(b,(x-a.x)/(b.x-a.x))
    return min(points,key=lambda point:abs(point.x-x))

closed_gaps={}
for side,points in basis_margin.items():
    upper,lower=branches(points);u=[closed_points[side][index] for index in upper];l=[closed_points[side][index] for index in lower]
    low=max(min(point.x for point in u),min(point.x for point in l));high=min(max(point.x for point in u),max(point.x for point in l))
    closed_gaps[side]=max((sample_path(u,float(x))-sample_path(l,float(x))).length for x in np.linspace(low,high,101))
checks['full_blink_hides_all_iris_rays']=all(value==0 for value in measurements[-1]['visible_iris_rays'].values())
checks['closed_margin_gap_below_0_3mm']=max(closed_gaps.values())<.0003
checks['margin_clearance_at_least_0_3mm']=minimum_clearance>=.0003
checks['source_uv_positions_weights_unchanged_outside_cut']=all(report[key]==0 for key in ['outside_cut_position_error_m','outside_cut_uv_error','outside_cut_weight_error'])
blink.value=0
data={'status':'PASS_SCOPED_GEOMETRY_ONLY' if all(checks.values()) else 'FAIL_SCOPED_GEOMETRY','checks':checks,
      'candidate_blend_sha256':report['blend_sha256'],'original_morph_delta_error_m':original_morph_error,
      'minimum_margin_iris_front_clearance_m':minimum_clearance,'closed_margin_gaps_m':closed_gaps,'measurements':measurements,
      'limits':'Independent evaluated skin/margin andoriginalrig checks only. NativeGodot/bodymotion,upperlidfaceting,neutralidentity andfinalfaceart remainopen. No runtime orsourcefile writes.'}
(case/'geometry-qualification.json').write_text(json.dumps(data,indent=2)+'\n')
print('BLINK_GEOMETRY',json.dumps({key:data[key] for key in ['status','checks','minimum_margin_iris_front_clearance_m','closed_margin_gaps_m']}))

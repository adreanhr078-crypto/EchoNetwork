"""Read-only ring correspondence diagnosis;front projection is not collision.

Compares the real source weld rim to derived rings. A manifold edge cycle
does not imply a simple projected contour or a bijective interpolated patch.
"""
from pathlib import Path
import hashlib,json
import bpy
import numpy as np

APP=Path(__file__).resolve().parents[2]
face=APP/'art/production/echo-school-rebuild-20261029/face'
case=face/'blink-retopology-20261102';intake=face/'intake-20261102'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
report=json.loads((case/'retopology-review.json').read_text())
rim=json.loads((intake/'eye-rim-region-preview.json').read_text())
mapping=json.loads((intake/'blink-whole-eye-mask-preview.json').read_text())['original_to_welded']
canonical={}
for index,welded in enumerate(mapping):canonical.setdefault(welded,index)
assert sha(case/'connected-blink-research.blend')==report['blend_sha256']
bpy.ops.wm.open_mainfile(filepath=str(case/'connected-blink-research.blend'))
obj=next(obj for obj in bpy.context.scene.objects if obj.type=='MESH')
blink=obj.data.shape_keys.key_blocks['blink']

def cross(a,b):return a[0]*b[1]-a[1]*b[0]
def crossing(a,b,c,d):
    denominator=cross(b-a,d-c)
    if abs(denominator)<1e-14:return False
    t=cross(c-a,d-c)/denominator;u=cross(c-a,b-a)/denominator
    return 1e-7<t<1-1e-7 and 1e-7<u<1-1e-7

def proper_crossings(points):
    points=np.asarray([(p.x,p.z) for p in points],dtype=np.float64)
    pairs=[];n=len(points)
    for i in range(n):
        a=points[i];b=points[(i+1)%n]
        for j in range(i+1,n):
            if j==i+1 or (i==0 and j==n-1):continue
            c=points[j];d=points[(j+1)%n]
            if crossing(a,b,c,d):pairs.append([i,j])
    return pairs

offset=report['source_vertices'];rings={}
for side,eye in rim['eyes'].items():
    count=len(eye['loop_welded_vertices'])
    rings[side]={'source_weld_rim':[canonical[index] for index in eye['loop_welded_vertices']],
                 'source_initial_aperture':[canonical[index] for index in eye['initial_path_loop']]}
    for ring in range(7):rings[side]['derived_ring_%d'%ring]=list(range(offset+ring*count,offset+(ring+1)*count))
    offset+=7*count
assert offset==report['source_vertices']+report['added_skin_vertices']
rows=[]
for phase in [0,.5,1]:
    blink.value=phase;bpy.context.view_layer.update()
    evaluated=obj.evaluated_get(bpy.context.evaluated_depsgraph_get());mesh=evaluated.to_mesh()
    points=[obj.matrix_world@vertex.co for vertex in mesh.vertices]
    eyes={};correspondence={}
    for side,loops in rings.items():
        eyes[side]={}
        for name,indices in loops.items():
            loop=[points[index] for index in indices];pairs=proper_crossings(loop)
            eyes[side][name]={'vertices':len(indices),'front_projection_proper_crossing_pairs':pairs,
                             'front_projection_signed_area_m2':sum(a.x*b.z-b.x*a.z for a,b in zip(loop,loop[1:]+loop[:1]))*.5}
        grids=[loops['source_weld_rim']]+[loops['derived_ring_%d'%index] for index in range(7)]
        projected=[np.asarray([(points[index].x,points[index].z) for index in indices],dtype=np.float64) for indices in grids]
        adjacent=[];spokes=[]
        for first,second in zip(projected,projected[1:]):
            n=len(first)
            adjacent.append(sum(int(crossing(first[i],first[(i+1)%n],second[j],second[(j+1)%n])) for i in range(n) for j in range(n)))
            spokes.append(sum(int(crossing(first[i],second[i],first[j],second[j])) for i in range(n) for j in range(i+1,n)))
        correspondence[side]={'adjacent_ring_edge_crossing_counts_XZ':adjacent,'within_strip_correspondence_spoke_crossing_counts_XZ':spokes}
    rows.append({'blink':phase,'eyes':eyes,'strip_correspondence':correspondence});evaluated.to_mesh_clear()
data={'status':'MEASURED_PROJECTED_CORRESPONDENCE_NOT_COLLISION_ACCEPTANCE','candidate_blend_sha256':sha(case/'connected-blink-research.blend'),
      'reviewer_sha256':sha(Path(__file__)),'phases':rows,
      'limits':'XZ orthographic front projection only;projected crossings can be separated in depth. These counts explain parameterization risk and do not establish3Dcollision. Independent triangle-intersection-diagnosis governs proper3Dcrossings. Closed upper/lower margins intentionally coincide;collinear contacts not counted. No source orcandidate geometry writes.'}
(case/'correspondence-diagnosis.json').write_text(json.dumps(data,indent=2)+'\n')
print('BLINK_CORRESPONDENCE',json.dumps([{'blink':row['blink'],'eyes':{side:{name:len(value['front_projection_proper_crossing_pairs']) for name,value in eye.items()} for side,eye in row['eyes'].items()}} for row in rows]))
print('BLINK_STRIPS',json.dumps([{'blink':row['blink'],'strips':row['strip_correspondence']} for row in rows]))

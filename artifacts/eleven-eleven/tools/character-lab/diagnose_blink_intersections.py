"""Read-only strict triangle crossings in the connected blink derivative.

BVH supplies candidate pairs. Independent segment/plane/barycentric tests
require a proper interior crossing. Touching/coplanar contacts are excluded;
this is a scoped diagnostic, never a general self-intersection acceptance.
"""
import hashlib,json
from pathlib import Path
from collections import Counter
import bpy
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from mathutils.geometry import intersect_ray_tri

APP=Path(__file__).resolve().parents[2]
case=APP/'art/production/echo-school-rebuild-20261029/face/blink-retopology-20261102'
sha=lambda path:hashlib.sha256(path.read_bytes()).hexdigest()
blend=case/'connected-blink-research.blend'
provenance=json.loads((case/'retopology-review.json').read_text())
assert sha(blend)==provenance['blend_sha256']
EPS_M=1e-7

def segment_crosses_triangle(a,b,triangle):
    a,b,p,q,r=[np.asarray(point,dtype=np.float64) for point in [a,b,*triangle]]
    normal=np.cross(q-p,r-p)
    length=np.linalg.norm(normal)
    if length<1e-14:return False
    normal/=length
    da=float(np.dot(a-p,normal));db=float(np.dot(b-p,normal))
    if not ((da>EPS_M and db<-EPS_M) or (db>EPS_M and da<-EPS_M)):return False
    hit=a+(b-a)*(da/(da-db))
    v0=q-p;v1=r-p;v2=hit-p
    d00=np.dot(v0,v0);d01=np.dot(v0,v1);d11=np.dot(v1,v1)
    d20=np.dot(v2,v0);d21=np.dot(v2,v1)
    denominator=d00*d11-d01*d01
    if abs(denominator)<1e-24:return False
    u=(d11*d20-d01*d21)/denominator
    v=(d00*d21-d01*d20)/denominator
    return u>1e-6 and v>1e-6 and u+v<1-1e-6

def crosses(first,second):
    return any(segment_crosses_triangle(a,b,second) for a,b in zip(first,first[1:]+first[:1])) or any(segment_crosses_triangle(a,b,first) for a,b in zip(second,second[1:]+second[:1]))

def library_crosscheck(first,second):
    for edges,triangle in [(first,second),(second,first)]:
        for a,b in zip(edges,edges[1:]+edges[:1]):
            direction=b-a
            # Blender's ray/triangle epsilon assumes meaningful ray magnitudes.
            # Evaluate in a translated millimeter-scaled fixture with a unit ray;
            # the semantic proper-crossing gate remains in original meters.
            scale=1000.0
            ray=direction.normalized()
            hit_local=intersect_ray_tri(*[(point-a)*scale for point in triangle],ray,Vector(),True)
            hit=a+hit_local/scale if hit_local is not None else None
            if hit is not None and direction.length_squared>1e-20:
                parameter=(hit-a).dot(direction)/direction.length_squared
                if 1e-6<parameter<1-1e-6:return True
    return False

V=lambda xyz:[Vector(point) for point in xyz]
fixture=V([(0,0,0),(1,0,0),(0,1,0)])
assert crosses(fixture,V([(.2,.2,-1),(.2,.2,1),(.6,.2,1)]))
assert not crosses(fixture,V([(2,2,-1),(2,2,1),(3,2,1)]))
assert not crosses(fixture,V([(.2,.2,0),(.3,.2,0),(.2,.3,0)]))

bpy.ops.wm.open_mainfile(filepath=str(blend))
obj=next(item for item in bpy.context.scene.objects if item.type=='MESH')
blink=obj.data.shape_keys.key_blocks['blink']
start=provenance['source_vertices'];stop=start+provenance['added_skin_vertices']
rows=[]
for phase in [0,.25,.5,.75,1]:
    blink.value=phase;bpy.context.view_layer.update()
    evaluated=obj.evaluated_get(bpy.context.evaluated_depsgraph_get());mesh=evaluated.to_mesh()
    mesh.calc_loop_triangles()
    points=[obj.matrix_world@vertex.co for vertex in mesh.vertices]
    all_triangles=[tuple(tri.vertices) for tri in mesh.loop_triangles]
    polygon_ids=[tri.polygon_index for tri in mesh.loop_triangles]
    skin=[i for i,tri in enumerate(all_triangles) if any(start<=v<stop for v in tri) and all(v<stop for v in tri)]
    skin_set=set(skin)
    whole_tree=BVHTree.FromPolygons(points,all_triangles,all_triangles=True)
    skin_tree=BVHTree.FromPolygons(points,[all_triangles[i] for i in skin],all_triangles=True)
    pairs=set();counts=Counter();records=[];crosscheck_mismatches=0;unconfirmed=[];primary_counts=Counter()
    candidates=skin_tree.overlap(whole_tree)
    for local,other in candidates:
        first=skin[local]
        if first==other or polygon_ids[first]==polygon_ids[other]:continue
        pair=tuple(sorted((first,other)))
        if pair in pairs:continue
        pairs.add(pair)
        a=all_triangles[first];b=all_triangles[other]
        if len(set(a)&set(b))>=2:continue
        if not crosses([points[v] for v in a],[points[v] for v in b]):continue
        kind='skin_vs_skin' if other in skin_set else 'skin_vs_new_cup' if any(v>=stop for v in b) else 'skin_vs_retained_source'
        primary_counts[kind]+=1
        record={'triangles':[first,other],'polygons':[polygon_ids[first],polygon_ids[other]],'kind':kind}
        if not library_crosscheck([points[v] for v in a],[points[v] for v in b]):
            crosscheck_mismatches+=1;unconfirmed.append(record);continue
        counts[kind]+=1
        records.append(record)
    rows.append({'blink':phase,'skin_triangles':len(skin),'bvh_candidates':len(candidates),'proper_crossing_counts':dict(counts),'proper_crossing_pairs':records,'primary_crossing_counts':dict(primary_counts),'independent_ray_triangle_crosscheck_mismatches':crosscheck_mismatches,'unconfirmed_primary_pairs_excluded_from_counts':unconfirmed})
    evaluated.to_mesh_clear()
report={'status':'MEASURED_STRICT_INTERIOR_CROSSINGS_NOT_ART_ACCEPTANCE','candidate_blend_sha256':sha(blend),'reviewer_sha256':sha(Path(__file__)),
        'plane_tolerance_m':EPS_M,'analytic_method_fixtures':3,'phases':rows,
        'limits':'Only proper noncoplanar triangle-interior crossings involving new skin,confirmed by float64 segment/plane/barycentric and independently scaled Blender ray/triangle,are counted. Any disagreements are retained as unconfirmed and excluded. Shared-edge faces,touching/coplanar contacts and degenerate triangles excluded;not watertightness,complete collision or artistic acceptance. Original source is not modified. Existing source intersections are separate from new skin crossings.'}
(case/'intersection-diagnosis.json').write_text(json.dumps(report,indent=2)+'\n')
print('BLINK_INTERSECTIONS',json.dumps([{key:row[key] for key in ['blink','skin_triangles','proper_crossing_counts']} for row in rows]))

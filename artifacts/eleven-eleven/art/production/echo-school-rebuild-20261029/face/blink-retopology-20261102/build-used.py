"""Bounded one-blink derivative from the reviewed real skin-edge rims.

No production asset is overwritten. Original vertices/weights/UV outside the
approved eye cuts stay exact. New lids share actual outer skin vertices.
"""
from collections import Counter
import hashlib
import json
from pathlib import Path
import zipfile
import sys
import bpy
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from mathutils.geometry import barycentric_transform
sys.path.insert(0,str(Path(__file__).resolve().parent))
from bake_blink_skin_atlas import bake as bake_skin_atlas

APP=Path(__file__).resolve().parents[2]
prod=APP/'art/production/echo-school-rebuild-20261029'
intake=prod/'face/intake-20261102'
out=prod/'face/blink-retopology-20261102'
out.mkdir(parents=True,exist_ok=True)
sha=lambda path:hashlib.sha256(path.read_bytes()).hexdigest()
source=prod/'source/echo-school-rig-metric.glb'
review=json.loads((intake/'eye-rim-region-preview.json').read_text())
assert sha(source)==review['source_sha256']
assert all(row['status']=='CAPTURED_CANDIDATE_PENDING_REVIEW' for row in review['eyes'].values())
source_ray_path=out/'source-iris-occlusion-reference.json'
build_inputs=[Path(__file__),Path(__file__).with_name('bake_blink_skin_atlas.py'),source,intake/'eye-rim-region-preview.json',intake/'head-topology-diagnostic.blend']
if source_ray_path.exists():build_inputs.append(source_ray_path)
build_input_sha256=hashlib.sha256((''.join(sha(path) for path in build_inputs)).encode()).hexdigest()
if (out/'retopology-review.json').exists():
    prior=json.loads((out/'retopology-review.json').read_text())
    atlas_valid=(out/'local-skin-albedo.png').exists() and prior.get('derived_skin_atlas',{}).get('output_sha256')==sha(out/'local-skin-albedo.png')
    if atlas_valid and prior.get('build_input_sha256')==build_input_sha256 and prior.get('blend_sha256')==sha(out/'connected-blink-research.blend') and all(sha(out/name)==digest for name,digest in prior['captures'].items()):
        print('CONNECTED_BLINK_CACHE_HIT',build_input_sha256);raise SystemExit(0)
    old_blend=out/'connected-blink-research.blend'
    if old_blend.exists():
        archive=out/('research-revision-'+sha(old_blend)[:12]+'.zip')
        if not archive.exists():
            with zipfile.ZipFile(archive,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=6) as bundle:
                for path in [old_blend,out/'retopology-review.json',out/'semantic-region-review.json',*out.glob('blink-*.png'),*out.glob('local-skin-albedo.png')]:
                    bundle.write(path,path.name)
semantic={'status':'REVIEWED_FOR_BOUNDED_LOCAL_RETOPOLOGY_ONLY','source_sha256':sha(source),
          'reviewer':'Root agent;actual front and both three-quarter diagnostic captures inspected',
          'scope':'The two bounded face regions enclose the painted ocular surface below the separate brows and exclude the front hair. This is region acceptance,not neutral/blink art acceptance.',
          'captures':{name:sha(intake/name) for name in ['eye-rim-region-front.png','eye-rim-region-threequarter.png','eye-rim-region-reverse-threequarter.png']},
          'prior_masks':'Sclera-only lower contour incomplete;whole-eye geodesic weights overlap and are not approved deformation masks;texture islands include upper lid/hair. None deform the face.'}
(out/'semantic-region-review.json').write_text(json.dumps(semantic,indent=2)+'\n')
bpy.ops.wm.open_mainfile(filepath=str(intake/'head-topology-diagnostic.blend'))
obj=next(item for item in bpy.context.scene.objects if item.type=='MESH')
original=obj.data
group_names=[group.name for group in obj.vertex_groups]
obj.modifiers.remove(obj.modifiers['DiagnosticWireOnly'])
components=json.loads((intake/'component-vertices.json').read_text())
mask=json.loads((intake/'blink-whole-eye-mask-preview.json').read_text())
vids=mask['original_to_welded']
positions=[vertex.co.copy() for vertex in original.vertices]
world=[obj.matrix_world@point for point in positions]
weights=[{item.group:item.weight for item in vertex.groups} for vertex in original.vertices]
normals=[normal.vector.copy() for normal in original.corner_normals]
uvs=[item.uv.copy() for item in original.uv_layers.active.data]
texture=next(node.image for material in original.materials if material and material.use_nodes
             for node in material.node_tree.nodes if node.type=='TEX_IMAGE' and node.image and 'basecolor' in node.image.name.lower())
pixels=np.empty(len(texture.pixels),dtype=np.float32);texture.pixels.foreach_get(pixels)
pixels=pixels.reshape(texture.size[1],texture.size[0],4)
def rgb_at(tex):return pixels[int(tex.y*(texture.size[1]-1))%texture.size[1],int(tex.x*(texture.size[0]-1))%texture.size[0],:3]
inverse=obj.matrix_world.inverted()
canonical={}
for index,welded in enumerate(vids):canonical.setdefault(welded,index)
cuts=set(pid for row in review['eyes'].values() for pid in row['cut_region_polygons'])
white=set(components[30]+components[31])
removed={poly.index for poly in original.polygons if poly.index in cuts or all(index in white for index in poly.vertices)}
rim_vertices={vid for eye in review['eyes'].values() for vid in eye['loop_welded_vertices']}
for welded in rim_vertices:
    copies=[index for index,value in enumerate(vids) if value==welded]
    assert all(weights[index]==weights[copies[0]] for index in copies),'Boundary weights differ;do not silently weld them'
faces=[];face_uvs=[];face_normals=[];materials=[];source_face_ids=[]
for poly in original.polygons:
    if poly.index in removed:continue
    faces.append([canonical[vids[index]] if vids[index] in rim_vertices else index for index in poly.vertices])
    face_uvs.append([uvs[index] for index in poly.loop_indices])
    face_normals.append([normals[index] for index in poly.loop_indices])
    materials.append(poly.material_index);source_face_ids.append(poly.index)
source_face_count=len(faces)
outside_edge_directions={}
for face in faces:
    for a,b in zip(face,face[1:]+face[:1]):outside_edge_directions.setdefault(tuple(sorted((a,b))),[]).append((a,b))
head_group=obj.vertex_groups['mixamorig:Head'].index
closed={};new_vertices=[];rings_by_eye={};inner_by_eye={};edge_seams=[]
neutral_inner={}
neutral_controls={};neutral_fit={};winding_checks={}
skin_face_styles={};skin_uv_fallback={}
cut_ids=sorted(cuts)
cut_surface=BVHTree.FromPolygons(world,[list(original.polygons[index].vertices) for index in cut_ids],all_triangles=True)
boundary_uv={}
warm_uv_candidates=[];white_uv_candidates=[];dark_uv_candidates=[]
for poly in original.polygons:
    centroid=sum((world[index] for index in poly.vertices),Vector())/len(poly.vertices)
    tex=sum((uvs[index] for index in poly.loop_indices),Vector((0,0)))/len(poly.loop_indices)
    rgb=rgb_at(tex)
    head_weight=sum(weights[poly.vertices[0]].get(group.index,0) for group in obj.vertex_groups if group.name in ['mixamorig:Head','mixamorig:HeadTop_End'])
    if head_weight>.5:
        if poly.index not in removed and rgb[0]-rgb[2]>.045 and .3<min(rgb)<.94:
            warm_uv_candidates.append((centroid,tex.copy()))
        if poly.index in cuts and rgb[2]-rgb[0]>.005 and min(rgb)>.65:
            white_uv_candidates.append((float(sum(rgb)),tex.copy()))
        if poly.index in cuts and max(rgb)<.22:
            dark_uv_candidates.append((float(sum(rgb)),tex.copy()))
    if poly.index in removed:continue
    for loop in poly.loop_indices:
        welded=vids[original.loops[loop].vertex_index]
        if welded in rim_vertices:boundary_uv.setdefault(welded,uvs[loop].copy())
assert warm_uv_candidates and white_uv_candidates and dark_uv_candidates
lash_uv=min(dark_uv_candidates,key=lambda row:row[0])[1]

def add_vertex(point,group_weights=None):
    index=len(positions);positions.append(inverse@point);weights.append(group_weights or {head_group:1.0});new_vertices.append(index)
    return index

def add_face(indices,tex):
    faces.append(indices);face_uvs.append(tex);face_normals.append(None);materials.append(0);source_face_ids.append(-1)

def surface_uv(index,cut):
    return boundary_uv[vids[index]].copy()

def hull(points):
    points=sorted(set(points))
    def cross(a,b,c):return (b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0])
    lower=[];upper=[]
    for point in points:
        while len(lower)>1 and cross(lower[-2],lower[-1],point)<=0:lower.pop()
        lower.append(point)
    for point in reversed(points):
        while len(upper)>1 and cross(upper[-2],upper[-1],point)<=0:upper.pop()
        upper.append(point)
    return lower,list(reversed(upper))

def at(curve,x):
    for a,b in zip(curve,curve[1:]):
        if a[0]<=x<=b[0] and b[0]-a[0]>1e-9:return a[1]+(b[1]-a[1])*(x-a[0])/(b[0]-a[0])
    return min(curve,key=lambda point:abs(point[0]-x))[1]

def branches(points):
    first=min(range(len(points)),key=lambda index:points[index].x)
    last=max(range(len(points)),key=lambda index:points[index].x)
    paths=[]
    for direction in [1,-1]:
        path=[first]
        while path[-1]!=last:path.append((path[-1]+direction)%len(points))
        paths.append(path)
    paths.sort(key=lambda path:sum(points[index].z for index in path)/len(path),reverse=True)
    return dict(zip(['upper','lower'],paths))

def arc_sample(points,t):
    distances=[(b-a).length for a,b in zip(points,points[1:])]
    target=sum(distances)*t;walked=0.0
    for index,distance in enumerate(distances):
        if target<=walked+distance:return points[index].lerp(points[index+1],(target-walked)/max(distance,1e-9))
        walked+=distance
    return points[-1].copy()

for side,eye in review['eyes'].items():
    outer=[canonical[index] for index in eye['loop_welded_vertices']]
    direction_checks=[]
    for first,last in zip(outer,outer[1:]+outer[:1]):
        direction=outside_edge_directions[tuple(sorted((first,last)))]
        assert len(direction)==1,'The reviewed cut must leave exactlyone sourceface at each weld edge'
        direction_checks.append(direction[0]==(first,last))
    assert all(value==direction_checks[0] for value in direction_checks),'Source rim winding is inconsistent;do not export a nonorientable patch'
    reverse_skin=direction_checks[0];winding_checks[side]={'source_seam_edges':len(direction_checks),'reversed_new_patch':reverse_skin}
    points=[world[index].copy() for index in outer]
    # Crack absorption changes only the outer weld region. The open aperture
    # follows the original snug anatomical contour,not the expanded cheek cut.
    template=[world[canonical[index]].copy() for index in eye['initial_path_loop']]
    center=sum(template,Vector())/len(template)
    inside=[None]*len(points)
    target_paths=branches(points);template_paths=branches(template)
    for label,path in target_paths.items():
        selected=[points[index] for index in path]
        distances=[0.0]
        for a,b in zip(selected,selected[1:]):distances.append(distances[-1]+(b-a).length)
        outline=[template[index] for index in template_paths[label]]
        for index,distance in zip(path,distances):
            point=arc_sample(outline,distance/distances[-1])
            radial=Vector((point.x-center.x,0,point.z-center.z))
            inside[index]=point-radial.normalized()*.0012
    # Remove the quantization zigzag only on newly authored margin vertices.
    corners={target_paths['upper'][0],target_paths['upper'][-1]}
    upper_vertices=set(target_paths['upper'])-corners
    upper_arc={index:slot/(len(target_paths['upper'])-1) for slot,index in enumerate(target_paths['upper'])}
    controls={}
    for iteration in range(2):
        inside=[point if i in corners else point*.6+(inside[(i-1)%len(inside)]+inside[(i+1)%len(inside)])*.2 for i,point in enumerate(inside)]
    lower,upper=hull([(point.x,point.z) for point in inside])
    first=min(inside,key=lambda point:point.x);last=max(inside,key=lambda point:point.x)
    cids=mask['eyes'][side]['eye_components']
    iris_cid=min(cids)
    front=min(world[index].y for index in components[iris_cid])-.0008
    segments=min(8,min(len(path)-1 for path in target_paths.values()))
    common=[]
    for u in np.linspace(0,1,segments+1):
        x=first.x+(last.x-first.x)*float(u)
        z=at(lower,x)*.82+at(upper,x)*.18
        edge_y=first.y*(1-u)+last.y*u
        y=edge_y+(front-(first.y+last.y)*.5)*np.sin(np.pi*u)
        common.append(Vector((x,float(y),z)))
    # Both margins must contain the same closure breakpoints. Sampling a curved
    # function at unrelated upper/lowerX values left a tiny real iris slit.
    # This shared polyline closes exactly even with unequal source rim counts.
    target=[None]*len(inside)
    for path in target_paths.values():
        anchors=[round((len(path)-1)*step/segments) for step in range(segments+1)]
        assert len(set(anchors))==len(anchors)
        for segment in range(segments):
            a,b=anchors[segment:segment+2]
            for slot in range(a,b+1):target[path[slot]]=common[segment].lerp(common[segment+1],(slot-a)/(b-a))
    outer_uv=[surface_uv(index,removed) for index in outer]
    warm_uv=[]
    for point,tex in zip(points,outer_uv):
        local=[row for row in warm_uv_candidates if (row[0]-point).length<.025]
        assert local,'No verified local skin texture sample near this eyelid'
        candidates=[row for row in local if (row[1]-tex).length<.025] or local
        chosen=min(candidates,key=lambda row:(row[0]-point).length)
        warm_uv.append(chosen[1].copy())
    mean_skin=np.mean([rgb_at(tex) for tex in warm_uv],axis=0)
    lid_uv=min(warm_uv,key=lambda tex:float(np.linalg.norm(rgb_at(tex)-mean_skin))).copy()
    skin_uv_fallback[side]=lid_uv.copy()
    rings=[outer]
    ring_uv=[outer_uv]
    for t in [.08,.25,.5,.75,.95,1.0]:
        ring=[]
        for i,(a,b) in enumerate(zip(points,inside)):
            point=a.lerp(b,t)
            if t<.95:
                hit,normal,polygon,distance=cut_surface.ray_cast(Vector((point.x,-.3,point.z)),Vector((0,1,0)),.6)
                if hit is not None:point.y=hit.y
            index=add_vertex(point,weights[outer[i]].copy());ring.append(index)
            closed[index]=positions[index]+inverse.to_3x3()@((target[i]-b)*(t*t))
            if i in upper_vertices:controls[index]=inverse.to_3x3()@Vector((0,0,-float(np.sin(np.pi*upper_arc[i])**.5)*(t*t)))
        rings.append(ring)
        ring_uv.append([lash_uv.copy() if t==1.0 else lid_uv.copy() for index in outer])
    lip=[]
    for i,point in enumerate(inside):
        offset=Vector((0,.0010,0))
        index=add_vertex(point+offset,weights[outer[i]].copy());lip.append(index)
        closed[index]=positions[index]+inverse.to_3x3()@(target[i]-point)
        if i in upper_vertices:controls[index]=inverse.to_3x3()@Vector((0,0,-float(np.sin(np.pi*upper_arc[i])**.5)))
    rings.append(lip)
    ring_uv.append([lash_uv.copy() for index in lip])
    for strip,(a,b,ua,ub) in enumerate(zip(rings,rings[1:],ring_uv,ring_uv[1:])):
        for i in range(len(a)):
            j=(i+1)%len(a)
            # Separate per-corner UV islands avoid interpolating across distant
            # source atlas islands. Geometry remains welded. Keep the exact
            # original UV on the narrow static outer strip;actual skin/lash
            # pixels from this face fill the new lid,not the painted eye.
            tex=[outer_uv[i],outer_uv[j],outer_uv[j],outer_uv[i]] if strip==0 else [lash_uv.copy() if strip>=len(rings)-3 else lid_uv.copy() for corner in range(4)]
            indices=[a[i],a[j],b[j],b[i]]
            add_face(list(reversed(indices)) if reverse_skin else indices,list(reversed(tex)) if reverse_skin else tex)
            skin_face_styles[len(faces)-1]=(side,'outer' if strip==0 else 'lash' if strip>=len(rings)-3 else 'skin')
    rings_by_eye[side]=rings;inner_by_eye[side]=rings[-2]
    neutral_inner[side]=inside
    assert len(controls)>3 and max(vector.length for vector in controls.values())>.5,'Named upper-lid controls must move actual eligible vertices'
    neutral_controls[side]=controls
    edge_seams.extend(tuple(sorted(edge)) for edge in zip(outer,outer[1:]+outer[:1]))

skin_vertex_count=len(new_vertices)
skin_face_count=len(faces)-source_face_count
sclera_uv=max(white_uv_candidates,key=lambda row:row[0])[1]
for side,eye in review['eyes'].items():
    iris=min(mask['eyes'][side]['eye_components'])
    iris_points=[world[index] for index in components[iris]]
    center=sum(iris_points,Vector())/len(iris_points)
    center.y=max(point.y for point in iris_points)+.001
    # A recessed cup bounded by the actual open margin cannot protrude through
    # nearby generated skin cracks as a broad sphere did. The iris is untouched.
    border=[]
    for point in neutral_inner[side]:
        radial=Vector((point.x-center.x,0,point.z-center.z)).normalized()
        border.append(point+radial*.00045+Vector((0,.0016,0)))
    pole=add_vertex(center);grid=[]
    for t in [.2,.4,.6,.8,1.0]:grid.append([add_vertex(center.lerp(point,t)) for point in border])
    for i in range(len(border)):
        j=(i+1)%len(border);add_face([pole,grid[0][j],grid[0][i]],[sclera_uv.copy() for index in range(3)])
    for a,b in zip(grid,grid[1:]):
        for i in range(len(border)):
            j=(i+1)%len(border);add_face([a[i],a[j],b[j],b[i]],[sclera_uv.copy() for index in range(4)])
    back=[add_vertex(point+Vector((0,.004,0))) for point in border]
    for i in range(len(border)):
        j=(i+1)%len(border);add_face([grid[-1][i],grid[-1][j],back[j],back[i]],[sclera_uv.copy() for index in range(4)])
    back_pole=add_vertex(center+Vector((0,.006,0)))
    for i in range(len(border)):
        j=(i+1)%len(border);add_face([back_pole,back[i],back[j]],[sclera_uv.copy() for index in range(3)])

if source_ray_path.exists():
    source_rays=json.loads(source_ray_path.read_text())
    assert source_rays['source_blend_sha256']==sha(intake/'head-topology-diagnostic.blend')
    assert source_rays['source_glb_sha256']==sha(source)
    # Named upper-lid drop only;fit one scalar per eye against the unchanged
    # source visibility,without copying a hair silhouette or editing the iris.
    skin_limit=len(original.vertices)+skin_vertex_count
    skin_faces=[face for face in faces if any(index>=len(original.vertices) for index in face) and all(index<skin_limit for index in face)]
    all_iris=set(components[26]+components[27])
    static_faces=[face for face in faces if face not in skin_faces and not all(index in all_iris for index in face)]
    world_points=[obj.matrix_world@point for point in positions]
    static_tree=BVHTree.FromPolygons(world_points,static_faces)
    for side,controls in neutral_controls.items():
        samples=source_rays['eyes'][side]['samples'];fixed_y=[]
        for sample in samples:
            hit,normal,face,distance=static_tree.ray_cast(Vector((sample['x'],-.3,sample['z'])),Vector((0,1,0)),.6)
            fixed_y.append(float(hit.y) if hit is not None else float('inf'))
        trials=[]
        for drop in np.linspace(0,.003,13):
            trial=world_points[:]
            for index,unit in controls.items():trial[index]=obj.matrix_world@(positions[index]+unit*float(drop))
            tree=BVHTree.FromPolygons(trial,skin_faces)
            extra=lost=intersection=union=0
            for sample,fixed in zip(samples,fixed_y):
                hit,normal,face,distance=tree.ray_cast(Vector((sample['x'],-.3,sample['z'])),Vector((0,1,0)),.6)
                visible=min(fixed,float(hit.y) if hit is not None else float('inf'))>sample['iris_y']+.00002
                expected=sample['source_visible']
                extra+=int(visible and not expected);lost+=int(expected and not visible)
                intersection+=int(visible and expected);union+=int(visible or expected)
            trials.append({'drop_m':float(drop),'extra':extra,'lost':lost,'iou':intersection/max(union,1),'score':extra+3*lost})
        selected=min(trials,key=lambda row:(row['score'],row['drop_m']))
        for index,unit in controls.items():positions[index]+=unit*selected['drop_m']
        neutral_fit[side]={'selected':selected,'trials':trials}
    (out/'neutral-fit-trials.json').write_text(json.dumps({'status':'BOUNDED_UPPER_LID_SOURCE_VISIBILITY_FIT_NOT_ART_ACCEPTANCE','source_reference_sha256':sha(source_ray_path),'eyes':neutral_fit},indent=2)+'\n')

# Reuse original local skin detail where the actual neutral surface projects to
# verified skin. The painted ocular region never becomes closed-lid skin UV.
projected_uv={};uv_stats={'skin_samples':0,'verified_original_skin':0,'fallback_samples':0,'atlas_seam_fallback_faces':0}
for side,rings in rings_by_eye.items():
    for ring_number,ring in enumerate(rings[1:-2],1):
        for index in ring:
            point=obj.matrix_world@positions[index]
            hit,normal,triangle,distance=cut_surface.ray_cast(Vector((point.x,-.3,point.z)),Vector((0,1,0)),.6)
            tex=None
            if hit is not None:
                polygon=original.polygons[cut_ids[triangle]]
                coordinates=[world[vertex] for vertex in polygon.vertices]
                texture_points=[Vector((*uvs[loop],0)) for loop in polygon.loop_indices]
                sampled=barycentric_transform(hit,*coordinates,*texture_points)
                candidate=Vector((sampled.x,sampled.y));rgb=rgb_at(candidate)
                if np.all(np.isfinite(rgb)) and rgb[0]-rgb[2]>.012 and .25<min(rgb)<.95:tex=candidate
            uv_stats['skin_samples']+=1
            if tex is None:tex=skin_uv_fallback[side].copy();uv_stats['fallback_samples']+=1
            else:uv_stats['verified_original_skin']+=1
            projected_uv[index]=tex
for face_id,(side,style) in skin_face_styles.items():
    if style!='skin':continue
    tex=[projected_uv.get(index,skin_uv_fallback[side]).copy() for index in faces[face_id]]
    if max((first-second).length for first in tex for second in tex)>.025:
        tex=[skin_uv_fallback[side].copy() for index in tex];uv_stats['atlas_seam_fallback_faces']+=1
    face_uvs[face_id]=tex

skin_material,atlas_report=bake_skin_atlas(out,original,world,uvs,pixels,removed,rim_vertices,vids,
    rings_by_eye,positions,obj.matrix_world,skin_face_styles,faces,face_uvs,materials)

new=bpy.data.meshes.new('School65_ConnectedBlinkResearch')
new.from_pydata(positions,[],faces);new.update()
for material in original.materials:new.materials.append(material)
new.materials.append(skin_material)
uv=new.uv_layers.new(name=original.uv_layers.active.name)
for polygon,tex,old_normals,material in zip(new.polygons,face_uvs,face_normals,materials):
    polygon.material_index=material;polygon.use_smooth=True
    for slot,loop in enumerate(polygon.loop_indices):
        uv.data[loop].uv=tex[slot]
new.update()
# Resolve all smoothing flags before reading any new vertex normal. Reading
# midway through face assignment cached mixed flat/smooth corner directions.
flat_normals=[]
for polygon,old_normals in zip(new.polygons,face_normals):
    for slot,loop in enumerate(polygon.loop_indices):
        flat_normals.append(old_normals[slot] if old_normals else new.vertices[new.loops[loop].vertex_index].normal.copy())
new.normals_split_custom_set(flat_normals)
obj.data=new
if not obj.vertex_groups:
    for name in group_names:obj.vertex_groups.new(name=name)
assert [group.name for group in obj.vertex_groups]==group_names
for index,row in enumerate(weights):
    for group,weight in row.items():obj.vertex_groups[group].add([index],weight,'REPLACE')
basis=obj.shape_key_add(name='Basis');blink=obj.shape_key_add(name='blink')
for index,point in closed.items():blink.data[index].co=point
seams=Counter()
for poly in new.polygons:
    indices=list(poly.vertices)
    for first,second in zip(indices,indices[1:]+indices[:1]):seams[tuple(sorted((first,second)))]+=1
bad_seams=[{'edge':edge,'incidence':seams[edge],
            'remaining_source_faces':[source_face_ids[i] for i,face in enumerate(faces[:source_face_count])
                                      if set(edge).issubset(face)]} for edge in edge_seams if seams[edge]!=2]
if bad_seams:
    (out/'topology-failure.json').write_text(json.dumps({'status':'FAIL_NO_EXPORT','bad_seams':bad_seams},indent=2)+'\n')
    print('BLINK_RIM_FAILURE',json.dumps(bad_seams))
assert not bad_seams,'New skin patch must share manifold source rim edges'
maximum_position=maximum_uv=maximum_weight=0.0
for old_id,poly in zip(source_face_ids[:source_face_count],list(new.polygons)[:source_face_count]):
    old=original.polygons[old_id]
    for old_loop,new_loop in zip(old.loop_indices,poly.loop_indices):
        old_index=original.loops[old_loop].vertex_index;new_index=new.loops[new_loop].vertex_index
        maximum_position=max(maximum_position,(original.vertices[old_index].co-new.vertices[new_index].co).length)
        maximum_uv=max(maximum_uv,(uvs[old_loop]-uv.data[new_loop].uv).length)
        got={item.group:item.weight for item in new.vertices[new_index].groups}
        maximum_weight=max(maximum_weight,max([abs(weights[old_index].get(k,0)-got.get(k,0)) for k in set(weights[old_index])|set(got)] or [0]))
assert maximum_position==maximum_uv==maximum_weight==0.0
for item in bpy.context.scene.objects:
    if item.type=='CURVE':item.hide_render=True
scene=bpy.context.scene;scene.display.shading.color_type='TEXTURE';camera=scene.camera
eye_center=Vector((-.003,-.05,1.597))
camera.data.ortho_scale=.17
captures=[]
for value in [0,.5,1]:
    blink.value=value
    for view,offset in [('front',(0,-3,0)),('threequarter',(1.5,-3,0)),('reverse-threequarter',(-1.5,-3,0))]:
        camera.location=eye_center+Vector(offset);camera.rotation_euler=(eye_center-camera.location).to_track_quat('-Z','Y').to_euler()
        scene.render.filepath=str(out/f'blink-{value:.2f}-{view}.png');bpy.ops.render.render(write_still=True);captures.append(Path(scene.render.filepath).name)
blink.value=0
bpy.ops.wm.save_as_mainfile(filepath=str(out/'connected-blink-research.blend'))
data={'status':'RESEARCH_RETOPOLOGY_PENDING_VISUAL_GATE_NOT_EXPORTED','source_sha256':sha(source),
      'build_input_sha256':build_input_sha256,'blend_sha256':sha(out/'connected-blink-research.blend'),
      'semantic_region_review_sha256':sha(out/'semantic-region-review.json'),'source_vertices':len(original.vertices),
      'retained_original_vertices':len(original.vertices),'added_skin_vertices':skin_vertex_count,'added_sclera_vertices':len(new_vertices)-skin_vertex_count,'removed_source_faces':len(removed),
      'new_skin_faces':skin_face_count,'body_bones':len(next(item for item in scene.objects if item.type=='ARMATURE').data.bones),
      'outside_cut_position_error_m':maximum_position,'outside_cut_uv_error':maximum_uv,'outside_cut_weight_error':maximum_weight,
      'outer_seam_edges':len(edge_seams),'outer_seam_edge_incidence':2,'source_morphs_added_to_original_file':False,
      'outer_seam_winding':winding_checks,'neutral_source_fit':neutral_fit,
      'neutral_skin_uv_projection':uv_stats,
      'derived_skin_atlas':atlas_report,
      'new_lid_uv_strategy':'Exact original UV on a narrow static outer strip;new connected skin uses its continuous local spatial albedo bake;the thin real margin/lip retains an existing dark lash pixel. Original maps andall outside-cut UV remain unchanged;finalart/color match unaccepted.',
      'known_open_gate':'Neutral identity,iris clearance,closed white leakage and native movement are unaccepted. Original iris geometry stays fixed. Recessed sclera samples an existing verified white texture pixel;maps unchanged. No export or runtime integration.',
      'captures':{name:sha(out/name) for name in captures},'new_vertex_indices':new_vertices,'inner_margins':inner_by_eye}
(out/'retopology-review.json').write_text(json.dumps(data,indent=2)+'\n')
assert sha(source)==review['source_sha256']
print('CONNECTED_BLINK_RESEARCH',json.dumps({k:data[k] for k in ['added_skin_vertices','removed_source_faces','outside_cut_position_error_m','outside_cut_uv_error','outside_cut_weight_error']}))

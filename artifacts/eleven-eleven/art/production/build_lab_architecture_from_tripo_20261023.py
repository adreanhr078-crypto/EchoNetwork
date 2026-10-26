"""Measured architectural derivative of retained Tripo full-room source.

Only perimeter architecture is retained. Native dry floor, coolant, chair,
memory pods, door collider and gameplay landmarks continue to own the room.
No character/collision/animation data is generated or modified.
"""
import bpy,bmesh,json,hashlib,math
from pathlib import Path
from mathutils import Vector
APP=Path(__file__).resolve().parents[2]
SOURCE=APP/'art/production/lab-clinical-kit-20261023/tripo/lab-full-room-textured-8k.glb'
OUT=APP/'art/production/lab-clinical-kit-20261023/tripo/architecture-derivative'
OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(SOURCE))
meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
before=0;after=0;kept=[]
for o in meshes:
 bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o
 bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
 o.data.calc_loop_triangles();before+=len(o.data.loop_triangles)
 bm=bmesh.new();bm.from_mesh(o.data)
 remove=[]
 for f in bm.faces:
  c=f.calc_center_median();x,y,z=c
  perimeter=abs(x)>.335 or y>.385
  # Front and centre remain open; remove low deck duplicates. Clear a
  # >=3.48m north opening, including triangles crossing its boundary.
  opening=any(v.co.y>.375 and abs(v.co.x)<.05 and v.co.z<.19 for v in f.verts)
  if not perimeter or z<.039 or opening:remove.append(f)
 bmesh.ops.delete(bm,geom=remove,context='FACES')
 orphan=[v for v in bm.verts if not v.link_faces]
 if orphan:bmesh.ops.delete(bm,geom=orphan,context='VERTS')
 for v in bm.verts:
  # The generated perimeter is a thick scenic shell. A uniform extent fit
  # put its inner wall atX11.6 and northY15.4, inside the retained native
  # 32x40m room. Compress wall thickness explicitly: clearX+-14.8 and
  # northY19.0, outer bounds+-15.7/19.6. Keep gallery detail between them.
  x,y=v.co.x,v.co.y
  if abs(x)>.335:
   v.co.x=math.copysign(14.8+(abs(x)-.335)*(.9/(.9033576846*.5-.335)),x)
  else:
   v.co.x=x*(14.8/.335)
  if y>.385:
   v.co.y=19.0+(y-.385)*(.6/(.9785512090*.5-.385))
  else:
   v.co.y=-19.6+(y+.9785512090*.5)*(38.6/(.385+.9785512090*.5))
  v.co.z=(v.co.z-.04)*42.0
 bm.to_mesh(o.data);bm.free();o.data.update()
 if not o.data.polygons:
  bpy.data.objects.remove(o,do_unlink=True);continue
 o.data.calc_loop_triangles();after+=len(o.data.loop_triangles);kept.append(o)
assert kept and after<before
bpy.ops.object.select_all(action='DESELECT')
for o in kept:o.select_set(True)
bpy.context.view_layer.objects.active=kept[0]
bpy.ops.object.join();shell=bpy.context.object;shell.name='ClinicalPerimeterShell'
shell.data.name='MeasuredClinicalPerimeter'
# Remove unused nodes from the derivative only; retained raw source is untouched.
for o in list(bpy.context.scene.objects):
 if o!=shell:bpy.data.objects.remove(o,do_unlink=True)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'clinical-perimeter.blend'))
target=OUT/'clinical_perimeter_tripo.glb'
bpy.ops.export_scene.gltf(filepath=str(target),export_format='GLB',use_selection=True,
 export_animations=False,export_yup=True,export_normals=True,export_texcoords=True)
record={'source':str(SOURCE),'source_sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
 'derivative':str(target),'sha256':hashlib.sha256(target.read_bytes()).hexdigest(),
 'source_triangles':before,'retained_triangles':after,'materials':len(shell.data.materials),
 'source_parts':len(meshes),'native_extent_target_m':[31.4,39.2,9.7],
 'measurement':'Source X/Y extent .9033576846/.978551209; piecewise measured fit: inner sidewallsX+-14.8,outer+-15.7,northinnerY19.0,outer19.6,south-19.6; floorZ=.04,heightscale42. Environment-only approximation, not exact reconstruction.',
 'selection':'Perimeter face centres absX>.335 orY>.385,aboveZ=.039; clear north opening any vertexY>.375,absX<.05,Z<.19. Native central equipment/floor/water/colliders retained separately.',
 'scope':'Candidate architectural derivative; visual seams, openings, scale, lighting and native route require review.'}
(OUT/'derivative.json').write_text(json.dumps(record,indent=2)+'\n')
print('CLINICAL_PERIMETER_BUILT',json.dumps(record))

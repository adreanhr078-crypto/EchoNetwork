"""Measured visual-only lab derivative: image-guided Tripo tile + authored frame.

No room collider, gameplay, character or animation is generated here. Run in a
fresh background Blender. Preserve the raw Tripo FBX/GLB and every earlier kit.
"""
import bpy, bmesh, math, json, hashlib
from pathlib import Path
from mathutils import Vector

APP=Path(__file__).resolve().parents[2]
P=APP/'art/production/lab-modular-refinement-20261024'
SOURCE=P/'clinical_wall_p2_pbr_4k.glb'
OUT=APP/'godot/assets/environments/lab_clinical_cp45/clinical_modular_perimeter.glb'
TILE_OUT=OUT.with_name('clinical_wall_p2_4k.glb')
FRAME_OUT=OUT.with_name('clinical_service_frame_clean.glb')
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(SOURCE))
sources=[o for o in bpy.context.scene.objects if o.type=='MESH']
assert len(sources)==1, 'Inspect a changed provider export before assembly'
tile=sources[0]
bpy.ops.object.select_all(action='DESELECT');tile.select_set(True);bpy.context.view_layer.objects.active=tile
bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
tile.data.calc_loop_triangles();before=len(tile.data.loop_triangles)
original_materials=list(tile.data.materials)
assert len(original_materials)==1
material=original_materials[0];material.name='ClinicalTripoWallPBR4K'
images=[n.image for n in material.node_tree.nodes if n.type=='TEX_IMAGE' and n.image]
assert len(images)==3 and all(max(image.size)>=4096 for image in images), 'Real4K PBR maps required'
raw_points=[v.co.copy() for v in tile.data.vertices]
lower=Vector(tuple(min(p[i] for p in raw_points) for i in range(3)))
upper=Vector(tuple(max(p[i] for p in raw_points) for i in range(3)))
size=upper-lower
assert size.y<min(size.x,size.z)*.25, 'Expected shallow upright tile,not a volume prop'
# Remove only nearly coplanar interior topology, respecting UV/material/normal
# borders. Vertex coordinates remain original; no arbitrary voxel remesh.
bm=bmesh.new();bm.from_mesh(tile.data)
bmesh.ops.dissolve_limit(bm,angle_limit=math.radians(.35),use_dissolve_boundaries=False,
    verts=list(bm.verts),edges=list(bm.edges),delimit={'UV','MATERIAL','NORMAL'})
bm.to_mesh(tile.data);bm.free();tile.data.update()
tile.data.calc_loop_triangles();after=len(tile.data.loop_triangles)
assert after<=before
for vertex in tile.data.vertices:
    v=vertex.co
    vertex.co=((v.x-(lower.x+upper.x)*.5)/size.x*3,
               (v.y-(lower.y+upper.y)*.5)/size.y*.20,
               (v.z-lower.z)/size.z*3)
tile.data.update();tile.name='TripoWallTile_Template_3x3m'
tile.hide_render=True;tile.hide_set(True)

def mat(name,color,metal,rough,emission=0):
    m=bpy.data.materials.new(name);m.use_nodes=True
    bs=m.node_tree.nodes.get('Principled BSDF')
    bs.inputs['Base Color'].default_value=(*color,1)
    bs.inputs['Metallic'].default_value=metal;bs.inputs['Roughness'].default_value=rough
    bs.inputs['Emission Color'].default_value=(*color,1);bs.inputs['Emission Strength'].default_value=emission
    return m
pearl=mat('ClinicalCleanPearl',(.66,.68,.69),.10,.62)
graphite=mat('ClinicalCleanGraphite',(.09,.12,.16),.30,.55)
alloy=mat('ClinicalCleanAlloy',(.31,.36,.40),.58,.42)
cyan=mat('ClinicalCleanServiceStrip',(.10,.37,.42),.10,.45,.6)
parts=[];walls={}

def place_tile(group,x,y,z,yaw=0,width=3,height=3):
    obj=tile.copy();obj.data=tile.data.copy();obj.name=group+'_Tile'
    obj.hide_render=False;obj.hide_set(False);bpy.context.collection.objects.link(obj)
    # glTF imports use quaternion rotation; Euler assignments otherwise leave
    # the mesh facing its original direction and create perpendicular fins.
    obj.rotation_mode='XYZ';obj.rotation_euler=(0,0,yaw)
    obj.location=(x,-z,y);obj.scale=(width/3,1,height/3)
    walls.setdefault(group,[]).append(obj)

def box(name,point,dimensions,m,bevel=.025):
    x,y,z=point;w,h,d=dimensions
    bpy.ops.mesh.primitive_cube_add(size=1,location=(x,-z,y))
    obj=bpy.context.object;obj.name=name;obj.scale=(w,d,h)
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    obj.data.materials.append(m)
    if bevel:
        mod=obj.modifiers.new('Measured machined bevel','BEVEL')
        mod.width=min(bevel,min(dimensions)*.24);mod.segments=2
        bpy.ops.object.modifier_apply(modifier=mod.name)
        weighted=obj.modifiers.new('Weighted architectural normals','WEIGHTED_NORMAL');weighted.keep_sharp=True
        bpy.ops.object.modifier_apply(modifier=weighted.name)
    parts.append(obj)
    return obj

# Frontmost panel faces sit2cm inside the EXISTING wall collider, within the
# native camera margin. No3m-wide tile crosses an entrance or exit aperture.
for side,label,yaw in [(-1,'West',math.pi*.5),(1,'East',-math.pi*.5)]:
    for z in [-2-3*i for i in range(13)]:
        for y in [0,3,6]:place_tile(label,side*16.08,y,z,yaw)
    for y in [.12,9.65]:box(label+'ServiceCap',(side*15.96,y,-20),(.12,.20,39.6),graphite)
    # Retain the source's inaccessible upper service-gallery silhouette.
    box(label+'GalleryDeck',(side*15.42,5.13,-20),(1.12,.12,38.6),alloy)
    for y in [5.40,6.25]:box(label+'GalleryRail',(side*14.91,y,-20),(.055,.055,38.5),graphite,.012)
    for z in [-1.0-3*i for i in range(13)]:
        box(label+'GalleryStanchion',(side*14.91,5.72,z),(.055,1.13,.055),graphite,.012)
    for z in [-.23,-39.77]:box(label+'CornerPier',(side*15.91,4.95,z),(.16,9.80,.38),alloy)
    for z in [-3.5,-9.5,-15.5,-21.5,-27.5,-33.5]:
        box(label+'UpperServiceIndicator',(side*15.88,9.25,z),(.045,.045,1.2),cyan,.009)
    for z in [-3.5,-15.5,-27.5,-39.5]:
        box(label+'MajorBayPier',(side*15.92,4.94,z),(.12,9.60,.24),graphite,.028)
        box(label+'BayServiceStatus',(side*15.845,1.12,z),(.025,.20,.035),cyan,.006)

for side in [-1,1]:
    for x in [7.55,10.8,14.05]:
        for y in [0,3,6]:place_tile('North',side*x,y,-40.08,0,3.15)
    for x in [3.09,6.69,10.29,13.89]:
        for y in [0,3,6]:place_tile('South',side*x,y,.08,math.pi,3.54)

# Clean north service bay,behind the original clock surface and gate. Its
# clear lower aperture remains >=2.05m wide x2.8m high at the native threshold.
for side in [-1,1]:
    box('NorthBaySidePanel',(side*3.40,1.48,-40.01),(4.60,2.96,.06),pearl)
    box('NorthBayUpperPier',(side*5.65,4.95,-39.99),(.44,9.80,.08),pearl)
    box('NorthBayPierChannel',(side*5.65,4.5,-39.92),(.075,7.0,.065),graphite,.013)
    box('GateJamb',(side*1.14,1.40,-39.94),(.18,2.80,.10),alloy,.023)
    box('ClockBezelSide',(side*5.08,5,-39.69),(.14,2.70,.10),graphite,.025)
    for y in [3.36,7.35]:box('BayCornerCap',(side*5.49,y,-39.92),(.68,.30,.11),alloy)
box('GateHead',(0,2.88,-39.94),(2.46,.16,.10),alloy,.023)
box('ClockUnderPanel',(0,3.38,-40.01),(10.80,.68,.06),pearl)
box('ClockUpperPanel',(0,6.88,-40.01),(10.80,1.0,.06),pearl)
box('ClockUpperLouvre',(0,7.50,-39.95),(9.80,.23,.12),alloy,.035)
box('ClockUpperServiceStrip',(0,7.49,-39.875),(8.20,.035,.025),cyan,.006)
for y in [3.73,6.27]:box('ClockBezelHorizontal',(0,y,-39.69),(10.30,.14,.10),graphite,.025)
box('ClockBacking',(0,5,-40.01),(10.80,2.92,.06),graphite)
for y,height in [(8.62,2.20)]:box('NorthUpperInfill',(0,y,-40.01),(11.68,height,.06),pearl)

# South doorway remains >=2.6m x3.2m. Header geometry starts at3.2m.
for y,height in [(4.88,3.36),(8.26,3.32)]:box('SouthDoorHeader',(0,y,.01),(2.60,height,.06),pearl)
for side in [-1,1]:box('SouthDoorJamb',(side*1.40,1.60,-.03),(.16,3.20,.10),alloy)
box('SouthDoorHead',(0,3.29,-.03),(2.96,.18,.10),alloy)
for side in [-1,1]:box('SouthPortalSleeve',(side*1.62,1.70,-.06),(.28,3.40,.12),graphite,.04)
box('SouthPortalCrown',(0,3.42,-.06),(3.52,.32,.12),graphite,.04)
box('SouthPortalServiceStrip',(0,3.43,-.135),(2.90,.04,.025),cyan,.008)
for z in [-.04,-39.96]:box('EndWallCrown',(0,9.65,z),(31.75,.20,.12),graphite)

def join(objects,name):
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objects:obj.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]
    bpy.ops.object.join();obj=bpy.context.object;obj.name=name
    bpy.context.scene.cursor.location=(0,0,0);bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    return obj
assembled=[join(objects,'ClinicalClean'+label+'Wall') for label,objects in walls.items()]
assembled.append(join(parts,'ClinicalCleanFrameAndGallery'))
for obj in assembled:obj.data.calc_loop_triangles()
def room_bounds(obj):
    points=[obj.matrix_world@v.co for v in obj.data.vertices]
    room_points=[Vector((v.x,v.z,-v.y)) for v in points]
    low=[min(v[i] for v in room_points) for i in range(3)]
    high=[max(v[i] for v in room_points) for i in range(3)]
    return {'min':low,'max':high,'dimensions':[high[i]-low[i] for i in range(3)]}
boundaries={o.name:room_bounds(o) for o in assembled}
for label in ['West','East']:
    assert boundaries['ClinicalClean'+label+'Wall']['dimensions'][0]<.201, 'Side cladding must be shallow alongX'
assert boundaries['ClinicalCleanWestWall']['max'][0]<-15.95
assert boundaries['ClinicalCleanEastWall']['min'][0]>15.95
assert boundaries['ClinicalCleanNorthWall']['max'][2]<-39.95
assert boundaries['ClinicalCleanSouthWall']['min'][2]>-.03
bpy.ops.object.select_all(action='DESELECT')
for obj in assembled:obj.select_set(True)
bpy.context.view_layer.objects.active=assembled[0]
OUT.parent.mkdir(parents=True,exist_ok=True)
bpy.ops.export_scene.gltf(filepath=str(OUT),export_format='GLB',use_selection=True,export_yup=True,
    export_animations=False,export_materials='EXPORT')
# Runtime uses one shared tile mesh in four MultiMesh batches, plus the frame.
# The full baked mesh above remains a diagnostic reference,not the runtime.
bpy.ops.object.select_all(action='DESELECT')
tile.hide_render=False;tile.hide_set(False);tile.select_set(True);bpy.context.view_layer.objects.active=tile
bpy.ops.export_scene.gltf(filepath=str(TILE_OUT),export_format='GLB',use_selection=True,export_yup=True,
    export_animations=False,export_materials='EXPORT')
tile.select_set(False);tile.hide_render=True;tile.hide_set(True)
frame=assembled[-1];frame.select_set(True);bpy.context.view_layer.objects.active=frame
bpy.ops.export_scene.gltf(filepath=str(FRAME_OUT),export_format='GLB',use_selection=True,export_yup=True,
    export_animations=False,export_materials='EXPORT')
bpy.ops.wm.save_as_mainfile(filepath=str(P/'clinical-modular-perimeter.blend'))
report={'source':str(SOURCE.relative_to(APP)).replace('\\','/'),'source_sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
    'raw_tile_triangles':before,'planar_cleanup_tile_triangles':after,'source_bounds_min':list(lower),'source_bounds_max':list(upper),
    'normalised_tile_dimensions_m':[3,.2,3],'tile_instances':sum(len(o) for o in walls.values()),
    'measured_room_bounds':boundaries,
    'image_dimensions':{i.name:list(i.size) for i in images},
    'output':str(OUT.relative_to(APP)).replace('\\','/'),'output_sha256':hashlib.sha256(OUT.read_bytes()).hexdigest(),
    'runtime_assets':[{ 'file':str(f.relative_to(APP)).replace('\\','/'),'sha256':hashlib.sha256(f.read_bytes()).hexdigest()} for f in [TILE_OUT,FRAME_OUT]],
    'meshes':[{'name':o.name,'vertices':len(o.data.vertices),'triangles':len(o.data.loop_triangles),'surfaces':len(o.data.materials)} for o in assembled],
    'scope':'Editable visual-only candidate. Repeated image-guided Tripo tile; authored exact portal/frame/gallery dimensions. Not an exact reconstruction from a film. Native collision,camera,path,state,art and performance acceptance remain required.'}
(P/'modular-perimeter-build.json').write_text(json.dumps(report,indent=2)+'\n')
print('CLINICAL_MODULAR_CANDIDATE_BUILT',json.dumps(report))

import bpy, math, bmesh, json
from pathlib import Path
from mathutils import Vector

dest=Path(r'C:\Users\yasmo\EchoNetwork\artifacts\eleven-eleven\art\production\room01-hero-clock-20261014')
scene=bpy.data.scenes['Room01ClockCraft']
bpy.context.window.scene=scene
collection=bpy.data.collections['Room01ClockAsset']
brass=bpy.data.objects['WatchCase'].data.materials[0]
enamel=bpy.data.objects['ClockDial'].data.materials[0]
ivory=bpy.data.materials[scene['ivory_material']]

def obj(name,vertices,faces,mat):
    mesh=bpy.data.meshes.new(name+'Mesh')
    mesh.from_pydata(vertices,[],faces)
    mesh.update()
    item=bpy.data.objects.new(name,mesh)
    collection.objects.link(item)
    mesh.materials.append(mat)
    return item

def lathe(name,profile,mat,segments=48):
    vs=[(r*math.sin(a*math.tau/segments),r*math.cos(a*math.tau/segments),z)
        for r,z in profile for a in range(segments)]
    fs=[(k*segments+a,k*segments+(a+1)%segments,
         ((k+1)%len(profile))*segments+(a+1)%segments,
         ((k+1)%len(profile))*segments+a)
        for k in range(len(profile)) for a in range(segments)]
    return obj(name,vs,fs,mat)

def prism(name,polygon,depth,mat):
    vs=[(x,y,z) for z in [-depth/2,depth/2] for x,y in polygon]
    n=len(polygon)
    fs=[tuple(range(n-1,-1,-1)),tuple(range(n,n*2))]
    fs += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    return obj(name,vs,fs,mat)

# Focal tick hierarchy: minute ticks quiet, quarter-hour batons broader.
vs=[];fs=[]
for minute in range(60):
    angle=minute*math.tau/60
    length=.021 if minute%5==0 else .008
    width=.0055 if minute%5==0 else .0023
    center=.151-length/2
    start=len(vs)
    for z in [.0175,.0195]:
        for x,y in [(-width/2,center-length/2),(width/2,center-length/2),
                    (width/2,center+length/2),(-width/2,center+length/2)]:
            vs.append((x*math.cos(angle)+y*math.sin(angle),-x*math.sin(angle)+y*math.cos(angle),z))
    fs.extend([tuple(start+i for i in f) for f in [(3,2,1,0),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]])
track=obj('MinuteTrack',vs,fs,brass)
track.data.materials.append(ivory)
for polygon in track.data.polygons:
    polygon.material_index=1 if polygon.index//6 in (11,55) else 0
lathe('InnerDialRule',[(.158,.0176),(.160,.0176),(.160,.0186),(.158,.0186)],brass)
lathe('CenterPin',[(0,0),(.009,0),(.012,.004),(.009,.010),(0,.010)],brass,24).location.z=.027

hour=prism('HourHand',[(-.004,-.023),(-.011,.042),(-.007,.083),(0,.111),(.007,.083),(.011,.042),(.004,-.023)],.004,brass)
minute=prism('MinuteHand',[(-.003,-.026),(-.006,.065),(-.004,.125),(0,.153),(.004,.125),(.006,.065),(.003,-.026)],.003,brass)
hour.location.z=.023
minute.location.z=.028
hour.rotation_euler.z=-math.radians(335.5)
minute.rotation_euler.z=-math.radians(66)
for hand,length,width in [(hour,.103,.003),(minute,.145,.0016)]:
    strip=prism(hand.name+'SignalStrip',[(-width,.021),(-width,length-.014),(0,length),(width,length-.014),(width,.021)],.0008,ivory)
    strip.rotation_euler=hand.rotation_euler.copy()
    strip.location=hand.location+Vector((0,0,.0028))
    bpy.ops.object.select_all(action='DESELECT')
    hand.select_set(True);strip.select_set(True)
    bpy.context.view_layer.objects.active=hand
    bpy.ops.object.join()

# Winding crown follows the12 axis, joined to the static brass body later.
crown=lathe('WindingCrown',[(0,-.008),(.013,-.008),(.019,-.004),(.019,.012),(.013,.017),(0,.017)],brass,32)
crown.rotation_euler.x=-math.pi/2
crown.location=(0,.215,.01)
neck=lathe('CrownNeck',[(0,-.009),(.009,-.009),(.010,-.006),(.010,.007),(.008,.009),(0,.009)],brass,24)
neck.rotation_euler.x=-math.pi/2
neck.location=(0,.200,.010)
hinge=lathe('LidHinge',[(0,-.018),(.012,-.018),(.014,-.013),(.014,.013),(.012,.018),(0,.018)],brass,24)
hinge.rotation_euler.y=math.pi/2
hinge.location=(0,.190,.021)

# A thin open bow with elliptical cross-section, no expensive chain repeats.
vertices=[];faces=[]
for a in range(32):
    theta=math.tau*a/32
    for b in range(8):
        phi=math.tau*b/8
        radius=.027+.0045*math.cos(phi)
        vertices.append((radius*math.sin(theta),.255+radius*math.cos(theta),.01+.0045*math.sin(phi)))
for a in range(32):
    for b in range(8):
        faces.append((a*8+b,a*8+(b+1)%8,((a+1)%32)*8+(b+1)%8,((a+1)%32)*8+b))
obj('BowRing',vertices,faces,brass)

# Repair orientation from topology, never by a guessed coordinate selection.
topology={}
for item in collection.objects:
    if item.type!='MESH': continue
    bm=bmesh.new();bm.from_mesh(item.data)
    # Seal tiny lathe centres that were only blockout placeholders.
    if item.name in ['ClockDial','PocketWatchLid']:
        holes=[edge for edge in bm.edges if edge.is_boundary]
        if holes: bmesh.ops.holes_fill(bm,edges=holes,sides=0)
    bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.000001)
    bmesh.ops.dissolve_degenerate(bm,dist=.000001,edges=list(bm.edges))
    loose=[edge for edge in bm.edges if not edge.link_faces]
    if loose:bmesh.ops.delete(bm,geom=loose,context='EDGES')
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    topology[item.name]={'non_manifold_edges':sum(not e.is_manifold for e in bm.edges),
                         'faces':len(bm.faces)}
    bm.to_mesh(item.data);bm.free()

# Merge static parts into one mesh with three shared material roles.
static=[o for o in collection.objects if o.type=='MESH' and o.name not in ['HourHand','MinuteHand']]
bpy.ops.object.select_all(action='DESELECT')
for o in static:o.select_set(True)
bpy.context.view_layer.objects.active=bpy.data.objects['WatchCase']
bpy.ops.object.join()
body=bpy.context.object
body.name='ClockBody'
scene.camera.data.ortho_scale=.84
scene.objects['ClockKey'].data.energy=8
scene.objects['ClockFill'].data.energy=3.5
result={'stage':'original hero detail candidate; needs rendered review and Godot integration',
        'objects':[o.name for o in collection.objects], 'topology_before_join':topology,
        'triangle_estimate':sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in collection.objects if o.type=='MESH'),
        'source_angles_degrees':{'HourHand':335.5,'MinuteHand':66.0},
        'blockout_decision':'continue after framed-v2: full case/lid silhouette, support and12 hinge visible; refine lighting power in metre-scale scene'}
(dest/'hero-detail-report.json').write_text(json.dumps(result,indent=2))

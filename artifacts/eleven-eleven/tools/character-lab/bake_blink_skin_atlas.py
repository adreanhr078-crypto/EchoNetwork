"""Bake a small continuous skin-only albedo field from this source face.

No original image is edited. Only new connected eyelid faces use this atlas;
the original body material,UV and maps remain unchanged.
"""
import hashlib
import bpy
import numpy as np
from mathutils import Vector

def bake(out,original,world,source_uv,pixels,removed,rim_ids,welded_ids,
         eye_rings,positions,matrix_world,face_styles,faces,face_uvs,materials):
    samples=[]
    # Samples come from actual source skin immediately bordering the reviewed
    # cut. Geometry and color jointly exclude the painted eye and front hair.
    boundary_vertices=set(index for index,value in enumerate(welded_ids) if value in rim_ids)
    for polygon in original.polygons:
        if polygon.index in removed or not any(index in boundary_vertices for index in polygon.vertices):continue
        uv=sum((source_uv[index] for index in polygon.loop_indices),Vector((0,0)))/len(polygon.loop_indices)
        rgb=pixels[int(uv.y*(pixels.shape[0]-1))%pixels.shape[0],int(uv.x*(pixels.shape[1]-1))%pixels.shape[1],:3]
        if rgb[0]-rgb[2]<.012 or min(rgb)<.24 or max(rgb)>.96:continue
        center=sum((world[index] for index in polygon.vertices),Vector())/len(polygon.vertices)
        samples.append((center,np.asarray(rgb,dtype=np.float64)))
    assert len(samples)>12,'No verified skin sample field;do not fabricate facial color'
    width,height=512,256
    colors=np.ones((height,width,4),dtype=np.float32)
    islands={};counts={};gains={}
    for tile,(side,rings) in enumerate(eye_rings.items()):
        neutral=[matrix_world@positions[index] for ring in rings for index in ring]
        low=np.asarray([min(point.x for point in neutral),min(point.z for point in neutral)])-.001
        high=np.asarray([max(point.x for point in neutral),max(point.z for point in neutral)])+.001
        center=(low+high)*.5
        local=[row for row in samples if abs(row[0].x-center[0])<.04 and abs(row[0].z-center[1])<.04]
        assert len(local)>6,'Each eye requires its own real local skin samples'
        coordinates=np.asarray([[row[0].x,row[0].z] for row in local])
        rgb=np.asarray([row[1] for row in local]);counts[side]=len(local)
        # Explicit source sample bounds only normalize new UVs;they never select
        # or deform facial vertices. The semantic mesh-edge cut owns that scope.
        uu=np.linspace(0,1,256);vv=np.linspace(0,1,height)
        grid=np.stack(np.meshgrid(uu,vv),axis=-1).reshape(-1,2)
        queries=low+grid*(high-low)
        baked=np.empty((len(queries),3),dtype=np.float64)
        neighbors=min(8,len(local))
        for start in range(0,len(queries),1024):
            q=queries[start:start+1024]
            distances=np.sum((q[:,None,:]-coordinates[None,:,:])**2,axis=2)
            slots=np.argpartition(distances,neighbors-1,axis=1)[:,:neighbors]
            chosen=np.take_along_axis(distances,slots,axis=1)
            weights=1/np.maximum(chosen,.00035**2)**1.4
            baked[start:start+len(q)]=np.sum(rgb[slots]*weights[:,:,None],axis=1)/weights.sum(axis=1)[:,None]
        colors[:,tile*256:(tile+1)*256,:3]=baked.reshape(height,256,3)
        islands[side]=(tile,low,high)
    image=bpy.data.images.new('EchoBlink_LocalSkinAtlas',width=width,height=height,alpha=True,float_buffer=False)
    image.colorspace_settings.name='sRGB';image.pixels.foreach_set(colors.ravel());image.update()
    image.filepath_raw=str(out/'local-skin-albedo.png');image.file_format='PNG';image.save()
    image.pack()
    material=bpy.data.materials.new('EchoSkin_ConnectedBlinkAtlas');material.use_nodes=True
    shader=material.node_tree.nodes.get('Principled BSDF');shader.inputs['Roughness'].default_value=.62;shader.inputs['Metallic'].default_value=0
    node=material.node_tree.nodes.new('ShaderNodeTexImage');node.image=image;node.interpolation='Linear';node.extension='EXTEND'
    material.node_tree.links.new(node.outputs['Color'],shader.inputs['Base Color']);material.node_tree.nodes.active=node
    slot=len(original.materials)
    for face_id,(side,style) in face_styles.items():
        if style!='skin':continue
        tile,low,high=islands[side];uv=[]
        for index in faces[face_id]:
            point=matrix_world@positions[index];normalized=(np.asarray([point.x,point.z])-low)/(high-low)
            uv.append(Vector(((tile+float(normalized[0]))*.5,float(normalized[1]))))
        face_uvs[face_id]=uv;materials[face_id]=slot
    return material,{'status':'DERIVED_CONTINUOUS_SKIN_ALBEDO_BAKE_NOT_ART_ACCEPTANCE','size':[width,height],
                     'verified_local_samples':counts,'source_maps_edited':False,
                     'output_sha256':hashlib.sha256((out/'local-skin-albedo.png').read_bytes()).hexdigest(),
                     'material':'New connected skin faces only;original narrow outer rim and thin lash remain source mapped. New skin material has no emission and no borrowed tangent-space normal map.',
                     'method':'Local actual source skin bordering the reviewed cut -> continuous spatial albedo bake -> new eye UV islands. Painted ocular pixels/front hair are excluded.'}

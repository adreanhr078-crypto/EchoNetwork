import argparse, sys, bpy
parser=argparse.ArgumentParser(); parser.add_argument('--input',required=True); args=parser.parse_args(sys.argv[sys.argv.index('--')+1:])
bpy.ops.import_scene.gltf(filepath=args.input)
for obj in bpy.context.scene.objects:
    if obj.type=='ARMATURE':
        print('ARMATURE',obj.name)
        for bone in obj.data.bones:
            print('BONE',bone.name, 'PARENT', bone.parent.name if bone.parent else '')

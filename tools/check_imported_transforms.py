import bpy

props = [
    (r"C:\Users\yasmo\EchoNetwork\artifacts\eleven-eleven\art\production\tripo-20261007\standard-katana\tripo-out\standard-katana-20261007-f43b4b42\model.glb", "standard-katana"),
    (r"C:\Users\yasmo\EchoNetwork\artifacts\eleven-eleven\art\production\tripo-20261007\shadow-katana\tripo-out\shadow-katana-20261007-c9cae674\model.glb", "shadow-katana"),
    (r"C:\Users\yasmo\EchoNetwork\artifacts\eleven-eleven\art\production\tripo-20261007\diagnostic-cart\tripo-out\diagnostic-cart-20261007-787ef5a5\model.glb", "diagnostic-cart"),
    (r"C:\Users\yasmo\EchoNetwork\artifacts\eleven-eleven\art\production\tripo-20261007\security-terminal\tripo-out\security-terminal-20261007-df7cbe72\model.glb", "security-terminal"),
    (r"C:\Users\yasmo\EchoNetwork\artifacts\eleven-eleven\art\production\tripo-20261007\observation-server\tripo-out\observation-server-20261007-4cdb4008\model.glb", "observation-server"),
    (r"C:\Users\yasmo\EchoNetwork\artifacts\eleven-eleven\art\production\tripo-20261007\medical-wall-unit\tripo-out\medical-wall-unit-20261007-5affa583\model.glb", "medical-wall-unit")
]

for p, n in props:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=p)
    print(f"\n{n}:")
    for obj in bpy.context.scene.objects:
        print(f"  Obj: {obj.name}, type: {obj.type}, loc: {obj.location}, rot: {obj.rotation_euler}, scale: {obj.scale}")

bpy.ops.wm.quit_blender()

import os
import shutil

props_dir = r"C:\Users\yasmo\EchoNetwork\artifacts\eleven-eleven\godot\assets\props"
ids = [
    'standard-katana',
    'shadow-katana',
    'diagnostic-cart',
    'security-terminal',
    'observation-server',
    'medical-wall-unit'
]

for aid in ids:
    hyphen_name = f"{aid}_tripo_20261008.glb"
    underscore_name = f"{aid.replace('-', '_')}_tripo_20261008.glb"
    src = os.path.join(props_dir, hyphen_name)
    dst = os.path.join(props_dir, underscore_name)
    if os.path.exists(src):
        shutil.copyfile(src, dst)
        print(f"Copied {hyphen_name} -> {underscore_name}")

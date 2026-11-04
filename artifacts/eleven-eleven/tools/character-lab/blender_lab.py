"""Run the installed Blender with the project's isolated character-lab profile."""
from pathlib import Path
import os
import subprocess
import sys

app = Path(__file__).resolve().parents[2]
profile = app/'.tmp/echo-character-lab/blender-profile'
env = os.environ.copy()
env['BLENDER_USER_RESOURCES'] = str(profile)
for key, directory in [('CONFIG','config'),('SCRIPTS','scripts'),
                       ('EXTENSIONS','extensions'),('DATAFILES','datafiles')]:
    path = profile/directory
    path.mkdir(parents=True,exist_ok=True)
    env['BLENDER_USER_'+key] = str(path)
blender = Path('C:/Tools/Blender-5.2.2-portable/blender-5.2.2-windows-x64/blender.exe')
raise SystemExit(subprocess.call([str(blender),'--python-exit-code','1',*sys.argv[1:]],env=env,cwd=app))

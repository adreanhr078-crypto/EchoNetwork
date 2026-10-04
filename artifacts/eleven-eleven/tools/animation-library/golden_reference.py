"""Seal the Owner-approved Walk bytes once; verify them before every new fixture."""
import argparse
import ast
import hashlib
import json
from pathlib import Path
import shutil

APP = Path(__file__).resolve().parents[2]
ROOT = APP/'art/production/master-animation-library/golden/walk-v1'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def verify():
    manifest = ROOT/'GoldenReference.json'
    expected = (ROOT/'GoldenReference.sha256').read_text().strip()
    if sha(manifest) != expected:
        raise ValueError('Golden manifest changed')
    data = json.loads(manifest.read_text(encoding='utf-8'))
    for section in ['protected_files','snapshot_files']:
        for relative,digest in data[section].items():
            if sha(APP/relative) != digest:
                raise ValueError('Golden reference changed: '+relative)
    return data


def guard_output(path):
    path = path.resolve()
    original = APP/'audits/evidence/single-walk-20260930'
    if path == original or original in path.parents or path == ROOT or ROOT in path.parents:
        raise ValueError('Cannot write a new motion into the Golden Walk')
    if APP not in path.parents:
        raise ValueError('Review output must stay inside this application')


def assert_transfer_equal(path):
    """Source identity/timing may differ; the evaluated transfer body may not."""
    def body(script):
        tree = ast.parse(script.read_text(encoding='utf-8'))
        loops = [node for node in ast.walk(tree) if isinstance(node,ast.For)
                 and ast.unparse(node.target) == '(i, pose)'
                 and ast.unparse(node.iter) == 'enumerate(poses)']
        if len(loops) != 1:
            raise ValueError('Transfer loop missing or ambiguous')
        return ast.dump(loops[0],include_attributes=False)
    if body(path) != body(ROOT/'tools/single_walk.py'):
        raise ValueError('Transfer differs from the Golden pipeline')
    def upstream(script):
        tree = ast.parse(script.read_text(encoding='utf-8'))
        names = {'(sm, tm)','common','required','(sw, tw)','sr','tr','forward','yaw','align','leg_length','ratio'}
        nodes = [node for node in ast.walk(tree) if isinstance(node,ast.Assign)
                 and ast.unparse(node.targets[0]) in names]
        angle_function = [node for node in tree.body if isinstance(node,ast.FunctionDef) and node.name == 'angle']
        exports = [node for node in ast.walk(tree) if isinstance(node,ast.Call)
                   and ast.unparse(node.func) == 'bpy.ops.export_scene.gltf']
        for call in exports:
            call.keywords = [keyword for keyword in call.keywords if keyword.arg != 'filepath']
        return [ast.dump(node,include_attributes=False) for node in [*nodes,*angle_function,*exports]]
    if upstream(path) != upstream(ROOT/'tools/single_walk.py'):
        raise ValueError('Rest/alignment/export math differs from the Golden pipeline')


def seal():
    if ROOT.exists():
        verify()
        raise ValueError('Golden already sealed; resealing is prohibited')
    evidence = APP/'audits/evidence/single-walk-20260930'
    ref = json.loads((evidence/'blender-reference.json').read_text())
    visual = json.loads((evidence/'blender-visual-review.json').read_text())
    godot = json.loads((evidence/'godot-lossless-review.json').read_text())
    if ref['status'] != 'PASS' or godot['status'] != 'PASS' or sha(evidence/'single-walk.blend') != visual['blend_sha256']:
        raise ValueError('Existing Walk acceptance evidence is invalid')
    tools = ['single_walk.py','single_walk.gd','retarget_contract.py','bone_roles.py','configure_review_import.gd']
    protected = {str(p.relative_to(APP)).replace('\\','/'):sha(p) for p in evidence.rglob('*') if p.is_file()}
    for name in tools:
        p = APP/'tools/animation-library'/name
        protected[str(p.relative_to(APP)).replace('\\','/')] = sha(p)
    for path,digest in ref['hashes'].items():
        p = Path(path)
        if sha(p) != digest:
            raise ValueError('Golden original source changed')
        protected[str(p.relative_to(APP)).replace('\\','/')] = digest
    ROOT.mkdir(parents=True)
    copies = {evidence/name:ROOT/name for name in ['single-walk.blend','single-walk.glb','blender-reference.json',
              'diagnosis.json','blender-visual-review.json','godot-lossless-review.json','godot-lossless-import.cfg','export-check.json']}
    copies.update({APP/'tools/animation-library'/name:ROOT/'tools'/name for name in tools})
    for source,destination in copies.items():
        destination.parent.mkdir(exist_ok=True)
        shutil.copy2(source,destination)
    data = {'schema_version':1,'status':'OWNER_APPROVED_GOLDEN_REFERENCE','owner_approved_date':'2026-09-30',
            'animation':'MOB1_Walk_F','take_id':'d72ede82bef3da0a88a96c36:0:fd47e298',
            'target_sha256':'62db579a81296122f293fe0c5a6290ef0b06dfc430e31c9a1d7861cf3e1b6ef1',
            'blender_version':'5.2.2','godot_version':'4.7.2','runtime_integrated':False,
            'restrictions':['no Walk regeneration/improvement/source edits','no Skeleton Retarget/Root Motion/player changes',
                            'no AnimationTree/blending during verification','one motion at a time'],
            'protected_files':protected,'snapshot_files':{str(p.relative_to(APP)).replace('\\','/'):sha(p) for p in copies.values()}}
    manifest = ROOT/'GoldenReference.json'
    manifest.write_text(json.dumps(data,indent=2)+'\n',encoding='utf-8')
    (ROOT/'GoldenReference.sha256').write_text(sha(manifest)+'\n',encoding='utf-8')
    verify()


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--seal',action='store_true')
    args = parser.parse_args()
    if args.seal:
        seal()
    data = verify()
    print(json.dumps({'status':'PASS','golden_status':data['status'],'protected_files':len(data['protected_files'])}))

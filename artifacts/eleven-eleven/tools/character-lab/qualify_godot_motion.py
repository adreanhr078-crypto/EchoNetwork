"""Run the existing frozen Godot reviewer in a content-addressed isolated project."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess

APP = Path(__file__).resolve().parents[2]
GODOT = Path('C:/Tools/Godot-4.8-dev7/Godot_v4.8-dev7_win64_console.exe')
DRIVERS = APP/'tools/animation-library'


def sha(path):
    with path.open('rb') as handle:
        return hashlib.file_digest(handle,'sha256').hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--case',type=Path,required=True)
    parser.add_argument('--render',action='store_true')
    parser.add_argument('--mesh-bounds',action='store_true',help='Frame the actual evaluated skin,including wing feather extremities')
    args = parser.parse_args()
    case = args.case.resolve(strict=True)
    if '/golden/' in case.as_posix().lower():
        raise ValueError('Never reopen the frozen reference')
    source = case/'single-motion.glb'
    reference = case/'blender-reference.json'
    visual = json.loads((case/'blender-visual-review.json').read_text(encoding='utf-8'))
    if visual['status'] != 'PASS' or visual['blend_sha256'] != sha(case/'single-motion.blend'):
        raise ValueError('Exact saved Blender visual gate required')
    data = json.loads(reference.read_text(encoding='utf-8'))
    if data['status'] != 'PASS' or any(sha(Path(p)) != h for p,h in data['hashes'].items()):
        raise ValueError('Blender numerical gate or input identity changed')
    identity = sha(source)
    provenance_path = case/'godot-qualification-provenance.json'
    prior = json.loads(provenance_path.read_text(encoding='utf-8')) if provenance_path.exists() else {}
    project = APP/'.tmp/echo-character-lab/cases'/f'{case.name}-{identity[:12]}-godot'
    project.mkdir(parents=True,exist_ok=True)
    shutil.copy2(source,project/'candidate.glb')
    config = project/'project.godot'
    config.write_text('config_version=5\n[application]\nconfig/name="Isolated source fidelity"\n'
                      '[display]\nwindow/size/viewport_width=480\nwindow/size/viewport_height=640\n'
                      '[rendering]\nrenderer/rendering_method="gl_compatibility"\n',encoding='utf-8')

    def run(name,arguments):
        log = project/(name+'.log')
        with log.open('w',encoding='utf-8') as handle:
            timeout = max(120,45+len(data['samples'])*.8) if name == 'review' and args.render else 120
            result = subprocess.run([str(GODOT),*arguments],cwd=APP,
                                    stdout=handle,stderr=subprocess.STDOUT,timeout=timeout)
        text = log.read_text(encoding='utf-8',errors='replace')
        if result.returncode or 'SCRIPT ERROR:' in text or 'ERROR:' in text:
            raise RuntimeError(f'{name} failed: {log}\n{text[-1200:]}')

    base = ['--headless','--path',str(project)]
    run('import',['--headless','--editor','--path',str(project),'--import'])
    run('profile',base+['--script',str(DRIVERS/'configure_review_import.gd'),'--','res://candidate.glb'])
    native_profile = None
    if data.get('fps') != 30:
        provenance = json.loads((case/'native-adapter-provenance.json').read_text(encoding='utf-8'))
        if data.get('fps') != 24 or provenance.get('native_fps') != 24 or provenance.get('source_keys_changed') is not False:
            raise ValueError('Non30Hz import requires independently validated native clock provenance')
        native_profile = Path(__file__).with_name('configure_native_clock.gd')
        run('native-clock',base+['--script',str(native_profile),'--','res://candidate.glb',str(reference)])
    run('reimport',['--headless','--editor','--path',str(project),'--import'])
    output = case/'godot-review.json'
    reviewer = DRIVERS/'single_motion.gd'
    if args.render:
        code = reviewer.read_text(encoding='utf-8')
        original = '\t\t\t\tvar center := skeleton.to_global(skeleton.get_bone_global_pose(hips).origin)\n\t\t\t\tcenter.y = 0.9'
        framed = '''\t\t\t\tvar low := Vector3(INF,INF,INF)
\t\t\t\tvar high := Vector3(-INF,-INF,-INF)
\t\t\t\tfor bone in skeleton.get_bone_count():
\t\t\t\t\tvar point := skeleton.to_global(skeleton.get_bone_global_pose(bone).origin)
\t\t\t\t\tlow = low.min(point)
\t\t\t\t\thigh = high.max(point)
\t\t\t\tvar center := (low+high)*0.5
\t\t\t\tvar width := high.x-low.x if view == "back" else high.z-low.z
\t\t\t\tcamera.size = maxf(high.y-low.y+0.30,(width+0.30)/(480.0/640.0))'''
        if code.count(original) != 1:
            raise ValueError('Frozen render framing changed; inspect before adapting camera')
        reviewer = project/'framed_review.gd'
        code=code.replace(original,framed)
        if args.mesh_bounds:
            anchor='\t\t\t\tvar center := (low+high)*0.5'
            bounded='''\t\t\t\tawait RenderingServer.frame_post_draw
\t\t\t\tfor visible_mesh in model.find_children("*","MeshInstance3D",true,false):
\t\t\t\t\tif not visible_mesh.skin: continue
\t\t\t\t\tvar baked_skin: ArrayMesh = visible_mesh.bake_mesh_from_current_skeleton_pose()
\t\t\t\t\tvar bounds: AABB = baked_skin.get_aabb()
\t\t\t\t\tfor corner in 8:
\t\t\t\t\t\tvar point: Vector3 = visible_mesh.global_transform*bounds.get_endpoint(corner)
\t\t\t\t\t\tlow=low.min(point)
\t\t\t\t\t\thigh=high.max(point)
'''
            if code.count(anchor)!=1:raise ValueError('Skin framing anchor changed')
            code=code.replace(anchor,bounded+anchor)
        render_clock='player.seek(float(frame)/30,true)'
        if code.count(render_clock)!=1:
            raise ValueError('Render sampling changed;inspect native clock first')
        code=code.replace(render_clock,'player.seek(float(reference.samples[frame].time),true)')
        reviewer.write_text(code,encoding='utf-8')
    arguments = ['--path',str(project),'--script',str(reviewer),'--',
                 'res://candidate.glb',str(reference),str(output)]
    run('review',(['--rendering-method','gl_compatibility','--resolution','480x640'] if args.render else ['--headless'])
        +arguments+(['--render'] if args.render else []))
    report = json.loads(output.read_text(encoding='utf-8'))
    if report['status'] != 'PASS' or sha(source) != identity:
        raise ValueError('Godot fidelity failed or source changed')
    provenance = {
        'source_sha256':identity,'blender_reference_sha256':sha(reference),
        'reviewer_sha256':sha(reviewer),'frozen_numeric_reviewer_sha256':sha(DRIVERS/'single_motion.gd'),
        'render_adaptation':'Camera bounds and reference-native render times; entire numerical evaluation remains verbatim',
        'profile_sha256':sha(DRIVERS/'configure_review_import.gd'),
        'native_clock_profile_sha256':sha(native_profile) if native_profile else None,
        'native_fps':data['fps'],
        'project':str(project),'rendered':args.render,
        'renderer':'Compatibility' if args.render else 'headless',
        'visual_status':'CAPTURED_PENDING_ACTUAL_REVIEW' if args.render else 'UNVERIFIED'}
    provenance['evaluated_skin_bounds']=args.mesh_bounds
    if not args.render and prior.get('rendered') and str(prior.get('visual_status','')).startswith('PASS') \
            and prior.get('source_sha256') == identity and prior.get('blender_reference_sha256') == sha(reference):
        provenance.update({key:value for key,value in prior.items() if key.startswith('visual_')})
        provenance['rendered'] = True
        provenance['renderer'] = prior['renderer']
        provenance['visual_reused_after_hash_match'] = True
    provenance_path.write_text(json.dumps(provenance,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({k:report[k] for k in ['status','sample_count','max_position_error_m','max_rotation_error_degrees']}))


if __name__ == '__main__':
    main()

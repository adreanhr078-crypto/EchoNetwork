"""Resume all inspected forward-walk comparisons; never approve/publish a clip."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write(path, value):
    temporary = path.with_suffix('.partial')
    temporary.write_text(json.dumps(value, indent=2, ensure_ascii=False)+'\n', encoding='utf-8')
    temporary.replace(path)


def reusable_fingerprint(previous, current):
    """A diagnostic change needs remeasurement, not a fresh mocap bake."""
    def baking_contract(value):
        return {**value, 'tool_hashes':{name:checksum for name,checksum in value.get('tool_hashes',{}).items()
                                      if name != 'review_skin.py'}}
    return baking_contract(previous) == baking_contract(current)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--blender', required=True)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--render', action='store_true')
    parser.add_argument('--batch-name', default='walk-comparison-v3')
    args = parser.parse_args()
    app = Path.cwd()
    tools = app/'tools/animation-library'
    manifests = app/'art/production/master-animation-library/manifests'
    if not args.batch_name.replace('-','').isalnum():
        raise ValueError('Batch name must be letters, digits and hyphens')
    staging = app/'art/production/master-animation-library/staging'/args.batch_name
    project = app/'.tmp/master-animation-library'/args.batch_name
    staging.mkdir(parents=True, exist_ok=True)
    project.mkdir(parents=True, exist_ok=True)
    (project/'project.godot').write_text('config_version=5\n[application]\nconfig/name="Walk comparison"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n', encoding='utf-8')
    for name in ['configure_review_import.gd', 'review_contacts.gd']:
        shutil.copy2(tools/name, project/name)
    inventory = json.loads((manifests/'SourceInventory.json').read_text(encoding='utf-8'))['files']
    candidates = json.loads((manifests/'CandidateReviews.json').read_text(encoding='utf-8'))['candidates']
    groups = {}
    for candidate in candidates:
        if candidate.get('proposed_action_id') == 'walk_forward':
            groups.setdefault(candidate['take_id'], []).append(candidate)
    target = app/'art/production/echo-master-character/prepared-v1/echo-master-review-lod.glb'
    tool_hashes = {name:digest(tools/name) for name in ['retarget_contacts.py','retarget_contract.py','review_contacts.gd','configure_review_import.gd','review_skin.py']}
    results = []
    report = {'status':'IN_PROGRESS', 'canonical_approvals':0, 'candidate_records':sum(map(len,groups.values())),
              'unique_takes':len(groups), 'target_sha256':digest(target), 'tool_hashes':tool_hashes, 'results':results}
    report_path = manifests/'WalkComparison.json'

    def run(command, log, timeout=300):
        environment = os.environ.copy()
        environment['BLENDER_USER_RESOURCES'] = str(project/'blender-user')
        for suffix in ['CONFIG','SCRIPTS','EXTENSIONS','DATAFILES']:
            environment['BLENDER_USER_'+suffix] = str(project/'blender-user'/suffix.lower())
        with log.open('w', encoding='utf-8') as stream:
            process = subprocess.Popen(list(map(str,command)), stdout=stream, stderr=subprocess.STDOUT,
                                       env=environment, creationflags=subprocess.CREATE_NO_WINDOW)
            try:
                returncode = process.wait(timeout=timeout)
            except subprocess.TimeoutExpired:
                subprocess.run(['taskkill','/PID',str(process.pid),'/T','/F'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
                process.wait()
                raise
        if returncode:
            raise RuntimeError(f'{log.name}: process exit {returncode}')

    def godot(*arguments):
        return [args.godot, '--path', project, *arguments]

    for take_id, records in groups.items():
        candidate = records[0]
        source_info = next(item for item in inventory if item['sha256']==candidate['file_sha256'])
        source = app/source_info['working_copy']
        slug = candidate['file_sha256'][:12]
        output = staging/(slug+'.glb')
        evidence = project/slug
        evidence.mkdir(exist_ok=True)
        fingerprint = {'source_sha256':candidate['file_sha256'], 'take_id':take_id,
                       'target_sha256':report['target_sha256'], 'tool_hashes':tool_hashes}
        entry = {'take_id':take_id, 'filename':candidate['original_filename'],
                 'source_ids':[r['source_id'] for r in records], 'source_pack':candidate['source_pack'],
                 'license_status':source_info['license_status'], 'fingerprint':fingerprint,
                 'derivative':str(output.relative_to(app)).replace('\\','/'), 'status':'PENDING'}
        try:
            if digest(source) != candidate['file_sha256']:
                raise ValueError('Working source no longer matches protected inventory')
            cache = evidence/'comparison.json'
            previous = json.loads(cache.read_text(encoding='utf-8')) if cache.exists() else {}
            if reusable_fingerprint(previous.get('fingerprint',{}),fingerprint) and previous.get('status')=='MEASURED' and output.exists() and previous.get('derivative_sha256')==digest(output) and (not args.render or previous.get('rendered')):
                entry = previous
                if previous['fingerprint']['tool_hashes'].get('review_skin.py') != tool_hashes['review_skin.py']:
                    run([args.blender,'--factory-startup','--offline-mode','--background','--python-exit-code','1',
                         '--python',tools/'review_skin.py','--','--clip',output,'--output',evidence/'skin-review.json'], evidence/'skin.log')
                    entry['skin_review'] = json.loads((evidence/'skin-review.json').read_text(encoding='utf-8'))
                    entry['fingerprint'] = fingerprint
                    write(cache,entry)
            else:
                run([args.blender,'--factory-startup','--offline-mode','--background','--python-exit-code','1','--python',tools/'retarget_contacts.py','--',
                     '--source',source,'--target',target,'--output',output,'--action','Walk_Forward',
                     '--source-take',candidate['source_take'],'--source-rig',candidate['rig']], evidence/'retarget.log')
                sidecar = json.loads(output.with_suffix('.json').read_text(encoding='utf-8'))
                if abs(sidecar['duration_seconds']-candidate['duration_seconds']) > 1/30:
                    raise ValueError('Retargeted take timing differs from inspected source')
                run([args.blender,'--factory-startup','--offline-mode','--background','--python-exit-code','1',
                     '--python',tools/'review_skin.py','--','--clip',output,'--output',evidence/'skin-review.json'], evidence/'skin.log')
                entry['skin_review'] = json.loads((evidence/'skin-review.json').read_text(encoding='utf-8'))
                shutil.copy2(output, project/output.name)
                run(godot('--headless','--editor','--import'), evidence/'import.log')
                run(godot('--headless','--script','res://configure_review_import.gd','--','res://'+output.name), evidence/'profile.log')
                run(godot('--headless','--editor','--import'), evidence/'reimport.log')
                run(godot('--headless','--script','res://review_contacts.gd','--','res://'+output.name, output.with_suffix('.json'), evidence), evidence/'headless.log')
                entry['import_review'] = json.loads((evidence/'godot-contact-review.json').read_text(encoding='utf-8'))
                if args.render:
                    run(godot('--resolution','1280x720','--script','res://review_contacts.gd','--','res://'+output.name, output.with_suffix('.json'), evidence, '9'), evidence/'render.log')
                entry.update(status='MEASURED', rendered=args.render, derivative_sha256=digest(output),
                             duration_seconds=sidecar['duration_seconds'], transport_speed_mps=sidecar['transport_speed_mps'],
                             root_mode=sidecar['root_mode'], max_unreachable_error_m=sidecar['max_unreachable_error_m'],
                             contact_intervals=sidecar['contact_intervals'])
                entry['evidence_directory'] = str(evidence.relative_to(app)).replace('\\','/')
                entry['visual_status'] = 'PENDING'
                write(cache, entry)
        except (RuntimeError, ValueError, subprocess.TimeoutExpired) as error:
            entry.update(status='FAILED', error=str(error))
        results.append(entry)
        write(report_path, report)
        print(json.dumps({key:entry.get(key) for key in ['filename','take_id','status','error','transport_speed_mps']},ensure_ascii=True),flush=True)
    report['status'] = 'MEASURED' if all(item['status']=='MEASURED' for item in results) else 'INCOMPLETE'
    report['limits'] = 'Measurements and staged visual evidence only; skin, loops, rights, facial/finger rig and player integration remain separate gates.'
    write(report_path, report)
    return 0 if report['status']=='MEASURED' else 1


if __name__ == '__main__':
    raise SystemExit(main())

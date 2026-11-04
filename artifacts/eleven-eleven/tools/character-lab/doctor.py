"""Reusable offline character intake and environment check. Python standard library only.

Writes only to the dedicated .tmp/echo-character-lab workspace. No downloads,
retarget, mesh deformation, animation edits, installation or runtime changes.
"""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import math
from pathlib import Path
import shutil
import statistics
import struct
import subprocess
import sys

APP = Path(__file__).resolve().parents[2]
SOURCE = APP / 'art/production/echo-school-rebuild-20261029'
LAB = APP / '.tmp/echo-character-lab'
TOOLS = Path(__file__).resolve().parent


def write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


def digest(path):
    with path.open('rb') as handle:
        return hashlib.file_digest(handle, 'sha256').hexdigest()


def glb_summary(path):
    sha = digest(path)  # Cache validity depends on content, not filename/mtime.
    parser_hash = digest(Path(__file__))[:16]
    cache = LAB / 'cache' / (sha + '-' + parser_hash + '.json')
    if cache.exists():
        value = json.loads(cache.read_text(encoding='utf-8'))
        value['cache_hit'] = True
        return value
    raw = path.read_bytes()
    if len(raw) < 20 or struct.unpack_from('<4sII', raw) != (b'glTF', 2, len(raw)):
        raise ValueError('Invalid GLB header: ' + str(path))
    offset, doc, binary = 12, None, None
    while offset < len(raw):
        length, kind = struct.unpack_from('<II', raw, offset)
        payload = raw[offset + 8:offset + 8 + length]
        if len(payload) != length:
            raise ValueError('Truncated GLB chunk')
        if kind == 0x4e4f534a:
            doc = json.loads(payload)
        elif kind == 0x004e4942:
            binary = payload
        offset += length + 8
    if doc is None or offset != len(raw):
        raise ValueError('Invalid GLB chunks')
    animations = []
    for animation in doc.get('animations', []):
        clocks = []
        for index in sorted({s['input'] for s in animation.get('samplers', [])}):
            accessor = doc['accessors'][index]
            if accessor['type'] != 'SCALAR' or accessor['componentType'] != 5126 or accessor.get('sparse'):
                raise ValueError('Unsupported native animation clock')
            view = doc['bufferViews'][accessor['bufferView']]
            if binary is None or view.get('buffer', 0) != 0:
                raise ValueError('External animation clock not supported')
            start = view.get('byteOffset', 0) + accessor.get('byteOffset', 0)
            stride = view.get('byteStride', 4)
            times = [struct.unpack_from('<f', binary, start + i * stride)[0]
                     for i in range(accessor['count'])]
            if not times or not all(math.isfinite(t) for t in times):
                raise ValueError('Empty or nonfinite animation clock')
            steps = [b - a for a, b in zip(times, times[1:])]
            if any(step <= 0 for step in steps):
                raise ValueError('Non-monotonic animation clock')
            median = statistics.median(steps) if steps else None
            clocks.append({'samples': len(times), 'first_s': times[0], 'last_s': times[-1],
                           'observed_sample_hz': round(1 / median, 4) if median else None,
                           'uniform': all(abs(step - median) < 0.00001 for step in steps)})
        animations.append({'name': animation.get('name'), 'native_clocks': clocks,
                           'channels': len(animation.get('channels', []))})
    value = {'sha256': sha, 'bytes': len(raw),
             'skin_joint_counts': [len(s['joints']) for s in doc.get('skins', [])],
             'morph_targets': max((len(p.get('targets', [])) for m in doc.get('meshes', [])
                                   for p in m['primitives']), default=0),
             'animations': animations, 'cache_hit': False,
             'scope': 'Metadata and original clocks only; not retarget/visual acceptance'}
    write(cache, value)
    return value


def resolve_tool(override, default, command):
    candidate = override or (str(default) if default.is_file() else shutil.which(command))
    if not candidate or not Path(candidate).is_file():
        return None
    return str(Path(candidate).resolve())


def run(command, log, timeout):
    with log.open('w', encoding='utf-8') as handle:
        result = subprocess.run(command, cwd=APP, stdout=handle, stderr=subprocess.STDOUT,
                                timeout=timeout, check=False)
    if result.returncode:
        raise RuntimeError('Probe failed; see ' + str(log))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--probe', action='store_true', help='Run isolated Blender and Godot checks')
    parser.add_argument('--blender')
    parser.add_argument('--godot')
    args = parser.parse_args()
    for folder in ['raw_tripo', 'templates', 'processed_characters', 'audio', 'lipsync_data',
                   'cache', 'cases', 'logs', 'godot', 'blender-profile']:
        (LAB / folder).mkdir(parents=True, exist_ok=True)
    project = LAB / 'godot/project.godot'
    if not project.exists():
        project.write_text('config_version=5\n[application]\nconfig/name="Echo Character Lab"\n'
                           '[rendering]\nrenderer/rendering_method="gl_compatibility"\n', encoding='utf-8')
    blender = resolve_tool(args.blender, Path('C:/Tools/Blender-5.2.2-portable/blender-5.2.2-windows-x64/blender.exe'), 'blender')
    godot = resolve_tool(args.godot, Path('C:/Tools/Godot-4.8-dev7/Godot_v4.8-dev7_win64_console.exe'), 'godot')
    sources = {'school_target': SOURCE / 'source/echo-school-rig-metric.glb',
               'tripo_boxing': SOURCE / 'motions/tripo-boxing/source.glb'}
    for motion in ['run', 'idle', 'jump']:
        sources[motion] = SOURCE / 'motions' / motion / 'single-motion.glb'
    report = {'schema_version': 1, 'updated_utc': datetime.now(timezone.utc).isoformat(),
              'status': 'PASS_INTAKE_ONLY', 'workspace': str(LAB),
              'tools': {'python': sys.executable, 'blender': blender, 'godot': godot,
                        'ffmpeg': shutil.which('ffmpeg'), 'rhubarb': shutil.which('rhubarb')},
              'assets': {}, 'missing': [], 'rooms': [],
              'runtime_integration': False, 'art_and_gameplay_acceptance': 'UNVERIFIED'}
    for name, path in sources.items():
        if path.is_file():
            report['assets'][name] = {'path': str(path.relative_to(APP)), **glb_summary(path)}
        else:
            report['missing'].append(str(path.relative_to(APP)))
    inventory = json.loads((APP / 'docs/internal/production/ROOM_QUALITY_INVENTORY.json').read_text(encoding='utf-8-sig'))
    for room in inventory['rooms']:
        path = APP / room['current_source']
        capture = APP / room['capture']
        source_match = path.is_file() and digest(path) == room['current_source_sha256'].lower()
        capture_match = capture.is_file() and digest(capture) == room['capture_sha256'].lower()
        report['rooms'].append({'room': room['room'], 'status_recorded': room['status'],
                                'source_matches_record': source_match,
                                'capture_matches_record': capture_match,
                                'fresh_visual_review': False, 'full_acceptance': 'OPEN'})
    if args.probe:
        if not blender or not godot:
            raise RuntimeError('Both Blender and Godot are required for --probe')
        blend = SOURCE / 'source/echo-school-rig-metric.blend'
        before = digest(blend)
        run([godot, '--headless', '--path', str(project.parent), '--script',
             str(TOOLS / 'api_probe.gd'), '--', str(LAB / 'godot-api.json')],
            LAB / 'logs/godot-api.log', 90)
        run([blender, '--background', '--factory-startup', '--disable-autoexec', '--offline-mode',
             '--python-exit-code', '1', '--python', str(TOOLS / 'inspect_blender.py'), '--',
             '--source', str(blend), '--output', str(LAB / 'blender-inspection.json')],
            LAB / 'logs/blender-inspection.log', 120)
        if digest(blend) != before:
            raise RuntimeError('Source .blend changed')
        report['probe_reports'] = ['godot-api.json', 'blender-inspection.json']
    report['status'] = 'FAIL_MISSING_INPUT' if report['missing'] else 'PASS_INTAKE_ONLY'
    write(LAB / 'intake.json', report)
    print(json.dumps({'status': report['status'], 'assets': len(report['assets']),
                      'cache_hits': sum(v['cache_hit'] for v in report['assets'].values()),
                      'rooms_source_match': sum(v['source_matches_record'] for v in report['rooms']),
                      'rooms_capture_match': sum(v['capture_matches_record'] for v in report['rooms']),
                      'report': str(LAB / 'intake.json')}))
    return 1 if report['missing'] else 0


if __name__ == '__main__':
    raise SystemExit(main())

"""Read-only Git index inventory and source-tree hygiene check. No deletes or moves."""
from pathlib import Path
import argparse
import collections
import json
import subprocess

ROOT = Path(__file__).resolve().parents[2]
BUILD_SUFFIXES = {'.exe', '.pck', '.apk', '.aab', '.msix', '.msixbundle'}

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    raw = subprocess.check_output(['git', 'ls-files', '-z'], cwd=ROOT)
    paths = [p.decode('utf-8') for p in raw.split(b'\0') if p]
    groups = collections.Counter()
    violations = []
    for path in paths:
        parts = path.split('/')
        group = '/'.join(parts[:3]) if path.startswith('artifacts/eleven-eleven/') else parts[0]
        groups[group] += 1
        cache = any(p in {'__pycache__', '.godot', 'node_modules', 'app_userdata'} for p in parts)
        review_build = path.startswith('artifacts/eleven-eleven/audits/evidence/') and Path(path).suffix.lower() in BUILD_SUFFIXES
        if cache or path.endswith('.pyc') or review_build:
            violations.append(path)
    print(json.dumps({'tracked_files': len(paths), 'groups': dict(groups.most_common()),
                      'tracked_generated_violations': violations}, ensure_ascii=True, indent=2))
    return 1 if args.check and violations else 0

if __name__ == '__main__':
    raise SystemExit(main())

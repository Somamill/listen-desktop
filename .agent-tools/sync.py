"""Verify reviewed neutral documentation; never fetch or execute helper scripts."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--update', action='store_true', help='Verify the same approved pin; never adopt unreviewed revisions')
    parser.add_argument('--shared-checkout', type=Path, help='Optionally verify an existing authorized neutral tooling checkout')
    args = parser.parse_args()
    root = Path(__file__).resolve().parent / 'requirements'
    source = json.loads((root / 'source.json').read_text())
    if source.get('schemaVersion') != 1 or source.get('repository') != 'Somamill/mac-development-tools':
        raise ValueError('Unexpected technical provenance')
    revision = source.get('commit', '')
    if not re.fullmatch(r'[0-9a-f]{40}', revision):
        raise ValueError('A reviewed full commit SHA is required')
    local = source.get('localFiles', {})
    if set(local) != {'AGENT_DEVELOPMENT.md', 'TOOL_CATALOG.md'}:
        raise ValueError('Unexpected local documentation manifest')
    for name, expected in local.items():
        path = root / name
        if path.is_symlink() or hashlib.sha256(path.read_bytes()).hexdigest() != expected:
            raise ValueError('Local documentation differs from its reviewed provenance: ' + name)
    if args.shared_checkout:
        head = subprocess.check_output(['git', '-C', str(args.shared_checkout), 'rev-parse', 'HEAD'], text=True).strip()
        if head != revision:
            raise ValueError('Shared checkout is not at the reviewed revision')
        for name, expected in source['upstreamFiles'].items():
            if name not in {'README.md', 'runner.py', 'install-agent.py', 'artifact-manifest.py'}:
                raise ValueError('Unexpected shared reference')
            data = subprocess.check_output(['git', '-C', str(args.shared_checkout), 'show', revision + ':' + name])
            if hashlib.sha256(data).hexdigest() != expected:
                raise ValueError('Shared source hash mismatch: ' + name)
        print('Verified optional existing shared checkout; no helper executed.')
    else:
        print('Shared source access is optional; upstream checkout not rechecked.')
    print('Verified independent desktop requirements and neutral shared tooling at ' + revision)
    print('No executable download, service installation, queue job, signing or brand membership change.')


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, KeyError) as error:
        raise SystemExit('Requirements verification failed: ' + str(error))

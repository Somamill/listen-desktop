"""Copy a checked-out public brand kit; only branding/dot is managed."""
import hashlib
import json
import pathlib
import shutil
import subprocess
import sys

if len(sys.argv) != 2:
    raise SystemExit('Usage: sync-dot-brand.py /path/to/reviewed-brand-kit-checkout')
source = pathlib.Path(sys.argv[1]).resolve()
root = pathlib.Path(subprocess.check_output(
    ['git', '-C', str(source), 'rev-parse', '--show-toplevel'], text=True).strip()).resolve()
if source != root:
    raise ValueError('Source must be the brand-kit repository root')
if subprocess.check_output(['git', '-C', str(source), 'status', '--porcelain',
                            '--untracked-files=all', '--ignored', '--', 'kit'], text=True):
    raise ValueError('Commit or discard kit changes before syncing; source.json must identify exact committed files')
repo = pathlib.Path(__file__).resolve().parents[1]
sha = subprocess.check_output(['git', '-C', str(source), 'rev-parse', 'HEAD'], text=True).strip()
kit = source / 'kit'
# Validate before replacing the managed snapshot, including under python -O.
files = sorted(p for p in kit.rglob('*') if p.is_file())
if not files or kit.is_symlink() or any(p.is_symlink() for p in kit.rglob('*')):
    raise ValueError('Kit must contain regular files, without symlinks')
if not all(p.suffix in {'.json', '.svg', '.md', '.css', '.ts', '.py'} or p.name == 'LICENSE' for p in files):
    raise ValueError('Unexpected file type in kit')
if sum(p.stat().st_size for p in files) >= 2_000_000:
    raise ValueError('Kit exceeds the snapshot size limit')
manifest = {'repository': 'Somamill/dot-brand-kit', 'commit': sha,
            'version': json.loads((kit / 'tokens.json').read_text())['version'],
            'files': {str(p.relative_to(kit)): hashlib.sha256(p.read_bytes()).hexdigest() for p in files}}
target = repo / 'branding' / 'dot'
if target.is_symlink():
    raise ValueError('Brand directory must not be a symlink')
if target.exists():
    shutil.rmtree(target)
shutil.copytree(kit, target)
(target / 'source.json').write_text(json.dumps(manifest, indent=2) + '\n')
# Runtime exports are included in the same update PR as the snapshot.
exports = {'listen_app/static/css/dot-tokens.css': 'tokens.css'}
for destination, name in exports.items():
    output = repo / destination
    output.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(kit / name, output)
print('Updated dot. kit to ' + sha)

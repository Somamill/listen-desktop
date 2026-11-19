"""Brand snapshot provenance must stay truthful, even under optimized Python."""
import hashlib
import json
import pathlib
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = next(p for p in pathlib.Path(__file__).resolve().parents if (p / 'AGENTS.md').exists())
SCRIPT = next(p for p in [ROOT / 'Scripts/sync-dot-brand.py', ROOT / 'scripts/sync-dot-brand.py'] if p.exists())


class BrandSyncTests(unittest.TestCase):
    def fixture(self, folder):
        source = folder / 'source'
        kit = source / 'kit'
        kit.mkdir(parents=True)
        (kit / 'tokens.json').write_text('{"version":"1.0.0"}')
        (kit / 'tokens.css').write_text(':root {}')
        (kit / 'tokens.ts').write_text('export {};')
        self.git(source, 'init', '-q')
        self.commit(source)
        app = folder / 'app'
        scripts = app / SCRIPT.parent.name
        scripts.mkdir(parents=True)
        shutil.copyfile(SCRIPT, scripts / 'sync-dot-brand.py')
        (scripts / 'build-dot-theme.py').write_text('')
        target = app / 'branding/dot'
        target.mkdir(parents=True)
        (target / 'sentinel').write_text('existing snapshot')
        return source, scripts / 'sync-dot-brand.py', target

    def git(self, source, *args):
        return subprocess.check_output(['git', '-C', str(source), '-c', 'core.hooksPath=/dev/null',
            '-c', 'user.name=Brand test', '-c', 'user.email=brand-test@example.invalid', *args],
            text=True, stderr=subprocess.DEVNULL).strip()

    def commit(self, source):
        self.git(source, 'add', '.')
        self.git(source, 'commit', '-qm', 'fixture')

    def sync(self, script, source):
        return subprocess.run([sys.executable, '-O', str(script), str(source)],
            capture_output=True, text=True, timeout=15)

    def test_clean_kit_records_exact_revision_and_hashes(self):
        with tempfile.TemporaryDirectory() as temporary:
            source, script, target = self.fixture(pathlib.Path(temporary))
            (source / 'unrelated.md').write_text('not part of the kit')
            result = self.sync(script, source)
            self.assertEqual(result.returncode, 0, result.stderr)
            manifest = json.loads((target / 'source.json').read_text())
            self.assertEqual(manifest['commit'], self.git(source, 'rev-parse', 'HEAD'))
            for name, digest in manifest['files'].items():
                self.assertEqual(hashlib.sha256((target / name).read_bytes()).hexdigest(), digest)
            self.assertFalse((target / 'sentinel').exists())

    def test_invalid_sources_leave_existing_snapshot_untouched(self):
        for case in ['modified', 'staged', 'untracked', 'ignored', 'symlink', 'unexpected', 'oversized', 'nested']:
            with self.subTest(case=case), tempfile.TemporaryDirectory() as temporary:
                source, script, target = self.fixture(pathlib.Path(temporary))
                kit = source / 'kit'
                if case in ['modified', 'staged']:
                    (kit / 'tokens.css').write_text('changed')
                    if case == 'staged':
                        self.git(source, 'add', '.')
                elif case == 'untracked':
                    (kit / 'new.md').write_text('uncommitted')
                elif case == 'ignored':
                    (source / '.gitignore').write_text('*.tmp\n')
                    (kit / 'hidden.tmp').write_text('uncommitted')
                elif case == 'symlink':
                    (kit / 'link.md').symlink_to('tokens.css')
                    self.commit(source)
                elif case == 'unexpected':
                    (kit / 'run.sh').write_text('echo unexpected')
                    self.commit(source)
                elif case == 'oversized':
                    (kit / 'large.md').write_text('x' * 2_000_000)
                    self.commit(source)
                else:
                    source = kit
                result = self.sync(script, source)
                self.assertNotEqual(result.returncode, 0, case)
                self.assertEqual((target / 'sentinel').read_text(), 'existing snapshot')
                self.assertEqual([p.name for p in target.iterdir()], ['sentinel'])


if __name__ == '__main__':
    unittest.main()

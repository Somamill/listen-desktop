import base64
from datetime import datetime, timedelta
from pathlib import Path
import plistlib
import runpy
import uuid
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch


class SigningProfileTests(unittest.TestCase):
    def check_profiles(self, invalid=None):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            environment = {'GITHUB_ACTIONS': 'true', 'RUNNER_TEMP': str(root),
                           'GITHUB_ENV': str(root / 'environment'), 'DOT_TARGET': 'ios',
                           'ASC_KEY_ID': 'DUMMYKEY', 'APPLE_DISTRIBUTION_PASSWORD': 'dummy'}
            for name in ['APPLE_DISTRIBUTION_P12_BASE64', 'IOS_PROVISIONING_PROFILE_BASE64',
                         'IOS_WIDGETS_PROFILE_BASE64', 'IOS_SHARE_PROFILE_BASE64', 'ASC_API_KEY_P8_BASE64']:
                environment[name] = base64.b64encode(b'synthetic credential fixture').decode()

            def command(args, **kwargs):
                if args[1] == 'cms':
                    role = Path(args[-1]).stem
                    suffix = {'app': '', 'widgets': '.widgets', 'share': '.share'}[role]
                    profile = {'Name': 'Test ' + role, 'UUID': str(uuid.uuid5(uuid.NAMESPACE_URL, role)), 'TeamIdentifier': ['YJH8WWUVF3'],
                               'ExpirationDate': datetime.now() + timedelta(days=1),
                               'Entitlements': {'application-identifier': 'YJH8WWUVF3.io.github.somamill.listen.mobile' + suffix}}
                    if invalid == 'team': profile['TeamIdentifier'] = ['WRONGTEAM']
                    if invalid == 'expired': profile['ExpirationDate'] = datetime.now() - timedelta(days=1)
                    if invalid == 'development': profile['Entitlements']['get-task-allow'] = True
                    return SimpleNamespace(returncode=0, stdout=plistlib.dumps(profile))
                return SimpleNamespace(returncode=0, stdout=b'')

            with patch.dict('os.environ', environment), patch('subprocess.run', command), patch('urllib.request.urlretrieve'), patch.object(Path, 'home', return_value=root / 'home'):
                runpy.run_path(str(Path(__file__).with_name('ci-signing.py')))
            saved = (root / 'environment').read_text()
            self.assertIn('LISTEN_IOS_PROFILE_WIDGET=Test widgets', saved)
            self.assertIn('LISTEN_IOS_PROFILE_SHARE=Test share', saved)
            self.assertNotIn('synthetic credential', saved)

    def test_all_three_profiles_export_the_xcode_target_variables(self):
        self.check_profiles()

    def test_mismatched_expired_and_development_profiles_fail_closed(self):
        for invalid in ['team', 'expired', 'development']:
            with self.subTest(invalid=invalid), self.assertRaises(RuntimeError):
                self.check_profiles(invalid)


if __name__ == '__main__':
    unittest.main()

"""Run native regression suites on fresh, disposable iPhone and iPad simulators."""
import json
import os
from pathlib import Path
import re
import subprocess


def capture(*args):
    return subprocess.check_output(args, text=True, timeout=60).strip()


def verify_results(result):
    nodes = list(result.get('testNodes', []))
    passed = set()
    while nodes:
        node = nodes.pop()
        nodes.extend(node.get('children', []))
        if node.get('nodeType') == 'Test Case' and node.get('result') == 'Passed':
            passed.add(node['nodeIdentifier'].split('/')[0])
    assert {'ListenTests', 'ListenUITests'} <= passed, 'Both native logic and UI suites must run and pass'


def main():
    artifacts = Path(os.environ['RUNNER_TEMP']) / 'listen-qa'
    artifacts.mkdir(parents=True, exist_ok=True)
    derived = Path(os.environ['RUNNER_TEMP']) / 'listen-qa-derived'
    devices = json.loads(capture('xcrun', 'simctl', 'list', 'devices', 'available', '--json'))['devices']
    types = json.loads(capture('xcrun', 'simctl', 'list', 'devicetypes', '--json'))['devicetypes']
    runtimes = sorted((r for r in devices if 'SimRuntime.iOS-' in r),
                      key=lambda r: tuple(map(int, re.findall(r'\d+', r))), reverse=True)
    for family in ('iPhone', 'iPad'):
        matches = [(r, d) for r in runtimes for d in devices[r] if family in d['name']]
        if not matches:
            raise RuntimeError(f'No available {family} simulator runtime')
        matches = [match for match in matches if match[0] == matches[0][0]]
        preferred = 'Pro Max' if family == 'iPhone' else '13-inch'
        runtime, template = next((m for m in matches if preferred in m[1]['name']), matches[0])
        device_type = template.get('deviceTypeIdentifier') or next(t['identifier'] for t in types if t['name'] == template['name'])
        udid = capture('xcrun', 'simctl', 'create', f'dot-qa-sovo-{family}', device_type, runtime)
        try:
            subprocess.run(['xcrun', 'simctl', 'boot', udid], check=True, timeout=180)
            subprocess.run(['xcrun', 'simctl', 'bootstatus', udid, '-b'], check=True, timeout=300)
            with (artifacts / f'{family}-xcodebuild.log').open('w') as log:
                result = subprocess.run([
                    'xcodebuild', '-project', 'ios/Listen.xcodeproj', '-scheme', 'Listen',
                    '-destination', f'platform=iOS Simulator,id={udid}',
                    '-derivedDataPath', str(derived), '-jobs', '2',
                    '-resultBundlePath', str(artifacts / f'{family}.xcresult'),
                    '-parallel-testing-enabled', 'NO', '-test-timeouts-enabled', 'YES',
                    '-maximum-test-execution-time-allowance', '180', 'CODE_SIGNING_ALLOWED=NO', 'test',
                ], stdout=log, stderr=subprocess.STDOUT, timeout=1800)
            if result.returncode:
                print((artifacts / f'{family}-xcodebuild.log').read_text()[-16000:])
                raise RuntimeError(f'{family} native regression tests failed')
            verify_results(json.loads(capture('xcrun', 'xcresulttool', 'get', 'test-results', 'tests',
                                              '--path', str(artifacts / f'{family}.xcresult'), '--compact')))
            subprocess.run(['python3', 'ios/scripts/check_bundle.py',
                            str(derived / 'Build/Products/Debug-iphonesimulator/sovo.app')], check=True)
        finally:
            subprocess.run(['xcrun', 'simctl', 'shutdown', udid], check=False, timeout=60)
            subprocess.run(['xcrun', 'simctl', 'delete', udid], check=True, timeout=180)
    # Preserve result bundles and logs, not gigabytes of rebuildable intermediates.
    import shutil
    shutil.rmtree(derived)


if __name__ == '__main__':
    main()

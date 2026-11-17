import importlib.util
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('native_qa', Path(__file__).with_name('qa-simulator.py'))
qa = importlib.util.module_from_spec(spec)
spec.loader.exec_module(qa)


class NativeSimulatorSafetyTests(unittest.TestCase):
    def test_empty_or_partial_test_runs_cannot_pass(self):
        case = lambda name: {'nodeType': 'Test Case', 'result': 'Passed', 'nodeIdentifier': name + '/example()'}
        for nodes in ([], [case('ListenTests')], [case('ListenUITests')]):
            with self.assertRaises(AssertionError):
                qa.verify_results({'testNodes': nodes})
        qa.verify_results({'testNodes': [{'children': [case('ListenTests'), case('ListenUITests')]}]})

    def test_failed_boot_still_removes_only_the_created_device(self):
        def capture(*args):
            if 'devices' in args:
                return json.dumps({'devices': {'com.apple.CoreSimulator.SimRuntime.iOS-27-0': [
                    {'name': 'iPhone Custom QA', 'udid': 'personal-device', 'deviceTypeIdentifier': 'phone-type'}]}})
            if 'devicetypes' in args:
                return json.dumps({'devicetypes': [{'name': 'iPhone Test', 'identifier': 'phone-type'}]})
            if 'create' in args:
                return 'new-disposable-device'
            raise AssertionError(args)

        calls = []

        def run(args, **kwargs):
            calls.append(args)
            if 'boot' in args:
                raise RuntimeError('boot failed')

        with tempfile.TemporaryDirectory() as directory:
            with patch.dict(os.environ, RUNNER_TEMP=directory):
                with patch.object(qa, 'capture', capture), patch.object(qa.subprocess, 'run', run):
                    with self.assertRaisesRegex(RuntimeError, 'boot failed'):
                        qa.main()
        self.assertIn(['xcrun', 'simctl', 'shutdown', 'new-disposable-device'], calls)
        self.assertIn(['xcrun', 'simctl', 'delete', 'new-disposable-device'], calls)
        self.assertFalse(any('personal-device' in call for call in calls))


if __name__ == '__main__':
    unittest.main()

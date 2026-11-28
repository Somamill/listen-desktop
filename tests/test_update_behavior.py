from unittest.mock import Mock

import pytest
import requests

from listen_app import updates
from listen_app.server import create_app


def test_stable_architecture_cache_manual_and_offline(tmp_path, monkeypatch):
    monkeypatch.setenv('LISTEN_DATA_DIR', str(tmp_path))
    monkeypatch.setenv('LISTEN_DISABLE_UPDATE_CHECK', '1')
    monkeypatch.setattr(updates, 'ARCH', 'arm64')
    monkeypatch.setattr(updates, 'flavor', lambda: 'standard')
    base = 'https://github.com/Somamill/listen-desktop/releases'

    def release(version, arch='arm64', **flags):
        return dict(tag_name=f'v{version}', html_url=f'{base}/tag/v{version}',
                    assets=[dict(name=f'listen-{version}-macOS-{arch}.dmg', size=42,
                                 browser_download_url=f'{base}/download/v{version}/listen-{version}-macOS-{arch}.dmg')], **flags)

    response = Mock(content=b'[]')
    response.json.return_value = [release('99.0', 'x86_64'), release('98.0', draft=True),
                                  release('97.0', prerelease=True), release('96.0')]
    request = Mock(return_value=response)
    monkeypatch.setattr(updates.requests, 'get', request)
    automatic = updates.check()
    assert automatic['latest'] == '96.0' and automatic['available']
    assert request.call_args.args[0] == 'https://api.github.com/repos/Somamill/listen-desktop/releases'
    assert request.call_args.kwargs['allow_redirects'] is False
    request.side_effect = requests.ConnectionError('private details')
    assert updates.check() == automatic
    assert request.call_count == 1
    with pytest.raises(requests.ConnectionError):
        updates.check(force=True)
    assert updates.check() == automatic
    app = create_app()
    app.config['BOUND_PORT'] = 58432
    headers = {'X-Listen-Token': app.config['SERVICE_TOKEN']}
    client = app.test_client()
    reply = client.get('/api/update', base_url='http://127.0.0.1:58432', headers=headers)
    assert reply.status_code == 503 and 'private details' not in reply.get_data(as_text=True)
    status = '/api/transfers/status'
    assert app.test_client(use_cookies=False).get(status, base_url='http://127.0.0.1:58432').status_code == 401
    assert client.get(status, base_url='http://localhost:58432', headers=headers).status_code == 403
    assert client.get(status, base_url='http://127.0.0.1:58432', headers=headers).is_json


def test_automatic_update_recovers_after_offline(monkeypatch):
    check = Mock(side_effect=[requests.ConnectionError('offline'), {}])
    monkeypatch.setattr(updates, 'check', check)
    class Stop(Exception):
        pass
    sleep = Mock(side_effect=[None, Stop])
    monkeypatch.setattr(updates.time, 'sleep', sleep)
    with pytest.raises(Stop):
        updates.background()
    assert check.call_count == 2 and all(not call.args and not call.kwargs for call in check.call_args_list)
    assert [call.args for call in sleep.call_args_list] == [(3600,), (3600,)]

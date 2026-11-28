import json
import os
import tempfile
from pathlib import Path
from unittest.mock import Mock, patch
from listen_app import settings,updates
from listen_app.server import create_app


def test_current_tree_has_no_store_binary_inputs():
    root=Path(__file__).resolve().parents[1]
    assert not (root/'ios').exists()
    assert not (root/'app-store').exists()
    assert 'io.github.somamill.listen' in (root/'scripts/build_macos.py').read_text()
    assert 'io.github.somamill.listen.mobile' not in (root/'scripts/build_macos.py').read_text()
    assert 'Somamill/listen-desktop' in updates.REPOSITORY


@patch.object(updates,'flavor',return_value='standard')
def test_update_rejects_native_repo_and_prereleases(_flavor):
    response=Mock(content=b'[]')
    response.json.return_value=[
      {'tag_name':'v90','html_url':'https://github.com/Somamill/sovo/releases/tag/v90'},
      {'tag_name':'v80b1','html_url':'https://github.com/Somamill/listen-desktop/releases/tag/v80b1','prerelease':True},
      {'tag_name':'v1.0.0','html_url':'https://github.com/Somamill/listen-desktop/releases/tag/v1.0.0','assets':[{'name':'listen-1.0.0-macOS-'+updates.ARCH+'.zip','size':1,'browser_download_url':'https://github.com/Somamill/listen-desktop/releases/download/v1.0.0/listen-1.0.0-macOS-'+updates.ARCH+'.zip'}]}]
    with tempfile.TemporaryDirectory() as folder,patch.dict(os.environ,LISTEN_DATA_DIR=folder),patch('requests.get',return_value=response) as fetch:
      result=updates.check(force=True)
      assert result['latest']=='1.0.0'
      assert result['available']
      assert updates.check()==result
      assert fetch.call_count==1
      assert fetch.call_args.kwargs['allow_redirects'] is False


def test_interface_language_is_separate_from_audio_filters():
    with tempfile.TemporaryDirectory() as folder,patch.dict(os.environ,LISTEN_DATA_DIR=folder):
      cfg=settings.validate({'ui_language':'ar','languages':['English']})
      settings.atomic_json(Path(folder)/'settings.json',cfg)
      app=create_app();app.config['BOUND_PORT']=58432
      r=app.test_client().get('/settings',base_url='http://127.0.0.1:58432',headers={'X-Listen-Token':app.config['SERVICE_TOKEN']})
      assert r.status_code==200
      assert b'lang="ar" dir="rtl"' in r.data
      assert settings.load()['languages']==['English']


def test_language_negotiation_uses_supported_preference():
    with tempfile.TemporaryDirectory() as folder,patch.dict(os.environ,LISTEN_DATA_DIR=folder):
      app=create_app();app.config['BOUND_PORT']=58432
      r=app.test_client().get('/settings',base_url='http://127.0.0.1:58432',headers={'X-Listen-Token':app.config['SERVICE_TOKEN'],'Accept-Language':'de-DE,de;q=0.9,en;q=0.5'})
      assert b'lang="de"' in r.data


def test_requested_catalogs_are_complete_and_keep_placeholders():
    root=Path(__file__).resolve().parents[1]/'listen_app/locales'
    source=json.loads((root/'en.json').read_text())
    assert len(source)>=387
    for code in ('en','zh','es','ar','id','pt','fr','ja','ru','de'):
      rows=json.loads((root/(code+'.json')).read_text())
      assert set(rows)==set(source)
      assert all(isinstance(value,str) and value.strip() for value in rows.values())
      import re
      for key,value in rows.items():assert re.findall(r'\{[^{}]+\}',key)==re.findall(r'\{[^{}]+\}',value)
      assert rows['qBittorrent']=='qBittorrent'
      assert rows['http://127.0.0.1:8080']=='http://127.0.0.1:8080'


def test_rejected_client_settings_are_localized_without_changing_credentials():
    with tempfile.TemporaryDirectory() as folder,patch.dict(os.environ,LISTEN_DATA_DIR=folder):
      settings.atomic_json(Path(folder)/'settings.json',{'ui_language':'de'})
      app=create_app();app.config['BOUND_PORT']=58432
      r=app.test_client().post('/api/settings',base_url='http://127.0.0.1:58432',headers={'X-Listen-Token':app.config['SERVICE_TOKEN']},json={'theme':'malformed'})
      assert r.status_code==400
      assert r.json['error']=='Wähle ein unterstütztes Design.'
      assert settings.load()['theme']=='system'


def test_update_ignores_release_without_compatible_download():
    response=Mock(content=b'[]');response.json.return_value=[{'tag_name':'v99','html_url':'https://github.com/Somamill/listen-desktop/releases/tag/v99'}]
    with tempfile.TemporaryDirectory() as folder,patch.dict(os.environ,LISTEN_DATA_DIR=folder),patch('requests.get',return_value=response):
      assert updates.check(force=True)['available'] is False


def test_distribution_signing_uses_explicit_keychain_and_nested_runtime():
    import importlib.util
    path=Path(__file__).resolve().parents[1]/'scripts/build_macos.py'
    spec=importlib.util.spec_from_file_location('listen_build_macos',path);build=importlib.util.module_from_spec(spec);spec.loader.exec_module(build)
    with tempfile.TemporaryDirectory() as folder:
      app=Path(folder)/'listen.app';(app/'Contents').mkdir(parents=True)
      binary=app/'Contents/helper';binary.write_bytes(b'\xcf\xfa\xed\xfe'+b'test')
      (app/'Contents/config').write_text('not executable')
      with patch.object(build,'run') as run:
        build.sign_bundle(app,Path(folder)/'entitlements.plist','approved-identity','/private/isolated.keychain-db')
      assert run.call_count==2
      for row in run.call_args_list:
        args=row.args[0];assert '--timestamp' in args and '--options' in args and 'runtime' in args
        assert args[args.index('--keychain')+1]=='/private/isolated.keychain-db'
      assert run.call_args_list[-1].args[0][-1]==app


def test_open_library_missing_cover_is_not_a_blank_placeholder():
    from listen_app.covers import safe_url
    from urllib.parse import urlparse,parse_qs
    for url in ['https://covers.openlibrary.org/b/id/123-L.jpg','https://covers.openlibrary.org/b/id/123-L.jpg?default=true']:
      assert parse_qs(urlparse(safe_url(url)).query)['default']==['false']


def test_update_matches_build_variant_cache_and_exact_asset(tmp_path, monkeypatch):
    import requests

    def release(version, variants):
        tag = f'v{version}'
        base = f'https://github.com/{updates.REPOSITORY}/releases'
        assets = []
        for arch, suffix, extension in variants:
            name = f'listen-{version}-macOS-{arch}{suffix}.{extension}'
            assets.append({'name': name, 'size': 19, 'browser_download_url': f'{base}/download/{tag}/{name}'})
        return {'tag_name': tag, 'html_url': f'{base}/tag/{tag}', 'assets': assets}

    monkeypatch.setenv('LISTEN_DATA_DIR', str(tmp_path))
    monkeypatch.setattr(updates, 'ARCH', 'arm64')
    current_flavor = 'standard'
    monkeypatch.setattr(updates, 'flavor', lambda: current_flavor)
    wrong_url = release('6.0.0', [('arm64', '-embedded', 'dmg')])
    wrong_url['assets'][0]['browser_download_url'] += '.unrelated'
    rows = [
        wrong_url,
        release('5.0.0', [('arm64', '', 'dmg'), ('x86_64', '-embedded', 'dmg')]),
        release('4.0.0', [('arm64', '-embedded', 'zip'), ('arm64', '-embedded', 'dmg')]),
    ]
    response = Mock(content=b'[]')
    response.json.return_value = rows
    app = create_app()
    app.config['BOUND_PORT'] = 58432
    client = app.test_client()
    options = {'base_url': 'http://127.0.0.1:58432', 'headers': {'X-Listen-Token': app.config['SERVICE_TOKEN']}}
    with patch('requests.get', return_value=response) as fetch:
        assert client.get('/api/update?cached=1', **options).json == {'available': False}
        fetch.assert_not_called()
        assert updates.check()['latest'] == '5.0.0'
        current_flavor = 'embedded'
        assert client.get('/api/update?cached=1', **options).json == {'available': False}
        update = updates.check()
        assert update['asset'] == 'listen-4.0.0-macOS-arm64-embedded.dmg'
        assert update['download_url'].endswith('/v4.0.0/' + update['asset'])
        assert fetch.call_count == 2
        assert client.get('/api/update?cached=1', **options).json == update
        assert fetch.call_count == 2
        fetch.side_effect = requests.ConnectionError('offline')
        assert client.get('/api/update', **options).status_code == 503
        assert client.get('/api/update?cached=1', **options).json == update
        assert fetch.call_count == 3

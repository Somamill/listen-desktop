"""Stable desktop release checks; never downloads or executes an update."""
import argparse
import json
import threading
import time
import platform
from packaging.version import Version, InvalidVersion
from urllib.parse import quote
import requests
from . import __version__, embedded, settings

REPOSITORY = 'Somamill/listen-desktop'
LOCK = threading.Lock()
ARCH = 'arm64' if platform.machine() == 'arm64' else 'x86_64'

def flavor():
    return 'embedded' if embedded.available() else 'standard'

def cached():
    saved = settings.read_json(settings.data_dir() / 'update-check.json', {})
    if not isinstance(saved, dict):
        return None
    checked_at = saved.get('checked_at')
    if (saved.get('current') == __version__ and saved.get('arch') == ARCH
        and saved.get('flavor') == flavor() and type(checked_at) in (int, float)
        and 0 <= time.time() - checked_at < 86400):
        return saved
    return None

def check(force=False):
    path = settings.data_dir() / 'update-check.json'
    with LOCK:
        saved = None if force else cached()
        if saved is not None:
            return saved
        build_flavor = flavor()
        suffix = '-embedded' if build_flavor == 'embedded' else ''
        response = requests.get('https://api.github.com/repos/'+REPOSITORY+'/releases', params={'per_page': 20},
            headers={'Accept': 'application/vnd.github+json', 'User-Agent': 'listen-desktop/'+__version__}, timeout=8, allow_redirects=False)
        response.raise_for_status()
        if len(response.content) > 2_000_000:
            raise ValueError('Release response is too large.')
        rows = response.json()
        if not isinstance(rows, list):
            raise ValueError('Invalid release response.')
        choices = []
        for release in rows:
            if not isinstance(release, dict) or release.get('draft') or release.get('prerelease'):
                continue
            tag = release.get('tag_name')
            if not isinstance(tag, str):
                continue
            try:
                version = Version(tag.removeprefix('v'))
            except InvalidVersion:
                continue
            if version.is_prerelease or version.is_devrelease:
                continue
            release_base = 'https://github.com/' + REPOSITORY + '/releases/'
            tag_path = quote(tag, safe='')
            url = release_base + 'tag/' + tag_path
            if release.get('html_url') != url:
                continue
            name = f'listen-{version}-macOS-{ARCH}{suffix}'
            assets = release.get('assets')
            if not isinstance(assets, list):
                continue
            for extension in ('.dmg', '.zip'):
                filename = name + extension
                download = release_base + 'download/' + tag_path + '/' + filename
                if any(isinstance(asset, dict) and asset.get('name') == filename
                       and type(asset.get('size')) is int and 0 < asset['size'] < 4_000_000_000
                       and asset.get('browser_download_url') == download for asset in assets):
                    choices.append((version, url, filename, download))
                    break
        result = {'current': __version__, 'arch': ARCH, 'flavor': build_flavor, 'available': False,
                  'checked_at': time.time(), 'message': 'No public release is available yet.'}
        if choices:
            version, url, filename, download = max(choices)
            newer = version > Version(__version__)
            result.update(latest=str(version), available=newer, url=url,
                          asset=filename, download_url=download,
                          message='A newer release is available.' if newer else 'You are using the latest published version.')
        settings.atomic_json(path, result)
        return result

def background():
    while True:
        try:
            check()
        except (requests.RequestException, ValueError, OSError):
            pass  # The manual checker reports failures; startup remains available offline.
        time.sleep(3600)

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true', help='Check the official desktop release without installing it')
    parser.parse_args()
    try:
        print(json.dumps(check(force=True), ensure_ascii=False))
    except (requests.RequestException, ValueError, OSError) as error:
        parser.exit(2, 'Could not check releases: '+str(error)+'\n')

if __name__ == '__main__':
    main()
